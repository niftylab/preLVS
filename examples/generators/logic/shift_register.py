
import numpy as np
import laygo2
import laygo2.interface
import laygo2_tech as tech
from laygo2.object.netmap import NetMap

# Parameter definitions #############
# Design Variables
cell_name = 'shift_register'
n_filpflops = [10, 20, 30, 50]

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
# print(templates[tpmos_name], templates[tnmos_name], sep="\n") 

print("Load grids")
grids = tech.load_grids(templates=templates)
pg, r12, r23, r34 = grids[pg_name], grids[r12_name], grids[r23_name], grids[r34_name]
# print(grids[pg_name], grids[r12_name], grids[r23_name], grids[r34_name], sep="\n")


for n_filpflop in n_filpflops:
    cellname = cell_name+'_'+str(n_filpflop)
    print('------------------')
    print('Now Creating '+cellname)

    # 2. Create a design hierarchy
    lib = laygo2.Library(name=libname)
    dsn = laygo2.Design(name=cellname, libname=libname)
    lib.append(dsn)

    # 3. Create instances.
    print("Create instances")
    inst_list = []
    for i in range(n_filpflop):
        i_net = "I" if i == 0 else "Q"+str(i-1)
        o_net = "Q"+str(i) if i < n_filpflop-1 else "O"
        dff = tlib["dff_2x"].generate(name="dff"+str(i), netmap={"I": i_net, "O": o_net, "CLK": "CK", "VSS:":"VSS:","VDD:":"VDD:"})
        inst_list.append(dff)


    # 4. Place instances.
    dsn.place(grid=pg, inst=inst_list, mn=[0,0])


    # 5. Create and place wires.
    print("Create wires")
    _trk = r34(inst_list[0])[0, 1]
    rc = laygo2.RoutingMeshTemplate(grid=r34)
    rc.add_trunk(name="I", index=[None, _trk], netname="I")
    rc.add_trunk(name="O", index=[None, _trk + 2], netname="OUT")
    rc.add_trunk(name="CK", index=[None, _trk + 3], netname="CK")
    for i in range(n_filpflop-1):
        rc.add_trunk(name="Q"+str(i), index=[None, _trk + 1], netname="Q"+str(i))

    rc.add_node(list(dsn.instances.values()))  # Add all instances to the routing mesh as nodes
    rinst = rc.generate()
    dsn.place(grid=pg, inst=rinst)

    # 6. Create pins.
    pin0 = dsn.pin(name='I', grid=r23, mn=r23.mn.bbox(inst_list[0].pins['I']))
    pout0 = dsn.pin(name='O', grid=r23, mn=r23.mn.bbox(inst_list[-1].pins['O']))
    pclk0 = dsn.pin(name='CLK', grid=r23, mn=r23.mn.bbox(inst_list[0].pins['CLK']))
    tech.generate_pwr_rail(dsn, grids, netname=['VSS:', 'VDD:'], vertical=False)  

    # 7. Export to physical database.
    print("Export design")
    print("")
    # laygo2.export(lib, tech=tech, filename=export_path_skill+libname+'_'+cellname+'.il')
        
    # 8. Export to a template database file.
    grid_table = dict()
    grid_table['M1'] = r12
    grid_table['M2'] = r23
    grid_table['M3'] = r34
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