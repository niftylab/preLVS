import numpy as np
import laygo2
import laygo2_tech as tech
import laygo2.object.database
import laygo2.interface.json

export_path_db      = './laygo2_generators_private/prj_db/tbadc/' # Path for JSON DB export

# Parameter definitions #############
# Design Variables
#cell_type = ['xor']

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
# End of parameter definitions ######

# Generation start ##################
# 1. Load templates and grids.
print("Load templates")
templates = tech.load_templates()
tpmos, tnmos = templates[tpmos_name], templates[tnmos_name]
tlib = laygo2.import_template(filename=export_path+'tbadc_generated_templates.yaml')
tlib_logic = laygo2.import_template(filename='./laygo2_generators_private/logic/logic_generated_templates.yaml')

print("Load grids")
grids = tech.load_grids(templates=templates)
pg, r12, r23, r34 = grids[pg_name], grids[r12_name], grids[r23_name], grids[r34_name]


cellname = 'xor_static_inv_v1'
print('--------------------')
print(f'Creating {cellname}')
 
# 2. Create a design hierarchy
lib = laygo2.Library(name=libname)
dsn = laygo2.Design(name=cellname, libname=libname)
lib.append(dsn)

# 3. Create istances.
print("Create instances")
inv0        = tlib_logic['inv_2x'               ].generate(name='I0', transform='MX',   netmap={'I': 'B',  'O': 'Bb'})
inv1        = tlib_logic['inv_2x'               ].generate(name='I1', transform='MX',   netmap={'I': 'A',  'O': 'Ab'})
nand_match0 = tlib['nand_match_2x_for_xor'].generate(name='I2',                   netmap={'A': 'A',  'B': 'B',  'O': 'N0'})
nand_match1 = tlib['nand_match_2x_for_xor'].generate(name='I3',                   netmap={'A': 'N0', 'B': 'N1', 'O': 'XOR'})
nand_match2 = tlib['nand_match_2x_for_xor'].generate(name='I4', transform='R180', netmap={'A': 'Ab', 'B': 'Bb', 'O': 'N1'})

# 4. Place instances.
dsn.place(grid=pg, inst=[[nand_match0, nand_match1], [None, nand_match2]], mn=[0, 0])
dsn.place(grid=pg, inst=inv0, mn=pg.top_left(nand_match0) + pg.mn.height_vec(inv0))
dsn.place(grid=pg, inst=inv1, mn=pg.top_center(nand_match0) + pg.mn.height_vec(inv1))
tech.fill_by_instance(dsn, grids, tlib_logic, tlib_logic, 'space_2x', iter_type=('R0', 'MX'))

# 5. Create and place wires.
print("Create wires")

# A
rA0 = dsn.route(grid=r34, mn=[inv1.p['I'], nand_match0.p['A']])

# B
rB0 = dsn.route(grid=r34, mn=[inv0.p['I'], nand_match0.p['B']])

# INV out to NAND input
dsn.route(grid=r34, mn=[inv0.p['O'], nand_match2.p['B']], via_tag=[True, True])

_track = [None, r34.center(inv1.p['O'])[1] - 1]
dsn.route(grid=r34, mn=[inv1.p['O'], nand_match2.p['A']], track=_track)

# NAND to NAND
dsn.route(grid=r34, mn=[r34.center(nand_match0.p['O']) + [0, 1], nand_match1.p['A']], via_tag=[True, True])

_track = [None, r34(nand_match1.p['B'])[1,1] + 2]
dsn.route(grid=r34, mn=[nand_match1.p['B'], nand_match2.p['O']], track=_track)

# 6. Create pins.
pA  = dsn.pin(name='A',   grid=r34, mn=rA0)
pB  = dsn.pin(name='B',   grid=r34, mn=rB0)
pXOR  = dsn.pin(name='XOR',   grid=r34, mn=nand_match1.p['O'])
tech.generate_pwr_rail(dsn, grids, netname=['VSS', 'VDD'], vertical=False)

# 7. Export to physical database.
print("Export design")
print("")
# laygo2.export(lib, tech=tech, filename=export_path_skill+libname+'_'+cellname+'.il')
# Filename example: ./laygo2_generators_private/tbadc/xor/skill/xor.il
 
# 8. Export to a template database file.
nat_temp = dsn.export_to_template()
laygo2.export_template(nat_temp, filename=export_path+libname+'_templates.yaml', mode='append')
# Filename example: ./laygo2_generators_private/tbadc/xor/tbadc_generated_templates.yaml

# test jSON DB export
grid_table = dict()
grid_table['M1'] = r12
grid_table['M2'] = r23
grid_table['M3'] = r34
grid_table['M4'] = r34
exporter = laygo2.object.database.DesignExporter(dsn, grid_table, lib_ref = "laygo2_generators_private/prj_db/tbadc/library.yaml")
nat_dict = exporter.export_to_dict()
laygo2.interface.json.export_dict(nat_dict, filename=export_path_db+libname+'_db.json', mode='append')