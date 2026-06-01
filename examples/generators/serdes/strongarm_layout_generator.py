##########################################################
#                                                           
# StrongArm Comparator Layout Gernerator                 
# Contributors: J. Han
# Last Updated: 2024-10-28
#
# D. Lee 2025-05-02 (Netmap + JSON export)
#                                                           
##########################################################

import yaml
import numpy as np
import laygo2
import laygo2_tech as tech
from laygo2.object.netmap import NetMap

# Load parameters ############################
spec_params = {}
# Load design-specific parameters
param_fname = "./laygo2_generators_private/serdes/comp/strongarm_spec.yaml"
with open(param_fname, 'r') as stream:
    try:
        spec_params.update(yaml.safe_load(stream))
    except yaml.YAMLError as exc:
        print(exc)
##############################################
cell_type = ['strongarm', 'strongarm_rtap']

# Parameter definitions start #######
nf_clkh = int(spec_params['nf_clkh'])
nf_in = int(spec_params['nf_in'])
nf_th = int(spec_params['nf_th'])
nf_os = int(spec_params['nf_os'])
nf_rgnn = int(spec_params['nf_rgnn'])
nf_rgnp = int(spec_params['nf_rgnp'])
nf_rst = int(spec_params['nf_rst'])
#nf_clkh = 6
#nf_in = 6
#nf_th = 6
#nf_os = 2
#nf_rgnn = 6
#nf_rgnp = 6
#nf_rst = 2

# Templates
tpmos_name = 'pmos'
tnmos_name = 'nmos'
tntap_name = 'ntap'
tptap_name = 'ptap'

# Grids
pg_name = 'placement_basic'
r12_name = 'routing_12_cmos'
r23_name = 'routing_23_cmos'
r34_name = 'routing_34_cmos'

# Design hierarchy
libname = 'comp_generated'
# Layout generation path is set to "export_path/libname/cellname".
export_path = './laygo2_generators_private/serdes/comp/' 
# SKILL file generation path is set to "export_path_skill/libname_cellname.il"
export_path_skill = export_path+'skill/' 
export_path_db = './laygo2_generators_private/prj_db/'
# Parameter definition end ##########

# Generation start ##################
# 1. Load templates and grids.
print("Load templates")
templates = tech.load_templates()
tpmos, tnmos = templates[tpmos_name], templates[tnmos_name]
tntap, tptap = templates[tntap_name], templates[tptap_name]


print("Load grids")
grids = tech.load_grids(templates=templates)
pg, r12, r23, r34 = grids[pg_name], grids[r12_name], grids[r23_name], grids[r34_name]

#cellname = 'strongarm'
for cellname in cell_type:
    print('--------------------')
    print(f'Creating {cellname}')
    
    # 2. Create a design hierarchy
    lib = laygo2.Library(name=libname)
    dsn = laygo2.Design(name=cellname, libname=libname)
    lib.append(dsn)
    
    # 3. Create istances.
    print("Create instances")
    ickn0  = tnmos.generate(name='MCKN0',                  params={'nf': nf_clkh, 'tie': 'S', 'rtrackswap': False}, netmap={'G': 'CLK', 'D': 'TAIL', 'S': 'VSS'})
    ickn1  = tnmos.generate(name='MCKN1',                  params={'nf': nf_clkh, 'tie': 'S', 'rtrackswap': False}, netmap={'G': 'CLK', 'D': 'TAIL', 'S': 'VSS'})
    ios0   = tnmos.generate(name='MOS0',   transform='MX', params={'nf': nf_os, 'rtrackswap': True}, netmap={'G': 'OSP', 'D': 'INTN', 'S': 'TAIL'})
    ith0   = tnmos.generate(name='MTH0',   transform='MX', params={'nf': nf_th, 'rtrackswap': True}, netmap={'G': 'OSP', 'D': 'INTN', 'S': 'TAIL'})
    iin0   = tnmos.generate(name='MIN0',   transform='MX', params={'nf': nf_in, 'rtrackswap': True}, netmap={'G': 'INP', 'D': 'INTN', 'S': 'TAIL'})
    iin1   = tnmos.generate(name='MIN1',   transform='MX', params={'nf': nf_in, 'rtrackswap': True}, netmap={'G': 'INN', 'D': 'INTP', 'S': 'TAIL'})
    ith1   = tnmos.generate(name='MTH1',   transform='MX', params={'nf': nf_th, 'rtrackswap': True}, netmap={'G': 'OSN', 'D': 'INTP', 'S': 'TAIL'})
    ios1   = tnmos.generate(name='MOS1',   transform='MX', params={'nf': nf_os, 'rtrackswap': True}, netmap={'G': 'OSN', 'D': 'INTP', 'S': 'TAIL'})
    irgnn0 = tnmos.generate(name='MRGNN0',                 params={'nf': nf_rgnn, 'nfdmyr': 2, 'rtrackswap': False}, netmap={'G': 'OUTP', 'D': 'OUTN', 'S': 'INTN'})
    irgnn1 = tnmos.generate(name='MRGNN1',                 params={'nf': nf_rgnn, 'nfdmyl': 2, 'rtrackswap': False}, netmap={'G': 'OUTN', 'D': 'OUTP', 'S': 'INTP'})
    irgnp0 = tpmos.generate(name='MRGNP0', transform='MX', params={'nf': nf_rgnp, 'nfdmyr': 2, 'tie': 'S', 'rtrackswap': False}, netmap={'G': 'OUTP', 'D': 'OUTN', 'S': 'VDD'})
    irgnp1 = tpmos.generate(name='MRGNP1', transform='MX', params={'nf': nf_rgnp, 'nfdmyl': 2, 'tie': 'S', 'rtrackswap': False}, netmap={'G': 'OUTN', 'D': 'OUTP', 'S': 'VDD'})
    irstp0 = tpmos.generate(name='MRSTP0',                 params={'nf': nf_rst, 'bndl': False, 'tie': 'S', 'rtrackswap': False}, netmap={'G': 'CLK', 'D': 'OUTN', 'S': 'VDD'})
    irstp1 = tpmos.generate(name='MRSTP1',                 params={'nf': nf_rst, 'bndr': False, 'tie': 'S', 'rtrackswap': False}, netmap={'G': 'CLK', 'D': 'OUTP', 'S': 'VDD'})
    irstp2 = tpmos.generate(name='MRSTP2',                 params={'nf': nf_rst, 'bndr': False, 'tie': 'S', 'rtrackswap': True},  netmap={'G': 'CLK', 'D': 'INTN', 'S': 'VDD'})
    irstp3 = tpmos.generate(name='MRSTP3',                 params={'nf': nf_rst, 'bndl': False, 'tie': 'S', 'rtrackswap': True},  netmap={'G': 'CLK', 'D': 'INTP', 'S': 'VDD'})
    
    # 4. Place instances.
    dsn.place(grid=pg, inst=[[ickn0, ickn1], [ios0, ith0, iin0, iin1, ith1, ios1], [irgnn0, irgnn1], [irgnp0, irgnp1], [irstp2, irstp0, irstp1, irstp3]],
                        mn=[0, 0], pattern='stripe_center')

    # 5. Create and place wires.
    print("Create wires")
    trk_ref_left = r23(iin0.p['S'])[1, 0]
    trk_ref_right = r23(iin1.p['S'])[0, 0]
    _trks = dsn.get_routing_tracks(grid=r23)[0]
    trk_ref_center = _trks[(len(_trks) - 1)//2]  # center index
    
    # core routing mesh
    rc = laygo2.RoutingMeshTemplate(grid=r23)
    rc.add_node(list(dsn.virtual_instances.values()))  # Add all instances to the routing mesh as nodes
    
    # clock
    rc.add_trunk(name="CLK0", index=[trk_ref_center, None],  netname="CLK")
    
    # tail
    _trks = list(range(trk_ref_left, trk_ref_left - max(nf_clkh, nf_in) - 1, -2)) + \
            list(range(trk_ref_right, trk_ref_right + max(nf_clkh, nf_in) + 1, 2))
    for _trk in _trks:
        rc.add_trunk(name="TAIL"+str(_trk), index=[_trk, None],  netname="TAIL")
    
    # intn - left
    _trks = range(trk_ref_left - 1, trk_ref_left - max(nf_in, nf_rgnn) - 2 - 1, -2)
    for _trk in _trks:
        rc.add_trunk(name="INTN"+str(_trk), index=[_trk, None],  netname="INTN", dedicated=[iin0, ios0, ith0, irgnn0])
    
    # intn-rst left
    _trks = range(trk_ref_left - nf_rst - 2 - 1, trk_ref_left - nf_rst - 2 - min(nf_rgnn, nf_rst) - 1, -2)
    for _trk in _trks:
        rc.add_trunk(name="INTN_RSTP"+str(_trk), index=[_trk, None],  netname="INTN", dedicated=[irstp2, irgnn0])

    # intp - right
    _trks = range(trk_ref_right + 1, trk_ref_right + max(nf_in, nf_rgnn) + 2 + 1, 2)
    for _trk in _trks:
        rc.add_trunk(name="INTP"+str(_trk),  index=[_trk, None],  netname="INTP", dedicated=[iin1, ios1, ith1, irgnn1])
    
    # intp-rst - right
    _trks = range(trk_ref_right + nf_rst + 2 + 1, trk_ref_right + nf_rst + 2 + min(nf_rgnn, nf_rst) + 1, 2)
    for _trk in _trks:
        rc.add_trunk(name="INTP_RSTN"+str(_trk),  index=[_trk, None],  netname="INTP", dedicated=[irstp3, irgnn1])
    
    # outn/outp - left
    _trks = range(trk_ref_left, trk_ref_left - max(nf_rgnn, nf_rgnp) - 2 - 1, -2)
    for i, _trk in enumerate(_trks):
        rc.add_trunk(name="OUTN"+str(i),  index=[_trk, None],  netname="OUTN", dedicated=[irgnn0, irgnp0])
    rc.add_trunk(name="OUTP_G",  index=[_trks[0]-3, None],  netname="OUTP", dedicated=[irgnn0, irgnp0])
    _trks = range(trk_ref_left, trk_ref_left - min(nf_rgnp, nf_rst) - 1, -2)
    for _trk in _trks:
        rc.add_trunk(name="OUTN_RST"+str(_trk),  index=[_trk, None],  netname="OUTN", dedicated=[irgnp0, irstp0])
    
    # outp/outn - right
    _trks = range(trk_ref_right, trk_ref_right + max(nf_rgnn, nf_rgnp) + 2 + 1, 2)
    for i, _trk in enumerate(_trks):
        rc.add_trunk(name="OUTP"+str(i),  index=[_trk, None],  netname="OUTP", dedicated=[irgnn1, irgnp1])
    rc.add_trunk(name="OUTN_G",  index=[_trks[0]+3, None],  netname="OUTN", dedicated=[irgnn1, irgnp1])
    _trks = range(trk_ref_right, trk_ref_right + min(nf_rgnp, nf_rst) + 1, 2)
    for _trk in _trks:
        rc.add_trunk(name="OUTP_RST"+str(_trk),  index=[_trk, None],  netname="OUTP", dedicated=[irgnp1, irstp1])
    
    rinst_core = rc.generate()
    dsn.place(grid=pg, inst=rinst_core)

    
    # outp/outn - cross connect
    _trks = r23(rinst_core.p['OUTN_G'])[:, 1]
    rc = laygo2.RoutingMeshTemplate(grid=r23)
    rc.add_trunk(name="OUTNC0",  index=[None, _trks[0]],  netname="OUTN")
    rc.add_trunk(name="OUTPC0",  index=[None, _trks[1]],  netname="OUTP")
    rc.add_node(rinst_core.p['OUTP0'])
    rc.add_node(rinst_core.p['OUTN0'])
    rc.add_node(rinst_core.p['OUTN_G'])
    rc.add_node(rinst_core.p['OUTP_G'])
    rinst_cc = rc.generate()
    dsn.place(grid=pg, inst=rinst_cc)
    
    # tap
    if cellname == 'strongarm_rtap':
        ntap0 = templates['nmos4_fast_tap'].generate(name='ntap0')
        ntap1 = templates['nmos4_fast_tap'].generate(name='ntap1', transform='MX')
        ntap2 = templates['nmos4_fast_tap'].generate(name='ntap2')
        ptap0 = templates['pmos4_fast_tap'].generate(name='ptap0', transform='MX')
        ptap1 = templates['pmos4_fast_tap'].generate(name='ptap1')

        _mn = pg(dsn.bbox)[1]
        _mn[1] = 0
        dsn.place(grid=pg, inst=[[ntap0], [ntap1], [ntap2], [ptap0], [ptap1]], mn=_mn)

        rvss0 = dsn.route(grid=r12, mn=[r12.bottom_left(ntap0), r12.bottom_right(ntap0)])
        _mn = [r12(ntap0.p['TAP0'])[0], [r12(ntap0.p['TAP0'])[0,0], r12.bottom_right(ntap0)[1]]]
        dsn.route(grid=r12, mn=_mn, via_tag=[False, True])
        _mn = [r12(ntap1.p['TAP0'])[0], [r12(ntap1.p['TAP0'])[0,0], r12.top_right(ntap1)[1]]]
        dsn.route(grid=r12, mn=_mn, via_tag=[False, True])
        _mn = [r12(ntap2.p['TAP0'])[0], [r12(ntap2.p['TAP0'])[0,0], r12.bottom_right(ntap2)[1]]]
        dsn.route(grid=r12, mn=_mn, via_tag=[False, True])
        _mn = [r12(ptap0.p['TAP0'])[0], [r12(ptap0.p['TAP0'])[0,0], r12.top_right(ptap0)[1]]]
        dsn.route(grid=r12, mn=_mn, via_tag=[False, True])
        _mn = [r12(ptap1.p['TAP0'])[0], [r12(ptap1.p['TAP0'])[0,0], r12.bottom_right(ptap1)[1]]]
        dsn.route(grid=r12, mn=_mn, via_tag=[False, True])
    
    # 6. Create pins.
    dsn.pin(name='CLK', grid=r23, mn=rinst_core.p['CLK0'])
    dsn.pin(name='INP', grid=r23, mn=iin0.p['G'])
    dsn.pin(name='INN', grid=r23, mn=iin1.p['G'])
    dsn.pin(name='THP', grid=r23, mn=ith0.p['G'])
    dsn.pin(name='THN', grid=r23, mn=ith1.p['G'])
    dsn.pin(name='OSP', grid=r23, mn=ios0.p['G'])
    dsn.pin(name='OSN', grid=r23, mn=ios1.p['G'])
    dsn.pin(name='INTP', grid=r23, mn=iin1.p['D'])
    dsn.pin(name='INTN', grid=r23, mn=iin0.p['D'])
    dsn.pin(name='OUTP', grid=r23, mn=rinst_core.p['OUTP0'])
    dsn.pin(name='OUTN', grid=r23, mn=rinst_core.p['OUTN0'])
    
    tech.fill_by_instance(dsn, grids, templates, templates, 
                      ("nmos4_fast_space_1x", 
                       "nmos4_fast_space_1x", 
                       "nmos4_fast_space_1x", 
                       "pmos4_fast_space_1x", 
                       "pmos4_fast_space_1x"), 
                      iter_type=("R0","MX"))

    
    tech.generate_pwr_rail(dsn, grids, netname=['VSS', 'VSS', 'VDD'], vertical=False)  
    
    # 7. Export to physical database.
    print("Export design\n")
    # laygo2.export(lib, tech=tech, filename=export_path_skill+libname+'_'+cellname+'.il')
    # Filename example: ./laygo2_generators_private/logic/skill/logic_generated_nand_2x.il
    
    ## 8. Export to a template database file.
    # nat_temp = dsn.export_to_template()
    # laygo2.export_template(nat_temp, filename=export_path+libname+'_templates.yaml', mode='append')
    ## Filename example: ./laygo2_generators_private/logic/logic_generated_templates.yaml
    # test JSON DB export
    grid_table = dict()
    grid_table['M1'] = r12
    grid_table['M2'] = r23
    grid_table['M3'] = r23
    grid_table['M4'] = r34
    exporter = laygo2.object.database.DesignExporter(dsn, grid_table, lib_ref="laygo2_generators_private/prj_db/library.yaml")
    nat_dict = exporter.export_to_dict()
    laygo2.interface.json.export_dict(nat_dict, filename=export_path+libname+'_db.json', mode='append')
    # Pre-LVS test
    via_table = dict()
    # via_table["via_M1_M2_0"] = ('M1','M2')
    # via_table["via_M1_M2_1"] = ('M1','M2')
    # via_table["via_M2_M3_0"] = ('M2','M3')
    # via_table["via_M2_M3_1"] = ('M2','M3')
    # via_table["via_M3_M4_0"] = ('M3','M4')
    # mosList = ["nmos4_fast_center_nf2", "nmos4_fast_center_2stack","pmos4_fast_center_nf2", "pmos4_fast_center_2stack"]
    # nMap = NetMap.import_from_design(dsn, grid_table, via_table, orient_first="vertical", layer_names=['M1','M2','M3','M4'],
    #                                     net_ignore = [], lib_ref = "laygo2_generators_private/serdes/comp/comp_generated_templates.yaml", core_templates=mosList)

    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
