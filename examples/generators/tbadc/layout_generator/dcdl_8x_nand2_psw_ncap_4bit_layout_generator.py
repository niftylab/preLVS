##########################################################
#                                                      
# dcdl_8x_nand2_psw_ncap_4bit Layout Generator          
# Contributors: D. Lee, S. Lee, Y. Byun 
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
cell_type = ['dcdl_8x_nand2_psw_ncap_4bit', 'dcdl_8x_nand2_psw_ncap_4bit_ltap']

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
export_path_db      = './laygo2_generators_private/prj_db/tbadc/' # Path for JSON DB export
# End of parameter definitions ######

# Generation start ##################
# 1. Load templates and grids.
print("Load templates")
templates = tech.load_templates()
tpmos, tnmos = templates[tpmos_name], templates[tnmos_name]
tlib = laygo2.import_template(filename=export_path+'tbadc_generated_templates.yaml')
tlib_logic = laygo2.interface.yaml.import_template(filename='./laygo2_generators_private/logic/logic_generated_templates.yaml')

print("Load grids")
grids = tech.load_grids(templates=templates)
pg, r12, r23, r34 = grids[pg_name], grids[r12_name], grids[r23_name], grids[r34_name]


for celltype in cell_type:
    cellname = celltype
    print('--------------------')
    print(f'Creating {cellname}')


    # 2. Create a design hierarchy
    lib = laygo2.Library(name=libname)
    dsn = laygo2.Design(name=cellname, libname=libname)
    lib.append(dsn)
 
    # 3. Create istances.
    print("Create instances")
    tap0   = tlib_logic['tap'].generate(name="ITAP0")
    tap1   = tlib_logic['tap'].generate(name="ITAP1")

    inv0   = tlib_logic['inv_8x'].generate(name="I1", netmap={"I": "IN", "O": "A_1"})
    inv1   = tlib_logic['inv_8x'].generate(name="I3", netmap={"I": "A_1", "O": "A_2"})
    inv2   = tlib_logic['inv_8x'].generate(name="I9", netmap={"I": "A_2", "O": "A_3"})
    inv3   = tlib_logic['inv_10x'].generate(name="I11", netmap={"I": "A_3", "O": "OUT"})

    ncap0  = tlib['ncap_nsw_2x_bot'].generate(name="I4", netmap={"IN": "A_2", "EN": "EN_0"}) 
    ncap1  = tlib['ncap_nsw_2x_bot'].generate(name="I5", netmap={"IN": "A_2", "EN": "EN_1"}) 
    ncap2  = tlib['ncap_nsw_2x_bot'].generate(name="I6", netmap={"IN": "A_2", "EN": "EN_2"})
    ncap3  = tlib['ncap_nsw_2x_bot'].generate(name="I7", netmap={"IN": "A_2", "EN": "EN_3"})
    ncap4  = tlib['ncap_nsw_2x_bot'].generate(name="I8", netmap={"IN": "A_2", "EN": "EN_3"})

    dmy0   = tlib['filler_dmy_2x'].generate(name="I0")
    dmy1   = tlib['filler_dmy_2x'].generate(name="I2")
    dmy2   = tlib['filler_dmy_2x'].generate(name="I10")
    dmy3   = tlib['filler_dmy_2x'].generate(name="I12")

    # 4. Place instances.
    if celltype == 'dcdl_8x_nand2_psw_ncap_4bit':
        dsn.place(grid=pg, inst=[dmy0, inv0, dmy1, inv1, ncap0, ncap1, ncap2, ncap3, ncap4, inv2, dmy2, inv3, dmy3], mn=[0, 0])
    if celltype == 'dcdl_8x_nand2_psw_ncap_4bit_ltap':
        dsn.place(grid=pg, inst=[tap0, dmy0, inv0, dmy1, inv1, ncap0, ncap1, ncap2, ncap3, ncap4, inv2, dmy2, inv3, dmy3, tap1], mn=[0, 0])

    # 5. Create and place wires.
    print("Create wires")

    #A<1:3>
    _trk = r34.mn(inv0.p["O"])[0, 1] +3
    _trk_EN = r34.mn(ncap3.p["EN"])[0, 1]
    rc = laygo2.RoutingMeshTemplate(grid=r34)
    rc.add_trunk(name="A_1", index=[None, _trk], netname="A_1")
    rc.add_trunk(name="A_2", index=[None, _trk], netname="A_2")
    rc.add_trunk(name="A_3", index=[None, _trk], netname="A_3")
    rc.add_trunk(name="EN_3", index=[None, _trk_EN], netname="EN_3")
    rc.add_node(list(dsn.instances.values()))
    rinst = rc.generate()
    dsn.place(grid=pg, inst=rinst)
          
    # 6. Create pins.
    pIN = dsn.pin(name='IN', grid=r34, mn=r34(inv0.p['I']))
    pA1 = dsn.pin(name='A<1>', grid=r34, mn=rinst.pins['A_1'])
    pA2 = dsn.pin(name='A<2>', grid=r34, mn=rinst.pins['A_2'])
    pA3 = dsn.pin(name='A<3>', grid=r34, mn=rinst.pins['A_3'])
    pEN0 = dsn.pin(name='EN<0>', grid=r34, mn=r34(ncap0.p['EN']))
    pEN1 = dsn.pin(name='EN<1>', grid=r34, mn=r34(ncap1.p['EN']))
    pEN2 = dsn.pin(name='EN<2>', grid=r34, mn=r34(ncap2.p['EN']))
    pEN3 = dsn.pin(name='EN<3>', grid=r34, mn=rinst.pins['EN_3'])
    pOUT = dsn.pin(name='OUT', grid=r34, mn=r34(inv3.p['O']))
    tech.generate_pwr_rail(dsn, grids, netname=['VSS', 'VDD'], vertical=False)
        
    # 7. Export to physical database.
    print("Export design\n")
    # laygo2.export(lib, tech=tech, filename=export_path_skill+libname+'_'+cellname+'.il')
    # Filename example: ./laygo2_generators_private/logic/skill/logic_generated_dff_2x.il
 
    # 8. Export to a template database file.
    nat_temp = dsn.export_to_template()
    laygo2.export_template(nat_temp, filename=export_path+libname+'_templates.yaml', mode='append')
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
