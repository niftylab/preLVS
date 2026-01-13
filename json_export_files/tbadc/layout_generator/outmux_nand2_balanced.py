##########################################################
#                                                           
# NAND Layout Gernerator                 
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
cellname = 'outmux_nand2_balanced'
nfn=4
nfp=8
# Design hierarchy
libname = 'tbadc_generated'
export_path = './laygo2_generators_private/tbadc/' 
export_path_skill = export_path+'skill/' 
export_path_db      = './laygo2_generators_private/prj_db/tbadc/' # Path for JSON DB export
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
in0  = tnmos.generate(name='MN0', transform='MX', params={'nf': nfn, 'tie': 'S', 'rtrackswap': True},
                      netmap={'D':'N0','G':'A', 'S':'VSS:', 'RAIL':'VSS:'})
in2  = tnmos.generate(name='MN2', transform='MX', params={'nf': nfn, 'rtrackswap': False},
                      netmap={'D':'O','G':'B', 'S':'N0', 'RAIL':'VSS:'})
in1  = tnmos.generate(name='MN1', params={'nf': nfn, 'tie': 'S', 'rtrackswap': True},
                      netmap={'D':'N1','G':'B', 'S':'VSS:', 'RAIL':'VSS:'})
in3  = tnmos.generate(name='MN3', params={'nf': nfn, 'rtrackswap': False},
                      netmap={'D':'O','G':'A', 'S':'N1', 'RAIL':'VSS:'})
ip0  = tpmos.generate(name='MP0', params={'nf': nfp, 'tie': 'S', 'rtrackswap': True},
                      netmap={'D':'O','G':'B', 'S':'VDD:', 'RAIL':'VDD:'})
ip1  = tpmos.generate(name='MP1', transform='MX', params={'nf': nfp, 'tie': 'S', 'rtrackswap': True},
                      netmap={'D':'O','G':'A', 'S':'VDD:', 'RAIL':'VDD:'})
pspace0 = templates['pmos4_fast_space_1x'].generate(name = 'pspace0', shape = [2,1], netmap={'VDD:':'VDD:'})
pspace1 = templates['pmos4_fast_space_1x'].generate(name = 'pspace1', shape = [2,1], netmap={'VDD:':'VDD:'})
dsn.place(inst=[[pspace0, ip0], [in0, in2], [in1,in3], [pspace1, ip1]], pattern='stripe_left')

# Route wires
#_trks = dsn.get_routing_tracks(grid=r23)[0]
rc = laygo2.RoutingMeshTemplate(grid=dsn.rgrid)
rc.add_trunk(name="rA0", index=[in0.p['G'].left.m - 1, None], netname="A", dedicated=[in0, ip1])
rc.add_trunk(name="rA1", index=[in3.p['G'].left.m - 1, None], netname="A", dedicated=[in3, ip1])
rc.add_trunk(name="rB0", index=[in1.p['G'].left.m + 0, None], netname="B", dedicated=[in1, ip0])
rc.add_trunk(name="rB1", index=[in2.p['G'].left.m - 1, None], netname="B", dedicated=[in2, ip0])
rc.add_trunk(name="rN0", index=[None, in0.p['D'].left.n], netname="N0")
rc.add_trunk(name="rN1", index=[None, in1.p['D'].left.n], netname="N1")
rc.add_trunk(name="rO", index=[ip0.p['D'].right.m + 1, None], netname="O")
rc.add_node(dsn.virtual_instances)  # Add all instances to the routing mesh as nodes
rinst = rc.generate()
dsn.place(inst=rinst)

# 6. Create pins.
pA = dsn.pin(name='A', mn=rinst.p['rA0'])
pB = dsn.pin(name='B', mn=rinst.p['rB0'])
pO = dsn.pin(name='O', mn=rinst.p['rO'])
tech.generate_pwr_rail(dsn, grids, netname=['VDD', 'VSS', 'VDD'], vertical=False)

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
