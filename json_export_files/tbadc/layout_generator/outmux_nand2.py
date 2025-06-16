##########################################################
#                                                           
# Output MUX NAND Layout Generator                 
# Contributors: J. Choi, J. Han
# Last Updated: 2025-04-21
#                                                           
##########################################################
import laygo2
import laygo2_tech as tech
import laygo2.object.database
import laygo2.interface.json

# Parameter definitions #############
# Design Variables
cellname = 'outmux_nand2'
nf = 4
# Design hierarchy
libname = 'tbadc_generated'
export_path = './laygo2_generators_private/tbadc/' 
export_path_skill = export_path+'skill/' 
export_path_db      = './laygo2_generators_private/prj_db/tbadc/' # Path for JSON DB export
# End of parameter definitions ######

# Generation start ##################
# Load templates and grids.
templates, grids = tech.load_templates_and_grids()
tlib = laygo2.import_template(filename=export_path + 'tbadc_generated_templates.yaml')
tpmos, tnmos = templates['pmos'], templates['nmos']
pg, r23 = grids['placement_basic'], grids['routing_23_cmos']
r12 = grids['routing_12_cmos']

print('--------------------')
print(f'Creating {cellname}')
# Create a design, generate and place instances. 
dsn = laygo2.Design(name=cellname, libname=libname, pgrid=pg, rgrid=r23)
in0  = tnmos.generate(name='MN0', params={'nf': nf, 'tie': 'S', 'rtrackswap': True},
                      netmap={'D':'N0','G':'B', 'S':'VSS:', 'RAIL':'VSS:'})
ip0  = tpmos.generate(name='MP0', transform='MX', params={'nf': nf, 'tie': 'S', 'rtrackswap': True},
                      netmap={'D':'O','G':'B', 'S':'VDD:', 'RAIL':'VDD:'})
in1  = tnmos.generate(name='MN1',                 params={'nf': nf, 'rtrackswap': False},
                      netmap={'D':'O','G':'A','S':'N0', 'RAIL':'VSS:'})
ip1  = tpmos.generate(name='MP1', transform='MX', params={'nf': nf, 'tie': 'S', 'rtrackswap': True},
                      netmap={'D':'O','G':'A', 'S':'VDD:', 'RAIL':'VDD:'})
dsn.place(inst=[[in0, 2, in1],[ip0, 2, ip1]])

# Route wires
#_trks = dsn.get_routing_tracks(grid=r23)[0]
rc = laygo2.RoutingMeshTemplate(grid=dsn.rgrid)
rc.add_trunk(name="rA",  index=[in1.p['G'].left.m - 3, None], netname="A")
rc.add_trunk(name="rB",  index=[in0.p['G'].left.m - 1, None], netname="B")
rc.add_trunk(name="N0",  index=[None, in0.p['D'].left.n],     netname="N0")
rc.add_trunk(name="rO0", index=[in1.p['D'].left.m + 1, None], netname="O")
rc.add_trunk(name="rO1", index=[in1.p['D'].left.m + 3, None], netname="O")
rc.add_node(dsn.virtual_instances)  # Add all instances to the routing mesh as nodes
rinst = rc.generate()
dsn.place(inst=rinst)
tech.fill_by_instance(dsn, grids, tlib, tlib, 'space_2x', iter_type=('R0', 'MX'))

# Create pins.
pinB  = dsn.pin(name='B', mn=rinst.p['rB'])
pinA  = dsn.pin(name='A', mn=rinst.p['rA'])
pout0 = dsn.pin(name='O', mn=ip1.p['D'], netname='O')
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

