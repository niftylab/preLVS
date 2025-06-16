#########################################################
#                                                                   
# Contributors: H. Jeong     
# Last Updated: 2024-10-24              
#                                                        
#########################################################

import numpy as np
import laygo2
import laygo2_tech as tech
import laygo2.object.database
import laygo2.interface.json

# Parameter definitions #############
# Design Variables
cell_type = ['inv_cc_2s'] 
    # _ltap stands for tap on the left side
    # _hs stands for high-speed. (Output is connected with multiple wires to reduce R).
    # _hp stands for high-power. (hs + additional tap rows are placed to enhance power network).
    # _io stands for io. (hs + hp + additional tap rows btn p/n are placed for guardring).
nf_list = [4]

# Templates
tpmos_name = 'pmos'
tnmos_name = 'nmos'
tntap_name = 'ntap'
tptap_name = 'ptap'

# Grids
pg_name = 'placement_basic'
r12m_name = 'routing_12_mos'
r23m_name = 'routing_23_mos'

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
tntap, tptap = templates[tntap_name], templates[tptap_name]
logic_lib = laygo2.import_template(filename='./laygo2_generators_private/logic/logic_generated_templates.yaml')
# Uncomment the following line if you use the logic templates in the generator code.
# tlib = laygo2.import_template(filename=export_path+'logic_generated_templates.yaml') 
# Uncomment if you want to print template information.
# print(templates[tpmos_name], templates[tnmos_name], sep="\n") 

print("Load grids")
grids = tech.load_grids(templates=templates)
pg, r12m, r23m = grids[pg_name], grids[r12m_name], grids[r23m_name]
# Uncomment if you want to print grid information.
# print(grids[pg_name], grids[r12m_name], grids[r23m_name], sep="\n") 

for celltype in cell_type:
    for nf in nf_list:
        cellname = f'{celltype}_{nf}x'
        print('--------------------')
        print(f'Creating {cellname}')
        
        # Routing grid generation
        r12 = laygo2.grid.vstack([r12m, r12m.vflip()])
        r23 = laygo2.grid.vstack([r23m, r23m.vflip()])
        
        # 2. Create a design hierarchy
        lib = laygo2.Library(name=libname)
        dsn = laygo2.Design(name=cellname, libname=libname)
        lib.append(dsn)
        
        # 3. Create instances
        print("Create instances")
        # core devices 
        inv0 = logic_lib[f'inv_{nf}x'].generate(name='inv0', transform='MY')
        inv1 = logic_lib[f'inv_{nf}x'].generate(name='inv1', transform='MX')
        
        # 4. Place instances
        dsn.place(grid=pg, inst=inv0, mn=[0,0])
        dsn.place(grid=pg, inst=inv1, mn=pg.mn.top_left(inv0)+pg.mn.height_vec(inv1))
                   
        # 5. Create and place wires.
        print("Create wires")
        # In - Out connection
        _track = [r23.mn(inv0.pins['O'])[0,0], None]
        mn_list = []
        mn_list.append(r23.mn(inv1.pins['I'])[0])
        mn_list.append(r23.mn(inv1.pins['I'])[1])
        mn_list.append(r23.mn(inv0.pins['O'])[0])
        rcon0 = dsn.route_via_track(grid=r23, mn=mn_list, track=_track)
        
        _track = [r23.mn(inv0.pins['I'])[0,0], None]
        mn_list = []
        mn_list.append(r23.mn(inv1.pins['O'])[0])
        mn_list.append(r23.mn(inv1.pins['O'])[1])
        mn_list.append(r23.mn(inv0.pins['I'])[0])
        rcon1 = dsn.route_via_track(grid=r23, mn=mn_list, track=_track)
        
        _track = [r23.mn(inv1.pins['O'])[0,0], None]
        mn_list = []
        mn_list.append(r23.mn(inv0.pins['I'])[0])
        mn_list.append(r23.mn(inv0.pins['I'])[1])
        mn_list.append(r23.mn(inv1.pins['O'])[1])
        rcon0 = dsn.route_via_track(grid=r23, mn=mn_list, track=_track)
        
        _track = [r23.mn(inv1.pins['I'])[0,0], None]
        mn_list = []
        mn_list.append(r23.mn(inv0.pins['O'])[0])
        mn_list.append(r23.mn(inv0.pins['O'])[1])
        mn_list.append(r23.mn(inv1.pins['I'])[1])
        rcon1 = dsn.route_via_track(grid=r23, mn=mn_list, track=_track)
        
        #Input_pin
        _mn = [r23.mn(inv0.pins['I'])[0], r23.mn(inv0.pins['I'])[1]]
        rin0_0 = dsn.route(grid=r23, mn=_mn, via_tag=[False, False])
        _mn = [r23.mn(inv0.pins['I'])[0]-[1,0], r23.mn(inv0.pins['I'])[1]-[1,0]]
        rin0_1 = dsn.route(grid=r23, mn=_mn, via_tag=[False, False])
        
        _mn = [r23.mn(inv1.pins['I'])[0], r23.mn(inv1.pins['I'])[1]]
        rin1_0 = dsn.route(grid=r23, mn=_mn, via_tag=[False, False])
        _mn = [r23.mn(inv1.pins['I'])[0]+[1,0], r23.mn(inv1.pins['I'])[1]+[1,0]]
        rin1_1 = dsn.route(grid=r23, mn=_mn, via_tag=[False, False])
                       
        # Rails
        tech.generate_pwr_rail(dsn, grids, netname=['VSS', 'VDD'], vertical=False)
        
        # 6. Create pins.
        pin0_0 = dsn.pin(name='IN0_0', netname='IN0:', grid=r23, mn=r23.mn.bbox(rin0_0))
        pin0_1 = dsn.pin(name='IN0_1', netname='IN0:', grid=r23, mn=r23.mn.bbox(rin0_1))
        pin1_0 = dsn.pin(name='IN1_0', netname='IN1:', grid=r23, mn=r23.mn.bbox(rin1_0))
        pin1_1 = dsn.pin(name='IN1_1', netname='IN1:', grid=r23, mn=r23.mn.bbox(rin1_1))
        
        # 7. Export to physical database.
        print("Export design\n")
        # laygo2.export(lib, tech=tech, filename=export_path_skill+libname+'_'+cellname+'.il')
        # Filename example: ./laygo2_generators_private/logic/skill/logic_generated_inv_hs_2x.il
        
        # 8. Export to a template database file.
        nat_temp = dsn.export_to_template()
        laygo2.export_template(nat_temp, filename=f"{export_path}{libname}_templates.yaml", mode='append')
        # Filename example: ./laygo2_generators_private/logic/logic_generated_templates.yaml

        # test jSON DB export
        grid_table = dict()
        grid_table['M1'] = r12
        grid_table['M2'] = r23
        grid_table['M3'] = r23
        exporter = laygo2.object.database.DesignExporter(dsn, grid_table, lib_ref = "laygo2_generators_private/prj_db/tbadc/library.yaml")
        nat_dict = exporter.export_to_dict()
        laygo2.interface.json.export_dict(nat_dict, filename=export_path_db+libname+'_db.json', mode='append')
