##########################################################
#                                                      
# tdc_dcdl Layout Generator          
# Contributors: 
# Last Updated: 2024-10-17
#                                                      
##########################################################

import laygo2
import laygo2_tech as tech
import laygo2.object.database
import laygo2.interface.json

# Parameter definitions #############
# Design Variables

# Templates
tpmos_name = 'pmos'
tnmos_name = 'nmos'

# Grids
pg_name = 'placement_basic'
r12_name = 'routing_12_cmos'
r23_name = 'routing_23_cmos'
r34_name = 'routing_34_cmos'

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
tlib = laygo2.import_template(filename=export_path+'tbadc_generated_templates.yaml')

print("Load grids")
grids = tech.load_grids(templates=templates)
pg, r12, r23, r34 = grids[pg_name], grids[r12_name], grids[r23_name], grids[r34_name]

cellname = 'tdc_dcdl'
print('--------------------')
print(f'Creating {cellname}')

# 2. Create a design hierarchy
lib = laygo2.Library(name=libname)
dsn = laygo2.Design(name=cellname, libname=libname)
lib.append(dsn)

# 3. Create istances.
print("Create instances")
iinvp0 = tlib['tdc_dcdl_inv_4x'].generate(name="IINVP0", transform="MX", netmap={"I": "DP", "O": "dpb", "VDD:":"VDD:", "VSS:":"VSS:"})
iinvp1 = tlib['tdc_dcdl_inv_4x'].generate(name="IINVP1", transform="MX", netmap={"I": "dpb", "O": "dp_pre", "VDD:":"VDD:", "VSS:":"VSS:"})
iinvn0 = tlib['tdc_dcdl_inv_4x'].generate(name="IINVN0", transform="MX", netmap={"I": "DN", "O": "dnb", "VDD:":"VDD:", "VSS:":"VSS:"})
iinvn1 = tlib['tdc_dcdl_inv_4x'].generate(name="IINVN1", transform="MX", netmap={"I": "dnb", "O": "dn_pre", "VDD:":"VDD:", "VSS:":"VSS:"})
idcdlp_np  = tlib['tdc_dcdl_5bit'].generate(name="IDCDLP_NP", netmap={"IN": "dp_pre", "ENB<0>": "C_POS<0>", "ENB<1>": "C_POS<1>", "ENB<2>": "C_POS<2>", "ENB<3>": "C_POS<3>", "ENB<4>": "C_POS<4>", 
                                                                      "OUT": "DP_NP", "int<0>": "intp_np<0>", "int<1>": "intp_np<1>", "int<2>": "intp_np<2>", "int<3>": "intp_np<3>", "int<4>": "intp_np<4>", "VDD:": "VDD:", "VSS:": "VSS:"})
idcdlp_pn  = tlib['tdc_dcdl_5bit'].generate(name="IDCDLP_PN", transform="MX", netmap={"IN": "dp_pre", "ENB<0>": "C_POS<0>", "ENB<1>": "C_POS<1>", "ENB<2>": "C_POS<2>", "ENB<3>": "C_POS<3>", "ENB<4>": "C_POS<4>",
                                                                                      "OUT": "DP_PN", "int<0>": "intp_pn<0>", "int<1>": "intp_pn<1>", "int<2>": "intp_pn<2>", "int<3>": "intp_pn<3>", "int<4>": "intp_pn<4>", "VDD:": "VDD:", "VSS:": "VSS:"})
idcdln_pn  = tlib['tdc_dcdl_5bit'].generate(name="IDCDLN_PN", netmap={"IN": "dn_pre", "ENB<0>": "C_NEG<0>", "ENB<1>": "C_NEG<1>", "ENB<2>": "C_NEG<2>", "ENB<3>": "C_NEG<3>", "ENB<4>": "C_NEG<4>",
                                                                      "OUT": "DN_PN", "int<0>": "intn_pn<0>", "int<1>": "intn_pn<1>", "int<2>": "intn_pn<2>", "int<3>": "intn_pn<3>", "int<4>": "intn_pn<4>", "VDD:": "VDD:", "VSS:": "VSS:"})
idcdln_np  = tlib['tdc_dcdl_5bit'].generate(name="IDCDLN_NP", transform="MX", netmap={"IN": "dn_pre", "ENB<0>": "C_NEG<0>", "ENB<1>": "C_NEG<1>", "ENB<2>": "C_NEG<2>", "ENB<3>": "C_NEG<3>", "ENB<4>": "C_NEG<4>",
                                                                                      "OUT": "DN_NP", "int<0>": "intn_np<0>", "int<1>": "intn_np<1>", "int<2>": "intn_np<2>", "int<3>": "intn_np<3>", "int<4>": "intn_np<4>", "VDD:": "VDD:", "VSS:": "VSS:"})

# 4. Place instances.
dsn.place(grid=pg, inst=[[iinvn0, iinvn1, idcdln_np], [None, None, idcdln_pn], [iinvp0, iinvp1, idcdlp_pn], [None, None, idcdlp_np]])
tech.fill_by_instance(dsn, grids, tlib, tlib, 'space_2x', iter_type=('MX', 'R0'))

# 5. Create and place wires.
print("Create wires")
#_trk = dsn.get_routing_tracks(grid=r34)[0][0]
rc = laygo2.RoutingMeshTemplate(grid=r23)
_trk = r23(iinvp0.p['O'])[1][1]
rc.add_trunk(name="rdpb", index=[None, _trk], netname="dpb")
rc.add_trunk(name="rdp_pre", index=[None, _trk], netname="dp_pre")
_trk = r23(iinvn0.p['O'])[1][1]
rc.add_trunk(name="rdnb", index=[None, _trk], netname="dnb")
rc.add_trunk(name="rdn_pre", index=[None, _trk], netname="dn_pre")
rc.add_node(list(dsn.instances.values()))
rinst = rc.generate()
dsn.place(grid=pg, inst=rinst)

dsn.route(grid=r34, mn=[idcdlp_np.p['ENB<0>'], idcdlp_pn.p['ENB<0>']])
dsn.route(grid=r34, mn=[idcdlp_np.p['ENB<1>'], idcdlp_pn.p['ENB<1>']])
dsn.route(grid=r34, mn=[idcdlp_np.p['ENB<2>'], idcdlp_pn.p['ENB<2>']])
dsn.route(grid=r34, mn=[idcdlp_np.p['ENB<3>'], idcdlp_pn.p['ENB<3>']])
dsn.route(grid=r34, mn=[idcdlp_np.p['ENB<4>'], idcdlp_pn.p['ENB<4>']])
dsn.route(grid=r34, mn=[idcdln_np.p['ENB<0>'], idcdln_pn.p['ENB<0>']])
dsn.route(grid=r34, mn=[idcdln_np.p['ENB<1>'], idcdln_pn.p['ENB<1>']])
dsn.route(grid=r34, mn=[idcdln_np.p['ENB<2>'], idcdln_pn.p['ENB<2>']])
dsn.route(grid=r34, mn=[idcdln_np.p['ENB<3>'], idcdln_pn.p['ENB<3>']])
dsn.route(grid=r34, mn=[idcdln_np.p['ENB<4>'], idcdln_pn.p['ENB<4>']])
      
# 6. Create pins.
pdp = dsn.pin(name='DP', grid=r34, mn=r34(iinvp0.p['I']))
pdn = dsn.pin(name='DN', grid=r34, mn=r34(iinvn0.p['I']))
pdp_pre = dsn.pin(name='dp_pre', grid=r34, mn=r34(iinvp1.p['O']))
pdn_pre = dsn.pin(name='dn_pre', grid=r34, mn=r34(iinvn1.p['O']))
pdlypb_np0 = dsn.pin(name='C_POS<0>', grid=r34, mn=r34(idcdlp_np.p['ENB<0>']))
pdlypb_np1 = dsn.pin(name='C_POS<1>', grid=r34, mn=r34(idcdlp_np.p['ENB<1>']))
pdlypb_np2 = dsn.pin(name='C_POS<2>', grid=r34, mn=r34(idcdlp_np.p['ENB<2>']))
pdlypb_np3 = dsn.pin(name='C_POS<3>', grid=r34, mn=r34(idcdlp_np.p['ENB<3>']))
pdlypb_np4 = dsn.pin(name='C_POS<4>', grid=r34, mn=r34(idcdlp_np.p['ENB<4>']))
pdlynb_np0 = dsn.pin(name='C_NEG<0>', grid=r34, mn=r34(idcdln_np.p['ENB<0>']))
pdlynb_np1 = dsn.pin(name='C_NEG<1>', grid=r34, mn=r34(idcdln_np.p['ENB<1>']))
pdlynb_np2 = dsn.pin(name='C_NEG<2>', grid=r34, mn=r34(idcdln_np.p['ENB<2>']))
pdlynb_np3 = dsn.pin(name='C_NEG<3>', grid=r34, mn=r34(idcdln_np.p['ENB<3>']))
pdlynb_np4 = dsn.pin(name='C_NEG<4>', grid=r34, mn=r34(idcdln_np.p['ENB<4>']))

pdlypb_np0 = dsn.pin(name='intp_np<0>', grid=r23, mn=r23(idcdlp_np.p['int<0>']))
pdlypb_np1 = dsn.pin(name='intp_np<1>', grid=r23, mn=r23(idcdlp_np.p['int<1>']))
pdlypb_np2 = dsn.pin(name='intp_np<2>', grid=r23, mn=r23(idcdlp_np.p['int<2>']))
pdlypb_np3 = dsn.pin(name='intp_np<3>', grid=r23, mn=r23(idcdlp_np.p['int<3>']))
pdlypb_np4 = dsn.pin(name='intp_np<4>', grid=r23, mn=r23(idcdlp_np.p['int<4>']))
pdlypb_pn0 = dsn.pin(name='intp_pn<0>', grid=r23, mn=r23(idcdlp_pn.p['int<0>']))
pdlypb_pn1 = dsn.pin(name='intp_pn<1>', grid=r23, mn=r23(idcdlp_pn.p['int<1>']))
pdlypb_pn2 = dsn.pin(name='intp_pn<2>', grid=r23, mn=r23(idcdlp_pn.p['int<2>']))
pdlypb_pn3 = dsn.pin(name='intp_pn<3>', grid=r23, mn=r23(idcdlp_pn.p['int<3>']))
pdlypb_pn4 = dsn.pin(name='intp_pn<4>', grid=r23, mn=r23(idcdlp_pn.p['int<4>']))
pdlynb_pn0 = dsn.pin(name='intn_pn<0>', grid=r23, mn=r23(idcdln_pn.p['int<0>']))
pdlynb_pn1 = dsn.pin(name='intn_pn<1>', grid=r23, mn=r23(idcdln_pn.p['int<1>']))
pdlynb_pn2 = dsn.pin(name='intn_pn<2>', grid=r23, mn=r23(idcdln_pn.p['int<2>']))
pdlynb_pn3 = dsn.pin(name='intn_pn<3>', grid=r23, mn=r23(idcdln_pn.p['int<3>']))
pdlynb_pn4 = dsn.pin(name='intn_pn<4>', grid=r23, mn=r23(idcdln_pn.p['int<4>']))
pdlynb_np0 = dsn.pin(name='intn_np<0>', grid=r23, mn=r23(idcdln_np.p['int<0>']))
pdlynb_np1 = dsn.pin(name='intn_np<1>', grid=r23, mn=r23(idcdln_np.p['int<1>']))
pdlynb_np2 = dsn.pin(name='intn_np<2>', grid=r23, mn=r23(idcdln_np.p['int<2>']))
pdlynb_np3 = dsn.pin(name='intn_np<3>', grid=r23, mn=r23(idcdln_np.p['int<3>']))
pdlynb_np4 = dsn.pin(name='intn_np<4>', grid=r23, mn=r23(idcdln_np.p['int<4>']))

pdlypb_np0 = dsn.pin(name='DP_NP', grid=r34, mn=r34(idcdlp_np.p['OUT']))
pdlypb_pn0 = dsn.pin(name='DP_PN', grid=r34, mn=r34(idcdlp_pn.p['OUT']))
pdlynb_pn0 = dsn.pin(name='DN_PN', grid=r34, mn=r34(idcdln_pn.p['OUT']))
pdlynb_np0 = dsn.pin(name='DN_NP', grid=r34, mn=r34(idcdln_np.p['OUT']))

tech.generate_pwr_rail(dsn, grids, netname=['VDD', 'VSS'], vertical=False)
    
# 7. Export to physical database.
print("Export design\n")
# laygo2.export(lib, tech=tech, filename=export_path_skill+libname+'_'+cellname+'.il')
# Filename example: ./laygo2_generators_private/logic/skill/logic_generated_dff_2x.il

# 8. Export to a template database file.
nat_temp = dsn.export_to_template()
laygo2.export_template(nat_temp, filename=export_path+libname+'_templates.yaml', mode='append')
# Filename example: ./laygo2_generators_private/logic/logic_generated_templates.yaml

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
# tap0 = tlib_logic['tap'].generate(name='tap0', transform='MX')
# tap1 = tlib_logic['tap'].generate(name='tap1')
# tap2 = tlib_logic['tap'].generate(name='tap2', transform='MX')
# tap3 = tlib_logic['tap'].generate(name='tap3')
# dsn.place(grid=pg, inst=[[tap0],[tap1],[tap2],[tap3]], mn=pg.bottom_right(idcdln_np))
# dsn.cellname = dsn.cellname+'_lvs'
# lib.append(dsn)
# laygo2.export(lib, cellname=dsn.cellname, tech=tech, filename=export_path_skill+libname+'_'+cellname+'.il')
