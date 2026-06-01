##########################################################
#                                                        #
#           Tri-State Inverter Layout Generator          #
#     Contributors: T. Shin, S. Park, Y. Oh, T. Kang     #
#                 Last Update: 2022-05-27                #
#                                                        #
##########################################################

import numpy as np
import pprint
import laygo2
import laygo2.interface
import laygo2_tech as tech
from laygo2.object.netmap import NetMap
# Parameter definitions #############
# Design Variables
cell_type = ['tinv']#, 'tinv_ltap']#, 'tinv_hs'] # tinv_hs stands for high-speed tri-state inverter. Output is connected with multiple wires while that of simple tri-state inverter is connected with a single wire.
nf_list = [2, 4, 6]#, 8]

# Templates
tpmos_name = 'pmos'
tnmos_name = 'nmos'
tntap_name = 'ntap'
tptap_name = 'ptap'

# Grids
pg_name = 'placement_basic'
r12_name = 'routing_12_cmos'
r23_name = 'routing_23_cmos'
r34_name = 'routing_34_basic'

# Design hierarchy
libname              = 'test_generated'
export_path          = './laygo2_generators_private/feature_test/export_raw_dict/' # Layout generation path: "export_path/libname/cellname"
export_path_skill    = export_path+'skill/' # SKILL file generation path: "export_path_skill/libname_cellname.il"
export_path_db       = './laygo2_generators_private/prj_db/'
# End of parameter definitions ######

# Generation start ##################
# 1. Load templates and grids.
print("Load templates")
templates = tech.load_templates()
tpmos, tnmos = templates[tpmos_name], templates[tnmos_name]
tntap, tptap = templates[tntap_name], templates[tptap_name]
# tlib = laygo2.interface.yaml.import_template(filename=export_path+'logic_generated_templates.yaml') # Uncomment if you use the logic templates
# print(templates[tpmos_name], templates[tnmos_name], sep="\n") # Uncomment if you want to print templates

print("Load grids")
grids = tech.load_grids(templates=templates)
pg, r12, r23, r34 = grids[pg_name], grids[r12_name], grids[r23_name], grids[r34_name]
# print(grids[pg_name], grids[r12_name], grids[r23_name], grids[r34_name], sep="\n") # Uncomment if you want to print grids

for celltype in cell_type:
   for nf in nf_list:
      cellname = celltype+'_'+str(nf)+'x'
      print('--------------------')
      print('Now Creating '+cellname)
      
# 2. Create a design hierarchy
      lib = laygo2.object.database.Library(name=libname)
      dsn = laygo2.object.database.Design(name=cellname, libname=libname)
      lib.append(dsn)
      
# 3. Create istances.
      print("Create instances")
      if celltype == 'tinv_hs':
         net_out = 'O:'    
      else:
         net_out = 'O'
      iptl = tptap.generate(name='PT0',                  params={'nf': 2, 'tie': 'TAP0'}, netmap={'D':'VSS:', 'RAIL':'VSS:'}) # ':' for pre-LVS tap M1 issue
      intl = tntap.generate(name='NT0', transform='MX',  params={'nf': 2, 'tie': 'TAP0'}, netmap={'D':'VDD:', 'RAIL':'VDD:'}) # ':' for pre-LVS tap M1 issue
      in0 = tnmos.generate(name='MN0',                   params={'nf': nf, 'tie': 'S'},  
                  netmap={'G':'I', 'D':'Ninternal','RAIL':'VSS:'})
      ip0 = tpmos.generate(name='MP0', transform='MX',   params={'nf': nf, 'tie': 'S'},  
                  netmap={'G':'I', 'D':'Pinternal', 'RAIL':'VDD:'})
      in1 = tnmos.generate(name='MN1',                   params={'nf': nf, 'trackswap': True},  
                  netmap={'G':'EN', 'D':net_out, 'S':'Ninternal', 'RAIL':'VSS:'})
      ip1 = tpmos.generate(name='MP1', transform='MX',   params={'nf': nf, 'trackswap': True},
                  netmap={'G':'ENB', 'D':net_out, 'S':'Pinternal', 'RAIL':'VDD:'})
      
# 4. Place instances.
      if celltype == 'tinv_ltap':
         dsn.place(grid=pg, inst=[[iptl, in0, in1], [intl, ip0, ip1]], mn=[0,0])
      else:
         dsn.place(grid=pg, inst=[[in0, in1], [ip0, ip1]], mn=[0,0])

# 5. Create and place wires.
      print("Create wires")
      
      # IN
      _mn = [r23.mn(in0.pins['G'])[0], r23.mn(ip0.pins['G'])[0]]
      v0, rin0, v1 = dsn.route(grid=r23, mn=_mn, via_tag=[True, True])
   
      # OUT
      if (celltype == 'tinv') or (celltype == 'tinv_ltap'):      
         _mn = [r23.mn(in1.pins['D'])[1]+[-1,0], r23.mn(ip1.pins['D'])[1]+[-1,0]]
         vout0, rout0, vout1 = dsn.route(grid=r23, mn=_mn, via_tag=[True, True])
      elif celltype == 'tinv_hs':
         for i in range(int(nf/2)):
            _mn = [r23.mn(in1.pins['D'])[0]+[2*i-1,0], r23.mn(ip1.pins['D'])[0]+[2*i-1,0]]
            vout0, rout0, vout1 = dsn.route(grid=r23, mn=_mn, via_tag=[True, True])
      
      # EN
      _mn = [r23.mn(in1.pins['G'])[1]+[1,0], r23.mn(ip1.pins['G'])[1]+[1,0]]
      ven0, ren0 = dsn.route(grid=r23, mn=_mn, via_tag=[True, False])

      _mn = [r23.mn(in1.pins['G'])[1], r23.mn(in1.pins['G'])[1]+[1,0]]
      renint = dsn.route(grid=r23, mn=_mn)
      
      # ENB
      _mn = [r23.mn(in1.pins['G'])[1]+[-1,0], r23.mn(ip1.pins['G'])[1]+[-1,0]]
      renb0, venb0 = dsn.route(grid=r23, mn=_mn, via_tag=[False, True])
      
      _mn = [r23.mn(ip1.pins['G'])[1]+[-1,0], r23.mn(ip1.pins['G'])[1]]
      renbint = dsn.route(grid=r23, mn=_mn)
      
      # Internal
      _mn = [r23.mn(ip0.pins['D'])[0], r23.mn(ip1.pins['S'])[0]]
      rintp0 = dsn.route(grid=r23, mn=_mn)

      _mn = [r23.mn(in0.pins['D'])[0], r23.mn(in1.pins['S'])[0]]
      rintn0 = dsn.route(grid=r23, mn=_mn)
      
# 6. Create pins.
      pin0 = dsn.pin(name='I', grid=r23, mn=r23.mn.bbox(rin0))
      pen0 = dsn.pin(name='EN', grid=r23, mn=r23.mn.bbox(ren0))
      penb0 = dsn.pin(name='ENB', grid=r23, mn=r23.mn.bbox(renb0))
      if (celltype == 'tinv') or (celltype == 'tinv_ltap'):
         pout0 = dsn.pin(name='O', grid=r23, mn=r23.mn.bbox(rout0))
      elif celltype == 'tinv_hs':
         pout0 = dsn.pin(name='O'+str(i), grid=r23, mn=r23.mn.bbox(rout0), netname='O:')
      tech.generate_pwr_rail(dsn, grids, netname=['VSS', 'VDD'], vertical=False) # pin name이 VSS1 VDD1 이런식으로 되어야 할 것 같음 -> 수정 필요.
      
# 7. Export to physical database.
      print("Export design")
      print("")
#      laygo2.interface.bag.export(lib, filename=export_path_skill +libname+'_'+cellname+'.il', cellname=None, scale=1e-3, reset_library=False, tech_library=tech.name)
      # Filename example: ./laygo2_generators_private/logic/skill/logic_generated_tinv_4x.il

      # 8. Export to a template database file.
      # test JSON db export
      grid_table = dict()
      grid_table['M1'] = r12
      grid_table['M2'] = r23
      grid_table['M3'] = r23
      exporter = laygo2.object.database.DesignExporter(dsn, grid_table, lib_ref = "laygo2_generators_private/prj_db/library.yaml")
      nat_dict = exporter.export_to_dict()
      laygo2.interface.json.export_dict(nat_dict, filename=export_path_db+libname+'_db.json', mode='append')
      # test pre-LVS
      via_table = dict()
      via_table["via_M1_M2_0"] = ('M1','M2')
      via_table["via_M1_M2_1"] = ('M1','M2')
      via_table["via_M2_M3_0"] = ('M2','M3')
      via_table["via_M2_M3_1"] = ('M2','M3')
      mosList = ["nmos4_fast_center_nf2", "nmos4_fast_center_2stack","pmos4_fast_center_nf2", "pmos4_fast_center_2stack"]
      nMap = NetMap.import_from_design(dsn, grid_table, via_table, orient_first="vertical", layer_names=['M1','M2','M3'], net_ignore = [], lib_ref = "laygo2_generators_private/prj_db/library.yaml", core_templates=mosList)
      nat_temp = dsn.export_to_template(metal_table=grid_table, net_ignore = [], export_mask=False)
      laygo2.interface.yaml.export_template(nat_temp, filename=export_path+libname+'_templates.yaml', mode='append')    
      # Filename example: ./laygo2_generators_private/logic/logic_generated_templates.yaml