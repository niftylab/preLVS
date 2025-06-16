##########################################################
#                                                           
# NAND Layout Gernerator                 
# Contributors: Created J. Choi    
# Last Updated: 2024-10-10
#                                                           
##########################################################

import numpy as np
import laygo2
import laygo2_tech as tech
import laygo2.object.database
import laygo2.interface.json

# Parameter definitions #############
# Design Variables
cell_type = 'nand2_balanced'
nf = [4,8]

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
tntap, tptap = templates[tntap_name], templates[tptap_name]
tlib = laygo2.import_template(filename=export_path + 'tbadc_generated_templates.yaml')

print("Load grids")
grids = tech.load_grids(templates=templates)
pg, r12, r23, r34 = grids[pg_name], grids[r12_name], grids[r23_name], grids[r34_name]
# Uncomment if you want to print grids
# print(grids[pg_name], grids[r12_name], grids[r23_name], sep="\n")
cellname = cell_type
print('--------------------')
print(f'Creating {cellname}')

# 2. Create a design hierarchy
lib = laygo2.Library(name=libname)
dsn = laygo2.Design(name=cellname, libname=libname)
lib.append(dsn)

# 3. Create istances.
print("Create instances")

in0  = tnmos.generate(name='MN0', transform='MX' ,params={'nf': nf[0], 'tie': 'S', 'rtrackswap': True})
in1  = tnmos.generate(name='MN1', params={'nf': nf[0], 'tie': 'S', 'rtrackswap': True})
in2  = tnmos.generate(name='MN2', transform='MX', params={'nf': nf[0], 'rtrackswap': False})
in3  = tnmos.generate(name='MN3', params={'nf': nf[0], 'rtrackswap': False})
ip0  = tpmos.generate(name='MP0', params={'nf': nf[1], 'tie': 'S', 'rtrackswap': True})
ip1  = tpmos.generate(name='MP1', transform='MX', params={'nf': nf[1], 'tie': 'S', 'rtrackswap': True})
nspace0 = templates['nmos4_fast_space_1x'].generate(name = 'nspace0', shape = [1,1])
nspace1 = templates['nmos4_fast_space_1x'].generate(name = 'nspace1', shape = [1,1])
pspace0 = templates['pmos4_fast_space_1x'].generate(name = 'pspace0', shape = [2,1])
pspace1 = templates['pmos4_fast_space_1x'].generate(name = 'pspace1', shape = [2,1])
pspace2 = templates['pmos4_fast_space_1x'].generate(name = 'pspace2', shape = [1,1])
pspace3 = templates['pmos4_fast_space_1x'].generate(name = 'pspace3', shape = [1,1])

# 4. Place instances.
dsn.place(grid=pg, inst=[[pspace0],[in0],[in1],[pspace1]], mn=[0,0])
dsn.place(grid=pg, inst=[[ip0,pspace2]], mn = pg.bottom_right(pspace0))
dsn.place(grid=pg, inst=[[in2,nspace0]], mn = pg.bottom_right(in0))
dsn.place(grid=pg, inst=[[in3,nspace1]], mn = pg.bottom_right(in1))
dsn.place(grid=pg, inst=[[ip1,pspace3]], mn = pg.bottom_right(pspace1))

# 5. Create and place wires.
print("Create wires")

# Internal
#S/D 
_mn = [r12.mn(in0.p['D'])[0], r12.mn(in2.pins['S'])[0]]  
_track = [None, r12(in0.p['D'])[0,1]]
dsn.route_via_track(grid=r12, mn=_mn, track=_track)

_mn = [r12.mn(in1.p['D'])[0], r12.mn(in3.pins['S'])[0]]  
_track = [None, r12(in1.p['D'])[0,1]]
dsn.route_via_track(grid=r12, mn=_mn, track=_track)

#G
_mn = [r12.mn(in2.p['G'])[1], r12.mn(ip0.pins['G'])[1]]  
_track = [r12(in2.p['G'])[1,0], None]
dsn.route_via_track(grid=r12, mn=_mn, track=_track)

_mn = [r12.mn(in2.p['G'])[0], r12.mn(ip0.pins['G'])[1]]  
_track = [r12(in2.p['G'])[0,0],None]
dsn.route_via_track(grid= r12, mn=_mn, track=_track)

_mn = [r12.mn(in3.p['G'])[1], r12.mn(ip1.pins['G'])[1]]  
_track = [r12(in3.p['G'])[1,0], None]
dsn.route_via_track(grid=r12, mn=_mn, track=_track)

_mn = [r12.mn(in3.p['G'])[0], r12.mn(ip1.pins['G'])[1]]  
_track = [r12(in3.p['G'])[0,0], None]
dsn.route_via_track(grid=r12, mn=_mn, track=_track)

_mn = [r23.mn(in2.p['G'])[0], r23.mn(ip0.pins['G'])[1]]  
_track = [r23(in2.p['G'])[0,0] - 1,None]
dsn.route_via_track(grid= r23, mn=_mn, track=_track)

_mn = [r23.mn(in3.p['G'])[0], r23.mn(ip1.pins['G'])[1]]  
_track = [r23(in3.p['G'])[0,0] - 1,None]
dsn.route_via_track(grid= r23, mn=_mn, track=_track)


#external 
#Gate connetion between input nodes
_mn = [r23.mn(in0.p['G'])[0], r23.mn(ip1.pins['G'])[0]]  
_track = [r23(in0.p['G'])[0,0] - 1, None]
rA = dsn.route_via_track(grid=r23, mn=_mn, track=_track)[-1]

_mn = [r23.mn(in1.p['G'])[1], r23.mn(ip0.pins['G'])[0]]  
_track = [r23(in1.p['G'])[1,0] - 1, None]
rB = dsn.route_via_track(grid=r23, mn=_mn, track=_track)[-1] 

#OUT
_mn = [r23.mn(ip1.p['D'])[1], r23.mn(in3.pins['D'])[1],r23.mn(in2.p['D'])[1], r23.mn(ip0.pins['D'])[1]]  
_track = [r23(ip1.p['D'])[1,0] + 2, None]
rout = dsn.route_via_track(grid=r23, mn=_mn, track=_track, via_tag=[True, True, True, True])[-1]

_mn = [r23.mn(ip1.p['D'])[1], r23.mn(in3.pins['D'])[1],r23.mn(in2.p['D'])[1], r23.mn(ip0.pins['D'])[1]]  
_track = [r23(ip1.p['D'])[1,0], None]
dsn.route_via_track(grid=r23, mn=_mn, track=_track, via_tag=[True, True, True, True])


# 6. Create pins.
pA = dsn.pin(name='A', grid=r23, mn=rA)
pB = dsn.pin(name='B', grid=r23, mn=rB)
pout = dsn.pin(name='O', grid=r23, mn=rout)


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
grid_table['M3'] = r34
grid_table['M4'] = r34
exporter = laygo2.object.database.DesignExporter(dsn, grid_table, lib_ref = "laygo2_generators_private/prj_db/tbadc/library.yaml")
nat_dict = exporter.export_to_dict()
laygo2.interface.json.export_dict(nat_dict, filename=export_path_db+libname+'_db.json', mode='append')
