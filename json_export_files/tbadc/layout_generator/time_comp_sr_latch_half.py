##########################################################
#                                                      
# sr_latch_high_half Layout Generator          
# Contributors: D. Lee, B. Lim, S. Lim, J. Han
# Last Updated: 2025-04-21
#                                                      
##########################################################
import laygo2
import laygo2_tech as tech
import laygo2.object.database
import laygo2.interface.json

export_path_db      = './laygo2_generators_private/prj_db/tbadc/' # Path for JSON DB export
# Parameter definitions #############
# Design Variables
nf = [2,4,6]
# Design hierarchy
libname = 'tbadc_generated'
cellname = f'time_comp_sr_latch_half'
export_path = './laygo2_generators_private/tbadc/' 
export_path_skill = export_path+'skill/' 
# End of parameter definitions ######

# Generation start ##################
# Load templates and grids.
templates, grids = tech.load_templates_and_grids()
pg,  r12 = grids['placement_basic'], grids['routing_12_cmos']
r23, r34 = grids['routing_23_cmos'], grids['routing_34_cmos']
tlib = laygo2.interface.yaml.import_template(filename=export_path+'tbadc_generated_templates.yaml')
tlib_logic = laygo2.interface.yaml.import_template(filename='./laygo2_generators_private/logic/logic_generated_templates.yaml')

print('--------------------')
print(f'Creating {cellname}')
dsn = laygo2.Design(name=cellname, libname=libname, pgrid=pg, rgrid=r23)

dm0 = tlib['filler_dmy_2x'].generate(name="dm0")
dm1 = tlib['filler_dmy_2x'].generate(name="dm1")
dm2 = tlib['filler_dmy_2x'].generate(name="dm2")
dm3 = tlib['filler_dmy_2x'].generate(name="dm3")
ndmy0 = templates['nmos4_fast_dmy_nf2'].generate(name='ndmy0')
ndmy1 = templates['nmos4_fast_dmy_nf2'].generate(name='ndmy1')
ndmy2 = templates['nmos4_fast_dmy_nf2'].generate(name='ndmy2')
ndmy3 = templates['nmos4_fast_dmy_nf2'].generate(name='ndmy3')
pdmy0 = templates['pmos4_fast_dmy_nf2'].generate(name='pdmy0', transform='MX')
pdmy1 = templates['pmos4_fast_dmy_nf2'].generate(name='pdmy1', transform='MX')
pdmy2 = templates['pmos4_fast_dmy_nf2'].generate(name='pdmy2', transform='MX')
pdmy3 = templates['pmos4_fast_dmy_nf2'].generate(name='pdmy3', transform='MX')
pdmy4 = templates['pmos4_fast_dmy_nf2'].generate(name='pdmy4', transform='MX')
tap0 = tlib_logic['tap'].generate(name="ITAP0")
tap1 = tlib_logic['tap'].generate(name="ITAP1")
tap2 = tlib_logic['tap'].generate(name="ITAP2")
tap3 = tlib_logic['tap'].generate(name="ITAP3")
in0 = templates['nmos4_fast_center_nf2'].generate(name='in0')
in1 = templates['nmos4_fast_center_nf2'].generate(name='in1')
in2 = templates['nmos4_fast_center_nf2'].generate(name='in2')
in3 = templates['nmos4_fast_center_nf2'].generate(name='in3')
in4 = templates['nmos4_fast_center_nf2'].generate(name='in4')
in5 = templates['nmos4_fast_center_nf2'].generate(name='in5')
ip0 = templates['pmos4_fast_center_nf2'].generate(name='ip0', transform='MX')
ip1 = templates['pmos4_fast_center_nf2'].generate(name='ip1', transform='MX')
ip2 = templates['pmos4_fast_center_nf2'].generate(name='ip2', transform='MX')
ip3 = templates['pmos4_fast_center_nf2'].generate(name='ip3', transform='MX')
ip4 = templates['pmos4_fast_center_nf2'].generate(name='ip4', transform='MX')

dsn.place(inst=[[ndmy0,in0,in1,ndmy1,in2,in3,in4,ndmy2,ndmy3,in5],
                [pdmy0,pdmy1,ip0,pdmy2,ip1,ip2,ip3,pdmy3,pdmy4,ip4]])

# Route wires
_mn = [r12(pdmy1.p['D0'])[0], r12(pdmy1.p['D0'])[0]+[0,+2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r12(ndmy0.p['D0'])[1], r12(ndmy0.p['D0'])[1]+[0,-2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r12(pdmy0.p['D0'])[0], r12(pdmy0.p['D0'])[0]+[0,2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

g0 = dsn.via(grid=r12, mn=[r12(ip1.p['G0'])[0]])

g0 = dsn.via(grid=r12, mn=[r12(ip2.p['G0'])[0]])

g0 = dsn.via(grid=r12, mn=[r12(ip3.p['G0'])[0]])

_mn = [r12(in0.p['G0'])[0]+[-2,0], r12(in1.p['G0'])[0]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r12(in0.p['D0'])[0], r12(in1.p['D0'])[0], r12(ndmy1.p['D0'])[0]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[True, True, False])

_mn = [r12(in0.p['D0'])[1], r12(in1.p['D0'])[1], r12(ndmy1.p['D0'])[1]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[True, True, False])

_mn = [r12(in5.p['S0'])[0],r12(in5.p['D0'])[0], r12(in5.p['S1'])[0]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True, False])

_mn = [r12(in5.p['S0'])[1],r12(in5.p['D0'])[1], r12(in5.p['S1'])[1]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True, False])

_mn = [r12(ip4.p['S0'])[0],r12(ip4.p['D0'])[0], r12(ip4.p['S1'])[0]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True, False])

_mn = [r12(ip4.p['S0'])[1],r12(ip4.p['D0'])[1], r12(ip4.p['S1'])[1]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True, False])

_mn = [r23(ndmy1.p['D0'])[0], r23(ndmy1.p['D0'])[1], r23(pdmy2.p['D0'])[0]]
rG1 = dsn.route(grid=r23, mn=_mn, via_tag=[True, True, True])

_mn = [r12(in1.p['G0'])[0], r12(ip0.p['G0'])[0]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, False])

_mn = [r23(in2.p['G0'])[0], r23(in3.p['G0'])[0], r23(in4.p['G0'])[0]]
rG0 = dsn.route(grid=r23, mn=_mn, via_tag=[False, False, False])

_mn = [r23(ip1.p['G0'])[0]+[-2,0], r23(ip3.p['G0'])[0]]
rG0 = dsn.route(grid=r23, mn=_mn, via_tag=[True, True])

_mn = [r12(ip0.p['D0'])[0], r12(pdmy2.p['D0'])[0]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[True, False])

_mn = [r12(ip0.p['G0'])[0]+[-2,0], r12(ip0.p['G0'])[0]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r23(ip1.p['D0'])[0], r23(ip3.p['S1'])[0], r23(pdmy3.p['D0'])[0]]
rG0 = dsn.route(grid=r23, mn=_mn, via_tag=[False, False, False])

_mn = [r23(in2.p['D0'])[1], r23(in4.p['S1'])[1], r23(ndmy2.p['D0'])[1]]
rG0 = dsn.route(grid=r23, mn=_mn, via_tag=[False, False, False])

_mn = [r34(pdmy3.p['D0'])[0], r34(ndmy2.p['D0'])[1]]
rG0 = dsn.route(grid=r34, mn=_mn, via_tag=[False, False])

_mn = [r34(ip3.p['S1'])[0], r34(in4.p['S1'])[1]]
rG0 = dsn.route(grid=r34, mn=_mn, via_tag=[False, False])

_mn = [r23(in2.p['G0'])[0], r23(ip1.p['G0'])[0]]
rG0 = dsn.route(grid=r23, mn=_mn, via_tag=[True, False])

_mn = [r23(in3.p['G0'])[0], r23(ip2.p['G0'])[0]]
rG0 = dsn.route(grid=r23, mn=_mn, via_tag=[False, False])

#r34
_mn = [r34(ndmy0.p['S0'])[0]+[-1,4], r34(ip1.p['G0'])[0], r34(ip2.p['G0'])[0]]
rG0 = dsn.route(grid=r34, mn=_mn, via_tag=[False, True, True])

_mn = [r34(ip3.p['S1'])[0]+[0,-2], r34(pdmy3.p['D0'])[0]+[0,-2], r34(ip4.p['S1'])[0]+[0,-2]]
rG0 = dsn.route(grid=r34, mn=_mn, via_tag=[True, True, False])

#tie
_mn = [r12(ndmy0.p['S0'])[1], r12(ndmy0.p['S0'])[1]+[0,-2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r12(ndmy0.p['D0'])[1], r12(ndmy0.p['D0'])[1]+[0,-2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r12(ndmy0.p['S1'])[1], r12(ndmy0.p['S1'])[1]+[0,-2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r12(ndmy1.p['S0'])[1], r12(ndmy1.p['S0'])[1]+[0,-2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r12(ndmy1.p['D0'])[1], r12(ndmy1.p['D0'])[1]+[0,-2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r12(ndmy1.p['S1'])[1], r12(ndmy1.p['S1'])[1]+[0,-2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r12(ndmy2.p['S0'])[1], r12(ndmy2.p['S0'])[1]+[0,-2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r12(ndmy2.p['D0'])[1], r12(ndmy2.p['D0'])[1]+[0,-2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r12(ndmy2.p['S1'])[1], r12(ndmy2.p['S1'])[1]+[0,-2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r12(ndmy3.p['S0'])[1], r12(ndmy3.p['S0'])[1]+[0,-2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r12(ndmy3.p['D0'])[1], r12(ndmy3.p['D0'])[1]+[0,-2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r12(ndmy3.p['S1'])[1], r12(ndmy3.p['S1'])[1]+[0,-2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

##

_mn = [r12(pdmy0.p['S0'])[0], r12(pdmy0.p['S0'])[0]+[0,+2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r12(pdmy0.p['D0'])[0], r12(pdmy0.p['D0'])[0]+[0,+2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r12(pdmy0.p['S1'])[0], r12(pdmy0.p['S1'])[0]+[0,+2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r12(pdmy1.p['S0'])[0], r12(pdmy1.p['S0'])[0]+[0,+2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r12(pdmy1.p['S1'])[0], r12(pdmy1.p['S1'])[0]+[0,+2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r12(pdmy2.p['S0'])[0], r12(pdmy2.p['S0'])[0]+[0,+2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r12(pdmy2.p['D0'])[0], r12(pdmy2.p['D0'])[0]+[0,+2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r12(pdmy2.p['S1'])[0], r12(pdmy2.p['S1'])[0]+[0,+2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r12(pdmy3.p['S0'])[0], r12(pdmy3.p['S0'])[0]+[0,+2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r12(pdmy3.p['D0'])[0], r12(pdmy3.p['D0'])[0]+[0,+2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r12(pdmy3.p['S1'])[0], r12(pdmy3.p['S1'])[0]+[0,+2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r12(pdmy4.p['S0'])[0], r12(pdmy4.p['S0'])[0]+[0,+2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r12(pdmy4.p['D0'])[0], r12(pdmy4.p['D0'])[0]+[0,+2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r12(pdmy4.p['S1'])[0], r12(pdmy4.p['S1'])[0]+[0,+2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

##
_mn = [r12(in0.p['S0'])[1], r12(in0.p['S0'])[1]+[0,-2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r12(in0.p['S1'])[1], r12(in0.p['S1'])[1]+[0,-2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r12(in1.p['S1'])[1], r12(in1.p['S1'])[1]+[0,-2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r12(in2.p['S0'])[1], r12(in2.p['S0'])[1]+[0,-2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r12(in3.p['S0'])[1], r12(in3.p['S0'])[1]+[0,-2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r12(in4.p['S0'])[1], r12(in4.p['S0'])[1]+[0,-2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r12(in4.p['S1'])[1], r12(in4.p['S1'])[1]+[0,-2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r12(in5.p['S0'])[1], r12(in5.p['S0'])[1]+[0,-2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r12(in5.p['S1'])[1], r12(in5.p['S1'])[1]+[0,-2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r12(ip4.p['S0'])[0], r12(ip4.p['S0'])[0]+[0,+2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r12(ip4.p['S1'])[0], r12(ip4.p['S1'])[0]+[0,+2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r12(ip0.p['S0'])[0], r12(ip0.p['S0'])[0]+[0,+2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r12(ip0.p['S1'])[0], r12(ip0.p['S1'])[0]+[0,+2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r12(ip1.p['S0'])[0], r12(ip1.p['S0'])[0]+[0,+2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r12(ip2.p['S0'])[0], r12(ip2.p['S0'])[0]+[0,+2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r12(ip3.p['S0'])[0], r12(ip3.p['S0'])[0]+[0,+2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r12(ip3.p['S1'])[0], r12(ip3.p['S1'])[0]+[0,+2]]
rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[False, True])

_mn = [r23(in5.p['S0'])[1], r23(ip4.p['S0'])[0]]
rG0 = dsn.route(grid=r23, mn=_mn, via_tag=[False, False])

_mn = [r23(in5.p['S1'])[1], r23(ip4.p['S1'])[0]]
rG0 = dsn.route(grid=r23, mn=_mn, via_tag=[False, False])

_mn = [r23(in5.p['G0'])[1], r23(in5.p['G0'])[0]]
rG0 = dsn.route(grid=r23, mn=_mn, via_tag=[False, False])

_mn = [r23(ip4.p['G0'])[1], r23(ip4.p['G0'])[0]]
rG0 = dsn.route(grid=r23, mn=_mn, via_tag=[False, False])

_mn = [r12(in4.p['S1'])[0]+[0,-1], r12(ip3.p['S1'])[1]+[0,+1]]
#rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[True, True])

_mn = [r12(in5.p['S0'])[1]+[0,-2], r12(ip4.p['S0'])[0]+[0,+2]]
#rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[True, True])

_mn = [r12(in5.p['S1'])[1]+[0,-2], r12(ip4.p['S1'])[0]+[0,+2]]
#rG0 = dsn.route(grid=r12, mn=_mn, via_tag=[True, True])

tech.generate_pwr_rail(dsn, grids, netname=['VSS','VDD'], vertical=False)

_mn = [r23(ip4.p['G0'])[0], r23(ip4.p['G0'])[1]]
rG0 = dsn.route(grid=r23, mn=_mn, via_tag=[False, False])

####via
dsn.via(grid=r12, mn=[r12(in4.p['D0'])[1]])
dsn.via(grid=r12, mn=[r12(in3.p['D0'])[1]])
dsn.via(grid=r12, mn=[r12(in2.p['G0'])[1]])
dsn.via(grid=r12, mn=[r12(in3.p['G0'])[1]])
dsn.via(grid=r12, mn=[r12(in4.p['G0'])[1]])
dsn.via(grid=r12, mn=[r12(in2.p['D0'])[1]])
dsn.via(grid=r23, mn=[r23(in5.p['D0'])[1]])
dsn.via(grid=r12, mn=[r12(in0.p['G0'])[0]])

dsn.via(grid=r12, mn=[r12(ip3.p['D0'])[0]])
dsn.via(grid=r12, mn=[r12(ip2.p['D0'])[0]])
dsn.via(grid=r12, mn=[r12(ip1.p['D0'])[0]])
dsn.via(grid=r23, mn=[r23(ip4.p['D0'])[0]])
dsn.via(grid=r23, mn=[r23(in4.p['G0'])[0]])
dsn.via(grid=r12, mn=[r12(ip4.p['G0'])[0]])
dsn.via(grid=r12, mn=[r12(in5.p['G0'])[0]])

dsn.via(grid=r23, mn=[r23(ip4.p['G0'])[0]])
dsn.via(grid=r34, mn=[r34(ip4.p['G0'])[0]])

# Create pins
pA = dsn.pin(name='A', grid=r34, mn= [r34(pdmy0.p['D0'])[0]+[0,-2], r34(pdmy0.p['D0'])[0]+[0,-1]])
pB = dsn.pin(name='B', grid=r23, mn= [r23(pdmy0.p['D0'])[0]+[0,-3], r23(pdmy0.p['D0'])[0]+[0,-2]])
pC = dsn.pin(name='C', grid=r23, mn= [r23(in0.p['G0'])[0], r23(in1.p['G0'])[0]+[-1,0]])
pD = dsn.pin(name='D', grid=r23, mn=[r23(pdmy2.p['D0'])[0]+[0,-1],r23(pdmy2.p['D0'])[0]])
pd = dsn.pin(name='d', grid=r34, mn=[r34(pdmy1.p['S1'])[0]+[0,-3], r34(pdmy1.p['S1'])[0]+[0,-2]])
pE = dsn.pin(name='E', grid=r34, mn=r34(ip4.p['S0']))
pG = dsn.pin(name='G', grid=r34, mn=r34(ip4.p['S1']))
pK = dsn.pin(name='K', grid=r23, mn=[r23(ip4.p['G0'])[0]+[-1,0],r23(ip4.p['G0'])[0]+[1,0] ])
pM = dsn.pin(name='M', grid=r23, mn=[r23(in5.p['G0'])[0]+[-1,0],r23(in5.p['G0'])[0]+[1,0] ])
dP = dsn.pin(name='P', grid=r23, mn=r23(in5.p['S0']))
dQ = dsn.pin(name='Q', grid=r23, mn=r23(in5.p['S1']))

# Export design
# laygo2.export(dsn, tech=tech, filename=export_path_skill+libname+'_'+cellname+'.il')
laygo2.export_template(dsn, filename=f"{export_path}{libname}_templates.yaml", mode='append')

# test jSON DB export
grid_table = dict()
grid_table['M1'] = r12
grid_table['M2'] = r23
grid_table['M3'] = r34
grid_table['M4'] = r34
exporter = laygo2.object.database.DesignExporter(dsn, grid_table, lib_ref = "laygo2_generators_private/prj_db/tbadc/library.yaml")
nat_dict = exporter.export_to_dict()
laygo2.interface.json.export_dict(nat_dict, filename=export_path_db+libname+'_db.json', mode='append')