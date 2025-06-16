##########################################################
#                                                      
# tdc zero_inj Layout Generator          
# Contributors: J. Han
# Last Updated: 2025-04-22
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
cellname = 'zero_inj'
export_path = './laygo2_generators_private/tbadc/' 
export_path_skill = export_path+'skill/' 
export_path_db      = './laygo2_generators_private/prj_db/tbadc/'
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
inor0 = tlib['zero_inj_nor2_inp_6x'].generate(name='INR0', transform='MX', netmap={'A':'INP', 'B':'CLKREF', 'O':'norp', 'VSS:':'VSS:', 'VDD:':'VDD:'})
inor1 = tlib['zero_inj_nor2_inn_6x'].generate(name='INR1', transform='MX', netmap={'A':'INN', 'B':'CLKREF', 'O':'norn', 'VSS:':'VSS:', 'VDD:':'VDD:'})
iinv0 = tlib['zero_inj_inv_4x'].generate(name='IINV0', transform='MX', netmap={'I':'norp', 'O':'ORP', 'VSS:':'VSS:', 'VDD:':'VDD:'})
iinv1 = tlib['zero_inj_inv_4x'].generate(name='IINV1', transform='MX', netmap={'I':'norn', 'O':'ORN', 'VSS:':'VSS:', 'VDD:':'VDD:'})
iinv2 = tlib['zero_inj_inv_rtrackswap_2x'].generate(name='IINV2', transform='R0', netmap={'I':'SHORT', 'O':'enb', 'VSS:':'VSS:', 'VDD:':'VDD:'})
iinv3 = tlib['zero_inj_inv_2x'].generate(name='IINV3', transform='R0', netmap={'I':'enb', 'O':'en', 'VSS:':'VSS:', 'VDD:':'VDD:'})
itg0 = tlib['zero_inj_tgate_2x'].generate(name='ITG0', transform='R0', netmap={'I':'norp', 'O':'norn', 'EN':'en', 'ENB':'enb', 'VSS:':'VSS:', 'VDD:':'VDD:'})
itg1 = tlib['zero_inj_tgate_2x'].generate(name='ITG1', transform='MY', netmap={'I':'norn', 'O':'norp', 'EN':'en', 'ENB':'enb', 'VSS:':'VSS:', 'VDD:':'VDD:'})


# Place instances.
dsn.place(inst = [[inor1, iinv1], [iinv2, iinv3, itg0, itg1], [inor0, iinv0]], pattern='stripe_left')
tech.fill_by_instance(dsn, grids, tlib, tlib, 'space_2x', iter_type=('MX', 'R0'))

# Route wires
#_trks = dsn.get_routing_tracks(grid=r23)[0]
rc = laygo2.RoutingMeshTemplate(grid=dsn.rgrid)
rc.add_trunk(name="rnorp", index=[None, inor0.p['O'].bottom.n], netname="norp")
rc.add_trunk(name="rnorn", index=[None, inor1.p['O'].top.n], netname="norn")
rc.add_trunk(name="ren0", index=[None, itg0.p['EN'].bottom.n], netname="en", dedicated=[itg0, itg1])
rc.add_trunk(name="ren1", index=[None, iinv3.p['O'].bottom.n], netname="en", dedicated=[itg0, iinv3])
rc.add_trunk(name="renb0", index=[None, itg0.p['ENB'].top.n], netname="enb", dedicated=[itg0, itg1, iinv3])
rc.add_trunk(name="renb1", index=[None, iinv2.p['O'].bottom.n], netname="enb", dedicated=[iinv2, iinv3])
rc.add_trunk(name="rclkref", index=[inor0.p['B'].left.m, None], netname="CLKREF")
rc.add_node(dsn.instances)  # Add all instances to the routing mesh as node
rinst = rc.generate()
dsn.place(inst=rinst)

# Create pins
pINP = dsn.pin(name='INP', mn=inor0.p['A'])
pINN = dsn.pin(name='INN', mn=inor1.p['A'])
pCLKREF = dsn.pin(name='CLKREF', mn=rinst.p['rclkref'])
pnorp = dsn.pin(name='norp', mn=inor0.p['O'])
pnorn = dsn.pin(name='norn', mn=inor1.p['O'])
pSHORT = dsn.pin(name='SHORT', mn=iinv2.p['I'])
pORP = dsn.pin(name='ORP', mn=iinv0.p['O'])
pORN = dsn.pin(name='ORN', mn=iinv1.p['O'])
tech.generate_pwr_rail(dsn, grids, netname=['VDD','VSS'], vertical=False)


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

