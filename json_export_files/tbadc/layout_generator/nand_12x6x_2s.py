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
cell_type = ['nand2_12x6x_2s'] 
    # _ltap stands for tap on the left side
    # _hs stands for high-speed. (Output is connected with multiple wires to reduce R).
    # _hp stands for high-power. (hs + additional tap rows are placed to enhance power network).
    # _io stands for io. (hs + hp + additional tap rows btn p/n are placed for guardring).

# Templates
tpmos_name = 'pmos'
tnmos_name = 'nmos'
tntap_name = 'ntap'
tptap_name = 'ptap'

# Grids
pg_name = 'placement_basic'
r12m_name = 'routing_12_mos'
r23m_name = 'routing_23_mos'
r34m_name = 'routing_34_cmos'


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
tlib = laygo2.import_template(filename=export_path+'tbadc_generated_templates.yaml')
# Uncomment the following line if you use the logic templates in the generator code.
# tlib = laygo2.import_template(filename=export_path+'logic_generated_templates.yaml') 
# Uncomment if you want to print template information.
# print(templates[tpmos_name], templates[tnmos_name], sep="\n") 

print("Load grids")
grids = tech.load_grids(templates=templates)
pg, r12m, r23m, r34m = grids[pg_name], grids[r12m_name], grids[r23m_name], grids[r34m_name]
# Uncomment if you want to print grid information.
# print(grids[pg_name], grids[r12m_name], grids[r23m_name], sep="\n") 

for celltype in cell_type:
    cellname = f'{celltype}'
    print('--------------------')
    print(f'Creating {cellname}')
    
    # Routing grid generation
    r12 = laygo2.grid.vstack([r12m, r12m.vflip()])
    r23 = laygo2.grid.vstack([r23m, r23m.vflip()])
    r34 = laygo2.grid.vstack([r34m, r34m.vflip()])
    
    # 2. Create a design hierarchy
    lib = laygo2.Library(name=libname)
    dsn = laygo2.Design(name=cellname, libname=libname)
    lib.append(dsn)
    
    # 3. Create instances
    print("Create instances")
    # core devices 
    nand_half0  = tlib['nand2_12x6x_half'].generate(name='nand_half0')
    nand_half1  = tlib['nand2_12x6x_half'].generate(name='nand_half1', transform='MX')
    
    # 4. Place instances
    dsn.place(grid=pg, inst=nand_half0, mn=[0,0])
    dsn.place(grid=pg, inst=nand_half1, mn=pg.mn.top_left(nand_half0)+pg.mn.height_vec(nand_half1))
            
    # 5. Create and place wires.
    print("Create wires")
    
    #IN_A
    _track = [r23.mn(nand_half0.pins['G_in1'])[0,0], None]
    mn_list = []
    mn_list.append(r23.mn(nand_half0.pins['G_in1'])[1])
    mn_list.append(r23.mn(nand_half1.pins['G_in1'])[1])
    mn_list.append(r23.mn(nand_half1.pins['G_ip0'])[1])
    rina0 = dsn.route_via_track(grid=r23, mn=mn_list, track=_track)
    
    _mn = [r34.mn(nand_half1.pins['G_in0'])[0]- [1,1]]
    _mn.append([r34.mn(nand_half0.pins['G_in1'])[0,0], r34.mn(nand_half1.pins['G_in0'])[0,1]-1]) 
    rina1, _ = dsn.route(grid=r34, mn=_mn, via_tag=[False, True])
    
    
    #IN_B
    _track = [r23.mn(nand_half0.pins['G_in0'])[1,0], None]
    mn_list = []
    mn_list.append(r23.mn(nand_half0.pins['G_in0'])[0])
    mn_list.append(r23.mn(nand_half1.pins['G_in0'])[0])
    mn_list.append(r23.mn(nand_half0.pins['G_ip0'])[0])
    rinb0 = dsn.route_via_track(grid=r23, mn=mn_list, track=_track)
    
    _mn = [r34.mn(nand_half0.pins['G_in0'])[0]- [1,-1]]
    _mn.append([r34.mn(nand_half0.pins['G_in0'])[1,0], r34.mn(nand_half0.pins['G_in0'])[0,1]+1]) 
    rinb1, _ = dsn.route(grid=r34, mn=_mn, via_tag=[False, True])
             
    # OUT
    mn_list = []
    mn_list.append(r23.mn(nand_half0.pins['O'])[0])
    mn_list.append(r23.mn(nand_half1.pins['O'])[1])
    rout0 = dsn.route(grid=r23, mn=mn_list, via_tag=[False, False])
    
    # Rails
    tech.generate_pwr_rail(dsn, grids, netname=['VSS', 'VDD'], vertical=False)
   
   
    # 6. Create pins.
    pout0 = dsn.pin(name='O', grid=r23, mn=rout0)
    pina0 = dsn.pin(name='A', grid=r34, mn=rina1)
    pinb0 = dsn.pin(name='B', grid=r34, mn=rinb1)
    
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
    grid_table['M3'] = r34
    grid_table['M4'] = r34
    exporter = laygo2.object.database.DesignExporter(dsn, grid_table, lib_ref = "laygo2_generators_private/prj_db/tbadc/library.yaml")
    nat_dict = exporter.export_to_dict()
    laygo2.interface.json.export_dict(nat_dict, filename=export_path_db+libname+'_db.json', mode='append')
