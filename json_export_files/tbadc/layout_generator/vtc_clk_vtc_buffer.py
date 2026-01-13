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

export_path_db      = './laygo2_generators_private/prj_db/tbadc/' # Path for JSON DB export

# Parameter definitions #############
# Design Variables
#cell_type = ['clk_vtc_buffer_4s_cc_place'] 
cell_type = ['vtc_clk_vtc_buffer'] 
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
r12m_name = 'routing_12_cmos'
r23m_name = 'routing_23_cmos'
r34m_name = 'routing_34_cmos'
r45m_name = 'routing_45_cmos'


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
tntap, tptap = templates[tntap_name], templates[tptap_name]
tlib = laygo2.import_template(filename=export_path+'tbadc_generated_templates.yaml')
#logic_lib = laygo2.import_template(filename='./laygo2_generators_private/logic/logic_generated_templates.yaml')
# Uncomment the following line if you use the logic templates in the generator code.
# tlib = laygo2.import_template(filename=export_path+'logic_generated_templates.yaml') 
# Uncomment if you want to print template information.
# print(templates[tpmos_name], templates[tnmos_name], sep="\n") 

print("Load grids")
grids = tech.load_grids(templates=templates)
pg, r12m, r23m, r34m, r45m = grids[pg_name], grids[r12m_name], grids[r23m_name], grids[r34m_name], grids[r45m_name]
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
    r45 = laygo2.grid.vstack([r45m, r45m.vflip()])
    
    # 2. Create a design hierarchy
    lib = laygo2.Library(name=libname)
    dsn = laygo2.Design(name=cellname, libname=libname)
    lib.append(dsn)
    
    # 3. Create instances
    print("Create instances")
    # core devices 
    inv_24x_0  = tlib['vtc_inv_24x_2s'].generate(name='inv_24x_0')
    inv_24x_1  = tlib['vtc_inv_24x_2s'].generate(name='inv_24x_1')
    inv_24x_2  = tlib['vtc_inv_24x_2s'].generate(name='inv_24x_2')
    inv_24x_3  = tlib['vtc_inv_24x_2s'].generate(name='inv_24x_3')
    inv_24x_4  = tlib['vtc_inv_24x_2s'].generate(name='inv_24x_4', transform='MY')
    inv_24x_5  = tlib['vtc_inv_24x_2s'].generate(name='inv_24x_5', transform='MY')
    
    inv_16x_0  = tlib['vtc_inv_16x'].generate(name='inv_16x_0')
    inv_16x_1  = tlib['vtc_inv_16x'].generate(name='inv_16x_1', transform='MX')
    inv_16x_2  = tlib['vtc_inv_16x'].generate(name='inv_16x_2')
    inv_16x_3  = tlib['vtc_inv_16x'].generate(name='inv_16x_3', transform='MX')
    inv_16x_4  = tlib['vtc_inv_16x'].generate(name='inv_16x_4')
    inv_16x_5  = tlib['vtc_inv_16x'].generate(name='inv_16x_5', transform='MX')
    
    inv_8x_0  = tlib['vtc_inv_8x'].generate(name='inv_8x_0')
    inv_8x_1  = tlib['vtc_inv_8x'].generate(name='inv_8x_1')
    inv_8x_2  = tlib['vtc_inv_8x'].generate(name='inv_8x_2', transform='MX')
    inv_8x_3  = tlib['vtc_inv_8x'].generate(name='inv_8x_3', transform='MX')
    inv_8x_4  = tlib['vtc_inv_8x'].generate(name='inv_8x_4')
    inv_8x_5  = tlib['vtc_inv_8x'].generate(name='inv_8x_5')
    inv_8x_6  = tlib['vtc_inv_8x'].generate(name='inv_8x_6', transform='MX')
    inv_8x_7  = tlib['vtc_inv_8x'].generate(name='inv_8x_7', transform='MX')
    inv_8x_8  = tlib['vtc_inv_8x'].generate(name='inv_8x_8')
    inv_8x_9  = tlib['vtc_inv_8x'].generate(name='inv_8x_9')
    inv_8x_10  = tlib['vtc_inv_8x'].generate(name='inv_8x_10', transform='MX')
    inv_8x_11  = tlib['vtc_inv_8x'].generate(name='inv_8x_11', transform='MX')
    
    inv_4x_2s_0  = tlib['vtc_inv_cc_2s_4x'].generate(name='inv_4x_2s_0')
    inv_4x_2s_1  = tlib['vtc_inv_cc_2s_4x'].generate(name='inv_4x_2s_1')
    inv_4x_2s_2  = tlib['vtc_inv_cc_2s_4x'].generate(name='inv_4x_2s_2')

    space1_0 = tlib['space_17x'].generate(name='space1_0')
    space1_1 = tlib['space_4x'].generate(name='space1_1')
    space1_2 = tlib['space_4x'].generate(name='space1_2')
    space1_3 = tlib['space_4x'].generate(name='space1_3')
    space1_4 = tlib['space_4x'].generate(name='space1_4')
    space1_5 = tlib['space_4x'].generate(name='space1_5')
    space2_0 = tlib['space_17x'].generate(name='space2_0', transform='MX')
    space2_1 = tlib['space_4x'].generate(name='space2_1', transform='MX')
    space2_2 = tlib['space_4x'].generate(name='space2_2', transform='MX')
    space2_3 = tlib['space_4x'].generate(name='space2_3', transform='MX')
    space2_4 = tlib['space_4x'].generate(name='space2_4', transform='MX')
    space2_5 = tlib['space_4x'].generate(name='space2_5', transform='MX')
    
    space3_0 = tlib['space_103x'].generate(name='space3_0')
    space4_0 = tlib['space_18x'].generate(name='space4_0', transform='MX')
    space4_1 = tlib['space_85x'].generate(name='space4_1', transform='MX')
    
    space5_0 = tlib['space_36x'].generate(name='space5_0')
    space5_1 = tlib['space_67x'].generate(name='space5_1')
    space6_0 = tlib['space_54x'].generate(name='space6_0', transform='MX')
    space6_1 = tlib['space_49x'].generate(name='space6_1', transform='MX')
    
    space7_0 = tlib['space_72x'].generate(name='space7_0')
    space7_1 = tlib['space_31x'].generate(name='space7_1')
    space8_0 = tlib['space_90x'].generate(name='space8_0', transform='MX')
    space8_1 = tlib['space_13x'].generate(name='space8_1', transform='MX')
    
    space9_0 = tlib['space_121x'].generate(name='space9_0')
    space10_0 = tlib['space_121x'].generate(name='space10_0', transform='MX')
    space11_0 = tlib['space_121x'].generate(name='space11_0')
    space12_0 = tlib['space_121x'].generate(name='space12_0', transform='MX')
    space13_0 = tlib['space_121x'].generate(name='space13_0')
    space14_0 = tlib['space_121x'].generate(name='space14_0', transform='MX')

    # 4. Place instances
    # 1-2floor
    dsn.place(grid=pg,inst=space1_0,mn=[0,0])
    dsn.place(grid=pg,inst=space2_0,mn=pg.mn.top_left(space1_0)+pg.mn.height_vec(space2_0))
    dsn.place(grid=pg, inst=inv_24x_0, mn=pg.mn.bottom_right(space1_0))
    dsn.place(grid=pg, inst=space1_1, mn=pg.mn.bottom_right(inv_24x_0))
    dsn.place(grid=pg, inst=space2_1, mn=pg.mn.top_left(space1_1)+pg.mn.height_vec(space2_1))
    dsn.place(grid=pg, inst=inv_24x_1, mn=pg.mn.bottom_right(space1_1))
    dsn.place(grid=pg, inst=space1_2, mn=pg.mn.bottom_right(inv_24x_1))
    dsn.place(grid=pg, inst=space2_2, mn=pg.mn.top_left(space1_2)+pg.mn.height_vec(space2_2))
    dsn.place(grid=pg, inst=inv_24x_2, mn=pg.mn.bottom_right(space1_2))
    dsn.place(grid=pg, inst=space1_3, mn=pg.mn.bottom_right(inv_24x_2))
    dsn.place(grid=pg, inst=space2_3, mn=pg.mn.top_left(space1_3)+pg.mn.height_vec(space2_3))
    dsn.place(grid=pg, inst=inv_24x_3, mn=pg.mn.bottom_right(space1_3))
    dsn.place(grid=pg, inst=space1_4, mn=pg.mn.bottom_right(inv_24x_3))
    dsn.place(grid=pg, inst=space2_4, mn=pg.mn.top_left(space1_4)+pg.mn.height_vec(space2_4))
    dsn.place(grid=pg, inst=inv_24x_4, mn=pg.mn.bottom_right(space1_4)+pg.mn.width_vec(inv_24x_4))
    dsn.place(grid=pg, inst=space1_5, mn=pg.mn.bottom_right(inv_24x_4))
    dsn.place(grid=pg, inst=space2_5, mn=pg.mn.top_left(space1_5)+pg.mn.height_vec(space2_5))
    dsn.place(grid=pg, inst=inv_24x_5, mn=pg.mn.bottom_right(space1_5)+pg.mn.width_vec(inv_24x_5))

    # 3floor
    dsn.place(grid=pg, inst=inv_16x_0, mn=pg.mn.top_left(space1_0)+pg.mn.height_vec(space2_4))
    dsn.place(grid=pg, inst=space3_0, mn=pg.mn.bottom_right(inv_16x_0))
    
    # 4floor
    dsn.place(grid=pg, inst=inv_16x_1, mn=pg.mn.top_right(inv_16x_0)+pg.mn.height_vec(inv_16x_1))
    dsn.place(grid=pg, inst=space4_0, mn=pg.mn.top_left(inv_16x_0)+pg.mn.height_vec(space4_0))
    dsn.place(grid=pg, inst=space4_1, mn=pg.mn.top_right(inv_16x_0)+pg.mn.height_vec(inv_16x_2)+1*pg.mn.width_vec(inv_16x_2))
    
    # 5floor
    dsn.place(grid=pg, inst=inv_16x_2, mn=pg.mn.top_right(inv_16x_0)+pg.mn.height_vec(inv_16x_2)+1*pg.mn.width_vec(inv_16x_2))
    dsn.place(grid=pg, inst=space5_0, mn=pg.mn.top_left(space4_0))
    dsn.place(grid=pg, inst=space5_1, mn=pg.mn.bottom_right(inv_16x_2))
    
    # 6floor
    dsn.place(grid=pg, inst=inv_16x_3, mn=pg.mn.top_right(inv_16x_0)+3*pg.mn.height_vec(inv_16x_3)+2*pg.mn.width_vec(inv_16x_3))
    dsn.place(grid=pg, inst=space6_0, mn=pg.mn.top_left(space5_0)+pg.mn.height_vec(space6_0))
    dsn.place(grid=pg, inst=space6_1, mn=pg.mn.top_right(inv_16x_3))
 
    # 7floor
    dsn.place(grid=pg, inst=inv_16x_4, mn=pg.mn.top_right(inv_16x_0)+3*pg.mn.height_vec(inv_16x_4)+3*pg.mn.width_vec(inv_16x_4))
    dsn.place(grid=pg, inst=space7_0, mn=pg.mn.top_left(space6_0))
    dsn.place(grid=pg, inst=space7_1, mn=pg.mn.bottom_right(inv_16x_4))
    
    # 8floor
    dsn.place(grid=pg, inst=inv_16x_5, mn=pg.mn.top_right(inv_16x_0)+5*pg.mn.height_vec(inv_16x_5)+4*pg.mn.width_vec(inv_16x_5))
    dsn.place(grid=pg, inst=space8_0, mn=pg.mn.top_left(space7_0)+pg.mn.height_vec(space8_0))
    dsn.place(grid=pg, inst=space8_1, mn=pg.mn.top_right(inv_16x_5))
    
    # 9floor
    dsn.place(grid=pg, inst=space9_0, mn=pg.mn.top_left(space8_0))
    dsn.place(grid=pg, inst=inv_8x_0, mn=pg.mn.bottom_left(space9_0)-pg.mn.width_vec(inv_8x_0))
    dsn.place(grid=pg, inst=inv_4x_2s_0, mn=pg.mn.bottom_left(inv_8x_0)-pg.mn.width_vec(inv_4x_2s_0))
    dsn.place(grid=pg, inst=inv_8x_1, mn=pg.mn.bottom_left(inv_4x_2s_0)-pg.mn.width_vec(inv_8x_1))
    
    # 10floor
    dsn.place(grid=pg, inst=space10_0, mn=pg.mn.top_left(space9_0)+pg.mn.height_vec(space10_0))
    dsn.place(grid=pg, inst=inv_8x_2, mn=pg.mn.top_left(space10_0)-pg.mn.width_vec(inv_8x_2))
    dsn.place(grid=pg, inst=inv_8x_3, mn=pg.mn.top_left(inv_8x_1)+pg.mn.height_vec(inv_8x_3))
    
    # 11floor
    dsn.place(grid=pg, inst=space11_0, mn=pg.mn.top_left(space10_0))
    dsn.place(grid=pg, inst=inv_8x_4, mn=pg.mn.bottom_left(space11_0)-pg.mn.width_vec(inv_8x_4))
    dsn.place(grid=pg, inst=inv_4x_2s_1, mn=pg.mn.bottom_left(inv_8x_4)-pg.mn.width_vec(inv_4x_2s_1))
    dsn.place(grid=pg, inst=inv_8x_5, mn=pg.mn.bottom_left(inv_4x_2s_1)-pg.mn.width_vec(inv_8x_5))
    
    # 12floor
    dsn.place(grid=pg, inst=space12_0, mn=pg.mn.top_left(space11_0)+pg.mn.height_vec(space12_0))
    dsn.place(grid=pg, inst=inv_8x_6, mn=pg.mn.top_left(space12_0)-pg.mn.width_vec(inv_8x_6))
    dsn.place(grid=pg, inst=inv_8x_7, mn=pg.mn.top_left(inv_8x_5)+pg.mn.height_vec(inv_8x_7))
     
    # 13floor
    dsn.place(grid=pg, inst=space13_0, mn=pg.mn.top_left(space12_0))
    dsn.place(grid=pg, inst=inv_8x_8, mn=pg.mn.bottom_left(space13_0)-pg.mn.width_vec(inv_8x_8))
    dsn.place(grid=pg, inst=inv_4x_2s_2, mn=pg.mn.bottom_left(inv_8x_8)-pg.mn.width_vec(inv_4x_2s_2))
    dsn.place(grid=pg, inst=inv_8x_9, mn=pg.mn.bottom_left(inv_4x_2s_2)-pg.mn.width_vec(inv_8x_9))
    
    # 14floor
    dsn.place(grid=pg, inst=space14_0, mn=pg.mn.top_left(space13_0)+pg.mn.height_vec(space14_0))
    dsn.place(grid=pg, inst=inv_8x_10, mn=pg.mn.top_left(space14_0)-pg.mn.width_vec(inv_8x_10))
    dsn.place(grid=pg, inst=inv_8x_11, mn=pg.mn.top_left(inv_8x_9)+pg.mn.height_vec(inv_8x_11))
    

    # 5. Create and place wires.
    print("Create wires")
    #IN
    _mn = [r34.mn(inv_8x_1.pins['I'])[0]-[2,0], r34.mn(inv_8x_1.pins['I'])[0]]
    rps2_n, _ = dsn.route(grid=r34, mn=_mn, via_tag=[False, True])
    _mn = [r34.mn(inv_8x_3.pins['I'])[0]-[2,0], r34.mn(inv_8x_3.pins['I'])[0]]
    rps2_p, _ = dsn.route(grid=r34, mn=_mn, via_tag=[False, True])
    _mn = [r34.mn(inv_8x_5.pins['I'])[0]-[2,0], r34.mn(inv_8x_5.pins['I'])[0]]
    rps0_p, _ = dsn.route(grid=r34, mn=_mn, via_tag=[False, True])
    _mn = [r34.mn(inv_8x_7.pins['I'])[0]-[2,0], r34.mn(inv_8x_7.pins['I'])[0]]
    rps0_n, _ = dsn.route(grid=r34, mn=_mn, via_tag=[False, True])
    _mn = [r34.mn(inv_8x_9.pins['I'])[0]-[2,0], r34.mn(inv_8x_9.pins['I'])[0]]
    rps1_p, _ = dsn.route(grid=r34, mn=_mn, via_tag=[False, True])
    _mn = [r34.mn(inv_8x_11.pins['I'])[0]-[2,0], r34.mn(inv_8x_11.pins['I'])[0]]
    rps1_n, _ = dsn.route(grid=r34, mn=_mn, via_tag=[False, True])
    
    #Cross coupled inv, 8-8 connection
    _mn = [[r34.mn(inv_8x_1.pins['O'])[0,0],r34.mn(inv_8x_0.pins['I'])[0,1]], r34.mn(inv_8x_0.pins['I'])[0]]
    _, rps2_n0, _ = dsn.route(grid=r34, mn=_mn, via_tag=[True, True])
    _mn = [[r34.mn(inv_8x_3.pins['O'])[0,0],r34.mn(inv_8x_2.pins['I'])[0,1]], r34.mn(inv_8x_2.pins['I'])[0]]
    _, rps2_p0, _ = dsn.route(grid=r34, mn=_mn, via_tag=[True, True])
    _mn = [[r34.mn(inv_8x_5.pins['O'])[0,0],r34.mn(inv_8x_4.pins['I'])[0,1]], r34.mn(inv_8x_4.pins['I'])[0]]
    _, rps0_p0, _ = dsn.route(grid=r34, mn=_mn, via_tag=[True, True])
    _mn = [[r34.mn(inv_8x_7.pins['O'])[0,0],r34.mn(inv_8x_6.pins['I'])[0,1]], r34.mn(inv_8x_6.pins['I'])[0]]
    _, rps0_n0, _ = dsn.route(grid=r34, mn=_mn, via_tag=[True, True])
    _mn = [[r34.mn(inv_8x_9.pins['O'])[0,0],r34.mn(inv_8x_8.pins['I'])[0,1]], r34.mn(inv_8x_8.pins['I'])[0]]
    _, rps1_p0, _ = dsn.route(grid=r34, mn=_mn, via_tag=[True, True])
    _mn = [[r34.mn(inv_8x_11.pins['O'])[0,0],r34.mn(inv_8x_10.pins['I'])[0,1]], r34.mn(inv_8x_10.pins['I'])[0]]
    _, rps1_n0, _ = dsn.route(grid=r34, mn=_mn, via_tag=[True, True])
    
    mn_list = []
    mn_list.append(r34.mn(inv_4x_2s_0.pins['IN0_0'])[0])
    mn_list.append(r34.mn(inv_4x_2s_0.pins['IN0_1'])[0])
    mn_list.append(r34.mn(inv_4x_2s_0.pins['IN1_0'])[0])
    mn_list.append(r34.mn(inv_4x_2s_0.pins['IN1_1'])[0])
    mn_list.append(r34.mn(inv_4x_2s_1.pins['IN0_0'])[0])
    mn_list.append(r34.mn(inv_4x_2s_1.pins['IN0_1'])[0])
    mn_list.append(r34.mn(inv_4x_2s_1.pins['IN1_0'])[0])
    mn_list.append(r34.mn(inv_4x_2s_1.pins['IN1_1'])[0])
    mn_list.append(r34.mn(inv_4x_2s_2.pins['IN0_0'])[0])
    mn_list.append(r34.mn(inv_4x_2s_2.pins['IN0_1'])[0])
    mn_list.append(r34.mn(inv_4x_2s_2.pins['IN1_0'])[0])
    mn_list.append(r34.mn(inv_4x_2s_2.pins['IN1_1'])[0])
    dsn.via(grid=r34, mn=mn_list)
    
    # 8 - 16 connection
    _mn = [r34.mn(inv_8x_0.pins['O'])[0],[r34.mn(inv_16x_0.pins['I'])[1,0],r34.mn(inv_8x_0.pins['O'])[0,1]]]
    _, routing0_0 = dsn.route(grid=r34, mn=_mn, via_tag=[True, False])
    
    _mn = [r34.mn(inv_16x_0.pins['I'])[0]-[2,0],r34.mn(inv_16x_0.pins['I'])[0] + [2,0]]
    routing0_0 = dsn.route(grid=r34, mn=_mn, via_tag=[False, False])  
    dsn.via(grid=r34, mn=r34.mn(inv_16x_0.pins['I'])[0])
    
    _mn = [[r45.mn(inv_16x_0.pins['I'])[0,0],r45.mn(inv_8x_0.pins['O'])[0,1]],r45.mn(inv_16x_0.pins['I'])[0]]
    _, routing0_0, _ = dsn.route(grid=r45, mn=_mn, via_tag=[True, True])
    
    _mn = [r34.mn(inv_8x_2.pins['O'])[0],[r34.mn(inv_16x_1.pins['I'])[1,0],r34.mn(inv_8x_2.pins['O'])[0,1]]]
    _, routing1_0 = dsn.route(grid=r34, mn=_mn, via_tag=[True, False])
    
    _mn = [r34.mn(inv_16x_1.pins['I'])[0]-[2,0],r34.mn(inv_16x_1.pins['I'])[0] + [2,0]]
    routing1_0 = dsn.route(grid=r34, mn=_mn, via_tag=[False, False])  
    dsn.via(grid=r34, mn=r34.mn(inv_16x_1.pins['I'])[0])
    
    _mn = [[r45.mn(inv_16x_1.pins['I'])[0,0],r45.mn(inv_8x_2.pins['O'])[0,1]],r45.mn(inv_16x_1.pins['I'])[0]]
    _, routing1_0, _ = dsn.route(grid=r45, mn=_mn, via_tag=[True, True])
    
    _mn = [r34.mn(inv_8x_4.pins['O'])[0],[r34.mn(inv_16x_2.pins['I'])[1,0],r34.mn(inv_8x_4.pins['O'])[0,1]]]
    _, routing2_0 = dsn.route(grid=r34, mn=_mn, via_tag=[True, False])
    
    _mn = [r34.mn(inv_16x_2.pins['I'])[0]-[2,0],r34.mn(inv_16x_2.pins['I'])[0] + [2,0]]
    routing2_0 = dsn.route(grid=r34, mn=_mn, via_tag=[False, False])  
    dsn.via(grid=r34, mn=r34.mn(inv_16x_2.pins['I'])[0])
    
    _mn = [[r45.mn(inv_16x_2.pins['I'])[0,0],r45.mn(inv_8x_4.pins['O'])[0,1]],r45.mn(inv_16x_2.pins['I'])[0]]
    _, routing2_0, _ = dsn.route(grid=r45, mn=_mn, via_tag=[True, True])
    
    _mn = [r34.mn(inv_8x_6.pins['O'])[0],[r34.mn(inv_16x_3.pins['I'])[1,0],r34.mn(inv_8x_6.pins['O'])[0,1]]]
    _, routing3_0 = dsn.route(grid=r34, mn=_mn, via_tag=[True, False])
    
    _mn = [r34.mn(inv_16x_3.pins['I'])[0]-[2,0],r34.mn(inv_16x_3.pins['I'])[0] + [2,0]]
    routing3_0 = dsn.route(grid=r34, mn=_mn, via_tag=[False, False])  
    dsn.via(grid=r34, mn=r34.mn(inv_16x_3.pins['I'])[0])
    
    _mn = [[r45.mn(inv_16x_3.pins['I'])[0,0],r45.mn(inv_8x_6.pins['O'])[0,1]],r45.mn(inv_16x_3.pins['I'])[0]]
    _, routing3_0, _ = dsn.route(grid=r45, mn=_mn, via_tag=[True, True])
    
    _mn = [r34.mn(inv_8x_8.pins['O'])[0],[r34.mn(inv_16x_4.pins['I'])[1,0],r34.mn(inv_8x_8.pins['O'])[0,1]]]
    _, routing4_0 = dsn.route(grid=r34, mn=_mn, via_tag=[True, False])
    
    _mn = [r34.mn(inv_16x_4.pins['I'])[0]-[2,0],r34.mn(inv_16x_4.pins['I'])[0] + [2,0]]
    routing4_0 = dsn.route(grid=r34, mn=_mn, via_tag=[False, False])  
    dsn.via(grid=r34, mn=r34.mn(inv_16x_4.pins['I'])[0])
    
    _mn = [[r45.mn(inv_16x_4.pins['I'])[0,0],r45.mn(inv_8x_8.pins['O'])[0,1]],r45.mn(inv_16x_4.pins['I'])[0]]
    _, routing4_0, _ = dsn.route(grid=r45, mn=_mn, via_tag=[True, True])
    
    _mn = [r34.mn(inv_8x_10.pins['O'])[0],[r34.mn(inv_16x_5.pins['I'])[1,0],r34.mn(inv_8x_10.pins['O'])[0,1]]]
    _, routing5_0 = dsn.route(grid=r34, mn=_mn, via_tag=[True, False])
    
    _mn = [r34.mn(inv_16x_5.pins['I'])[0]-[2,0],r34.mn(inv_16x_5.pins['I'])[0] + [2,0]]
    routing5_0 = dsn.route(grid=r34, mn=_mn, via_tag=[False, False])  
    dsn.via(grid=r34, mn=r34.mn(inv_16x_5.pins['I'])[0])
    
    _mn = [[r45.mn(inv_16x_5.pins['I'])[0,0],r45.mn(inv_8x_10.pins['O'])[0,1]],r45.mn(inv_16x_5.pins['I'])[0]]
    _, routing5_0, _ = dsn.route(grid=r45, mn=_mn, via_tag=[True, True])
    
    # 16 - 24 connection
    _mn = [r34.mn(inv_16x_0.pins['O'])[1]-[2,0],r34.mn(inv_16x_0.pins['O'])[1]+[2,0]]
    routing0_1 = dsn.route(grid=r34, mn=_mn, via_tag=[False, False])  
    dsn.via(grid=r34, mn=r34.mn(inv_16x_0.pins['O'])[1])
    
    _mn = [r34.mn(inv_24x_0.pins['I'])[0]-[2,0],r34.mn(inv_24x_0.pins['I'])[0]+[2,0]]
    routing0_1 = dsn.route(grid=r34, mn=_mn, via_tag=[False, False])  
    dsn.via(grid=r34, mn=r34.mn(inv_24x_0.pins['I'])[0])
    
    _track = [r45.mn(inv_24x_0.pins['I'])[0,0], None]
    mn_list = []
    mn_list.append(r45.mn(inv_24x_0.pins['I'])[0]-[1,0])
    mn_list.append(r45.mn(inv_16x_0.pins['O'])[1]-[1,0])
    routing0_2 = dsn.route_via_track(grid=r45, mn=mn_list, track=_track)    
    
    _mn = [r34.mn(inv_16x_1.pins['O'])[1]-[2,0],r34.mn(inv_16x_1.pins['O'])[1]+[2,0]]
    routing1_1 = dsn.route(grid=r34, mn=_mn, via_tag=[False, False])  
    dsn.via(grid=r34, mn=r34.mn(inv_16x_1.pins['O'])[1])
    
    _mn = [r34.mn(inv_24x_1.pins['I'])[0]-[2,0],r34.mn(inv_24x_1.pins['I'])[0]+[2,0]]
    routing1_1 = dsn.route(grid=r34, mn=_mn, via_tag=[False, False])  
    dsn.via(grid=r34, mn=r34.mn(inv_24x_1.pins['I'])[0])
    
    _track = [r45.mn(inv_24x_1.pins['I'])[0,0], None]
    mn_list = []
    mn_list.append(r45.mn(inv_24x_1.pins['I'])[0]-[1,0])
    mn_list.append(r45.mn(inv_16x_1.pins['O'])[1]-[1,0])
    routing1_2 = dsn.route_via_track(grid=r45, mn=mn_list, track=_track)
    
    _mn = [r34.mn(inv_16x_2.pins['O'])[1]-[2,0],r34.mn(inv_16x_2.pins['O'])[1]+[2,0]]
    routing2_1 = dsn.route(grid=r34, mn=_mn, via_tag=[False, False])  
    dsn.via(grid=r34, mn=r34.mn(inv_16x_2.pins['O'])[1])
    
    _mn = [r34.mn(inv_24x_2.pins['I'])[0]-[2,0],r34.mn(inv_24x_2.pins['I'])[0]+[2,0]]
    routing2_1 = dsn.route(grid=r34, mn=_mn, via_tag=[False, False])  
    dsn.via(grid=r34, mn=r34.mn(inv_24x_2.pins['I'])[0])
    
    _track = [r45.mn(inv_24x_2.pins['I'])[0,0], None]
    mn_list = []
    mn_list.append(r45.mn(inv_24x_2.pins['I'])[0]-[1,0])
    mn_list.append(r45.mn(inv_16x_2.pins['O'])[1]-[1,0])
    routing2_2 = dsn.route_via_track(grid=r45, mn=mn_list, track=_track)     
    
    _mn = [r34.mn(inv_16x_3.pins['O'])[1]-[2,0],r34.mn(inv_16x_3.pins['O'])[1]+[2,0]]
    routing3_1 = dsn.route(grid=r34, mn=_mn, via_tag=[False, False])  
    dsn.via(grid=r34, mn=r34.mn(inv_16x_3.pins['O'])[1])
    
    _mn = [r34.mn(inv_24x_3.pins['I'])[0]-[2,0],r34.mn(inv_24x_3.pins['I'])[0]+[2,0]]
    routing3_1 = dsn.route(grid=r34, mn=_mn, via_tag=[False, False])  
    dsn.via(grid=r34, mn=r34.mn(inv_24x_3.pins['I'])[0])
    
    _track = [r45.mn(inv_24x_3.pins['I'])[0,0], None]
    mn_list = []
    mn_list.append(r45.mn(inv_24x_3.pins['I'])[0]-[1,0])
    mn_list.append(r45.mn(inv_16x_3.pins['O'])[1]-[1,0])
    routing3_2 = dsn.route_via_track(grid=r45, mn=mn_list, track=_track)
    
    _mn = [r34.mn(inv_16x_4.pins['O'])[1]-[2,0],r34.mn(inv_16x_4.pins['O'])[1]+[2,0]]
    routing4_1 = dsn.route(grid=r34, mn=_mn, via_tag=[False, False])  
    dsn.via(grid=r34, mn=r34.mn(inv_16x_4.pins['O'])[1])
    
    _mn = [r34.mn(inv_24x_4.pins['I'])[0]-[2,0],r34.mn(inv_24x_4.pins['I'])[0]+[2,0]]
    routing4_1 = dsn.route(grid=r34, mn=_mn, via_tag=[False, False])  
    dsn.via(grid=r34, mn=r34.mn(inv_24x_4.pins['I'])[0])
    
    _track = [r45.mn(inv_24x_4.pins['I'])[0,0], None]
    mn_list = []
    mn_list.append(r45.mn(inv_24x_4.pins['I'])[0]-[1,0])
    mn_list.append(r45.mn(inv_16x_4.pins['O'])[1]-[1,0])
    routing4_2 = dsn.route_via_track(grid=r45, mn=mn_list, track=_track)           

    _mn = [r34.mn(inv_16x_5.pins['O'])[1]-[2,0],r34.mn(inv_16x_5.pins['O'])[1]+[2,0]]
    routing5_1 = dsn.route(grid=r34, mn=_mn, via_tag=[False, False])  
    dsn.via(grid=r34, mn=r34.mn(inv_16x_5.pins['O'])[1])
    
    _mn = [r34.mn(inv_24x_5.pins['I'])[0]-[2,0],r34.mn(inv_24x_5.pins['I'])[0]+[2,0]]
    routing5_1 = dsn.route(grid=r34, mn=_mn, via_tag=[False, False])  
    dsn.via(grid=r34, mn=r34.mn(inv_24x_5.pins['I'])[0])
    
    _track = [r45.mn(inv_24x_5.pins['I'])[0,0], None]
    mn_list = []
    mn_list.append(r45.mn(inv_24x_5.pins['I'])[0]-[1,0])
    mn_list.append(r45.mn(inv_16x_5.pins['O'])[1]-[1,0])
    routing5_2 = dsn.route_via_track(grid=r45, mn=mn_list, track=_track)           

    #OUT - PU_CLKB
    _mn = [r34.mn(inv_24x_0.pins['O'])[1],r34.mn(inv_24x_0.pins['O'])[0]-[0,15]]
    rout0 = dsn.route(grid=r34, mn=_mn, via_tag=[False, False])
     
    #OUT - PU_CLK
    _mn = [r34.mn(inv_24x_1.pins['O'])[1],r34.mn(inv_24x_1.pins['O'])[0]-[0,15]]
    rout1= dsn.route(grid=r34, mn=_mn, via_tag=[False, False])
    
    #OUT - PD_CLK
    _mn = [r34.mn(inv_24x_2.pins['O'])[1],r34.mn(inv_24x_2.pins['O'])[0]-[0,15]]
    rout2 = dsn.route(grid=r34, mn=_mn, via_tag=[False, False])
    
    #OUT - PD_CLKB
    _mn = [r34.mn(inv_24x_3.pins['O'])[1],r34.mn(inv_24x_3.pins['O'])[0]-[0,15]]
    rout3 = dsn.route(grid=r34, mn=_mn, via_tag=[False, False])
    
    #OUT - TH1_CLK
    _mn = [r34.mn(inv_24x_4.pins['O'])[1]-[2,0],r34.mn(inv_24x_4.pins['O'])[1]+[2,0]]
    rout4 = dsn.route(grid=r34, mn=_mn, via_tag=[False, False])  
    dsn.via(grid=r34, mn=r34.mn(inv_24x_4.pins['O'])[1])
    
    _mn = [r34.mn(inv_24x_4.pins['O'])[0]-[2,0],r34.mn(inv_24x_4.pins['O'])[0]+[2,0]]
    rout4 = dsn.route(grid=r34, mn=_mn, via_tag=[False, False])  
    dsn.via(grid=r34, mn=r34.mn(inv_24x_4.pins['O'])[0])
    
    _track = [r45.mn(inv_24x_4.pins['O'])[0,0], None]
    mn_list = []
    mn_list.append(r45.mn(inv_24x_4.pins['O'])[0]-[1,0])
    mn_list.append(r45.mn(inv_24x_4.pins['O'])[1]-[1,0])
    rout4_0 = dsn.route_via_track(grid=r45, mn=mn_list, track=_track)
    
    _mn = [r45.mn(inv_24x_4.pins['O'])[0],r45.mn(inv_24x_4.pins['O'])[0]-[0,10]]
    rout4 = dsn.route(grid=r45, mn=_mn, via_tag=[False, False])  
     
    #OUT - TH1_CLKB
    _mn = [r34.mn(inv_24x_5.pins['O'])[1]-[2,0],r34.mn(inv_24x_5.pins['O'])[1]+[2,0]]
    rout5 = dsn.route(grid=r34, mn=_mn, via_tag=[False, False])  
    dsn.via(grid=r34, mn=r34.mn(inv_24x_5.pins['O'])[1])
    
    _mn = [r34.mn(inv_24x_5.pins['O'])[0]-[2,0],r34.mn(inv_24x_5.pins['O'])[0]+[2,0]]
    rout5 = dsn.route(grid=r34, mn=_mn, via_tag=[False, False])  
    dsn.via(grid=r34, mn=r34.mn(inv_24x_5.pins['O'])[0])
    
    _track = [r45.mn(inv_24x_5.pins['O'])[0,0], None]
    mn_list = []
    mn_list.append(r45.mn(inv_24x_5.pins['O'])[0]+[1,0])
    mn_list.append(r45.mn(inv_24x_5.pins['O'])[1]+[1,0])
    rout5_0 = dsn.route_via_track(grid=r45, mn=mn_list, track=_track)
    
    _mn = [r45.mn(inv_24x_5.pins['O'])[0],r45.mn(inv_24x_5.pins['O'])[0]-[0,10]]
    rout5 = dsn.route(grid=r45, mn=_mn, via_tag=[False, False])  

    # Rails
    tech.generate_pwr_rail(dsn, grids, netname=['VSS', 'VDD'], vertical=False)
    
   
    # 6. Create pins.
    #IN
    pps2_n = dsn.pin(name='PS2_N', grid=r34, mn=r34.mn.bbox(rps2_n))
    pps2_p = dsn.pin(name='PS2_P', grid=r34, mn=r34.mn.bbox(rps2_p))
    pps0_p = dsn.pin(name='PS0_P', grid=r34, mn=r34.mn.bbox(rps0_p))
    pps0_n = dsn.pin(name='PS0_N', grid=r34, mn=r34.mn.bbox(rps0_n))
    pps1_p = dsn.pin(name='PS1_P', grid=r34, mn=r34.mn.bbox(rps1_p))
    pps1_n = dsn.pin(name='PS1_N', grid=r34, mn=r34.mn.bbox(rps1_n))
    
    #TH1_CLK_PRE2
    th1_clkb_pre2 = dsn.pin(name='TH1_CLKB_PRE2', grid=r45, mn=r45.mn.bbox(routing5_0))
    th1_clk_pre2 = dsn.pin(name='TH1_CLK_PRE2', grid=r45, mn=r45.mn.bbox(routing4_0))
    
    #clk_pre
    pu_clkb_pre = dsn.pin(name='PU_CLKB_PRE', grid=r45, mn=r45.mn.bbox(routing0_1))
    pu_clk_pre = dsn.pin(name='PU_CLK_PRE', grid=r45, mn=r45.mn.bbox(routing1_1))
    pd_clk_pre = dsn.pin(name='PD_CLK_PRE', grid=r45, mn=r45.mn.bbox(routing2_1))
    pd_clkb_pre = dsn.pin(name='PD_CLKB_PRE', grid=r45, mn=r45.mn.bbox(routing3_1))
    th1_clk_pre = dsn.pin(name='TH1_CLK_PRE', grid=r45, mn=r45.mn.bbox(routing4_1))
    th1_clkb_pre = dsn.pin(name='TH1_CLKB_PRE', grid=r45, mn=r45.mn.bbox(routing5_1))
    
    #OUT
    pu_clkb = dsn.pin(name='PU_CLKB', grid=r34, mn=r34.mn.bbox(rout0))
    pu_clk = dsn.pin(name='PU_CLK', grid=r34, mn=r34.mn.bbox(rout1))
    pd_clk = dsn.pin(name='PD_CLK', grid=r34, mn=r34.mn.bbox(rout2))
    pd_clkb = dsn.pin(name='PD_CLKB', grid=r34, mn=r34.mn.bbox(rout3))
    th1_clk = dsn.pin(name='TH1_CLK', grid=r45, mn=r45.mn.bbox(rout4))
    th1_clkb = dsn.pin(name='TH1_CLKB', grid=r45, mn=r45.mn.bbox(rout5))
    
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
    grid_table['M4'] = r34
    grid_table['M5'] = r45
    exporter = laygo2.object.database.DesignExporter(dsn, grid_table, lib_ref = "laygo2_generators_private/prj_db/tbadc/library.yaml")
    nat_dict = exporter.export_to_dict()
    laygo2.interface.json.export_dict(nat_dict, filename=export_path_db+libname+'_db.json', mode='append')