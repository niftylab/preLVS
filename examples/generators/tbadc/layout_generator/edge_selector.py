##########################################################
#                                                      
# Edge selector Layout Generator          
# Contributors: J. Han
# Last Updated: 2025-05-03
#                                                      
##########################################################
import laygo2
import laygo2_tech as tech
import laygo2.object.database
import laygo2.interface.json

# Parameter definitions #############
# Design Variables

# Design hierarchy
libname = 'tbadc_generated'
cellname = 'edge_selector'
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
tlib = laygo2.interface.yaml.import_template(filename=export_path+'tbadc_generated_templates.yaml')

print('--------------------')
print(f'Creating {cellname}')
# Create a design, generate and place instances. 
dsn = laygo2.Design(name=cellname, libname=libname, pgrid=pg, rgrid=r23)
IAND0 = tlib['edge_selector_mux_nand'].generate(name='IAND0', transform='MX', netmap={'IN0':'DP_NP', 'IN1':'DN_PN', 'EN0':'ES_NP','EN1':'ES_PN', 
                                                                                      'OUT':'AND_OUT', 'mid0':'mid0_and', 'mid1':'mid1_and', 'VDD:':'VDD:', 'VSS:':'VSS:'})
IOR0  = tlib['edge_selector_mux_nand'].generate(name='IOR0', netmap={'IN0':'DN_NP', 'IN1':'DP_PN', 'EN0':'ES_NP','EN1':'ES_PN',
                                                                                      'OUT':'OR_OUT', 'mid0':'mid0_or', 'mid1':'mid1_or', 'VDD:':'VDD:', 'VSS:':'VSS:'})

# Place instance    
dsn.place(inst=[[IOR0],[IAND0]])

# Create and place wires.
print("Create wires")
rc = laygo2.RoutingMeshTemplate(grid=dsn.rgrid)
rc.add_trunk(name="res_np", index=[IAND0.p['EN0'].left.m, None], netname="ES_NP")
rc.add_trunk(name="res_pn", index=[IAND0.p['EN1'].left.m, None], netname="ES_PN")
rc.add_trunk(name="rdp_np", index=[IAND0.p['IN0A'].left.m-2, None], netname="DP_NP")
rc.add_trunk(name="rdn_pn", index=[IAND0.p['IN0A'].left.m-1, None], netname="DN_PN")
rc.add_trunk(name="rdn_np", index=[IAND0.p['IN0A'].left.m-1, None], netname="DN_NP")
rc.add_trunk(name="rdp_pn", index=[IAND0.p['IN0A'].left.m-2, None], netname="DP_PN")
rc.add_node(list(dsn.instances.values()))  # Add all instances to the routing mesh as nodes
rc.add_constraint(name="es_wire_matching", type="matching", trunk=["res_pn", "res_np"])
rinst = rc.generate()
dsn.place(inst=rinst)

# 6. Create pins.
pdp_np = dsn.pin(name='DP_NP', mn=rinst.p['rdp_np'])
pdn_pn = dsn.pin(name='DN_PN', mn=rinst.p['rdn_pn'])
pdn_np = dsn.pin(name='DN_NP', mn=rinst.p['rdn_np'])
pdp_pn = dsn.pin(name='DP_PN', mn=rinst.p['rdp_pn'])
pes_np = dsn.pin(name='ES_NP', mn=rinst.p['res_np'])
pes_pn = dsn.pin(name='ES_PN', mn=rinst.p['res_pn'])
pmid0_and = dsn.pin(name='mid0_and', mn=IAND0.p['mid0'])
pmid1_and = dsn.pin(name='mid1_and', mn=IAND0.p['mid1'])
por0_and = dsn.pin(name='mid0_or', mn=IOR0.p['mid0'])
por1_and = dsn.pin(name='mid1_or', mn=IOR0.p['mid1'])
pand_out = dsn.pin(name='AND_OUT', mn=IAND0.p['OUT'])
por_out = dsn.pin(name='OR_OUT', mn=IOR0.p['OUT'])

tech.generate_pwr_rail(dsn, grids, netname=['VDD', 'VSS', 'VDD', 'VSS', 'VDD'], vertical=False)

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

# lvs cell generation
# export_path_logic = "./laygo2_generators_private/logic/"
# tlib_logic = laygo2.import_template(filename=export_path_logic+'logic_generated_templates.yaml') 
# tap0 = tlib_logic['tap'].generate(name='tap0', transform='MX')
# tap1 = tlib_logic['tap'].generate(name='tap1')
# tap2 = tlib_logic['tap'].generate(name='tap2', transform='MX')
# tap3 = tlib_logic['tap'].generate(name='tap3')
# dsn.place(inst=[[tap0], [tap1], [tap2], [tap3]], mn=pg.bottom_right(IOR0))
# dsn.cellname = dsn.cellname+'_lvs'
# laygo2.export(dsn, tech=tech, filename=export_path_skill+libname+'_'+cellname+'.il')

