##########################################################
#                                                              
# Transmission Gate Layout Generator                
# Contributors: T. Shin, S. Park, Y. Oh, T. Kang        
# Last Update: 2024-09-16
#                                                              
##########################################################
import laygo2
import laygo2_tech as tech
import laygo2.object.database
import laygo2.interface.json

export_path_db      = './laygo2_generators_private/prj_db/tbadc/' # Path for JSON DB export

# Parameter definitions #############
# Design Variables
nf = 2

# Design hierarchy
libname = 'tbadc_generated'
cellname = f'zero_inj_tgate_{nf}x'
export_path = './laygo2_generators_private/tbadc/' 
export_path_skill = export_path+'skill/' 
# End of parameter definitions ######

# Generation start ##################
# Load templates and grids.
templates, grids = tech.load_templates_and_grids()
tpmos, tnmos = templates['pmos'], templates['nmos']
pg, r23 = grids['placement_basic'], grids['routing_23_cmos']
r12 = grids['routing_12_cmos']

print('--------------------')
print(f'Creating {cellname}')
# Create a design, generate and place instances. 
dsn = laygo2.Design(name=cellname, libname=libname, pgrid=pg, rgrid=r23)
in0 = tnmos.generate(name='MN0',                 params={'nf':nf}, netmap={'G':'EN','D':'O','S':'I','RAIL':'VSS:'})
ip0 = tpmos.generate(name='MP0', transform='MX', params={'nf':nf}, netmap={'G':'ENB','D':'O', 'S':'I', 'RAIL':'VDD:'}) 
nspace0 = templates['nmos4_fast_space_1x'].generate(name='nspace0', shape=[2,1], netmap={'VDD':'VDD','VSS':'VSS'})
pspace0 = templates['pmos4_fast_space_1x'].generate(name='pspace0', shape=[2,1], transform='MX', netmap={'VDD':'VDD','VSS':'VSS'})
dsn.place(inst=[[nspace0, in0], [pspace0, ip0]])

# Create and place wires.
# IN
_mn = [r23(in0.p['S'])[0], r23(ip0.p['S'])[0]]
vin0, rin0, vin1 = dsn.route(grid=r23, mn=_mn, via_tag=[True, True])
# OUT
_mn = [r23(in0.p['D'])[1], r23(ip0.p['D'])[1]]
vout0, rout0, vout1 = dsn.route(grid=r23, mn=_mn, via_tag=[True, True])
# EN
_mn = [r23(in0.p['G'])[0], r23(in0.p['G'])[0]+[-3,0]]
ren0, ven0 = dsn.route(grid=r23, mn=_mn, via_tag=[False, True])
_mn = [r23(ren0)[0], r23(ren0)[0]+[0,2]]
ren1 = dsn.route(grid=r23, mn=_mn)
# ENB
_mn = [r23(ip0.p['G'])[0], r23(ip0.p['G'])[0]+[-2,0]]
renb0, venb0 = dsn.route(grid=r23, mn=_mn, via_tag=[False, True])
_mn = [r23(renb0)[0]+[0,-2], r23(renb0)[0]]
renb1 = dsn.route(grid=r23, mn=_mn)
 
# Create pins.
pin0 = dsn.pin(name='I', mn=rin0)
pen0 = dsn.pin(name='EN',  mn=ren1)
penb0 = dsn.pin(name='ENB',mn=renb1)
pout0 = dsn.pin(name='O', mn=rout0)
tech.generate_pwr_rail(dsn, grids, netname=['VSS', 'VDD'], vertical=False)

# Export design
# laygo2.export(dsn, tech=tech, filename=export_path_skill+libname+'_'+cellname+'.il')
laygo2.export_template(dsn, filename=f"{export_path}{libname}_templates.yaml", mode='append')

# test jSON DB export
grid_table = dict()
grid_table['M1'] = r12
grid_table['M2'] = r23
grid_table['M3'] = r23
exporter = laygo2.object.database.DesignExporter(dsn, grid_table, lib_ref = "laygo2_generators_private/prj_db/tbadc/library.yaml")
nat_dict = exporter.export_to_dict()
laygo2.interface.json.export_dict(nat_dict, filename=export_path_db+libname+'_db.json', mode='append')
