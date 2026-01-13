##########################################################
#                                                      
# sr_latch_high_4x2x_6x6x_2x2x_rst Layout Generator          
# Contributors: D. Lee, B. Lim, S. Lim 
# Last Updated: 2024-10-17
#                                                      
##########################################################


import numpy as np
import laygo2
import laygo2_tech as tech
import yaml
import laygo2.interface
import laygo2.object.database
import laygo2.interface.json

export_path_db      = './laygo2_generators_private/prj_db/tbadc/' # Path for JSON DB export
# Parameter definitions #############
# Design Variables
celltype = ['sr_latch_high']
nf = [2,4,6]

# Templates
tpmos_name = 'pmos'
tnmos_name = 'nmos'
tntap_name = 'ntap'
tptap_name = 'ptap'

# Grids
pg_name = 'placement_basic'
r12_name = 'routing_12_cmos'
r23_name = 'routing_23_cmos'
r34_name = 'routing_34_cmos'
r45_name = 'routing_45_cmos'
r12m_name = 'routing_12_mos'
r23m_name = 'routing_23_mos'
r12cf_name = 'routing_12_cmos_flipped'

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
tlib = laygo2.interface.yaml.import_template(filename=export_path+'tbadc_generated_templates.yaml')
tlib_logic = laygo2.interface.yaml.import_template(filename='./laygo2_generators_private/logic/logic_generated_templates.yaml')


print("Load grids")
grids = tech.load_grids(templates=templates)
r12m= grids[r12m_name]
r23m= grids[r23m_name]
r12cf= grids[r12cf_name]
pg, r12c, r23c, r34, r45 = grids[pg_name], grids[r12_name], grids[r23_name], grids[r34_name], grids[r45_name]

r12 = laygo2.grid.vstack([r12m, r12c])#, r12m, r12cf])
r23 = laygo2.grid.vstack([r23m, r23c])
# Uncomment if you want to print grids
# print(grids[pg_name], grids[r12_name], grids[r23_name], sep="\n")
#cellname = cell_type+'_'+str(nf[0])+'x'+str(nf[0])+'x'+str(nf[1])+'x'

# cellname = f'sr_latch_high_tap'
#cellname = f'sr_latch_high_tap'
#cellname = f'sr_latch_high_4x2x_6x6x_2x2x_rst'
cellname = f'time_comp_sr_latch_high_rst'
print('--------------------')
print(f'Creating {cellname}')

# 2. Create a design hierarchy
lib = laygo2.Library(name=libname)
dsn = laygo2.Design(name=cellname, libname=libname)
lib.append(dsn)

 # 3. Create istances.
print("Create instances")

dm0 = tlib['filler_dmy_2x'].generate(name="dm0", transform='MX')
dm1 = tlib['filler_dmy_2x'].generate(name="dm1")

hf0 = tlib['time_comp_sr_latch_half'].generate(name="half0", transform='MX')
hf1 = tlib['time_comp_sr_latch_half2'].generate(name="half1")

ndmy0 = templates['nmos4_fast_dmy_nf2'].generate(name='ndmy0', transform='MX')
pdmy0 = templates['pmos4_fast_dmy_nf2'].generate(name='pdmy0', transform='MX')

#in0 = tlib['nmos_sj'].generate(name='in0')
in0 = tlib['time_comp_nmos_sj'].generate(name='in0')
ip0 = templates['pmos4_fast_center_nf2'].generate(name='ip0')

tap0 = tlib_logic['tap'].generate(name="ITAP0", transform='MX')
tap1 = tlib_logic['tap'].generate(name="ITAP1")
tap2 = tlib_logic['tap'].generate(name="ITAP2", transform='MX')
tap3 = tlib_logic['tap'].generate(name="ITAP3")


# 4. Place instances.

_height_srh     = pg.mn.height_vec(hf1)[1]      # height of sr_latch_half2
_width = pg.mn.width_vec(hf0)[0] + pg.mn.width_vec(dm0)[0] + pg.mn.width_vec(ip0)[0]
_offset_tap = -1

ipt0 = tptap.generate(name='PT2', params={'nf': _width, 'tie': 'TAP0'})
int0 = tntap.generate(name='PT0', params={'nf': _width, 'tie': 'TAP0'})
int1 = tntap.generate(name='PT1', params={'nf': _width, 'tie': 'TAP0'}, transform='MX')

_height_ntap = pg.mn.height_vec(int0)[1]     # height of ntap

dsn.place(grid=pg, inst=int0, mn=[_offset_tap,0])
dsn.place(grid=pg, inst=[hf0,dm0,ip0], mn=pg.mn.height_vec(int0))
dsn.place(grid=pg, inst=ipt0, mn=[_offset_tap,_height_srh+_height_ntap])

_height_ptap     = pg.mn.height_vec(ipt0)[1]    # height of ptap

dsn.place(grid=pg, inst=[hf1,dm1,in0], mn=[0,_height_srh+_height_ntap+_height_ptap])
dsn.place(grid=pg, inst=[ndmy0], mn=[pg.top_left(ip0)[0],pg.top_left(ip0)[1]])
dsn.place(grid=pg, inst=[pdmy0], mn=[pg.top_left(in0)[0],pg.top_left(in0)[1]])
dsn.place(grid=pg, inst=int1, mn=[_offset_tap,pg.top_right(hf1)[1]+_height_ntap])



##################################
##################################
##################################
##################################

# 5. Route wires
#tech.generate_pwr_rail(dsn, grids, netname=['VDD','VSS'], vertical=False)

##dmy
_mn = [r12(ndmy0.p['S0'])[0], r12(ndmy0.p['S0'])[0]+[0,2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])
_mn = [r12(ndmy0.p['D0'])[0], r12(ndmy0.p['D0'])[0]+[0,2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])
_mn = [r12(ndmy0.p['S1'])[0], r12(ndmy0.p['S1'])[0]+[0,2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])
_mn = [r12(pdmy0.p['S1'])[0], r12(pdmy0.p['S1'])[0]+[0,2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])
_mn = [r12(pdmy0.p['S0'])[0], r12(pdmy0.p['S0'])[0]+[0,2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])
_mn = [r12(pdmy0.p['D0'])[0], r12(pdmy0.p['D0'])[0]+[0,2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])
_mn = [r12(in0.p['S1'])[0], r12(in0.p['S1'])[0]+[0,-4]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])
_mn = [r12(in0.p['S0'])[0], r12(in0.p['S0'])[0]+[0,-4]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])
#_mn = [r12(ip0.p['S0'])[0], r12(ip0.p['S0'])[0]+[0,-2]]
#rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

##RST
_mn = [r45(in0.p['D0'])[1]+[2,1], r45(ip0.p['G0'])[0]+[2,-5]]
rG0 = dsn.route(grid=r45, mn=_mn, via_tag=[False, False])

_mn = [r34(in0.p['D0'])[1]+[0,1], r34(in0.p['D0'])[1]+[2,1]]
rG0 = dsn.route(grid=r34, mn=_mn, via_tag=[True, False])

_mn = [r23(in0.p['D0'])[1]+[0,2], r23(in0.p['D0'])[1]+[0,0]]
rG0 = dsn.route(grid=r23, mn=_mn, via_tag=[False, False])

g0 = dsn.via(grid=r45, mn=[r45(in0.p['D0'])[1]+[2,1]])

##RSTB
_mn = [r45(ip0.p['G0'])[0]+[0,0], r45(ip0.p['G0'])[0]+[0,-5]]
rG0 = dsn.route(grid=r45, mn=_mn, via_tag=[True, False])

_mn = [r34(ip0.p['G0'])[0]+[-1,0], r34(ip0.p['G0'])[0]+[1,0]]
rG0 = dsn.route(grid=r34, mn=_mn, via_tag=[False, False])

_mn = [r23(ip0.p['G0'])[0]+[0,1], r23(ip0.p['D0'])[1]+[0,-1]]
rG0 = dsn.route(grid=r23, mn=_mn, via_tag=[False, False])

g0 = dsn.via(grid=r34, mn=[r34(ip0.p['G0'])[0]])
##PD
_mn = [r23(hf1.p['C'])[1]+[1,1], r23(hf0.p['d'])[1]+[1,-1]]
rG0 = dsn.route(grid=r23, mn=_mn, via_tag=[True, False])
g0 = dsn.via(grid=r12, mn=[r12(hf1.p['C'])[1]+[1,1]])
g0 = dsn.via(grid=r34, mn=[r34(hf0.p['d'])[1]+[1,-1]])

##ND#######################################################################
_mn = [r23(hf1.p['d'])[1]+[-1,1], r23(hf0.p['C'])[0]+[0,0]]
rG0 = dsn.route(grid=r23, mn=_mn, via_tag=[False, True])
#g0 = dsn.via(grid=r34, mn=[r34(hf1.p['d'])[1]+[-1,1]])

##OUTN
_mn = [r23(hf0.p['E'])[0], r23(hf1.p['E'])[0]+[0,0]]
rG0 = dsn.route(grid=r23, mn=_mn, via_tag=[False, True])

g0 = dsn.via(grid=r23, mn=[r23(hf1.p['E'])[0]])
#g0 = dsn.via(grid=r12, mn=[r12(hf1.p['E'])[0]])
g0 = dsn.via(grid=r12, mn=[r12(hf1.p['E'])[0]+[1,0]])
g0 = dsn.via(grid=r23, mn=[r23(hf1.p['P'])[0]])
#g0 = dsn.via(grid=r12, mn=[r12(hf1.p['P'])[0]])
g0 = dsn.via(grid=r12, mn=[r12(hf1.p['P'])[0]+[1,0]])
#g0 = dsn.via(grid=r34, mn=[r34(hf0.p['K'])[0]])
#g0 = dsn.via(grid=r34, mn=[r23(hf0.p['K'])[0]])
g0 = dsn.via(grid=r34, mn=[r23(hf0.p['M'])[0]])
#g0 = dsn.via(grid=r12, mn=[r12(hf0.p['K'])[0]+[1,-1]])
g0 = dsn.via(grid=r12, mn=[r12(hf0.p['M'])[0]+[1,0]])

_mn = [r23(hf0.p['M'])[0], r23(hf0.p['M'])[1]]
rG0 = dsn.route(grid=r23, mn=_mn, via_tag=[True, False])
#_mn = [r23(hf0.p['K'])[0], r23(hf0.p['K'])[1]]
#rG0 = dsn.route(grid=r23, mn=_mn, via_tag=[False, False])
_mn = [r23(hf1.p['P'])[0], r23(in0.p['D0'])[0]]
rG0 = dsn.route(grid=r23, mn=_mn, via_tag=[False, False])

##OUTP
_mn = [r23(hf0.p['G'])[0], r23(hf1.p['G'])[0]+[0,1]]
rG0 = dsn.route(grid=r23, mn=_mn, via_tag=[True, False])

_mn = [r23(hf0.p['G'])[0]+[0,0], r23(hf0.p['G'])[0]+[3,0]]
rG0 = dsn.route(grid=r23, mn=_mn, via_tag=[False, False])

#_mn = [r23(hf1.p['M'])[0]+[0,0], r23(hf1.p['M'])[0]+[1,0]]
#rG0 = dsn.route(grid=r23, mn=_mn, via_tag=[False, False])
'''
_mn = [r23(in0.p['G0'])[1]+[-4,1], r23(in0.p['G0'])[1]+[-2,1]]
rG0 = dsn.route(grid=r23, mn=_mn, via_tag=[False, False])
_mn = [r23(hf1.p['K'])[0]+[-1,0], r23(hf1.p['K'])[1]+[1,0]]
rG0 = dsn.route(grid=r23, mn=_mn, via_tag=[False, False])
'''
#g0 = dsn.via(grid=r34, mn=[r34(hf1.p['K'])[1]+[0,1]])
g0 = dsn.via(grid=r23, mn=[r23(hf0.p['Q'])[1]])
g0 = dsn.via(grid=r23, mn=[r23(hf1.p['M'])[1]+[0,1]])
#g0 = dsn.via(grid=r23, mn=[r23(hf1.p['M'])[1]])F
g0 = dsn.via(grid=r12, mn=[r12(hf0.p['Q'])[0]+[-1,0]])
g0 = dsn.via(grid=r12, mn=[r12(hf0.p['G'])[0]+[-1,0]])
g0 = dsn.via(grid=r12, mn=[r12(ip0.p['G0'])[0]])
#g0 = dsn.via(grid=r12, mn=[r12(in0.p['G0'])[0]])
#g0 = dsn.via(grid=r23, mn=[r12(in0.p['G0'])[0]+[0,-1]])
g0 = dsn.via(grid=r23, mn=[r23(ip0.p['G0'])[0]])

_mn = [r12(ip0.p['S1'])[0]+[0,-1], r12(ip0.p['S1'])[0]+[0,0]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[True, False])

###via
'''
g0 = dsn.via(grid=r23, mn=[r23(hf1.p['E'])[0]+[1,0]])
g0 = dsn.via(grid=r23, mn=[r23(hf1.p['P'])[1]+[1,0]])
g0 = dsn.via(grid=r23, mn=[r23(hf0.p['Q'])[0]+[1,0]])
g0 = dsn.via(grid=r23, mn=[r23(hf0.p['Q'])[1]+[1,0]])
g0 = dsn.via(grid=r23, mn=[r23(hf0.p['G'])[1]+[1,0]])
g0 = dsn.via(grid=r12, mn=[r12(in0.p['S0'])[1]+[0,-2]])
#g0 = dsn.via(grid=r12, mn=[r12(in0.p['S1'])[1]+[0,-2]])
g0 = dsn.via(grid=r45, mn=[r45(in0.p['G0'])[0]+[3,-1]])
g0 = dsn.via(grid=r34, mn=[r34(hf1.p['K'])[1]+[1,0]])
g0 = dsn.via(grid=r34, mn=[r34(hf0.p['M'])[0]+[1,-1]])f
g0 = dsn.via(grid=r23, mn=[r23(ip0.p['G0'])[0]+[1,0]])
g0 = dsn.via(grid=r12, mn=[r12(hf0.p['G'])[0]+[4,0]])
'''
g0 = dsn.via(grid=r12, mn=[r12(in0.p['D0'])])
g0 = dsn.via(grid=r12, mn=[r12(ip0.p['D0'])])


# 6. Create pins
pINN  = dsn.pin(name='INN', grid=r45, mn=[r45(hf1.p['B'])[0]+[0,1], r45(hf1.p['B'])[0]+[-1,1]]) 
pINP  = dsn.pin(name='INP', grid=r34, mn=[r34(hf0.p['B'])[1]+[0,-1], r34(hf0.p['B'])[1]+[-1,-1]])
pND  = dsn.pin(name='ND', grid=r23, mn=[r23(hf0.p['D'])[0]+[0,0],r23(hf0.p['D'])[0]+[0,1]])
pPD  = dsn.pin(name='PD', grid=r23, mn=[r23(hf1.p['D'])[0]+[0,0],r23(hf1.p['D'])[0]+[0,-1]])
pOUTN  = dsn.pin(name='OUTN', grid=r34, mn=hf0.p['K'])
pOUTP  = dsn.pin(name='OUTP', grid=r23, mn=hf1.p['K'])
pRSTB  = dsn.pin(name='RSTB', grid=r45, mn=[r45(ip0.p['D0'])[0]+[0,0], r45(ip0.p['D0'])[0]+[0,3]])
pRST  = dsn.pin(name='RST', grid=r45, mn=[r45(ip0.p['G0'])[0]+[2,-3], r45(ip0.p['G0'])[0]+[2,0]])


# Add VDD/VSS metals
_mn = [r12(ip0.p['S0'])[0]+[0,-1], r12(ip0.p['S1'])[0]+[0,-1]]
dsn.route(grid=r12, mn=_mn, via_tag=[True, False])

_mn = [r12(in0.p['S0'])[0]+[0,-1], r12(in0.p['S1'])[0]+[0,-1]]
dsn.route(grid=r12, mn=_mn, via_tag=[True, False])

_mn = [r12(pdmy0.p['S0'])[1]+[0,1], r12(pdmy0.p['S1'])[1]+[0,1]]
dsn.route(grid=r12, mn=_mn, via_tag=[True, False])


# VDD VSS pins
# ntap
pvdd0 = dsn.pin(name='VDD0', grid=r12, mn=r12(int0.p['RAIL']), netname='VDD:')
# sr_latch_half
pvdd1 = dsn.pin(name='VDD1', grid=r12, mn=[r12(hf0.p['VDD:'])[0], r12(ip0.p['S1'])[0]+[0, -1]], netname='VDD:')
pvss0 = dsn.pin(name='VSS0', grid=r12, mn=[r12(hf0.p['VSS:'])[0], r12(ndmy0.p['S1'])[0]+[0, 2]], netname='VSS:')
# sr_latch_half2
pvdd2 = dsn.pin(name='VDD2', grid=r12, mn=[r12(hf1.p['VDD:'])[0], r12(pdmy0.p['S1'])[0]+[0, 2]], netname='VDD:')
pvss1 = dsn.pin(name='VSS1', grid=r12, mn=[r12(hf1.p['VSS:'])[0], r12(in0.p['S1'])[0]+[0, -1]], netname='VSS:')
# ptap
pvdd3 = dsn.pin(name='VDD3', grid=r12, mn=r12(int1.p['RAIL']), netname='VDD:')



 # 7. Export to physical database
print("Export design\n")
laygo2.interface.bag.export(lib, tech_library=tech.name, filename=export_path_skill+cellname+'.il', cellname=None, scale=1e-3,
                                reset_library=False)
# Filename example: ./laygo2_generators_private/logic/skill/logic_generated_dff_2x.il

# 8. Export to a template database file
nat_temp = dsn.export_to_template()
laygo2.interface.yaml.export_template(nat_temp, 
                                            filename=export_path+libname+'_templates.yaml', 
                                            mode='append')
# Filename example: ./laygo2_generators_private/logic/logic_generated_templates.yaml

# test jSON DB export
grid_table = dict()
grid_table['M1'] = r12
grid_table['M2'] = r23
grid_table['M3'] = r34
grid_table['M4'] = r34
grid_table['M5'] = r45
exporter = laygo2.object.database.DesignExporter(dsn, grid_table, lib_ref = "laygo2_generators_private/prj_db/tbadc/library.yaml")
nat_dict = exporter.export_to_dict()
laygo2.interface.json.export_dict(nat_dict, filename=export_path_db+libname+'_db.json', mode='append')
