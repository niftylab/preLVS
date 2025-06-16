#########################################################
#                                                                   
# Contributors: H. Jeong     
# Last Updated: 2024-10-24              
#                                                        
#########################################################
import laygo2
import laygo2_tech as tech  
import laygo2.object.database
import laygo2.interface.json

export_path_db      = './laygo2_generators_private/prj_db/tbadc/' # Path for JSON DB export

# Parameter definitions #############
# Design Variables

# Design hierarchy
libname = 'tbadc_generated'
cellname = 'vtc_clk_pulse_gen_dcdl'
export_path = './laygo2_generators_private/tbadc/' 
export_path_skill = export_path+'skill/' 
# End of parameter definitions ######

# Generation start ##################
# Load templates and grids.
templates, grids = tech.load_templates_and_grids()
tlib = laygo2.import_template(filename=export_path+'tbadc_generated_templates.yaml')
pg, r23, r34, r45 = grids['placement_basic'], grids['routing_23_cmos'], grids['routing_34_cmos'], grids['routing_45_cmos']
r12 = grids['routing_12_cmos']

print('--------------------')
print(f'Creating {cellname}')
# Create a design hierarchy
dsn = laygo2.Design(name=cellname, libname=libname, pgrid=pg, rgrid=r34)

# Create instances
print("Create instances")
# core devices 
inv_6x_0  = tlib['vtc_inv_rdmy_6x'].generate(name='inv_6x_0')
inv_6x_1  = tlib['vtc_inv_rdmy_6x'].generate(name='inv_6x_1')
inv_6x_2  = tlib['vtc_inv_rdmy_6x'].generate(name='inv_6x_2')
inv_6x_3  = tlib['vtc_inv_rdmy_6x'].generate(name='inv_6x_3')
inv_6x_4  = tlib['vtc_inv_rdmy_6x'].generate(name='inv_6x_4')
inv_6x_5  = tlib['vtc_inv_rdmy_6x'].generate(name='inv_6x_5')
inv_6x_6  = tlib['vtc_inv_rdmy_6x'].generate(name='inv_6x_6')
inv_6x_7  = tlib['vtc_inv_rdmy_6x'].generate(name='inv_6x_7')

inv_4x_0  = tlib['vtc_inv_rdmy_space_4x'].generate(name='inv_4x_0', transform='MX')
inv_4x_1  = tlib['vtc_inv_rdmy_space_4x'].generate(name='inv_4x_1', transform='MX')
inv_4x_2  = tlib['vtc_inv_rdmy_space_4x'].generate(name='inv_4x_2', transform='MX')

inv_8x_0  = tlib['vtc_inv_rdmy_8x'].generate(name='inv_8x_0')
inv_8x_1  = tlib['vtc_inv_rdmy_8x'].generate(name='inv_8x_1', transform='MX')
inv_8x_2  = tlib['vtc_inv_rdmy_8x'].generate(name='inv_8x_2')
inv_8x_3  = tlib['vtc_inv_rdmy_8x'].generate(name='inv_8x_3', transform='MX')
inv_8x_4  = tlib['vtc_inv_rdmy_8x'].generate(name='inv_8x_4')
inv_8x_5  = tlib['vtc_inv_rdmy_8x'].generate(name='inv_8x_5', transform='MX')

nand_12x6x_2s_0  = tlib['vtc_nand2'].generate(name='vtc_nand2_0', transform='MX')
nand_12x6x_2s_1  = tlib['vtc_nand2'].generate(name='vtc_nand2_1', transform='MX')
nand_12x6x_2s_2  = tlib['vtc_nand2'].generate(name='vtc_nand2_2', transform='MX')

space0 = tlib['space_8x'].generate(name='space0', transform='MX')
space1 = tlib['space_8x'].generate(name='space1', transform='MX')
space2 = tlib['space_8x'].generate(name='space2', transform='MX')

# Place instances
dcdl_space = 40
routing_space = -50

# 1floor
dsn.place(inst=inv_6x_0, mn=[0,0])
dsn.place(inst=inv_6x_1, mn=-pg.mn.width_vec(inv_6x_1))
dsn.place(inst=inv_6x_2, mn=-2*pg.mn.width_vec(inv_6x_2))
dsn.place(inst=inv_8x_0, mn=[dcdl_space,0])
dsn.place(inst=nand_12x6x_2s_0, mn=pg.mn.bottom_right(inv_8x_0)+pg.mn.height_vec(nand_12x6x_2s_0))
dsn.place(inst=inv_6x_5, mn=pg.mn.bottom_right(nand_12x6x_2s_0))

# 2floor
dsn.place(inst=inv_4x_0, mn=pg.mn.top_left(inv_6x_0)+pg.mn.height_vec(inv_4x_0))
dsn.place(inst=inv_8x_1, mn=pg.mn.top_left(inv_8x_0)+pg.mn.height_vec(inv_4x_0))
dsn.place(inst=space0, mn=pg.mn.top_right(nand_12x6x_2s_0))

# 3floor
dsn.place(inst=inv_6x_3, mn=pg.mn.top_left(inv_6x_0)+pg.mn.height_vec(inv_4x_0))
dsn.place(inst=inv_8x_2, mn=pg.mn.top_left(inv_8x_0)+pg.mn.height_vec(inv_4x_0))
dsn.place(inst=nand_12x6x_2s_1, mn=pg.mn.bottom_right(inv_8x_0)+2*pg.mn.height_vec(nand_12x6x_2s_0))
dsn.place(inst=inv_6x_6, mn=pg.mn.bottom_right(nand_12x6x_2s_1))

# 4floor
dsn.place(inst=inv_4x_1, mn=pg.mn.top_left(inv_6x_0)+2*pg.mn.height_vec(inv_4x_0)+pg.mn.height_vec(inv_6x_3))
dsn.place(inst=inv_8x_3, mn=pg.mn.top_left(inv_8x_0)+2*pg.mn.height_vec(inv_4x_0)+pg.mn.height_vec(inv_6x_3))
dsn.place(inst=space1, mn=pg.mn.top_right(nand_12x6x_2s_1))

# 5floor
dsn.place(inst=inv_6x_4, mn=pg.mn.top_left(inv_6x_0)+2*pg.mn.height_vec(inv_4x_0)+pg.mn.height_vec(inv_6x_3))
dsn.place(inst=inv_8x_4, mn=pg.mn.top_left(inv_8x_0)+2*pg.mn.height_vec(inv_4x_0)+pg.mn.height_vec(inv_6x_3))
dsn.place(inst=nand_12x6x_2s_2, mn=pg.mn.bottom_right(inv_8x_0)+3*pg.mn.height_vec(nand_12x6x_2s_0))
dsn.place(inst=inv_6x_7, mn=pg.mn.bottom_right(nand_12x6x_2s_2))

# 6floor
dsn.place(inst=inv_4x_2, mn=pg.mn.top_left(inv_6x_0)+3*pg.mn.height_vec(inv_4x_0)+2*pg.mn.height_vec(inv_6x_3))
dsn.place(inst=inv_8x_5, mn=pg.mn.top_left(inv_8x_0)+3*pg.mn.height_vec(inv_4x_0)+2*pg.mn.height_vec(inv_6x_3))
dsn.place(inst=space2, mn=pg.mn.top_right(nand_12x6x_2s_2))
        
# Create and place wires.
   
#IN_F
_track = [routing_space, None]
mn_list = []
mn_list.append(r34.mn(inv_6x_2.pins['I'])[0])
mn_list.append(r34.mn(inv_6x_3.pins['I'])[0])
mn_list.append(r34.mn(inv_6x_4.pins['I'])[0])
rinf0 = dsn.route_via_track(grid=r34, mn=mn_list, track=_track)
dsn.via(grid=r34, mn=mn_list)

_mn = [[routing_space, r34.mn(inv_6x_4.pins['I'])[0,1]], r34.mn(inv_6x_4.pins['I'])[0]]
rinf1 = dsn.route(grid=r34, mn=_mn, via_tag=[False, False])

#IN_R
_track = [r23.mn(inv_6x_1.pins['O'])[0,0]+1, None]
mn_list = []
mn_list.append(r45.mn(inv_4x_0.pins['I'])[0])
mn_list.append(r45.mn(inv_4x_1.pins['I'])[0])
mn_list.append(r45.mn(inv_4x_2.pins['I'])[0])
rinr0 = dsn.route_via_track(grid=r45, mn=mn_list, track=_track)
dsn.via(grid=r34, mn=mn_list)

_mn = [[r45.mn(inv_6x_1.pins['O'])[0,0], r45.mn(inv_4x_1.pins['I'])[0,1]], r45.mn(inv_4x_1.pins['I'])[0]]
rinr1 = dsn.route(grid=r45, mn=_mn, via_tag=[False, False])

# 1floor routing
_mn = [[r34.mn(inv_6x_2.pins['O'])[0,0],r34.mn(inv_6x_1.pins['I'])[0,1]], r34.mn(inv_6x_1.pins['I'])[0]]
_, r1_0, _ = dsn.route(grid=r34, mn=_mn, via_tag=[True, True])

_mn = [[r34.mn(inv_6x_1.pins['O'])[0,0],r34.mn(inv_6x_0.pins['I'])[0,1]], r34.mn(inv_6x_0.pins['I'])[0]]
_, r1_0, _ = dsn.route(grid=r34, mn=_mn, via_tag=[True, True])

_mn = [[r34.mn(inv_6x_0.pins['O'])[0,0], r34.mn(inv_8x_0.pins['I'])[0,1]], r34.mn(inv_8x_0.pins['I'])[0]]
_, r1_0, _ = dsn.route(grid=r34, mn=_mn, via_tag=[True, True])

_mn = [[r34.mn(inv_8x_0.pins['O'])[1,0],r34.mn(nand_12x6x_2s_0.pins['A'])[0,1]], r34.mn(nand_12x6x_2s_0.pins['A'])[0]]
_, r1_1 = dsn.route(grid=r34, mn=_mn, via_tag=[True, False])

_mn = [[r34.mn(nand_12x6x_2s_0.pins['O'])[0,0], r34.mn(inv_6x_5.pins['I'])[0,1]], r34.mn(inv_6x_5.pins['I'])[0]]
_, r1_2, _ = dsn.route(grid=r34, mn=_mn, via_tag=[True, True])

_mn = [r34.mn(inv_6x_5.pins['O'])[0], r34.mn(inv_6x_5.pins['O'])[1]]
r1_2 = dsn.route(grid=r34, mn=_mn, via_tag=[False, False])

# 2floor routing
_mn = [[r34.mn(inv_4x_0.pins['O'])[0,0], r34.mn(inv_8x_1.pins['I'])[0,1]], r34.mn(inv_8x_1.pins['I'])[0]]
_, r2_0, _ = dsn.route(grid=r34, mn=_mn, via_tag=[True, True])

_mn = [[r34.mn(inv_8x_1.pins['O'])[1,0],r34.mn(nand_12x6x_2s_0.pins['B'])[0,1]], r34.mn(nand_12x6x_2s_0.pins['B'])[0]]
_, r2_0 = dsn.route(grid=r34, mn=_mn, via_tag=[True, False])

# 3floor routing
_mn = [[r34.mn(inv_6x_3.pins['O'])[0,0], r34.mn(inv_8x_2.pins['I'])[0,1]], r34.mn(inv_8x_2.pins['I'])[0]]
_, r3_0, _ = dsn.route(grid=r34, mn=_mn, via_tag=[True, True])

_mn = [[r34.mn(inv_8x_2.pins['O'])[1,0],r34.mn(nand_12x6x_2s_1.pins['A'])[0,1]], r34.mn(nand_12x6x_2s_1.pins['A'])[0]]
_, r3_1 = dsn.route(grid=r34, mn=_mn, via_tag=[True, False])

_mn = [[r34.mn(nand_12x6x_2s_1.pins['O'])[0,0], r34.mn(inv_6x_6.pins['I'])[0,1]], r34.mn(inv_6x_6.pins['I'])[0]]
_, r3_2, _ = dsn.route(grid=r34, mn=_mn, via_tag=[True, True])

_mn = [r34.mn(inv_6x_6.pins['O'])[0], r34.mn(inv_6x_6.pins['O'])[1]]
r3_2 = dsn.route(grid=r34, mn=_mn, via_tag=[False, False])  

# 4floor routing
_mn = [[r34.mn(inv_4x_1.pins['O'])[0,0], r34.mn(inv_8x_3.pins['I'])[0,1]], r34.mn(inv_8x_3.pins['I'])[0]]
_, r4_0, _ = dsn.route(grid=r34, mn=_mn, via_tag=[True, True])

_mn = [[r34.mn(inv_8x_3.pins['O'])[1,0],r34.mn(nand_12x6x_2s_1.pins['B'])[0,1]], r34.mn(nand_12x6x_2s_1.pins['B'])[0]]
_, r4_0 = dsn.route(grid=r34, mn=_mn, via_tag=[True, False])

# 5floor routing
_mn = [[r34.mn(inv_6x_4.pins['O'])[0,0], r34.mn(inv_8x_4.pins['I'])[0,1]], r34.mn(inv_8x_4.pins['I'])[0]]
_, r5_0, _ = dsn.route(grid=r34, mn=_mn, via_tag=[True, True])

_mn = [[r34.mn(inv_8x_4.pins['O'])[1,0],r34.mn(nand_12x6x_2s_2.pins['A'])[0,1]], r34.mn(nand_12x6x_2s_2.pins['A'])[0]]
_, r5_1 = dsn.route(grid=r34, mn=_mn, via_tag=[True, False])

_mn = [[r34.mn(nand_12x6x_2s_2.pins['O'])[0,0], r34.mn(inv_6x_7.pins['I'])[0,1]], r34.mn(inv_6x_7.pins['I'])[0]]
_, r5_2, _ = dsn.route(grid=r34, mn=_mn, via_tag=[True, True])

_mn = [r34.mn(inv_6x_7.pins['O'])[0], r34.mn(inv_6x_7.pins['O'])[1]]
r5_2 = dsn.route(grid=r34, mn=_mn, via_tag=[False, False])   

# 6floor routing
_mn = [[r34.mn(inv_4x_2.pins['O'])[0,0], r34.mn(inv_8x_5.pins['I'])[0,1]], r34.mn(inv_8x_5.pins['I'])[0]]
_, r6_0, _ = dsn.route(grid=r34, mn=_mn, via_tag=[True, True])

_mn = [[r34.mn(inv_8x_5.pins['O'])[1,0],r34.mn(nand_12x6x_2s_2.pins['B'])[0,1]], r34.mn(nand_12x6x_2s_2.pins['B'])[0]]
_, r6_0 = dsn.route(grid=r34, mn=_mn, via_tag=[True, False])

#Rails
tech.generate_pwr_rail(dsn, grids, netname=['VSS', 'VDD'], vertical=False)

# 6. Create pins.
#IN
in_f = dsn.pin(name='IN_F', grid=r34, mn=r34.mn.bbox(rinf1))
in_r = dsn.pin(name='IN_R', grid=r34, mn=r34.mn.bbox(rinr1))

# Out pins
ps2_f_pre = dsn.pin(name='PS2_F_PRE', grid=r34, mn=r34.mn.bbox(r1_0))
ps2_f = dsn.pin(name='PS2_F', grid=r34, mn=r34.mn.bbox(r1_1))
ps2 = dsn.pin(name='PS2', grid=r34, mn=r34.mn.bbox(r1_2))
ps2_r = dsn.pin(name='PS2_R', grid=r34, mn=r34.mn.bbox(r2_0))

ps1_f_pre = dsn.pin(name='PS1_F_PRE', grid=r34, mn=r34.mn.bbox(r3_0))
ps1_f = dsn.pin(name='PS1_F', grid=r34, mn=r34.mn.bbox(r3_1))
ps1 = dsn.pin(name='PS1', grid=r34, mn=r34.mn.bbox(r3_2))
ps1_r = dsn.pin(name='PS1_R', grid=r34, mn=r34.mn.bbox(r4_0))

ps0_f_pre = dsn.pin(name='PS0_F_PRE', grid=r34, mn=r34.mn.bbox(r5_0))
ps0_f = dsn.pin(name='PS0_F', grid=r34, mn=r34.mn.bbox(r5_1))
ps0 = dsn.pin(name='PS0', grid=r34, mn=r34.mn.bbox(r5_2))
ps0_r = dsn.pin(name='PS0_R', grid=r34, mn=r34.mn.bbox(r6_0))

# Export design
# laygo2.export(dsn, tech=tech, filename=export_path_skill+libname+'_'+cellname+'.il')
laygo2.export_template(dsn, filename=f"{export_path}{libname}_templates.yaml", mode='append')

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