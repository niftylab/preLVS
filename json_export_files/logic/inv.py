##########################################################
#                                                        #
#                Inverter Layout Generator               #
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
cell_type = ['inv', 'inv_hs']#, 'inv_ltap', 'inv_hp', 'inv_io'] 
    # _ltap stands for tap on the left side
    # _hs stands for high-speed. (Output is connected with multiple wires to reduce R).
    # _hp stands for high-power. (hs + additional tap rows are placed to enhance power network).
    # _io stands for io. (hs + hp + additional tap rows btn p/n are placed for guardring).
nf_list = [2, 4, 6, 8, 24]#, 10, 12, 16, 24, 32]#, 36, 40, 50, 64, 72, 100]

# Templates
tpmos_name = 'pmos'
tnmos_name = 'nmos'
tntap_name = 'ntap'
tptap_name = 'ptap'

# Grids
pg_name = 'placement_basic'
r12m_name = 'routing_12_mos'
r23m_name = 'routing_23_mos'
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
pg, r12m, r23m, r34 = grids[pg_name], grids[r12m_name], grids[r23m_name], grids[r34_name]
# print(grids[pg_name], grids[r12_name], grids[r23_name], grids[r34_name], sep="\n") # Uncomment if you want to print grids

for celltype in cell_type:
   for nf in nf_list:
      cellname = celltype+'_'+str(nf)+'x'
      if (celltype == 'inv') or (cell_type == 'inv_ltap') or (celltype == 'inv_hs'):
         r12 = laygo2.object.grid.vstack([r12m, r12m.vflip()])
         r23 = laygo2.object.grid.vstack([r23m, r23m.vflip()])
      elif celltype.endswith('_hp'):
         r12 = laygo2.object.grid.vstack([r12m, r12m, r12m.vflip(), r12m.vflip()])
         r23 = laygo2.object.grid.vstack([r23m, r23m, r23m.vflip(), r23m.vflip()])
      elif celltype.endswith('_io'):
         r12 = laygo2.object.grid.vstack([r12m, r12m, r12m.vflip(), r12m, r12m.vflip(), r12m, r12m.vflip(), r12m.vflip()])
         r23 = laygo2.object.grid.vstack([r23m, r23m, r23m.vflip(), r23m, r23m.vflip(), r23m, r23m.vflip(), r23m.vflip()])

      print('--------------------')
      print('Now Creating '+cellname)
      
# 2. Create a design hierarchy
      lib = laygo2.object.database.Library(name=libname)
      dsn = laygo2.object.database.Design(name=cellname, libname=libname)
      lib.append(dsn)
      
# 3. Create instances.
      print("Create instances")
      if (celltype == 'inv_hs') or (celltype == 'inv_hp') or (celltype == 'inv_io'):
         net_out = 'O:'
      else:
         net_out = 'O'
      iptl = tptap.generate(name='PT0',                 params={'nf': 2, 'tie': 'TAP0'})
      ipt0 = tptap.generate(name='PT0',                 params={'nf': nf, 'tie': 'TAP0'})
      in0  = tnmos.generate(name='MN0',                 params={'nf': nf, 'tie': 'S'}, netmap={'G':'I','D':net_out,'RAIL':'VSS:'})
      ipt1 = tptap.generate(name='PT1', transform='MX', params={'nf': nf, 'tie': 'TAP0'})
      ipt2 = tptap.generate(name='PT2',                 params={'nf': nf, 'tie': 'TAP0'})
      int2 = tntap.generate(name='NT2', transform='MX', params={'nf': nf, 'tie': 'TAP0'})
      int1 = tntap.generate(name='NT1',                 params={'nf': nf, 'tie': 'TAP0'})
      ip0  = tpmos.generate(name='MP0', transform='MX', params={'nf': nf,'tie': 'S'}, netmap={'G':'I','D':net_out,'RAIL':'VDD:'})
      int0 = tntap.generate(name='NT0', transform='MX', params={'nf': nf, 'tie': 'TAP0'})
      intl = tntap.generate(name='NT0', transform='MX', params={'nf': 2, 'tie': 'TAP0'})
      
# 4. Place instances.
      if (celltype == 'inv') or (celltype == 'inv_hs'):
         dsn.place(grid=pg, inst=[[in0], [ip0]], mn=[0,0])
      elif (celltype == 'inv_ltap'):
         dsn.place(grid=pg, inst=[[iptl, in0], [intl, ip0]], mn=[0,0])
      elif celltype.endswith('_hp'):
         dsn.place(grid=pg, inst=[[ipt0], [in0], [ip0], [int0]], mn=[0,0])
      elif celltype.endswith('_io'):
         dsn.place(grid=pg, inst=[[ipt0], [in0], [ipt1], [ipt2], [int2], [int1], [ip0], [int0]], mn=[0,0])
      
# 5. Create and place wires.
      print("Create wires")

      # IN
      _mn = [r23.mn(in0.pins['G'])[0], r23.mn(ip0.pins['G'])[0]]
      _track = [r23.mn(in0.pins['G'])[0,0]-1, None]
      rin0 = dsn.route_via_track(grid=r23, mn=_mn, track=_track)
      
      # OUT
      if celltype == 'inv' or celltype == 'inv_ltap':
         _mn = [r23.mn(in0.pins['D'])[1], r23.mn(ip0.pins['D'])[1]]
         vout0, rout0, vout1 = dsn.route(grid=r23, mn=_mn, via_tag=[True, True])
      elif celltype.endswith('_hs') or celltype.endswith('_hp') or celltype.endswith('_io'):
         for i in range(int(nf/2)):
            _mn = [r23.mn(in0.pins['D'])[0]+[2*i,0], r23.mn(ip0.pins['D'])[0]+[2*i,0]]
            vout0, rout0, vout1 = dsn.route(grid=r23, mn=_mn, via_tag=[True, True])
      
      # VSS & VDD
      rvss0 = dsn.route(grid=r12, mn=[r12.mn(in0.pins['RAIL'])[0], r12.mn(in0.pins['RAIL'])[1]])
      rvdd0 = dsn.route(grid=r12, mn=[r12.mn(ip0.pins['RAIL'])[0], r12.mn(ip0.pins['RAIL'])[1]])
      if celltype.endswith('_hp') or celltype.endswith('io'):
         rvss1 = dsn.route(grid=r12, mn=[r12.mn(ipt0.pins['RAIL'])[0], r12.mn(ipt0.pins['RAIL'])[1]])
         rvdd1 = dsn.route(grid=r12, mn=[r12.mn(int0.pins['RAIL'])[0], r12.mn(int0.pins['RAIL'])[1]])
         for i in range(int(nf/2)+1): # vertical route
            dsn.route(grid=r12, mn=[r12.mn(ipt0.pins['RAIL'])[0]+[2*i+1, 0], r12.mn(in0.pins['RAIL'])[0]+[2*i+1, 0]])
            dsn.route(grid=r12, mn=[r12.mn(int0.pins['RAIL'])[0]+[2*i+1, 0], r12.mn(ip0.pins['RAIL'])[0]+[2*i+1, 0]])
      if celltype.endswith('_io'):
         rvss2 = dsn.route(grid=r12, mn=[r12.mn(ipt2.pins['RAIL'])[0], r12.mn(ipt2.pins['RAIL'])[1]])
         rvdd2 = dsn.route(grid=r12, mn=[r12.mn(int2.pins['RAIL'])[0], r12.mn(int2.pins['RAIL'])[1]])
      
# 6. Create pins.
      pin0 = dsn.pin(name='I', grid=r23, mn=r23.mn.bbox(rin0[2]))
      if (celltype == 'inv') or (celltype == 'inv_ltap'):
         pout0 = dsn.pin(name='O', grid=r23, mn=r23.mn.bbox(rout0))
      elif (celltype == 'inv_hs') or (celltype == 'inv_hp') or (celltype == 'inv_io'):
         pout0 = dsn.pin(name='O'+str(i), grid=r23, mn=r23.mn.bbox(rout0), netname='O:')
      if (celltype == 'inv') or (celltype == 'inv_ltap') or (celltype == 'inv_hs'):
         pvss0 = dsn.pin(name='VSS', grid=r12, mn=r12.mn.bbox(rvss0))
         pvdd0 = dsn.pin(name='VDD', grid=r12, mn=r12.mn.bbox(rvdd0))
      elif celltype.endswith('_hp'):
         pvss0 = dsn.pin(name='VSS0', grid=r12, mn=r12.mn.bbox(rvss0), netname='VSS:')
         pvdd0 = dsn.pin(name='VDD0', grid=r12, mn=r12.mn.bbox(rvdd0), netname='VDD:')
         pvss1 = dsn.pin(name='VSS1', grid=r12, mn=r12.mn.bbox(rvss1), netname='VSS:')
         pvdd1 = dsn.pin(name='VDD1', grid=r12, mn=r12.mn.bbox(rvdd1), netname='VDD:')
      elif celltype.endswith('_io'):
         pvss0 = dsn.pin(name='VSS0', grid=r12, mn=r12.mn.bbox(rvss0), netname='VSS:')
         pvdd0 = dsn.pin(name='VDD0', grid=r12, mn=r12.mn.bbox(rvdd0), netname='VDD:')
         pvss1 = dsn.pin(name='VSS1', grid=r12, mn=r12.mn.bbox(rvss1), netname='VSS:')
         pvdd1 = dsn.pin(name='VDD1', grid=r12, mn=r12.mn.bbox(rvdd1), netname='VDD:')
         pvss2 = dsn.pin(name='VSS2', grid=r12, mn=r12.mn.bbox(rvss2), netname='VSS:')
         pvdd2 = dsn.pin(name='VDD2', grid=r12, mn=r12.mn.bbox(rvdd2), netname='VDD:')
      
# 7. Export to physical database.
      print("Export design")
      print("")
   #   laygo2.interface.bag.export(lib, filename=export_path_skill +libname+'_'+cellname+'.il', cellname=None, scale=1e-3, reset_library=False, tech_library=tech.name)
      # Filename example: ./laygo2_generators_private/logic/skill/logic_generated_inv_hs_2x.il
      
# 8. Export to a template database file.
      # test JSON export
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
