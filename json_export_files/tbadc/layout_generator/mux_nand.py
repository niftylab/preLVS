import numpy as np
import laygo2
import laygo2_tech as tech
import laygo2.object.database
import laygo2.interface.json

# Parameter definitions #############
# Design Variables
cell_type = ['mux_nand', 'mux_nand_ltap']

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
r34t_name = 'routing_34_thick'
r45_name = 'routing_45_cmos'
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
tlib = laygo2.import_template(filename=export_path + 'tbadc_generated_templates.yaml')
print("Load grids")
grids = tech.load_grids(templates=templates)
pg, r12, r23, r34, r34t, r45 = grids[pg_name], grids[r12_name], grids[r23_name], grids[r34_name],grids[r34t_name], grids[r45_name]
for celltype in cell_type:
     cellname = f'{celltype}'
     print('--------------------')
     print(f'Creating {cellname}')
     # 2. Create a design hierarchy
     lib = laygo2.Library(name=libname)
     dsn = laygo2.Design(name=cellname, libname=libname)
     lib.append(dsn)

     # 3. Create intances.
     print("Create instances")
     if celltype in ['mux_nand_ltap']:
         #TAP
         ipt0 = templates['pmos4_fast_tap'].generate(name='PT0', transform='MX')
         ipt1 = templates['pmos4_fast_tap'].generate(name='PT1')
         int0 = templates['nmos4_fast_tap'].generate(name='NT0', transform='MX')
         int1 = templates['nmos4_fast_tap'].generate(name='NT1')
         #INSTANCE
         I0 = tlib['nand2'].generate(name = 'I0', transform = 'MX')
         I1 = tlib['nand2'].generate(name = 'I1')
         I2 = tlib['nand2_balanced'].generate(name = 'I2')
     else:
         #I0 = tlib['nand2'].generate(name = 'I0')
         I0 = tlib['nand2'].generate(name = 'I0', transform = 'MX')
         I1 = tlib['nand2'].generate(name = 'I1')
         I2 = tlib['nand2_balanced'].generate(name = 'I2')

     # 4. Place instance    
     if celltype in ['mux_nand_ltap']:
         dsn.place(grid=pg, inst=[[ipt1],[int0],[int1],[ipt0]], mn=[0,0])
         dsn.place(grid=pg, inst=[[I0],[I1]], mn = pg.bottom_right(ipt1))
         dsn.place(grid=pg, inst=[[I2]], mn = pg.bottom_right(I0))
     else:
         dsn.place(grid=pg, inst=[[I0],[I1]], mn = [0,0])
         dsn.place(grid=pg, inst=[[I2]], mn = pg.bottom_right(I0))
     
     # 5. Create and place wires.
     print("Create wires")
     if celltype in ['mux_nand_ltap']:
         #VSS_TAP
         rvss0 = dsn.route(grid=r12, mn=[r12.top_left(int0), r12.top_right(int0)])
         _mn = [r12(int0.p['TAP0'])[0], [r12(int0.p['TAP0'])[0,0], r12(rvss0)[0,1]]]
         dsn.route(grid=r12, mn=_mn, via_tag=[False, True])
         rvss1 = dsn.route(grid=r12, mn=[r12.bottom_left(int1), r12.bottom_right(int1)])
         _mn = [r12(int1.p['TAP0'])[0], [r12(int1.p['TAP0'])[0,0], r12(rvss1)[0,1]]]
         dsn.route(grid=r12, mn=_mn, via_tag=[False, True])
         #VDD_TAP
         rvdd0 = dsn.route(grid=r12, mn=[r12.top_left(ipt0), r12.top_right(ipt0)])
         _mn = [r12(ipt0.p['TAP0'])[0], [r12(ipt0.p['TAP0'])[0,0], r12(rvdd0)[0,1]]]
         dsn.route(grid=r12, mn=_mn, via_tag=[False, True])
         rvdd1 = dsn.route(grid=r12, mn=[r12.bottom_left(ipt1), r12.bottom_right(ipt1)])
         _mn = [r12(ipt1.p['TAP0'])[0], [r12(ipt1.p['TAP0'])[0,0], r12(rvdd1)[0,1]]]
         dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

     #IN
     IN_wire_length = 10
     _mn = [r34t.mn(I0.p['B'])[0], r34t.mn(I0.p['B'])[0] + [-1 * IN_wire_length, 0]]
     _track = [None, r34t(I0.p['B'])[0,1]]
     rin0 = dsn.route_via_track(grid=r34t, mn=_mn, track=_track, via_tag = [True, None])[-1]
     
     _mn = [r34t.mn(I1.p['B'])[0], r34t.mn(I1.p['B'])[0] + [-1 * IN_wire_length, 0]]
     _track = [None, r34t(I1.p['B'])[0,1]]
     rin1 = dsn.route_via_track(grid=r34t, mn=_mn, track=_track, via_tag = [True, None])[-1]

     #Routing between nand2 and nand2_balanced
     _mn = [r34t.mn(I0.p['O'])[0] + [-1, 0], r34t.mn(I2.p['B'])[0] + [4 , 0]] 
     _track = [None, r34t(I0.p['O'])[0,1]]
     rmid = dsn.route_via_track(grid=r34t, mn=_mn, track=_track, via_tag = [True, True])[-1]
     print(rmid)

     _mn = [r34t.mn(I1.p['O'])[0] + [-1, 0], r34t.mn(I2.p['B'])[1] + [4 , 1]]
     _track = [None, r34t(I1.p['O'])[0,1]]
     dsn.route_via_track(grid=r34t, mn=_mn, track=_track, via_tag = [True, True])


     # 6. Create pins.
     pmid = dsn.pin(name='MID', grid=r34t, mn=rmid)
     pout = dsn.pin(name='OUT', grid=r34, mn=r34.mn(I2.p['O']))
     pen0 = dsn.pin(name='EN0', grid=r34, mn=r34.mn(I0.p['A']))
     pen1 = dsn.pin(name='EN1', grid=r34, mn=r34.mn(I1.p['A']))
     pin0 = dsn.pin(name='IN0', grid=r34t, mn=rin0)
     pin1 = dsn.pin(name='IN1', grid=r34t, mn=rin1)

     tech.generate_pwr_rail(dsn, grids, netname=['VDD', 'VSS', 'VDD'], vertical=False)

     # 7. Export to physical database.
     print("Export design\n")
     # laygo2.export(lib, tech=tech, filename=export_path_skill+libname+'_'+cellname+'.il')
     # Filename example: ./laygo2_generators_private/logic/skill/logic_generated_nand_2x.il
     
     # 8. Export to a template database file.
     nat_temp = dsn.export_to_template()
     laygo2.export_template(nat_temp, filename=export_path+libname+'_templates.yaml', mode='append')
     # Filename example: ./laygo2_generators_pri

     # test jSON DB export
     grid_table = dict()
     grid_table['M1'] = r12
     grid_table['M2'] = r23
     grid_table['M3'] = r34 # Also r34t is used
     grid_table['M4'] = r45
     grid_table['M5'] = r45
     exporter = laygo2.object.database.DesignExporter(dsn, grid_table, lib_ref = "laygo2_generators_private/prj_db/tbadc/library.yaml")
     nat_dict = exporter.export_to_dict()
     laygo2.interface.json.export_dict(nat_dict, filename=export_path_db+libname+'_db.json', mode='append')



         





          


