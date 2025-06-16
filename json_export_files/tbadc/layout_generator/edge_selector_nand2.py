##########################################################
#                                                           
# NAND Layout Gernerator                 
# Contributors: Created J. Choi    
# Last Updated: 2024-10-10
#                                                           
##########################################################

import numpy as np
import laygo2
import laygo2_tech as tech
import laygo2.object.database
import laygo2.interface.json

# Parameter definitions #############
# Design Variables
nf = 4

# Templates
tpmos_name = 'pmos'
tnmos_name = 'nmos'
tntap_name = 'ntap'
tptap_name = 'ptap'

# Grids
pg_name = 'placement_basic'
r12_name = 'routing_12_cmos'
r23_name = 'routing_23_cmos'

# Design hierarchy
libname = 'tbadc_generated'
# Layout generation path is set to "export_path/libname/cellname".
export_path = './laygo2_generators_private/tbadc/' 
# SKILL file generation path is set to "export_path_skill/libname_cellname.il"
export_path_skill = export_path+'skill/' 
export_path_db      = './laygo2_generators_private/prj_db/tbadc/' # Path for JSON DB export
# End of parameter definitions ######

# Generation start ##################
# 1. Load templates and grids.
print("Load templates")
templates = tech.load_templates()
tpmos, tnmos = templates[tpmos_name], templates[tnmos_name]
tntap, tptap = templates[tntap_name], templates[tptap_name]

print("Load grids")
grids = tech.load_grids(templates=templates)
pg, r12, r23 = grids[pg_name], grids[r12_name], grids[r23_name]

cellname = 'edge_selector_nand2'
print('--------------------')
print(f'Creating {cellname}')
 
# Create a design hierarchy
dsn = laygo2.Design(name=cellname, libname=libname, pgrid=pg, rgrid=r23)

# 3. Create istances.
print("Create instances")
in0  = tnmos.generate(name='MN0', params={'nf': nf, 'tie': 'S', 'rtrackswap': True},
                      netmap={'D':'N0','G':'B', 'S':'VSS:', 'RAIL':'VSS:'})
ip0  = tpmos.generate(name='MP0', transform='MX', params={'nf': nf, 'tie': 'S', 'rtrackswap': True},
                      netmap={'D':'O','G':'B', 'S':'VDD:', 'RAIL':'VDD:'})
in1  = tnmos.generate(name='MN1',                 params={'nf': nf, 'rtrackswap': False},
                      netmap={'D':'O','G':'A','S':'N0', 'RAIL':'VSS:'})
ip1  = tpmos.generate(name='MP1', transform='MX', params={'nf': nf, 'tie': 'S', 'rtrackswap': True},
                      netmap={'D':'O','G':'A', 'S':'VDD:', 'RAIL':'VDD:'})

# 4. Place instances.
dsn.place(inst=[[in0, in1],[ip0, ip1]])

# 5. Create and place wires.
print("Create wires")
#_trks = dsn.get_routing_tracks(grid=r23)[0]
rc = laygo2.RoutingMeshTemplate(grid=dsn.rgrid)
rc.add_trunk(name="N0",  index=[None, in0.p['D'].left.n],     netname="N0")
rc.add_trunk(name="rO0", index=[in1.p['D'].left.m + 1, None], netname="O")
rc.add_trunk(name="rO1", index=[in1.p['D'].left.m + 3, None], netname="O")
rc.add_node(dsn.virtual_instances)  # Add all instances to the routing mesh as nodes
rinst = rc.generate()
dsn.place(inst=rinst)

# 6. Create pins.
pinB0 = dsn.pin(name='B0', mn=in0.p['G'], netname='B')
pinB1 = dsn.pin(name='B1', mn=ip0.p['G'], netname='B')
pinA0 = dsn.pin(name='A0', mn=in1.p['G'], netname='A')
pinA1 = dsn.pin(name='A1', mn=ip1.p['G'], netname='A')
pout0 = dsn.pin(name='O',  mn=ip1.p['D'], netname='O')
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

