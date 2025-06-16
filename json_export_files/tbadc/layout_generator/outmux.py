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
cellname = 'outmux'
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
I0 = tlib['outmux_nand2'].generate(name='I0', transform='MX', netmap={'B':'en0', 'O':'mid0', 'A':'IN0', 'VDD:':'VDD:', 'VSS:':'VSS:'})
I1 = tlib['outmux_nand2'].generate(name='I1', netmap={'B':'en1bb', 'O':'mid1', 'A':'IN1', 'VDD:':'VDD:', 'VSS:':'VSS:'})
I2 = tlib['outmux_nand2_balanced'].generate(name='I2', netmap={'A':'mid0', 'B':'mid1', 'O':'OUT', 'VDD:':'VDD:', 'VSS:':'VSS:'})
IINV0 = tlib['outmux_inv_nrtrackswap_2x'].generate(name='IINV0', transform='MX', netmap={'I':'EN1', 'O':'en0', 'VDD:':'VDD:', 'VSS:':'VSS:'})
IINV1 = tlib['outmux_inv_nrtrackswap_2x'].generate(name='IINV1', netmap={'I':'en0', 'O':'en1bb', 'VDD:':'VDD:', 'VSS:':'VSS:'})
dsn.place(inst=[[IINV0, 2, I0],[IINV1, 2, I1]])
dsn.place(inst=[[I2]], mn = I0.bottom_right)
tech.fill_by_instance(dsn, grids, tlib, tlib, 'space_2x', iter_type=('MX', 'R0'))

# Create and place wires.
rc = laygo2.RoutingMeshTemplate(grid=dsn.rgrid)
rc.add_trunk(name="rmid0", index=[I2.p['A'].left.m, None], netname="mid0")
rc.add_trunk(name="rmid1", index=[I2.p['B'].left.m, None], netname="mid1")
rc.add_trunk(name="ren1bb", index=[None, IINV1.p['O'].top.n], netname="en1bb")
rc.add_trunk(name="ren00", index=[None, IINV0.p['O'].top.n], netname="en0", dedicated=[IINV0, IINV1])
rc.add_trunk(name="ren01", index=[None, IINV0.p['O'].bottom.n], netname="en0", dedicated=[IINV0, I0])
rc.add_node(dsn.instances)  # Add all instances to the routing mesh as nodes
rinst = rc.generate()
dsn.place(inst=rinst)


# Create pins.
pin0 = dsn.pin(name='IN0', mn=I0.p['A'])
pin1 = dsn.pin(name='IN1', mn=I1.p['A'])
#pen0 = dsn.pin(name='EN0', mn=I0.p['B'])
#pen1 = dsn.pin(name='EN1', mn=I1.p['B'])
pen1 = dsn.pin(name='EN1', mn=IINV0.p['I'])
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
# export_path_logic = "./laygo2_generators_private/logic/"
# tlib_logic = laygo2.import_template(filename=export_path_logic+'logic_generated_templates.yaml') 
# tap0 = tlib_logic['tap'].generate(name='tap0', transform='MX')
# tap1 = tlib_logic['tap'].generate(name='tap1')
# dsn.place(inst=[[tap0], [tap1]], mn=I2.bottom_right)
# dsn.cellname = dsn.cellname+'_lvs'
# laygo2.export(dsn, tech=tech, filename=export_path_skill+libname+'_'+cellname+'.il')

