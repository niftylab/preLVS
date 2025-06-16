##########################################################
#                                                    
# Dummy Filler 2X Layout Gernerator             
# Contributors: Youjin Byun
# Last Updated: 2024-10-17
#                                                    
##########################################################

import numpy as np
import laygo2
import laygo2_tech as tech
import laygo2.object.database
import laygo2.interface.json

# Parameter definitions #############
# Design Variables
cell_name = 'filler_dmy_2x'

# Templates
tpmos_name = 'pmos'
tnmos_name = 'nmos'

# Grids
pg_name = 'placement_basic'
r12_name = 'routing_12_cmos'
r23_name = 'routing_23_cmos'

# Design hierarchy
libname = 'tbadc_generated'
export_path       = './laygo2_generators_private/tbadc/'  # Layout generation path: "export_path/libname/cellname"
export_path_skill = export_path+'skill/' # SKILL file generation path: "export_path_skill/libname_cellname.il"
export_path_db      = './laygo2_generators_private/prj_db/tbadc/' # Path for JSON DB export
# End of parameter definitions ######

# Generation start ##################
# 1. Load templates and grids.
print("Load templates")
templates = tech.load_templates()
# tlib = laygo2.interface.yaml.import_template(filename=export_path+'logic_generated_templates.yaml') # Uncomment if you use the logic templates
# print(templates[tpmos_name], templates[tnmos_name], sep="\n") # Uncomment if you want to print templates

print("Load grids")
grids = tech.load_grids(templates=templates)
pg, r12, r23 = grids[pg_name], grids[r12_name], grids[r23_name]
# print(grids[pg_name], grids[r12_name], grids[r23_name], sep="\n") # Uncomment if you want to print grids

print('--------------------')
print(f'Creating {cell_name}')

# 2. Create a design hierarchy
lib = laygo2.Library(name=libname)
dsn = laygo2.Design(name=cell_name, libname=libname)
lib.append(dsn)

# 3. Create istances.
print("Create instances")
ndmy0 = templates['nmos4_fast_dmy_nf2'].generate(name='ndmy0')
pdmy0 = templates['pmos4_fast_dmy_nf2'].generate(name='pdmy0', transform='MX')

# 4. Place instances.
dsn.place(grid=pg, inst=[[ndmy0], [pdmy0]], mn=[0,0])

#5. Create and place wires.
print("Create wires")

# VSS
_mn = [r12(ndmy0.p['D0'])[0], r12(ndmy0.p['S0'])[0], r12(ndmy0.p['S1'])[0]]
_track = [None, r12.bottom_right(ndmy0)[1]]
rvss0 = dsn.route_via_track(grid=r12, mn=_mn, track=_track)

# VDD
_mn = [r12(pdmy0.p['D0'])[0], r12(pdmy0.p['S0'])[0], r12(pdmy0.p['S1'])[0]]
_track = [None, r12.top_right(pdmy0)[1]]
rvdd0 = dsn.route_via_track(grid=r12, mn=_mn, track=_track)

# 6. Create pins.
tech.generate_pwr_rail(dsn, grids, netname=['VSS', 'VDD'], vertical=False)

# 7. Export to physical database.
print("Export design")
print("")
# laygo2.interface.bag.export(lib, tech_library=tech.name, filename=cell_name+'.il')
# Filename example: ./laygo2_generators_private/logic/skill/logic_tap.il

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
