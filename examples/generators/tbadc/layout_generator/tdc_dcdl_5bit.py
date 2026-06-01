##########################################################
#                                                      
# tdc_dcdl_5bit Layout Generator          
# Contributors: D. Lee, S. Lee, Y. Byun, J. Han
# Last Updated: 2025-04-21
#                                                      
##########################################################

import laygo2
import laygo2_tech as tech
import laygo2.object.database
import laygo2.interface.json

# Parameter definitions #############
# Design hierarchy
libname = 'tbadc_generated'
cellname = 'tdc_dcdl_5bit'
export_path = './laygo2_generators_private/tbadc/' 
export_path_skill = export_path+'skill/' 
export_path_db      = './laygo2_generators_private/prj_db/tbadc/' # Path for JSON DB export
# End of parameter definitions ######

# Generation start ##################
# Load templates and grids.
templates, grids = tech.load_templates_and_grids()
tlib = laygo2.import_template(filename=export_path+'tbadc_generated_templates.yaml')
pg, r23, r34 = grids['placement_basic'], grids['routing_23_cmos'], grids['routing_34_cmos']
r12 = grids['routing_12_cmos']

print('--------------------')
print(f'Creating {cellname}')
# Create a design hierarchy
dsn = laygo2.Design(name=cellname, libname=libname, pgrid=pg, rgrid=r23)

# Create istances.
print("Create instances")
inv0   = tlib['tdc_dcdl_inv_4x'].generate(name="IINV0", netmap={"I": "IN",     "O": "int<0>", "VDD:": "VDD:", "VSS:": "VSS:"})
inv1   = tlib['tdc_dcdl_inv_4x'].generate(name="IINV1", netmap={"I": "int<0>", "O": "int<1>", "VDD:": "VDD:", "VSS:": "VSS:"})
inv2   = tlib['tdc_dcdl_inv_4x'].generate(name="IINV2", netmap={"I": "int<1>", "O": "int<2>", "VDD:": "VDD:", "VSS:": "VSS:"})
inv3   = tlib['tdc_dcdl_inv_4x'].generate(name="IINV3", netmap={"I": "int<2>", "O": "int<3>", "VDD:": "VDD:", "VSS:": "VSS:"})
inv4   = tlib['tdc_dcdl_inv_4x'].generate(name="IINV4", netmap={"I": "int<3>", "O": "int<4>", "VDD:": "VDD:", "VSS:": "VSS:"})
inv5   = tlib['tdc_dcdl_inv_4x'].generate(name="IINV5", netmap={"I": "int<4>", "O": "OUT",    "VDD:": "VDD:", "VSS:": "VSS:"})

ncap0  = tlib['tdc_dcdl_ncap_psw_small'].generate(name="INCAP0A", netmap={"IN": "int<0>", "ENB": "ENB<0>", "cplus": "cplus0", "VDD:": "VDD:", "VSS:": "VSS:"}) 
ncap1  = tlib['tdc_dcdl_ncap_psw_2x'].generate(name="INCAP0B",    netmap={"IN": "int<0>", "ENB": "ENB<1>", "cplus": "cplus1", "VDD:": "VDD:", "VSS:": "VSS:"}) 
ncap2  = tlib['tdc_dcdl_ncap_psw_2x'].generate(name="INCAP1<1>",  netmap={"IN": "int<0>", "ENB": "ENB<2>", "cplus": "cplus2<1>", "VDD:": "VDD:", "VSS:": "VSS:"})
ncap3  = tlib['tdc_dcdl_ncap_psw_2x'].generate(name="INCAP1<0>",  netmap={"IN": "int<0>", "ENB": "ENB<2>", "cplus": "cplus2<0>", "VDD:": "VDD:", "VSS:": "VSS:"})
ncap4  = tlib['tdc_dcdl_ncap_psw_2x'].generate(name="INCAP2<3>",  netmap={"IN": "int<4>", "ENB": "ENB<3>", "cplus": "cplus3<3>", "VDD:": "VDD:", "VSS:": "VSS:"})
ncap5  = tlib['tdc_dcdl_ncap_psw_2x'].generate(name="INCAP2<2>",  netmap={"IN": "int<4>", "ENB": "ENB<3>", "cplus": "cplus3<2>", "VDD:": "VDD:", "VSS:": "VSS:"})
ncap6  = tlib['tdc_dcdl_ncap_psw_2x'].generate(name="INCAP2<1>",  netmap={"IN": "int<4>", "ENB": "ENB<3>", "cplus": "cplus3<1>", "VDD:": "VDD:", "VSS:": "VSS:"})
ncap7  = tlib['tdc_dcdl_ncap_psw_2x'].generate(name="INCAP2<0>",  netmap={"IN": "int<4>", "ENB": "ENB<3>", "cplus": "cplus3<0>", "VDD:": "VDD:", "VSS:": "VSS:"})
ncap8  = tlib['tdc_dcdl_ncap_psw_2x'].generate(name="INCAP3<5>",  netmap={"IN": "int<2>", "ENB": "ENB<4>", "cplus": "cplus4<5>", "VDD:": "VDD:", "VSS:": "VSS:"})
ncap9  = tlib['tdc_dcdl_ncap_psw_2x'].generate(name="INCAP3<4>",  netmap={"IN": "int<2>", "ENB": "ENB<4>", "cplus": "cplus4<4>", "VDD:": "VDD:", "VSS:": "VSS:"})
ncap10 = tlib['tdc_dcdl_ncap_psw_2x'].generate(name="INCAP3<3>",  netmap={"IN": "int<2>", "ENB": "ENB<4>", "cplus": "cplus4<3>", "VDD:": "VDD:", "VSS:": "VSS:"})
ncap11 = tlib['tdc_dcdl_ncap_psw_2x'].generate(name="INCAP3<2>",  netmap={"IN": "int<2>", "ENB": "ENB<4>", "cplus": "cplus4<2>", "VDD:": "VDD:", "VSS:": "VSS:"})
ncap12 = tlib['tdc_dcdl_ncap_psw_2x'].generate(name="INCAP3<1>",  netmap={"IN": "int<2>", "ENB": "ENB<4>", "cplus": "cplus4<1>", "VDD:": "VDD:", "VSS:": "VSS:"})
ncap13 = tlib['tdc_dcdl_ncap_psw_2x'].generate(name="INCAP3<0>",  netmap={"IN": "int<2>", "ENB": "ENB<4>", "cplus": "cplus4<0>", "VDD:": "VDD:", "VSS:": "VSS:"})

dmy0   = tlib['tdc_dcdl_filler_dmy_2x'].generate(name="IDMY0", netmap={"VDD:": "VDD:", "VSS:": "VSS:"})
dmy1   = tlib['tdc_dcdl_filler_dmy_2x'].generate(name="IDMY1", netmap={"VDD:": "VDD:", "VSS:": "VSS:"})
dmy2   = tlib['tdc_dcdl_filler_dmy_2x'].generate(name="IDMY2", netmap={"VDD:": "VDD:", "VSS:": "VSS:"})
dmy3   = tlib['tdc_dcdl_filler_dmy_2x'].generate(name="IDMY3", netmap={"VDD:": "VDD:", "VSS:": "VSS:"})
dmy4   = tlib['tdc_dcdl_filler_dmy_2x'].generate(name="IDMY4", netmap={"VDD:": "VDD:", "VSS:": "VSS:"})
dmy5   = tlib['tdc_dcdl_filler_dmy_2x'].generate(name="IDMY5", netmap={"VDD:": "VDD:", "VSS:": "VSS:"})
dmy6   = tlib['tdc_dcdl_filler_dmy_2x'].generate(name="IDMY6", netmap={"VDD:": "VDD:", "VSS:": "VSS:"})

# 4. Place instances.
dsn.place(inst=[dmy0, inv0, dmy1, ncap0, ncap1, ncap2, ncap3, inv1, dmy2, inv2, dmy3, ncap8, ncap9, ncap10, ncap11, ncap12, ncap13, inv3, dmy4, inv4, dmy5, ncap4, ncap5, ncap6, ncap7, inv5, dmy6])

# 5. Create and place wires.
print("Create wires")

#_trk = dsn.get_routing_tracks(grid=r34)[0][0]
rc = laygo2.RoutingMeshTemplate(grid=r23)
_trk = r23(ncap0.p['IN'])[0][1]
rc.add_trunk(name="rint0", index=[None, _trk], netname="int<0>")
rc.add_trunk(name="rint1", index=[None, _trk], netname="int<1>")
rc.add_trunk(name="rint2", index=[None, _trk], netname="int<2>")
rc.add_trunk(name="rint3", index=[None, _trk], netname="int<3>")
rc.add_trunk(name="rint4", index=[None, _trk], netname="int<4>")
_trk = r23(ncap0.p['ENB'])[1][1]
rc.add_trunk(name="rENB0", index=[None, _trk], netname="ENB<0>")
rc.add_trunk(name="rENB1", index=[None, _trk], netname="ENB<1>")
rc.add_trunk(name="rENB2", index=[None, _trk], netname="ENB<2>")
rc.add_trunk(name="rENB3", index=[None, _trk], netname="ENB<3>")
rc.add_trunk(name="rENB4", index=[None, _trk], netname="ENB<4>")
rc.add_node(list(dsn.instances.values()))
rinst = rc.generate()
dsn.place(grid=pg, inst=rinst)
      
# 6. Create pins.
pIN = dsn.pin(name='IN', grid=r34, mn=r34(inv0.p['I']))
pint0 = dsn.pin(name='int<0>', grid=r23, mn=rinst.p['rint0'])
pint1 = dsn.pin(name='int<1>', grid=r23, mn=rinst.p['rint1'])
pint2 = dsn.pin(name='int<2>', grid=r23, mn=rinst.p['rint2'])
pint3 = dsn.pin(name='int<3>', grid=r23, mn=rinst.p['rint3'])
pint4 = dsn.pin(name='int<4>', grid=r23, mn=rinst.p['rint4'])
pENB0 = dsn.pin(name='ENB<0>', grid=r34, mn=ncap0.p['ENB'])
pENB1 = dsn.pin(name='ENB<1>', grid=r34, mn=ncap1.p['ENB'])
pENB2 = dsn.pin(name='ENB<2>', grid=r34, mn=ncap2.p['ENB'])
pENB3 = dsn.pin(name='ENB<3>', grid=r34, mn=ncap4.p['ENB'])
pENB4 = dsn.pin(name='ENB<4>', grid=r34, mn=ncap8.p['ENB'])
pOUT = dsn.pin(name='OUT', grid=r34, mn=r34(inv5.p['O']))
tech.generate_pwr_rail(dsn, grids, netname=['VSS', 'VDD'], vertical=False)
    
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

# lvs cell generation
# export_path_logic = "./laygo2_generators_private/logic/"
# tlib_logic = laygo2.import_template(filename=export_path_logic+'logic_generated_templates.yaml') 
# tap0 = tlib_logic['tap'].generate(name='tap0')
# dsn.place(inst=[tap0], mn=pg.bottom_right(dmy6))
# dsn.cellname = dsn.cellname+'_lvs'
# laygo2.export(dsn, cellname=dsn.cellname, tech=tech, filename=export_path_skill+libname+'_'+cellname+'.il')

