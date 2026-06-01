##########################################################    
# Contributors: S. Yun
# Last Updated: 2024-10-22                
##########################################################

import numpy as np
import laygo2
import laygo2_tech as tech
import laygo2.object.database
import laygo2.interface.json

# Parameter definitions #############
# Design Variables
nf = 4
chain_length = 10
cell_name = f'inv_chain_{nf}x_1f_basic'

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
# Layout generation path: "export_path/libname/cellname"
export_path = './laygo2_generators_private/tbadc/' 
# SKILL file generation path: "export_path_skill/libname_cellname.il"
export_path_skill = export_path+'skill/' 
export_path_db      = './laygo2_generators_private/prj_db/tbadc/' # Path for JSON DB export
# End of parameter definitions ######

# Generation start ##################
# 1. Load templates and grids.
print("Load templates")
templates = tech.load_templates()
tlib = laygo2.interface.yaml.import_template(
   filename='./laygo2_generators_private/logic/logic_generated_templates.yaml')
tpmos, tnmos = templates[tpmos_name], templates[tnmos_name]

print("Load grids")
grids = tech.load_grids(templates=templates)
pg, r12, r23, r34 = grids[pg_name], grids[r12_name], grids[r23_name], grids[r34_name]

print('-----------------')
print(f'Creating {cell_name}')

# 2. Create a design hierarchy
lib = laygo2.Library(name=libname)
dsn = laygo2.Design(name=cell_name, libname=libname)
lib.append(dsn)

# 3. Create instances
print("Create instances")
inv_list = list()
for i in range(chain_length):
    _inv = tlib[f'inv_{nf}x'].generate(name=f'INV{i}', transform='R0')
    inv_list.append(_inv)

# 4. Place instances
cursor = [0,0]
for inv in inv_list:
    dsn.place(grid=pg, inst=inv, mn=cursor)
    cursor = pg.mn.bottom_right(inv)

# 5. Create and place wires.
print("Route wires")
rvout0 = []
for i, inv in enumerate(inv_list):
    if(i == len(inv_list)-1):
        pass
    else:
        inv_next = inv_list[i+1]
        _mn = [r23.mn.center(inv.p['O']), r23.mn.center(inv_next.p['I'])]
        _mn[0][1] = _mn[1][1]
        _, _rvout0, _ = dsn.route(grid=r34, mn=_mn, via_tag=[True, True])
        rvout0.append(_rvout0)

_mn = [r23.mn.top_left(inv_list[0]), r23.mn.top_right(inv_list[-1])]
rvdd0 = dsn.route(grid=r23, mn=_mn)
_mn = [r23.mn.bottom_left(inv_list[0]), r23.mn.bottom_right(inv_list[-1])]
rvss0 = dsn.route(grid=r23, mn=_mn)

#tech.generate_pwr_rail(dsn, grids, netname=['VSS', 'VDD'], vertical=False)


# 6. Create pinsf
pin0  = dsn.pin(name='IN', grid=r23, mn=r23.bbox(inv_list[0].p['I']))

for i in range(chain_length-1):
    pvout0 = dsn.pin(name=f'OUT<{i}>', grid=r34, mn=r34.bbox(rvout0[i]))

pvss0 = dsn.pin(name='VSS:', grid=r23, mn=r23.bbox(rvss0))
pvdd0 = dsn.pin(name='VDD:', grid=r23, mn=r23.bbox(rvdd0))

# 7. Export to physical database
# laygo2.interface.bag.export(lib, filename=export_path_skill+cell_name+'.il', cellname=None, scale=1e-3,
#                                 reset_library=False, tech_library=tech.name)
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
grid_table['M3'] = r34
grid_table['M4'] = r34
exporter = laygo2.object.database.DesignExporter(dsn, grid_table, lib_ref = "laygo2_generators_private/prj_db/tbadc/library.yaml")
nat_dict = exporter.export_to_dict()
laygo2.interface.json.export_dict(nat_dict, filename=export_path_db+libname+'_db.json', mode='append')
