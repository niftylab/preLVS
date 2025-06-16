##########################################################
#                                                        #
#              D-Flip Flop Layout Generator              #
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
cell_type = ['dff']#, 'dff_ltap']
nf_list = [2]#,4]

# Templates
tpmos_name = 'pmos'
tnmos_name = 'nmos'

# Grids
pg_name = 'placement_basic'
r12_name = 'routing_12_cmos'
r23_name = 'routing_23_cmos'
r34_name = 'routing_34_basic'

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
        inv0 = tlib['inv_'+str(nf)+'x'].generate(name="I6", netmap={"I": "CLK", "O": "ICLKB","VSS":"VSS:","VDD":"VDD:"})
        inv1 = tlib['inv_'+str(nf)+'x'].generate(name="I7", netmap={"I": "ICLKB", "O": "ICLK","VSS":"VSS:","VDD":"VDD:"})
        inv2 = tlib['inv_'+str(nf)+'x'].generate(name="I1", netmap={"I": "MEM1", "O": "LATCH","VSS":"VSS:","VDD":"VDD:"})
        inv3 = tlib['inv_'+str(nf)+'x'].generate(name="I4", netmap={"I": "MEM2", "O": "OUT","VSS":"VSS:","VDD":"VDD:"})

        tinv0 = tlib['tinv_'+str(nf)+'x'].generate(name="I0", netmap={"I": "I", "O": "MEM1", "EN": "ICLKB", "ENB": "ICLK","net0_0":"VSS:","net1_0":"VDD:"})
        tinv1 = tlib['tinv_'+str(nf)+'x'].generate(name="I3", netmap={"I": "LATCH", "O": "MEM2", "EN": "ICLK", "ENB": "ICLKB","net0_0":"VSS:","net1_0":"VDD:"})
        tinv_small0 = tlib["tinv_small_1x"].generate(name="I2", netmap={"I": "LATCH", "O": "MEM1", "EN": "ICLK", "ENB": "ICLKB","VSS":"VSS:","VDD":"VDD:"})
        tinv_small1 = tlib["tinv_small_1x"].generate(name="I5", netmap={"I": "OUT", "O": "MEM2", "EN": "ICLKB", "ENB": "ICLK","VSS":"VSS:","VDD":"VDD:"})
        # 4. Place instances.
        if celltype == 'dff_ltap':
            tap0 = tlib['tap'].generate(name="ITAP0")
            dsn.place(grid=pg, inst=[tap0, inv0, inv1, tinv0, tinv_small0, inv2, tinv1, 
                                        tinv_small1, inv3], mn=[0, 0])
        else:
            dsn.place(grid=pg, inst=[inv0, inv1, tinv0, tinv_small0, inv2, tinv1, 
                                        tinv_small1, inv3], mn=[0, 0])
 
        # 5. Create and place wires.
        print("Create wires")

        _trk = r34.mn(inv1.pins["O"])[0, 1] - 2
        rc = laygo2.object.template.RoutingMeshTemplate(grid=r34)
        rc.add_trunk(name="ICLK", index=[None, _trk], netname="ICLK")
        rc.add_trunk(name="ICLKB", index=[None, _trk + 1], netname="ICLKB")
        rc.add_trunk(name="MEM1", index=[None, _trk + 2], netname="MEM1")
        rc.add_trunk(name="MEM2", index=[None, _trk + 2], netname="MEM2")
        rc.add_trunk(name="LATCH", index=[None, _trk + 3], netname="LATCH")
        rc.add_trunk(name="OUT", index=[None, _trk + 3], netname="OUT")
        rc.add_node(list(dsn.instances.values()))  # Add all instances to the routing mesh as nodes
        rinst = rc.generate()
        dsn.place(grid=pg, inst=rinst)
     
        # 6. Create pins.
        pin0 = dsn.pin(name='I', grid=r23, mn=r23.mn.bbox(tinv0.pins['I']))
        pclk0 = dsn.pin(name='CLK', grid=r23, mn=r23.mn.bbox(inv0.pins['I']))
        pout0 = dsn.pin(name='O', grid=r23, mn=r23.mn.bbox(inv3.pins['O']), netname="OUT")
        tech.generate_pwr_rail(dsn, grids, netname=['VSS', 'VDD'], vertical=False)
        
        # 7. Export to physical database.
        print("Export design")
        print("")
    #    laygo2.interface.bag.export(lib, filename=export_path_skill +libname+'_'+cellname+'.il', cellname=None, scale=1e-3, reset_library=False, tech_library=tech.name)
        # Filename example: ./laygo2_generators_private/logic/skill/logic_generated_dff_2x.il

        # 8. Export to a template database file.
        # test jSON DB export
        grid_table = dict()
        grid_table['M1'] = r12
        grid_table['M2'] = r23
        grid_table['M3'] = r23
        grid_table['M4'] = r34
        exporter = laygo2.object.database.DesignExporter(dsn, grid_table, lib_ref = "laygo2_generators_private/prj_db/library.yaml")
        nat_dict = exporter.export_to_dict()
        laygo2.interface.json.export_dict(nat_dict, filename=export_path_db+libname+'_db.json', mode='append')
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
        laygo2.interface.yaml.export_template(nat_temp, filename=export_path+libname+'_templates.yaml', mode='append')
        # Filename example: ./laygo2_generators_private/logic/logic_generated_templates.yaml