##########################################################
#                                                    
#         NAND with nf matched Layout Gernerator     
#          modified to avoid DRC error when nf=2     
#     Contributors: T. Shin, S. Park, Y. Oh, T. Kang 
#                 Last Update: 2022-05-27            
#                                                    
##########################################################

import numpy as np
import laygo2
import laygo2_tech as tech
import laygo2.object.database
import laygo2.interface.json

# Parameter definitions #############
# Design Variables
cell_type = 'nand_match'
nf_list = [2]

# Templates
tpmos_name = 'pmos'
tnmos_name = 'nmos'

# Grids
pg_name = 'placement_basic'
r12_name = 'routing_12_cmos'
r23_name = 'routing_23_cmos'


# Design hierarchy
libname = 'tbadc_generated'
export_path = './laygo2_generators_private/tbadc/' 
export_path_skill = export_path+'skill/' # SKILL file generation path: "export_path_skill/libname_cellname.il"
export_path_db      = './laygo2_generators_private/prj_db/tbadc/' # Path for JSON DB export
# End of parameter definitions ######

# Generation start ##################
# 1. Load templates and grids.
print("Load templates")
templates = tech.load_templates()
tpmos, tnmos = templates[tpmos_name], templates[tnmos_name]
# tlib = laygo2.interface.yaml.import_template(filename=export_path+'logic_generated_templates.yaml') # Uncomment if you use the logic templates
# print(templates[tpmos_name], templates[tnmos_name], sep="\n") # Uncomment if you want to print templates

print("Load grids")
grids = tech.load_grids(templates=templates)
pg, r12, r23 = grids[pg_name], grids[r12_name], grids[r23_name]
# print(grids[pg_name], grids[r12_name], grids[r23_name], sep="\n") # Uncomment if you want to print grids

for nf in nf_list:
    cellname = cell_type+'_'+str(nf)+'x_for_xor'
    print('--------------------')
    print('Now Creating '+cellname)
    
    # 2. Create a design hierarchy
    lib = laygo2.Library(name=libname)
    dsn = laygo2.Design(name=cellname, libname=libname)
    lib.append(dsn)

    # 3. Create istances.
    print("Create instances")
    in0 = tnmos.generate(name='MN0',                 params={'nf': 2, 'tie': 'S'})
    in1 = tnmos.generate(name='MN1',                 params={'nf': 2, 'tie': 'S'})
    in2 = tnmos.generate(name='MN2',                 params={'nf': 2, 'trackswap': True})
    in3 = tnmos.generate(name='MN3',                 params={'nf': 2, 'trackswap': True})
    ip0 = tpmos.generate(name='MP0', transform='MX', params={'nf': 2, 'tie': 'S'})
    ip1 = tpmos.generate(name='MP1', transform='MX', params={'nf': 2,'trackswap': True, 'tie': 'S'})
    ip2 = tpmos.generate(name='MP2', transform='MX', params={'nf': 2, 'tie': 'S'})
    ip3 = tpmos.generate(name='MP3', transform='MX', params={'nf': 2,'trackswap': True, 'tie': 'S'})

    # 4. Place instances.
    dsn.place(grid=pg, inst=in0, mn=[0,0])
    dsn.place(grid=pg, inst=ip0, mn=pg.mn.top_left(in0) + pg.mn.height_vec(ip0))
    dsn.place(grid=pg, inst=in1, mn=pg.mn.bottom_right(in0))
    dsn.place(grid=pg, inst=in2, mn=pg.mn.bottom_right(in1))
    dsn.place(grid=pg, inst=in3, mn=pg.mn.bottom_right(in2))
    dsn.place(grid=pg, inst=ip1, mn=pg.mn.top_right(ip0))
    dsn.place(grid=pg, inst=ip2, mn=pg.mn.top_right(ip1))
    dsn.place(grid=pg, inst=ip3, mn=pg.mn.top_right(ip2))

    # 5. Create and place wires.
    print("Create wires")

    # A
    _mn = [r23(in2.p['G'])[0] - [1, 0], r23(ip2.p['G'])[0] - [1, 0]]
    vA0, rA0, vA1 = dsn.route(grid=r23, mn=_mn, via_tag=[True, True]) 

    # B
    _mn = [r23(in0.p['G'])[0] - [1, 0], r23(ip0.p['G'])[0] - [1, 0]]
    vB0, rB0, vB1 = dsn.route(grid=r23, mn=_mn, via_tag=[True, True])

    # OUT
    _mn = [r23(in2.p['D'])[0], r23(ip2.p['D'])[0]]
    _track = [r23(in3.p['RAIL'])[0,0], None]
    rout0 = dsn.route_via_track(grid=r23, mn=_mn, track=_track)

    # Internal
    _mn = [r23(in0.p['G'])[0], r23(in1.p['G'])[0]]
    dsn.route(grid=r23, mn=_mn)
    
    _mn = [r23(in2.p['G'])[0], r23(in3.p['G'])[0]]
    dsn.route(grid=r23, mn=_mn)
    
    _mn = [r23(ip0.p['D'])[1], r23(ip2.p['D'])[0]]
    dsn.route(grid=r23, mn=_mn)
    
    _mn = [r23(in0.p['D'])[1], r23(in3.p['S'])[0]]
    dsn.route(grid=r23, mn=_mn)
    
    _mn = [r23(in2.p['D'])[0], r23(in3.p['D'])[0]]
    dsn.route(grid=r23, mn=_mn)

    # Dummy tie
    _mn = [r23(ip1.p['G'])[0], r23(ip1.p['RAIL'])[0]]
    _track =  [r23(ip1.p['D'])[0,0], None]
    dsn.route_via_track(grid=r23, mn=_mn, track=_track)

    _mn = r23.center(ip1.p['RAIL']) - [0, 1]
    dsn.via(grid=r12, mn=_mn)
        
    _mn = [r23(ip3.p['G'])[0], r23(ip3.p['RAIL'])[0]]
    _track = [r23(ip3.p['D'])[0,0], None]
    dsn.route_via_track(grid=r23, mn=_mn, track=_track)

    _mn = r23.center(ip3.p['RAIL']) - [0, 1]
    dsn.via(grid=r12, mn=_mn)

    _mn = [r23(ip3.p['D'])[0], r23(ip1.p['D'])[0]]
    dsn.route(grid=r23, mn=_mn)

    # 6. Create pins.
    pinB = dsn.pin(name='B', grid=r23, mn=r23.bbox(rB0))
    pinA = dsn.pin(name='A', grid=r23, mn=r23.bbox(rA0))
    pout0 = dsn.pin(name='O', grid=r23, mn=r23.bbox(rout0[2]))
    tech.generate_pwr_rail(dsn, grids, netname=['VSS', 'VDD'], vertical=False)

    # 7. Export to physical database.
    print("Export design")
    print("")
    # laygo2.export(lib, tech=tech, filename=export_path_skill+libname+'_'+cellname+'.il')
    # Filename example: ./laygo2_generators_private/logic/skill/logic_generated_nand_match_2x.il

    # 8. Export to a template database file.
    nat_temp = dsn.export_to_template()
    laygo2.export_template(nat_temp, filename=export_path+libname+'_templates.yaml', mode='append')
    # Filename example: ./laygo2_generators_private/logic/logic_generated_templates.yaml

    # test jSON DB export
    grid_table = dict()
    grid_table['M1'] = r12
    grid_table['M2'] = r23
    grid_table['M3'] = r23
    exporter = laygo2.object.database.DesignExporter(dsn, grid_table, lib_ref = "laygo2_generators_private/prj_db/tbadc/library.yaml")
    nat_dict = exporter.export_to_dict()
    laygo2.interface.json.export_dict(nat_dict, filename=export_path_db+libname+'_db.json', mode='append')
