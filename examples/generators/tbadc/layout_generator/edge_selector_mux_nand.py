##########################################################
#                                                           
# Output MUX Layout Generator               
# Contributors: J. Han
# Last Updated: 2025-04-21
#                                                           
##########################################################
import laygo2
import laygo2_tech as tech
import laygo2.object.database
import laygo2.interface.json

# Parameter definitions #############
# Design Variables
cellname = 'edge_selector_mux_nand'
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
pg, r23 = grids['placement_basic'], grids['routing_23_cmos']
r12 = grids['routing_12_cmos']

print('--------------------')
print(f'Creating {cellname}')
# Create a design, generate and place instances. 
dsn = laygo2.Design(name=cellname, libname=libname, pgrid=pg, rgrid=r23)
I0 = tlib['edge_selector_nand2'].generate(name='I0', transform='MX', netmap={'A':'EN0', 'O':'mid0', 'B':'IN0', 'VDD:':'VDD:', 'VSS:':'VSS:'})
I1 = tlib['edge_selector_nand2'].generate(name='I1', netmap={'A':'EN1', 'O':'mid1', 'B':'IN1', 'VDD:':'VDD:', 'VSS:':'VSS:'})
I2 = tlib['edge_selector_nand2_balanced'].generate(name='I2', netmap={'A':'mid0', 'B':'mid1', 'O':'OUT', 'VDD:':'VDD:', 'VSS:':'VSS:'})
dsn.place(inst=[[I0],[I1]])
dsn.route(mn=[I0.p['A0'].left, I0.p['A0'].right])
dsn.place(inst=[[I2]], mn = I0.bottom_right)

# Create and place wires.
rc = laygo2.RoutingMeshTemplate(grid=dsn.rgrid)
rc.add_trunk(name="rmid0", index=[I2.p['A'].left.m, None], netname="mid0")
rc.add_trunk(name="rmid1", index=[I2.p['B'].left.m, None], netname="mid1")
rc.add_trunk(name="ren0", index=[I0.p['A0'].left.m-1, None], netname="EN0")
rc.add_trunk(name="ren1", index=[I0.p['A0'].left.m-0, None], netname="EN1")
rc.add_node(dsn.instances)  # Add all instances to the routing mesh as nodes
rinst = rc.generate()
dsn.place(inst=rinst)

# Create pins.
pin0 = dsn.pin(name='IN0A', mn=I0.p['B0'], netname='IN0')
pin0 = dsn.pin(name='IN0B', mn=I0.p['B1'], netname='IN0')
pin1 = dsn.pin(name='IN1A', mn=I1.p['B0'], netname='IN1')
pin1 = dsn.pin(name='IN1B', mn=I1.p['B1'], netname='IN1')
pen0 = dsn.pin(name='EN0', mn=rinst.p['ren0'])
pen1 = dsn.pin(name='EN1', mn=rinst.p['ren1'])
pmid0 = dsn.pin(name='mid0', mn=I0.p['O'])
pmid1 = dsn.pin(name='mid1', mn=I1.p['O'])
pout = dsn.pin(name='OUT', mn=I2.p['O'])
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

# lvs cell generation
export_path_logic = "./laygo2_generators_private/logic/"
tlib_logic = laygo2.import_template(filename=export_path_logic+'logic_generated_templates.yaml') 
tap0 = tlib_logic['tap'].generate(name='tap0', transform='MX')
tap1 = tlib_logic['tap'].generate(name='tap1')
dsn.place(inst=[[tap0], [tap1]], mn=I2.bottom_right)
dsn.cellname = dsn.cellname+'_lvs'
laygo2.export(dsn, tech=tech, filename=export_path_skill+libname+'_'+cellname+'.il')

