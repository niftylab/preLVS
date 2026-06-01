#########################################################
#                                                                   
# Inverter for TDC-DCDL Ncap with PMOS switch (2x)
# Contributors: J. Han    
# Last Updated: 2025-04-21
#                                                        
#########################################################

import laygo2
import laygo2_tech as tech
import laygo2.object.database
import laygo2.interface.json

# Parameter definitions #############
# Design Variables
cellname = 'tdc_dcdl_ncap_psw_2x'
nf = 2
# Design hierarchy
libname = 'tbadc_generated'
export_path = './laygo2_generators_private/tbadc/'
export_path_skill = export_path + 'skill/'
export_path_db      = './laygo2_generators_private/prj_db/tbadc/' # Path for JSON DB export
# End of parameter definitions ######

# Generation start ##################

# Load templates and grids.
templates, grids = tech.load_templates_and_grids()
tpmos, tnmos = templates['pmos'], templates['nmos']
pg, r12, r23 = grids['placement_basic'], grids['routing_12_cmos'], grids['routing_23_cmos']

print('--------------------')
print(f'Creating {cellname}')
# Create a design, generate and place instances. 
dsn = laygo2.Design(name=cellname, libname=libname, pgrid=pg, rgrid=r23)
ip0 = tpmos.generate(name='MP0_core', transform='MX', params={'nf': nf, "rtrackswap": True}, netmap={'G': 'ENB', 'D': 'cplus', 'S': 'IN', 'RAIL': 'VDD:'})
in0 = tnmos.generate(name='MN0_core', params={'nf': nf, 'tie': 'S'}, netmap={'G': 'cplus', 'D': 'VSS:', 'I':'VSS:', 'RAIL': 'VSS:'})
dsn.place(inst=[[in0], [ip0]])
# Route wires
# - CPLUS
_mn = [ip0.p['D'], in0.p['G']]
_track = [ip0.p['D'].right.m, None]
rCP0 = dsn.route(mn=_mn, track=_track)[-1]
# - in0 to VSS
dsn.route(grid=r12, mn=[in0.p['D'],in0.p['RAIL']], via_tag=[False,True])
_mn = ip0.p['G'].left
renb = dsn.route(mn=[_mn, _mn+[-1,0], dsn.rgrid(_mn)+[-1,-2]])[-1]
# - Rail
tech.generate_pwr_rail(dsn,grids,netname=['VSS','VDD'],vertical=False)
# Create pins.
pENB0 = dsn.pin(name='ENB', mn=renb)
pIN0 = dsn.pin(name='IN', mn=ip0.p['S'])
pCPLUS0 = dsn.pin(name='cplus', mn=rCP0)
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
