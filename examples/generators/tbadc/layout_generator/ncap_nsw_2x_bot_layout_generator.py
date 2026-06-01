import numpy as np
import laygo2
import laygo2_tech as tech
import laygo2.object.database
import laygo2.interface.json

# Parameter definitions #############
# Design Variables
celltype = 'ncap_nsw'
nf_list = [2]
#cellname = 'ncap_nsw_2x_bot'
#nf='2'

# Templates
tpmos_name = 'pmos'
tnmos_name = 'nmos'

# Grids
pg_name = 'placement_basic'
r12_name = 'routing_12_cmos'
r23_name = 'routing_23_cmos'
#r34_name = 'routing_34_basic'
r34_cmos_name = 'routing_34_cmos'
r45_cmos_name = 'routing_45_cmos'

# Design hierarchy
#libname = 'logic_generated'
libname = 'tbadc_generated'
#export_path = './laygo2_generators_private/logic/' # Layout generation path: "export_path/libname/cellname"
export_path = './laygo2_generators_private/tbadc/' # Layout generation path: "export_path/libname/cellname"
export_path_skill = export_path+'skill/' # SKILL file generation path: "export_path_skill/libname_cellname.il"
export_path_db      = './laygo2_generators_private/prj_db/tbadc/' # Path for JSON DB export
# End of parameter definitions ######

# Generation start ##################
# 1. Load templates and grids.
print("Load templates")
templates = tech.load_templates()
tpmos, tnmos = templates[tpmos_name], templates[tnmos_name]

print("Load grids")
grids = tech.load_grids(templates=templates)
#pg, r12, r23, r34 = grids[pg_name], grids[r12_name], grids[r23_name], grids[r34_name]
pg, r12, r23, r34_cmos, r45_cmos = grids[pg_name], grids[r12_name], grids[r23_name], grids[r34_cmos_name], grids[r45_cmos_name]

for nf in nf_list:
    cellname = celltype+'_'+str(nf)+'x_bot'

    # 2. Create a design hierarchy
    lib = laygo2.Library(name=libname)
    dsn = laygo2.Design(name=cellname, libname=libname)
    lib.append(dsn)

    # 3. Create instances
    in0 = tnmos.generate(name='MN0',                 params={'nf': nf, 'tie': 'S'})
    in1 = tnmos.generate(name='MN1',                 params={'nf': nf})
    ip0 = tpmos.generate(name='MP0', transform='MX', params={'nf': nf, 'tie': 'S'})
    ip1 = tpmos.generate(name='MP1', transform='MX', params={'nf': nf, 'tie': 'S'})

    # n0 : Switch / n1 : NCap

    # 4. Place instances
    print("Create instances")
    dsn.place(grid=pg, inst=[[in0, in1], [ip0, ip1]], mn=[0,0])

    # 5. Route wires
    print("Route wires")

    # EN
    _mn = [r23(in0.p['G'])[0], r23(ip0.p['G'])[0]]
    _track = [r23(in0.p['G'])[0, 0], None]
    rEN0 = dsn.route_via_track(grid=r23, mn=_mn, track=_track, via_tag=[True, False])

    # IN
    _mn = [r23(in1.p['G'])[0], r23(ip1.p['G'])[0]]
    _track = [r23(in1.p['G'])[0, 0], None]
    rIN0 = dsn.route_via_track(grid=r23, mn=_mn, track=_track, via_tag=[True, False])

    # CPLUS
    #_mn = [r23(in0.p['D'])[0], r23(in1.p['D'])[0]]
    #_track = [None, r12(in0.p['D'])[0, 1]]
    #rCPLUS1 = dsn.route_via_track(grid=r12, mn=_mn, track=_track, via_tag=[False, False])

    #_mn = [r12(in1.p['S'])[0]+[0,1], r12(in1.p['S'])[1]+[0,1]]
    #dsn.route(grid=r12, mn=_mn, via_tag=[True, True])

    _mn = [r23(in0.p['D'])[0]+[2,0], r23(in1.p['S'])[1]]
    _track = [None, r34_cmos(in1.p['S'])[0, 1]-2]
    rCPLUS1 = dsn.route_via_track(grid=r34_cmos, mn=_mn, track=_track, via_tag=[False,False])

    _mn = [r12(in0.p['D'])[0], r12(in0.p['D'])[0]+[2,0]]
    dsn.route(grid=r23, mn=_mn, via_tag=[False, True])

    _mn = [r12(in1.p['S'])[0], r12(in1.p['S'])[1]]
    dsn.route(grid=r23, mn=_mn, via_tag=[False, True])

    _mn = [r12(in0.p['D'])[0], r12(in1.p['D'])[0]]
    dsn.route(grid=r12, mn=_mn, via_tag=[False, False])

    # PMOS dummy
    _mn = [r12(ip0.p['D'])[0], r12(ip0.p['D'])[0]+[0,2]]
    dsn.route(grid=r12, mn=_mn, via_tag=[True, True])

    _mn = [r12(ip1.p['D'])[0], r12(ip1.p['D'])[0]+[0,2]]
    dsn.route(grid=r12, mn=_mn, via_tag=[True, True])

    _mn = [r12(ip0.p['D'])[1], r12(ip0.p['G'])[1]]
    dsn.route(grid=r12, mn=_mn, via_tag=[True, True])

    _mn = [r12(ip1.p['D'])[1], r12(ip1.p['G'])[1]]
    dsn.route(grid=r12, mn=_mn, via_tag=[True, True])

    # Rail
    tech.generate_pwr_rail(dsn, grids, netname=['VSS', 'VDD'], vertical=False)

    # 6. Create pins
    pEN0  = dsn.pin(name='EN', grid=r23, mn=rEN0[-1])
    pIN0 = dsn.pin(name='IN', grid=r23, mn=rIN0[-1])
    pCPLUS1 = dsn.pin(name='CPLUS', grid=r34_cmos, mn=rCPLUS1[-1])

    # 7. Export to physical database
    # laygo2.interface.bag.export(lib, filename='ncap_nsw_'+str(nf)+'x_bot.il', cellname=None, scale=1e-3,
    #                             reset_library=False, tech_library=tech.name)
    # Filename example: ./laygo2_generators_private/logic/skill/logic_generated_inv_hs_2x.il


    # 8. Export to a template database file
    nat_temp = dsn.export_to_template()
    laygo2.interface.yaml.export_template(nat_temp, 
                                            filename=export_path+libname+'_templates.yaml', 
                                            mode='append')
    # Filename example: ./laygo2_generators_private/logic/logic_generated_templates.yaml

    # test jSON DB export
    grid_table = dict()
    grid_table['M1'] = r12
    grid_table['M2'] = r23
    grid_table['M3'] = r34_cmos
    grid_table['M4'] = r45_cmos
    exporter = laygo2.object.database.DesignExporter(dsn, grid_table, lib_ref = "laygo2_generators_private/prj_db/tbadc/library.yaml")
    nat_dict = exporter.export_to_dict()
    laygo2.interface.json.export_dict(nat_dict, filename=export_path_db+libname+'_db.json', mode='append')
