##########################################################
#                                                    
#                 SPACE Layout Gernerator            
#     Contributors: T. Shin, S. Park, Y. Oh, T. Kang 
#                 Last Update: 2022-05-27            
#                                                    
##########################################################

import numpy as np
import pprint
import laygo2
import laygo2.interface
import laygo2_tech as tech
from laygo2.object.netmap import NetMap

# Parameter definitions #############
# Design Variables
cell_type = 'space'
nf_list = [1,2,4]

# Templates
tpmos_name = 'pmos'
tnmos_name = 'nmos'

# Grids
pg_name = 'placement_basic'
r12_name = 'routing_12_cmos'
r23_name = 'routing_23_cmos'


# Design hierarchy
libname             = 'test_generated'
export_path         = './laygo2_generators_private/feature_test/export_raw_dict/' # Layout generation path: "export_path/libname/cellname"
export_path_skill   = export_path+'skill/' # SKILL file generation path: "export_path_skill/libname_cellname.il"
export_path_db      = './laygo2_generators_private/prj_db/'
# End of parameter definitions ######

# Generation start ##################
# 1. Load templates and grids.
print("Load templates")
templates = tech.load_templates()
tpmos, tnmos = templates[tpmos_name], templates[tnmos_name]
tlib = laygo2.interface.yaml.import_template(filename=export_path+libname+'_templates.yaml') # Uncomment if you use the logic templates
# print(templates[tpmos_name], templates[tnmos_name], sep="\n") # Uncomment if you want to print templates

print("Load grids")
grids = tech.load_grids(templates=templates)
pg, r12, r23 = grids[pg_name], grids[r12_name], grids[r23_name]
# print(grids[pg_name], grids[r12_name], grids[r23_name], sep="\n") # Uncomment if you want to print grids

for nf in nf_list:
   cellname = cell_type+'_'+str(nf)+'x'
   print('--------------------')
   print('Now Creating '+cellname)

# 2. Create a design hierarchy
   lib = laygo2.Library(name=libname)
   dsn = laygo2.Design(name=cellname, libname=libname)
   lib.append(dsn)
   
# 3. Create istances.
   print("Create instances")
   nspace = templates['nmos4_fast_space_1x'].generate(name='nspace',                 shape=[nf, 1])
   pspace = templates['pmos4_fast_space_1x'].generate(name='pspace', transform='MX', shape=[nf, 1])
   
# 4. Place instances.
   dsn.place(grid=pg, inst=[[nspace], [pspace]], mn=[0,0])
   
# 5. Create and place wires.
   print("Create wires")
   
   # VSS
   if nf != 1:
      rvss0 = dsn.route(grid=r12, mn=[r12.bottom_left(nspace), r12.bottom_right(nspace)])
   
   # VDD
      rvdd0 = dsn.route(grid=r12, mn=[r12.top_left(pspace), r12.top_right(pspace)])
   
# 6. Create pins.
      pvss0 = dsn.pin(name='VSS', grid=r12, mn=r12(rvss0))
      pvdd0 = dsn.pin(name='VDD', grid=r12, mn=r12(rvdd0))
   
# 7. Export to physical database.
   print("Export design")
   print("")
#    laygo2.export(lib, tech=tech, filename=export_path_skill+libname+'_'+cellname+'.il')
#    # Filename example: ./laygo2_generators_private/logic/skill/logic_generated_space_1x.il

# # 8. Export to a template database file.
#    nat_temp = dsn.export_to_template()
#    laygo2.export_template(nat_temp, filename=export_path+libname+'_templates.yaml', mode='append')
#    # Filename example: ./laygo2_generators_private/logic/logic_generated_templates.yaml


   # test jSON DB export
   grid_table = dict()
   grid_table['M1'] = r12
   grid_table['M2'] = r23
   grid_table['M3'] = r23
   exporter = laygo2.object.database.DesignExporter(dsn, grid_table, lib_ref = "laygo2_generators_private/prj_db/library.yaml")
   nat_dict = exporter.export_to_dict()
   laygo2.interface.json.export_dict(nat_dict, filename=export_path_db+libname+'_db.json', mode='append')
   # Pre-LVS test
   via_table = dict()
   via_table["via_M1_M2_0"] = ('M1','M2')
   via_table["via_M1_M2_1"] = ('M1','M2')
   via_table["via_M2_M3_0"] = ('M2','M3')
   via_table["via_M2_M3_1"] = ('M2','M3')
   mosList = ["nmos4_fast_space_1x", "pmos4_fast_space_1x"]
   nMap = NetMap.import_from_design(dsn, grid_table, via_table, orient_first="vertical", layer_names=['M1','M2','M3'],
                                       net_ignore = [], lib_ref = "laygo2_generators_private/prj_db/library.yaml", core_templates=mosList)
#    metal_num = nMap.count_metals()
#    print("# of metal vectors =",metal_num)
   nat_temp = dsn.export_to_template(metal_table=grid_table, net_ignore = [], export_mask=False)
   laygo2.interface.yaml.export_template(nat_temp, filename=export_path+libname+'_templates.yaml', mode='append')
   # Filename example: ./laygo2_generators_private/logic/logic_generated_templates.yaml