##############################################
#                                            #
#       PROJECT: SCAN CHAIN AUTOMATION       #
#       SCAN CELL LAYOUT GENERATOR           #
#       CREATED BY TAEHO SHIN                #
#                                            #
##############################################

import numpy as np
import pprint
import laygo2
import laygo2.interface
import laygo2_tech as tech
from laygo2.object.netmap import NetMap

### PARAMETER DEFINITION
# Templates
tpmos_name = 'pmos'
tnmos_name = 'nmos'
tntap_name = 'ntap'
tptap_name = 'ptap'
# Grids
pg_name  = 'placement_basic'
r12_name = 'routing_12_cmos'
r23_name = 'routing_23_cmos'
r34_name = 'routing_34_basic'

# Design hierarchy
libname  = 'test_generated'
cellname = 'scan_cell'
ref_dir_template     = './laygo2_generators_private/scan/'       # Reference path for generated cell template yaml
ref_dir_BAG_exported = './laygo2_generators_private/scan/skill/' # Reference path for SKILL script
export_path         = './laygo2_generators_private/feature_test/export_raw_dict/' # Layout generation path: "export_path/libname/cellname"
export_path_skill   = export_path+'skill/' # SKILL file generation path: "export_path_skill/libname_cellname.il"
export_path_db      = './laygo2_generators_private/prj_db/'
# End of parameter definitions ######

### GENERATION START
# 1. Load templates and grids.
print("Load templates")
templates = tech.load_templates()
tpmos, tnmos = templates[tpmos_name], templates[tnmos_name]
tptap, tntap = templates[tptap_name], templates[tntap_name]
tlib = laygo2.interface.yaml.import_template(filename=export_path+libname+'_templates.yaml') # Uncomment if you use the logic templates
# Filename Example: ./laygo2_generators_private/scan/scan_generated_templates.yaml

print("Load grids")
grids = tech.load_grids(templates=templates)
pg, r12, r23, r34 = grids[pg_name], grids[r12_name], grids[r23_name], grids['routing_34_basic']

# 2. Create a design hierarchy
lib = laygo2.object.database.Library(name=libname)
dsn = laygo2.object.database.Design(name=cellname, libname=libname)
lib.append(dsn)

# 3. Create istances.
print("Create instances")
# BOTTOM INSTANCES
inv_load      = tlib['inv_2x'    ].generate(name='I0', transform='MX')
mux_in        = tlib['mux2to1_2x'].generate(name='I1', transform='MX')
dff_out       = tlib['dff_2x'    ].generate(name='I2', transform='MX')

inv_out0      = tlib['inv_2x'    ].generate(name='I4', transform='MX')
inv_out1      = tlib['inv_2x'    ].generate(name='I5', transform='MX')
inv_out2      = tlib['inv_2x'    ].generate(name='I6', transform='MX')
inv_out3      = tlib['inv_2x'    ].generate(name='I7', transform='MX')

inv_data_out0 = tlib['inv_2x'    ].generate(name='I22', transform='R180')
inv_data_out1 = tlib['inv_4x'    ].generate(name='I23', transform='MX')
inv_data_out2 = tlib['inv_24x'   ].generate(name='I24', transform='MX')

# TOP INSTANCES
inv_clk0      = tlib['inv_2x'    ].generate(name='I15', transform='MY')
inv_clk1      = tlib['inv_2x'    ].generate(name='I16', transform='MY')
inv_clk2      = tlib['inv_2x'    ].generate(name='I17', transform='MY')
inv_clk3      = tlib['inv_2x'    ].generate(name='I18', transform='MY')

inv_en        = tlib['inv_2x'    ].generate(name='I19')
dff_data_out  = tlib['dff_2x'    ].generate(name='I20')

inv_scan_gate = tlib['inv_2x'    ].generate(name='I3')
mux_data_out  = tlib['mux2to1_2x'].generate(name='I21')
inv_data_out3 = tlib['inv_24x'   ].generate(name='I14', transform='MY')

# TAP for DRC
# CAN BE DELETED
tap_bot_left  = tlib['tap'       ].generate(name='TAP0', transform='MX')
tap_bot_right = tlib['tap'       ].generate(name='TAP1', transform='MX')
tap_top_left  = tlib['tap'       ].generate(name='TAP2')
tap_top_right = tlib['tap'       ].generate(name='TAP3')

# 4. Place instances.
pg_list = [0]*2
pg_list[1] = [tap_top_left, inv_clk0, inv_clk1, inv_clk2, inv_clk3, inv_en,   dff_data_out, inv_scan_gate, mux_data_out,  inv_data_out3, None,          tap_top_right]
pg_list[0] = [tap_bot_left, inv_load, mux_in,   dff_out,  inv_out0, inv_out1, inv_out2,     inv_out3,      inv_data_out0, inv_data_out1, inv_data_out2, tap_bot_right]

for i in range(len(pg_list)):
   for j in range(len(pg_list[i])):
      print(pg_list[i][j])

############################ FILLING FUNCTION ####################################
nf_space = np.zeros((len(pg_list), len(pg_list)), dtype=int)
for i in range(len(pg_list)):
   for j in range(len(pg_list[i])):
      if pg_list[i][j] == None:
         pass
      else:
         nf_space[i] = nf_space[i] + pg.mn.bbox(pg_list[i][j])[:,0]
nf_space = sum(abs(nf_space[0]))-sum(abs(nf_space[1]))
######################### FILLING FUNCTION END ###################################

space0 = tlib['space_1x'].generate(name='SPACE', shape=[nf_space, 1]) 
for i in range(len(pg_list[1])):
   if pg_list[1][i] == None:
      pg_list[1][i] = space0

dsn.place(grid=pg, inst=pg_list[0], mn=[0,0])
dsn.place(grid=pg, inst=pg_list[1], mn=pg.mn.top_left(pg_list[0][0]))

# 5. Create and place wires.
print("Create wires")
############################# BOTTOM INSTANCES ##########################
track_ref_bot = [None, np.mean(r34.mn(inv_load.pins['I'])[:,1], dtype=np.int)]

# SCAN_LOAD signal to MUX
_mn = [r34.mn(inv_load.pins['I'])[0], r34.mn(mux_in.pins['EN1'])[0]]
dsn.route_via_track(grid=r34, mn=_mn, track=[None, track_ref_bot[1]+2])

_mn = [r34.mn(inv_load.pins['O'])[0], r34.mn(mux_in.pins['EN0'])[0]]
dsn.route_via_track(grid=r34, mn=_mn, track=[None, track_ref_bot[1]+3])

# MUX to DFF
_mn = [r34.mn(mux_in.pins['O'])[0], r34.mn(dff_out.pins['I'])[0]]
dsn.route_via_track(grid=r34, mn=_mn, track=[None, track_ref_bot[1]+2])

# SCAN_CLK to DFF
_mn = [r34.mn(inv_clk3.pins['I'])[0], r34.mn(dff_out.pins['CLK'])[1]]
_track = [None, track_ref_bot[1]+5]
dsn.route_via_track(grid=r34, mn=_mn, track=_track)

# DFF to INV chain for SCAN_OUT signal
_mn = [r34.mn(dff_out.pins['O'])[0], r34.mn(inv_out0.pins['I'])[0]]
_track = [None, track_ref_bot[1]+2]
dsn.route_via_track(grid=r34, mn=_mn, track=_track)

_mn = [r34.mn(inv_out0.pins['O'])[0], r34.mn(inv_out1.pins['I'])[0]]
_track = [None, track_ref_bot[1]+1]
dsn.route_via_track(grid=r34, mn=_mn, track=_track)

_mn = [r34.mn(inv_out1.pins['O'])[0], r34.mn(inv_out2.pins['I'])[0]]
_track = [None, track_ref_bot[1]+2]
dsn.route_via_track(grid=r34, mn=_mn, track=_track)

_mn = [r34.mn(inv_out2.pins['O'])[0], r34.mn(inv_out3.pins['I'])[0]]
_track = [None, track_ref_bot[1]+1]
dsn.route_via_track(grid=r34, mn=_mn, track=_track)
############################ BOTTOM INSTANCES END #######################

############################ TOP INSTANCES START ########################
track_ref_top = [None, np.mean(r34.mn(inv_clk0.pins['I'])[:,1], dtype=np.int)]

# INV chain for SCAN_CLK signal
_mn = [inv_clk3.pins['O'], inv_clk2.pins['I']]
#_mn = [r34.mn(inv_clk3.pins['O'])[0], r34.mn(inv_clk2.pins['I'])[0]]
_track = [None, track_ref_top[1]-2]
dsn.route_via_track(grid=r34, mn=_mn, track=_track)

_mn = [r34.mn(inv_clk2.pins['O'])[0], r34.mn(inv_clk1.pins['I'])[0]]
_track = [None, track_ref_top[1]-1]
dsn.route_via_track(grid=r34, mn=_mn, track=_track)

#_mn = [r34.mn(inv_clk1.pins['O'])[0], r34.mn(inv_clk0.pins['I'])[0]]
_mn = [inv_clk1.pins['O'], inv_clk0.pins['I']]
_track = [None, track_ref_top[1]-2]
dsn.route_via_track(grid=r34, mn=_mn, track=_track)

# SCAN_EN signal to DFF
_mn = [inv_en.pins['O'], dff_data_out.pins['CLK']]
#_mn = [r34.mn(inv_en.pins['O'])[0], r34.mn(dff_data_out.pins['CLK'])[0]]
_track = [None, track_ref_top[1]-2]
dsn.route_via_track(grid=r34, mn=_mn, track=_track)

# DFF for SCAN_DATA_OUT signal
_mn = [r34.mn(dff_data_out.pins['I'])[0]+[0,1], r34.mn(dff_out.pins['O'])[0]]
#_mn = [r34.mn(dff_data_out.pins['I'])[0], r34.mn(dff_out.pins['O'])[0]]
_track = [r34.mn(dff_out.pins['O'])[0,0]-2, None]
dsn.route_via_track(grid=r34, mn=_mn, track=_track)
dsn.via(grid=r34, mn=r34.mn(dff_out.pins['O'])[0])
dsn.via(grid=r34, mn=r34.mn(dff_data_out.pins['I'])[0]+[0,1])
#dsn.via(grid=r34, mn=r34.mn(dff_data_out.pins['I'])[0])

# SCAN_GATE signal
_mn = [r34.mn(inv_scan_gate.pins['I'])[1], r34.mn(mux_data_out.pins['EN0'])[1]]
if _mn[0][1] == track_ref_top[1]+2:  #collision with SCAN_GATE. Need to be fixed later.
    _mn[0][1] -= 1
    _mn[1][1] -= 1
_, r_scan_gate_m4, _ = dsn.route(grid=r34, mn=_mn, via_tag=[True, True])

_mn = [r34.mn(inv_scan_gate.pins['O'])[0], r34.mn(mux_data_out.pins['EN1'])[0]]
_track = [None, track_ref_top[1]+2]
dsn.route_via_track(grid=r34, mn=_mn, track=_track)

# INV chain for SCAN_DATA_OUT signal
_mn = [dff_data_out.pins['O'], mux_data_out.pins['I1']]
#_mn = [r34.mn(dff_data_out.pins['O'])[0], r34.mn(mux_data_out.pins['I1'])[0]]
_track = [None, track_ref_top[1]-2]
dsn.route_via_track(grid=r34, mn=_mn, track=_track)

_mn = [r34.mn(mux_data_out.pins['O'])[0]-[0,2], r34.mn(mux_data_out.pins['O'])[0]]
dsn.route(grid=r34, mn=_mn)

_mn = [_mn[0], r34.mn(inv_data_out0.pins['I'])[1]+[0,1]]
_track = [r34.mn(mux_data_out.pins['O'])[0,0]-2, None]
dsn.route_via_track(grid=r34, mn=_mn, track=_track)
dsn.via(grid=r34, mn=_mn[0])
dsn.via(grid=r34, mn=_mn[1])
_mn = [r34.mn(inv_data_out0.pins['I'])[1], r34.mn(inv_data_out0.pins['I'])[1]+[0,1]]
dsn.route(grid=r34, mn=_mn)

_mn = [r34.mn(inv_data_out0.pins['O'])[0], r34.mn(inv_data_out1.pins['I'])[0]]
_track = [None, track_ref_bot[1]+1]
dsn.route_via_track(grid=r34, mn=_mn, track=_track)

_mn = [r34.mn(inv_data_out1.pins['O'])[0], r34.mn(inv_data_out2.pins['I'])[0]]
_track = [None, track_ref_bot[1]+2]
dsn.route_via_track(grid=r34, mn=_mn, track=_track)

_mn = [r34.mn(inv_data_out2.pins['O'])[0], r34.mn(inv_data_out3.pins['I'])[0]]
_track = [None, track_ref_top[1]-3]
dsn.route_via_track(grid=r34, mn=_mn, track=_track)
############################### TOP INSTANCES END ################################

# VSS
rvss0 = dsn.route(grid=r12, mn=[r12.mn.top_left(pg_list[0][0]), r12.mn.top_right(pg_list[0][-1])])

# VDD
rvdd0 = dsn.route(grid=r12, mn=[r12.mn.bottom_left(pg_list[0][0]), r12.mn.bottom_right(pg_list[0][-1])])
rvdd1 = dsn.route(grid=r12, mn=[r12.mn.top_left(pg_list[-1][0]), r12.mn.top_right(pg_list[-1][-1])])


# 6. Create pins.
pSCAN_IN         = dsn.pin(name='SCAN_IN',         grid=r23, mn=r23.mn.bbox(mux_in.pins['I0']))
pSCAN_DATA_IN    = dsn.pin(name='SCAN_DATA_IN',    grid=r23, mn=r23.mn.bbox(mux_in.pins['I1']))
pSCAN_OUT        = dsn.pin(name='SCAN_OUT',        grid=r23, mn=r23.mn.bbox(inv_out3.pins['O']))
pSCAN_DATA_OUT   = dsn.pin(name='SCAN_DATA_OUT',   grid=r23, mn=r23.mn.bbox(inv_data_out3.pins['O']))

pSCAN_GATE       = dsn.pin(name='SCAN_GATE',       grid=r23, mn=r23.mn.bbox(mux_data_out.pins['EN0']))
pSCAN_GATE_M4    = dsn.pin(name='SCAN_GATE_M4',    grid=r34, mn=r34.mn.bbox(r_scan_gate_m4), netname = 'SCAN_GATE')
pSCAN_GATE_VALUE = dsn.pin(name='SCAN_GATE_VALUE', grid=r23, mn=r23.mn.bbox(mux_data_out.pins['I0']))

pSCAN_CLK        = dsn.pin(name='SCAN_CLK',        grid=r23, mn=r23.mn.bbox(inv_clk3.pins['I']))
pSCAN_CLK_OUT    = dsn.pin(name='SCAN_CLK_OUT',    grid=r23, mn=r23.mn.bbox(inv_clk0.pins['O']))

pSCAN_EN         = dsn.pin(name='SCAN_EN',         grid=r23, mn=r23.mn.bbox(inv_en.pins['I']))
pSCAN_LOAD       = dsn.pin(name='SCAN_LOAD',       grid=r23, mn=r23.mn.bbox(inv_load.pins['I']))

pvss0            = dsn.pin(name='VSS',             grid=r12, mn=r12.mn.bbox(rvss0))
pvdd0            = dsn.pin(name='VDD0',            grid=r12, mn=r12.mn.bbox(rvdd0), netname='VDD:')
pvdd1            = dsn.pin(name='VDD1',            grid=r12, mn=r12.mn.bbox(rvdd1), netname='VDD:')

# 7. Export to physical database.
print("Export design")
### EXPORT TO BAG
# # SKILL script for load in Virtuoso
# laygo2.interface.bag.export(lib, filename=ref_dir_BAG_exported+libname+'_'+cellname+'.il', cellname=None, scale=1e-3, reset_library=False, tech_library=tech.name)
# # Filename example: ./laygo2_generators_private/scan/skill/scan_generated_scan_cell.il

# # YAML script for generating new template library
# nat_temp = dsn.export_to_template() # nat_temp = native template ??
# laygo2.interface.yaml.export_template(nat_temp, filename=ref_dir_template+libname+'_templates.yaml', mode='append')
# # Filename example: ./laygo2_generators_private/scan/scan_generated_templates.yaml 

grid_table = dict()
grid_table['M1'] = r12
grid_table['M2'] = r23
grid_table['M3'] = r23
grid_table['M4'] = r34
exporter = laygo2.object.database.DesignExporter(dsn, grid_table, lib_ref = "laygo2_generators_private/prj_db/library.yaml")
nat_dict = exporter.export_to_dict()
laygo2.interface.json.export_dict(nat_dict, filename='./laygo2_generators_private/prj_db/test_generated_db.json', mode='append')
# Pre-LVS test
via_table = dict()
via_table["via_M1_M2_0"] = ('M1','M2')
via_table["via_M1_M2_1"] = ('M1','M2')
via_table["via_M2_M3_0"] = ('M2','M3')
via_table["via_M2_M3_1"] = ('M2','M3')
via_table["via_M3_M4_0"] = ('M3','M4')
mosList = ["nmos4_fast_center_nf2", "nmos4_fast_center_2stack","pmos4_fast_center_nf2", "pmos4_fast_center_2stack"]
nMap = NetMap.import_from_design(dsn, grid_table, via_table, orient_first="vertical", layer_names=['M1','M2','M3','M4'],
                                    net_ignore = [], lib_ref = "laygo2_generators_private/prj_db/library.yaml", core_templates=mosList)
#    metal_num = nMap.count_metals()
#    print("# of metal vectors =",metal_num)
nat_temp = dsn.export_to_template(metal_table=grid_table, net_ignore = [], export_mask=False)
laygo2.interface.yaml.export_template(nat_temp, filename='./laygo2_generators_private/feature_test/export_raw_dict/test_generated_templates.yaml', mode='append')
# Filename example: ./laygo2_generators_private/logic/logic_generated_templates.yaml