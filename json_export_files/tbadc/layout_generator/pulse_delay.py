##########################################################
#                                                      
# Pulse Delay tcmp wo DCDL Layout Generator          
# Contributors: Taehee Lee
# Last Updated: 2024-10-23
#                                                      
##########################################################

import numpy as np
import laygo2
import laygo2_tech as tech
import laygo2.object.database
import laygo2.interface.json

# Parameter definitions #############
# Design Variables
cell_name = 'pulse_delay_tcmp_wo_dcdl_v5'

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
r45_name = 'routing_45_cmos'

# Design hierarchy

libname = 'tbadc_generated'
# Layout generation path: "export_path/libenaem/cellname"
export_path       = "./laygo2_generators_private/tbadc/" 
# SKILL file generation path: "export_path_skill/libenaem_cellname.il"
export_path_skill = export_path+'skill/' 
export_path_db      = './laygo2_generators_private/prj_db/tbadc/' # Path for JSON DB export
# End of parameter definitions ######

# Generation start ##################
# 1. Load templates and grids.
print("Load templates")
templates = tech.load_templates()
tpmos, tnmos = templates[tpmos_name], templates[tnmos_name]
tntap, tptap = templates[tntap_name], templates[tptap_name] 
tlib = laygo2.interface.yaml.import_template(filename='./laygo2_generators_private/logic/logic_generated_templates.yaml')
tlib_adc = laygo2.interface.yaml.import_template(filename=export_path+'tbadc_generated_templates.yaml')

print("Load grids")
grids = tech.load_grids(templates=templates)
pg, r12, r23, r34, r45 = grids[pg_name], grids[r12_name], grids[r23_name], grids[r34_name], grids[r45_name]
# print(grids[pg_name], grids[r12_name], grids[r23_name], grids[r34_name], sep="\n")

cellname = cell_name
print('------------------')
print('Now Creating '+cellname)

# 2. Create a design hierarchy
lib = laygo2.Library(name=libname)
dsn = laygo2.Design(name=cellname, libname=libname)
lib.append(dsn)

# 3. Create instances.
print("Create instances")

space0  = tlib['space_2x'].generate(name='space0', shape=[5, 1])
#space0  = tlib_adc['filler_dmy_2x'].generate(name='dmy0', shape=[5, 1])
inv0 = tlib['inv_'+str(8)+'x'].generate(name='inv0', transform='MX')
inv1 = tlib['inv_'+str(4)+'x'].generate(name='inv1', transform='MX')
inv2 = tlib['inv_'+str(6)+'x'].generate(name='inv2', transform='MX')
nor0 = tlib['nor_'+str(8)+'x'].generate(name='nor0', transform='MX')
inv3 = tlib['inv_'+str(6)+'x'].generate(name='inv3', transform='MX')
inv4 = tlib['inv_'+str(8)+'x'].generate(name='inv4', transform='MX')

inv5 = tlib['inv_'+str(8)+'x'].generate(name='inv5')
nand0 = tlib['nand_'+str(8)+'x'].generate(name='nand0')
inv6 = tlib['inv_'+str(8)+'x'].generate(name='inv6')

nor1 = tlib['nor_'+str(8)+'x'].generate(name='nor1')
#inv7 = tlib['inv_'+str(8)+'x'].generate(name='inv7')

in0  = tnmos.generate(name='MN0',                 params={'nf': 8, 'nfdmyl': 2, 'nfdmyr' : 2, 'tie': 'S'})
ip0  = tpmos.generate(name='MP0', transform='MX', params={'nf': 6, 'nfdmyl': 2, 'nfdmyr' : 4, 'tie': 'S'})


# 4. Place instances.

cursor = [0,0]

dsn.place(grid=pg, inst=space0, mn=cursor)
cursor = pg.mn.bottom_right(space0)

dsn.place(grid=pg, inst=inv5, mn=cursor)

cursor = pg.mn.bottom_right(inv5)
dsn.place(grid=pg, inst=nand0, mn=cursor)

cursor = pg.mn.bottom_right(nand0)
dsn.place(grid=pg, inst=inv6, mn=cursor)

cursor = pg.mn.bottom_right(inv6)
dsn.place(grid=pg, inst=nor1, mn=cursor)

cursor = pg.mn.bottom_right(nor1)
#dsn.place(grid=pg, inst=inv7, mn=cursor)
dsn.place(grid=pg, inst=[[in0], [ip0]], mn=cursor)


dsn.place(grid=pg, inst=inv0, mn=pg.mn.top_left(space0)+pg.mn.height_vec(space0))
dsn.place(grid=pg, inst=inv1, mn=pg.mn.top_right(inv0))
dsn.place(grid=pg, inst=inv2, mn=pg.mn.top_right(inv1))
dsn.place(grid=pg, inst=nor0, mn=pg.mn.top_right(inv2))
dsn.place(grid=pg, inst=inv3, mn=pg.mn.top_right(nor0))
dsn.place(grid=pg, inst=inv4, mn=pg.mn.top_right(inv3))


#dsn.place(grid=pg, inst=[[inv5, nand0, inv6, None, None, nor1, inv7], [inv0, inv1, inv2, nor0, inv3, inv4, None]] ,mn=[0,0])


# 5. Create and place wires.
print("Create wires")

# A1
_mn = [r23(inv1.p['I'])[0], r23(inv5.p['I'])[0]]
dsn.route(grid=r23, mn= _mn, via_tag=[True, True])

_mn = [r34.mn.center(inv0.p['O']), r34.mn.center(inv1.p['I'])]
ra1 =dsn.route(grid=r34, mn= _mn, via_tag=[True, True])

# A1-1
_mn = [r34.mn.center(inv1.p['O']), r34.mn.center(inv2.p['I'])]
dsn.route(grid=r34, mn= _mn, via_tag=[True, True])

# B1
_mn = [r34.mn.center(inv2.p['O']), r34.mn.center(nor0.p['A'])]
rb1 = dsn.route(grid=r34, mn= _mn, via_tag=[True, True])

# B2
_mn = [r34(nor0.p['O'])[0]+[0,3], r34(inv3.p['I'])[0]]
rb2 = dsn.route(grid=r34, mn= _mn, via_tag=[True, True])

# B3
_mn = [r34(inv3.p['O'])[0]+[0,2], r34(inv4.p['I'])[0]]
rb3 = dsn.route(grid=r34, mn= _mn, via_tag=[True, True])


# B4

_mn = [r34(inv4.p['O'])[0], r34(nor1.p['A'])[1]] 
_track =  [r34(inv4.p['O'])[0,0], None]
rb4= dsn.route_via_track(grid=r34, mn=_mn, track=_track)
dsn.via(grid=r34, mn=r34(nor1.p['A'])[1])

# A2
_mn = [r34(inv5.p['O'])[0]+[0,2], r34(nand0.p['A'])[0]]
ra2 = dsn.route(grid=r34, mn= _mn, via_tag=[True, True])

# A3
_mn = [r34(nand0.p['O'])[0]+[0,3], r34(inv6.p['I'])[0]]
ra3 = dsn.route(grid=r34, mn= _mn, via_tag=[True, True])

# A4
_mn = [r34(inv6.p['O'])[0]+[0,2], r34(nor1.p['B'])[0]]
ra4 = dsn.route(grid=r34, mn= _mn, via_tag=[True, True])

# A5~6

# inv 8x6x IN
_track = [r23(in0.p['G'])[0,0]-1, None]
rin10 = dsn.route(grid=r23, mn=[in0.p['G'], ip0.p['G']], track=_track)

# inv 8x6x OUT
_track = [r23(in0.p['D'])[-1,0]+1, None]
rin11 = dsn.route(grid=r23, mn=[in0.p['D'], ip0.p['D']], track=_track)

#A5
_mn = [r34(nor1.p['O'])[0]+[0,2], r34(rin10[-1])[0]]
ra5 = dsn.route(grid=r34, mn= _mn, via_tag=[True, True])

#A6
_mn = [r34(rin11[-1])[0]+[0,2], r34(rin11[-1])[0]+[4,2]]
ra6 = dsn.route(grid=r34, mn= _mn, via_tag=[True, False])



# 6. Create pins.
pa0 = dsn.pin(name='A<0>', grid=r23, mn=inv0.p['I'])
pa1 = dsn.pin(name='A<1>', grid=r34, mn=ra1[1])
pa2 = dsn.pin(name='A<2>', grid=r34, mn=ra2[1])
pa3 = dsn.pin(name='A<3>', grid=r34, mn=ra3[1])
pb4 = dsn.pin(name='A<4>', grid=r34, mn=ra4[1])
pb5 = dsn.pin(name='A<5>', grid=r34, mn=ra5[1])
pb6 = dsn.pin(name='A<6>', grid=r34, mn=ra6[1])

pb1 = dsn.pin(name='B<1>', grid=r34, mn=rb1[1])
pb2 = dsn.pin(name='B<2>', grid=r34, mn=rb2[1])
pb3 = dsn.pin(name='B<3>', grid=r34, mn=rb3[1])
pb4 = dsn.pin(name='B<4>', grid=r34, mn=rb4[1][0])

pdlyen = dsn.pin(name='DLY_EN', grid=r23, mn=nor0.p['B'])
pdlyenb = dsn.pin(name='DLY_ENB', grid=r23, mn=nand0.p['B'])


#pb0 = dsn.pin(name='B', grid=r23, mn=inv2.p['I'])
#pclkp0 = dsn.pin(name='CLKP', grid=r23, mn=inv3.p['O'])
#pclkn0 = dsn.pin(name='CLKN', grid=r23, mn=inv2.p['O'])

# tech.fill_by_instance(dsn, grids, tlib, tlib, "space_1x" , iter_type=("R0","MX"))
tech.fill_by_instance(dsn, grids, tlib_adc, tlib_adc, "filler_dmy_2x" , iter_type=("R0","MX"))
# tech.fill_by_instance(dsn, grids, templates, templates, inst_name=("nmos4_fast_dmy_nf2", "pmos4_fast_dmy_nf2") , iter_type=("R0","MX"))

# Rails
tech.generate_pwr_rail(dsn, grids, netname=['VSS', 'VDD'], vertical=False)  

# 7. Export to physical database.
print("Export design")
print("")
# laygo2.export(lib, tech=tech, filename=export_path_skill+libname+'_'+cellname+'.il')
# Filename example: ./laygo2_generators_private/logic/skill/logic_tap.il
 
# 8. Export to a template database file.
nat_temp = dsn.export_to_template()
laygo2.export_template(nat_temp, filename=export_path+libname+'_templates.yaml', mode='append')
# Filename example: ./laygo2_generators_private/logic/logic_generated_templates.yaml

# test jSON DB export
grid_table = dict()
grid_table['M1'] = r12
grid_table['M2'] = r23
grid_table['M3'] = r34
grid_table['M4'] = r45
grid_table['M5'] = r45
exporter = laygo2.object.database.DesignExporter(dsn, grid_table, lib_ref = "laygo2_generators_private/prj_db/tbadc/library.yaml")
nat_dict = exporter.export_to_dict()
laygo2.interface.json.export_dict(nat_dict, filename=export_path_db+libname+'_db.json', mode='append')
