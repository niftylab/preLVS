##########################################################
#                                                        #
#  Tri-State Inverter with small size Layout Gernerator  #
#     Contributors: T. Shin, S. Park, Y. Oh, T. Kang     #
#                 Last Update: 2022-05-27                #
#                                                        #
##########################################################

import numpy as np
import pprint
import laygo2
import laygo2.interface
import laygo2_tech as tech
from laygo2.object.netmap import NetMap
# Parameter definitions #############
# Design Variables
cell_type = ['tinv_small', 'tinv_small_ltap']
nf = 1

# Templates
tpmos_name = 'pmos'
tnmos_name = 'nmos'
tntap_name = 'ntap'
tptap_name = 'ptap'

# Grids
pg_name = 'placement_basic'
r12_name = 'routing_12_cmos'
r23_name = 'routing_23_cmos'
r34_name = 'routing_34_basic'

# Design hierarchy
libname              = 'test_generated'
export_path          = './laygo2_generators_private/feature_test/export_raw_dict/' # Layout generation path: "export_path/libname/cellname"
export_path_skill    = export_path+'skill/' # SKILL file generation path: "export_path_skill/libname_cellname.il"
export_path_db       = './laygo2_generators_private/prj_db/'
# End of parameter definitions ######

# Generation start ##################
# 1. Load templates and grids.
print("Load templates")
templates = tech.load_templates()
tpmos, tnmos = templates[tpmos_name], templates[tnmos_name]
tntap, tptap = templates[tntap_name], templates[tptap_name]
# tlib = laygo2.interface.yaml.import_template(filename=export_path+'logic_generated_templates.yaml') # Uncomment if you use the logic templates
# print(templates[tpmos_name], templates[tnmos_name], sep="\n") # Uncomment if you want to print templates

print("Load grids")
grids = tech.load_grids(templates=templates)
pg, r12, r23, r34 = grids[pg_name], grids[r12_name], grids[r23_name], grids[r34_name]
# print(grids[pg_name], grids[r12_name], grids[r23_name], grids[r34_name], sep="\n") # Uncomment if you want to print grids

for celltype in cell_type:
    cellname = celltype+'_'+str(nf)+'x'
    print('--------------------')
    print('Now Creating '+cellname)

    # 2. Create a design hierarchy
    lib = laygo2.object.database.Library(name=libname)
    dsn = laygo2.object.database.Design(name=cellname, libname=libname)
    lib.append(dsn)

    # 3. Create istances.
    print("Create instances")
    iptl = tptap.generate(name='PT0',                 params={'nf': 2, 'tie': 'TAP0'}, netmap={'D':'VSS', 'RAIL':'VSS'})
    intl = tntap.generate(name='NT0', transform='MX', params={'nf': 2, 'tie': 'TAP0'}, netmap={'D':'VDD', 'RAIL':'VDD'})
    if 'nmos4_fast_center_2stack_lext' in templates:
        nstack = templates['nmos4_fast_center_2stack_lext'].generate(name='nstack', netmap={'D0':'O','G0':'I','S0':'VSS','G1':'EN'})
    else:    
        nstack = templates['nmos4_fast_center_2stack'].generate(name='nstack', netmap={'D0':'O','G0':'I','S0':'VSS','G1':'EN'})
    nbndl = templates['nmos4_fast_boundary'].generate(name='nbndl')
    nbndr = templates['nmos4_fast_boundary'].generate(name='nbndr')
    nspace0 = templates['nmos4_fast_space'].generate(name='nspace0')
    nspace1 = templates['nmos4_fast_space'].generate(name='nspace1')
    if 'pmos4_fast_center_2stack_lext' in templates:
        pstack = templates['pmos4_fast_center_2stack_lext'].generate(name='pstack', transform='MX', netmap={'D0':'O','G0':'I','S0':'VDD','G1':'ENB'})
    else:
        pstack = templates['pmos4_fast_center_2stack'].generate(name='pstack', transform='MX', netmap={'D0':'O','G0':'I','S0':'VDD','G1':'ENB'})
    pbndl = templates['pmos4_fast_boundary'].generate(name='pbndl', transform='MX')
    pbndr = templates['pmos4_fast_boundary'].generate(name='pbndr', transform='MX')
    pspace0 = templates['pmos4_fast_space'].generate(name='pspace0', transform='MX')
    pspace1 = templates['pmos4_fast_space'].generate(name='pspace1', transform='MX')

    # 4. Place instances.
    if celltype == 'tinv_small_ltap':
        dsn.place(grid=pg, inst=[[iptl, nbndl, nstack, nbndr, nspace0, nspace1],
                                    [intl, pbndl, pstack, pbndr, pspace0, pspace1]])
    else:
        dsn.place(grid=pg, inst=[[nbndl, nstack, nbndr, nspace0, nspace1],
                                    [pbndl, pstack, pbndr, pspace0, pspace1]])

    # 5. Create and place wires.
    print("Create wires")

    # IN
    _mn = [r12.mn(nstack.pins['G0'])[0], r12.mn(pstack.pins['G0'])[0]]
    _mn[0][1] = r12.mn(nstack.pins['G1'])[0, 1]  # use G1 as the lext extension templates will lead to zero height
    _mn[1][1] = r12.mn(pstack.pins['G1'])[0, 1]
    rin0 = dsn.route(grid=r23, mn=_mn)

    _mn = [r12.mn(nstack.pins['G0'])[0], r12.mn(pstack.pins['G0'])[0]]
    dsn.route(grid=r12, mn=_mn)

    _mn = [np.mean(r23.mn.bbox(rin0), axis=0, dtype=np.int), np.mean(r23.mn.bbox(rin0), axis=0, dtype=np.int)+[2,0]]
    dsn.route(grid=r23, mn=_mn, via_tag=[True, False])
    dsn.via(grid=r12, mn=np.mean(r23.mn.bbox(rin0), axis=0, dtype=np.int))

    # OUT
    _mn = [r23.mn(nstack.pins['D0'])[0], r23.mn(pstack.pins['D0'])[1]]
    vout0, rout0, vout1 = dsn.route(grid=r23, mn=_mn, via_tag=[True, True])

    vint0 = dsn.via(grid=r12, mn=r23.mn(nstack.pins['D0'])[0])
    vint1 = dsn.via(grid=r12, mn=r23.mn(pstack.pins['D0'])[1])

    # EN
    _mn = [r23.mn(nstack.pins['G1'])[0], r23.mn(nstack.pins['G1'])[0]+[1,0]]
    ren0, ven0 = dsn.route(grid=r23, mn=_mn, via_tag=[False, True])

    ven1 = dsn.via(grid=r12, mn=r12.mn(nstack.pins['G1'])[0])
    _mn = [r23.mn(nstack.pins['G1'])[0]+[1,0], r23.mn(pstack.pins['G1'])[0]+[1,0]]
    ren1 = dsn.route(grid=r23, mn=_mn)

    # ENB
    _mn = [r23.mn(pstack.pins['G1'])[0], r23.mn(pstack.pins['G1'])[0]+[-1,0]]
    renb0, venb0 = dsn.route(grid=r23, mn=_mn, via_tag=[False, True])

    venb1 = dsn.via(grid=r12, mn=r12.mn(pstack.pins['G1'])[0])
    _mn = [r23.mn(pstack.pins['G1'])[0]+[-1,0], r23.mn(nstack.pins['G1'])[0]+[-1,0]]
    renb1 = dsn.route(grid=r23, mn=_mn)

    # VSS  
    _mn = [r12.mn.bottom_left(nbndl), r12.mn.bottom_right(nspace1)]
    rvss0 = dsn.route(grid=r12, mn=_mn)

    _mn = [r12.mn(nstack.pins['S0'])[0], r12.mn(rvss0)[0]+[1,0]]
    #_mn = [r12.mn(nstack.pins['S0'])[0], r12.mn(nstack.pins['S0'])[0]+[0,-1]]
    rvss1, _ = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

    # VDD
    _mn = [r12.mn.top_left(pbndl), r12.mn.top_right(pspace1)]
    rvdd0 = dsn.route(grid=r12, mn=_mn)

    _mn = [r12.mn(pstack.pins['S0'])[1], r12.mn(rvdd0)[0]+[1,0]]
    rvdd1 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

    ################################ ADDED FOR DRC ################################
    _mn = [r23.mn(nstack.pins['D0'])[0], r23.mn(nstack.pins['D0'])[0]+[-2,0]]
    dsn.route(grid=r23, mn=_mn)
    _mn = [r23.mn(pstack.pins['D0'])[1], r23.mn(pstack.pins['D0'])[1]+[-2,0]]
    dsn.route(grid=r23, mn=_mn)
    _mn = [r23.mn(nstack.pins['G1'])[0], r23.mn(nstack.pins['G1'])[0]+[2,0]]
    dsn.route(grid=r23, mn=_mn)
    _mn = [r23.mn(pstack.pins['G1'])[0], r23.mn(pstack.pins['G1'])[0]+[2,0]]
    dsn.route(grid=r23, mn=_mn)
    ############################## LINES FOR DRC END ##############################

    # 6. Create pins.
    pin0 = dsn.pin(name='I', grid=r23, mn=r23.mn.bbox(rin0))
    pout0 = dsn.pin(name='O', grid=r23, mn=r23.mn.bbox(rout0))
    pen0 = dsn.pin(name='EN', grid=r23, mn=r23.mn.bbox(ren1))
    penb0 = dsn.pin(name='ENB', grid=r23, mn=r23.mn.bbox(renb1))
    pvss0 = dsn.pin(name='VSS', grid=r12, mn=r12.bbox(rvss0))
    pvdd0 = dsn.pin(name='VDD', grid=r12, mn=r12.bbox(rvdd0))

    # 7. Export to physical database.
    print("Export design")
    print("")
#    laygo2.interface.bag.export(lib, filename=export_path_skill +libname+'_'+cellname+'.il', cellname=None, scale=1e-3, reset_library=False, tech_library=tech.name)
    # Filename example: ./laygo2_generators_private/logic/skill/logic_generated_tinv_small_1x.il
    grid_table = dict()
    grid_table['M1'] = r12
    grid_table['M2'] = r23
    grid_table['M3'] = r23
    exporter = laygo2.object.database.DesignExporter(dsn, grid_table, lib_ref = "laygo2_generators_private/prj_db/library.yaml")
    nat_dict = exporter.export_to_dict()
    laygo2.interface.json.export_dict(nat_dict, filename=export_path_db+libname+'_db.json', mode='append')
    # 8. Export to a template database file.
    via_table = dict()
    via_table["via_M1_M2_0"] = ('M1','M2')
    via_table["via_M1_M2_1"] = ('M1','M2')
    via_table["via_M2_M3_0"] = ('M2','M3')
    via_table["via_M2_M3_1"] = ('M2','M3')
    mosList = ["nmos4_fast_center_nf2", "nmos4_fast_center_2stack","pmos4_fast_center_nf2", "pmos4_fast_center_2stack"]
    nMap = NetMap.import_from_design(dsn, grid_table, via_table, orient_first="vertical", layer_names=['M1','M2','M3'], net_ignore = [], lib_ref = "laygo2_generators_private/prj_db/library.yaml", core_templates=mosList)
    nat_temp = dsn.export_to_template(metal_table=grid_table, net_ignore = [], export_mask=False) 
    laygo2.interface.yaml.export_template(nat_temp, filename=export_path+libname+'_templates.yaml', mode='append')
    # Filename example: ./laygo2_generators_private/logic/logic_generated_templates.yaml
