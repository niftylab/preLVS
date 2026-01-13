##########################################################
#                                                      
# D-Flip Flop Layout Generator          
# Contributors: T. Shin, S. Park, Y. Oh, T. Kang 
# Last Updated: 2022-09-16
#                                                      
##########################################################

import numpy as np
import laygo2
import laygo2_tech as tech
import laygo2.object.database
import laygo2.interface.json

export_path_db      = './laygo2_generators_private/prj_db/tbadc/' # Path for JSON DB export

# Parameter definitions #############
# Design Variables
cell_type = ['vtc_crossing_detector_inv_feedback']

# Templates
tpmos_name = 'pmos'
tnmos_name = 'nmos'

# Grids
pg_name = 'placement_basic'
r12_name = 'routing_12_cmos'
r23_name = 'routing_23_cmos'
r34_name = 'routing_34_cmos'

# Adjust PN ratio
ratio_42 = 4
ratio_22 = 2

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

print("Load grids")
grids = tech.load_grids(templates=templates)
pg, r12, r23, r34 = grids[pg_name], grids[r12_name], grids[r23_name], grids[r34_name]

for celltype in cell_type:
    #cellname = f'{celltype}_{ratio_42*4}x{ratio_22*2}x'
    cellname=celltype
    print('--------------------')
    print(f'Creating {cellname}')
 
    # 2. Create a design hierarchy
    lib = laygo2.Library(name=libname)
    dsn = laygo2.Design(name=cellname, libname=libname)
    lib.append(dsn)
 
    # 3. Create istances.
    print("Create instances")
    #inv0 = [tlib['crossing_detector_inv_4x_2x' ].generate(name="I1"+str(ratio), netmap={"I": "IN", "O": "VTC_OB"}) for ratio in range(ratio_42)]
    #inv1 = [tlib['crossing_detector_inv_2x_2x' ].generate(name="I2"+str(ratio), netmap={"I": "VTC_OB", "O": "VTC_O"}) for ratio in range(ratio_22)]
    inv0 = [tlib['vtc_crossing_detector_inv_4x' ].generate(name="I1"+str(ratio), netmap={"I": "IN", "O": "VTC_OB"}) for ratio in range(ratio_42)]
    inv1 = [tlib['vtc_crossing_detector_inv_2x' ].generate(name="I2"+str(ratio), netmap={"I": "VTC_OB", "O": "VTC_O"}) for ratio in range(ratio_22)]

    # 4. Place instances.
    dsn.place(grid=pg, inst= inv0 + inv1, mn=[0, 0])
 
    # 5. Create and place wires.

    print("Create wires")

    # IN
        
    _track = [r23(inv0[0].p['I'])[0,0]-1, r23(inv0[0].p['I'])[0,1]+2]
    rin0 = [dsn.route(grid=r23, mn=[inv0[ratio].p['I'], inv0[ratio+1].p['I']], track=_track) for ratio in range(0, ratio_42-1)]

    # VTC_OB

    _track = [r23(inv0[0].p['O'])[0,0], None]
    rvtc_ob1 = [dsn.route(grid=r23, mn=[inv0[ratio].p['O'], inv0[ratio+1].p['O']], track=_track) for ratio in range(0, ratio_42-1)]
        
    _track = [r34(inv0[-1].p['O'])[0,0], None]
    rvtc_ob2 = dsn.route(grid=r34, mn=[inv0[-1].p['O'], inv1[0].p['I']], track=_track)
        
    _track = [r23(inv1[0].p['I'])[0,0], r23(inv1[-1].p['I'])[0,1]-2]
    rvtc_ob3 = [dsn.route(grid=r23, mn=[inv1[ratio].p['I'], inv1[ratio+1].p['I']], track=_track) for ratio in range(0, ratio_22-1)]

    # VTC_O

    _track = [r23(inv1[0].p['O'])[0,0], None]
    rvtc_o = [dsn.route(grid=r23, mn=[inv1[ratio].p['O'], inv1[ratio+1].p['O']], track=_track) for ratio in range(0, ratio_22-1)]

    # 6. Create pins.
    pin0  = dsn.pin(name='IN',   grid=r34, mn=inv0[0].p['I'])
    pvtc_ob0 = dsn.pin(name='VTC_OB', grid=r34, mn=inv0[-1].p['O'])
    pvtc_o0 = dsn.pin(name='VTC_O',   grid=r34, mn=inv1[-1].p['O'])
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
    grid_table['M3'] = r23
    grid_table['M4'] = r34
    exporter = laygo2.object.database.DesignExporter(dsn, grid_table, lib_ref = "laygo2_generators_private/prj_db/tbadc/library.yaml")
    nat_dict = exporter.export_to_dict()
    laygo2.interface.json.export_dict(nat_dict, filename=export_path_db+libname+'_db.json', mode='append')