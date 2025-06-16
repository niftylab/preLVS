#########################################################
#                                                                   
# VTC NAND2
# Contributors: H. Jeong, J. Han 
# Last Updated: 2025-04-17 
#                                                        
#########################################################
import laygo2
import laygo2_tech as tech
import laygo2.object.database
import laygo2.interface.json

export_path_db      = './laygo2_generators_private/prj_db/tbadc/' # Path for JSON DB export

# Parameter definitions #############
# Design Variables

# Design hierarchy
libname = 'tbadc_generated'
cellname = 'vtc_nand2'
export_path = './laygo2_generators_private/tbadc/' 
export_path_skill = export_path+'skill/' 
# End of parameter definitions ######

# Generation start ##################
# Load templates and grids.
templates, grids = tech.load_templates_and_grids()
#tpmos, tnmos = templates['pmos'], templates['nmos']
pg, r23, r34 = grids['placement_basic'], grids['routing_23_cmos'], grids['routing_34_cmos']
r12 = grids['routing_12_cmos']
tlib = laygo2.import_template(filename=export_path+'tbadc_generated_templates.yaml')

print('--------------------')
print(f'Creating {cellname}')
# Create a design, generate and place instances. 
dsn = laygo2.Design(name=cellname, libname=libname, pgrid=pg, rgrid=r23)
nand_half0  = tlib['vtc_nand2_half'].generate(name='nand_half0')
nand_half1  = tlib['vtc_nand2_half'].generate(name='nand_half1', transform='MX')
#dsn.place(inst=nand_half0, mn=[0,0])
#dsn.place(inst=nand_half1, mn=pg.mn.top_left(nand_half0)+pg.mn.height_vec(nand_half1))
dsn.place(inst=[[nand_half0],[nand_half1]])
# Create and place wires.

#IN_A
_track = [r23.mn(nand_half0.pins['G_in1'])[0,0], None]
mn_list = []
mn_list.append(r23.mn(nand_half0.pins['G_in1'])[1])
mn_list.append(r23.mn(nand_half1.pins['G_in1'])[1])
mn_list.append(r23.mn(nand_half1.pins['G_ip0'])[1])
rina0 = dsn.route_via_track(grid=r23, mn=mn_list, track=_track)

_mn = [r34.mn(nand_half1.pins['G_in0'])[0]- [1,1]]
_mn.append([r34.mn(nand_half0.pins['G_in1'])[0,0], r34.mn(nand_half1.pins['G_in0'])[0,1]-1]) 
rina1, _ = dsn.route(grid=r34, mn=_mn, via_tag=[False, True])


#IN_B
_track = [r23.mn(nand_half0.pins['G_in0'])[1,0], None]
mn_list = []
mn_list.append(r23.mn(nand_half0.pins['G_in0'])[0])
mn_list.append(r23.mn(nand_half1.pins['G_in0'])[0])
mn_list.append(r23.mn(nand_half0.pins['G_ip0'])[0])
rinb0 = dsn.route_via_track(grid=r23, mn=mn_list, track=_track)

_mn = [r34.mn(nand_half0.pins['G_in0'])[0]- [1,-1]]
_mn.append([r34.mn(nand_half0.pins['G_in0'])[1,0], r34.mn(nand_half0.pins['G_in0'])[0,1]+1]) 
rinb1, _ = dsn.route(grid=r34, mn=_mn, via_tag=[False, True])
 
# OUT
mn_list = []
mn_list.append(r23.mn(nand_half0.pins['O'])[0])
mn_list.append(r23.mn(nand_half1.pins['O'])[1])
rout0 = dsn.route(grid=r23, mn=mn_list, via_tag=[False, False])

# Rails
tech.generate_pwr_rail(dsn, grids, netname=['VSS', 'VDD'], vertical=False)

# Create pins.
pout0 = dsn.pin(name='O', grid=r23, mn=rout0)
pina0 = dsn.pin(name='A', grid=r34, mn=rina1)
pinb0 = dsn.pin(name='B', grid=r34, mn=rinb1)

# Export design
# laygo2.export(dsn, tech=tech, filename=export_path_skill+libname+'_'+cellname+'.il')
laygo2.export_template(dsn, filename=f"{export_path}{libname}_templates.yaml", mode='append')

# test jSON DB export
grid_table = dict()
grid_table['M1'] = r12
grid_table['M2'] = r23
grid_table['M3'] = r34
grid_table['M4'] = r34
exporter = laygo2.object.database.DesignExporter(dsn, grid_table, lib_ref = "laygo2_generators_private/prj_db/tbadc/library.yaml")
nat_dict = exporter.export_to_dict()
laygo2.interface.json.export_dict(nat_dict, filename=export_path_db+libname+'_db.json', mode='append')