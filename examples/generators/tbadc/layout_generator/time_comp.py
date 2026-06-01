import numpy as np
import laygo2
import laygo2_tech as tech
import laygo2.object.database
import laygo2.interface.json

export_path_db      = './laygo2_generators_private/prj_db/tbadc/' # Path for JSON DB export

# Parameter definitions #############
# Design Variables
#cellname = 'time_cmp_v2_generated'
cellname = 'time_comp'


# Templates
tpmos_name = 'pmos'
tnmos_name = 'nmos'
tntap_name = 'ntap'
tptap_name = 'ptap'

# Grids


pg_name = 'placement_basic'
r12m_name = 'routing_12_mos'
r23m_name = 'routing_23_mos'
#r34m_name = 'routing_34_mos'
r12_name = 'routing_12_cmos'
r23_name = 'routing_23_cmos'
r34_name = 'routing_34_cmos'
r45_name = 'routing_45_cmos'
r12f_name   = 'routing_12_cmos_flipped'
r23f_name   = 'routing_23_cmos_flipped'
#r34f_name   = 'routing_34_cmos_flipped'

# Design hierarchy
libname = 'tbadc_generated'
export_path       = "./laygo2_generators_private/tbadc/" # Layout generation path: "export_path/libenaem/cellname"
export_path_skill = export_path+'skill/' # SKILL file generation path: "export_path_skill/libenaem_cellname.il"
# End of parameter definitions ######

# Generation start ##################
# 1. Load templates and grids.
print("Load templates")
templates = tech.load_templates()
tpmos, tnmos = templates[tpmos_name], templates[tnmos_name]
tntap, tptap = templates[tntap_name], templates[tptap_name]

tlib = laygo2.interface.yaml.import_template(filename='./laygo2_generators_private/tbadc/tbadc_generated_templates.yaml')


print("Load grids")
grids = tech.load_grids(templates=templates)

pg, r12m, r23m = grids[pg_name], grids[r12m_name], grids[r23m_name]
r12cmf, r23cmf = grids[r12f_name], grids[r23f_name] 
r12cm, r23cm, r34cm = grids[r12_name], grids[r23_name], grids[r34_name]

r12 = laygo2.grid.vstack([r12m, r12cm])
r23 = laygo2.grid.vstack([r23m, r23cm])

r12f= laygo2.grid.vstack([r12cmf, r12m])
r23f= laygo2.grid.vstack([r23cmf, r23m])
r34 = grids[r34_name]
r45 = grids[r45_name]

# grid for VDD/VSS metals
r23pw = laygo2.grid.vstack([r23m, r23m, r23cm, r23m, r23cm, r23m])

# 2. Create a design hierarchy
lib = laygo2.object.database.Library(name=libname)
dsn = laygo2.object.database.Design(name=cellname, libname=libname)
lib.append(dsn)


# 3. Create instances.
print("Create instances")
async_latch = tlib['time_comp_async_latch'].generate(name='async_latch',transform='MX')
#async_latch = tlib['async_latch_12x_4x8x_10x10x_2x2x'].generate(name='async_latch',transform='MX')
buffer = tlib['time_comp_buffer'].generate(name='buffer')
#sr_latch = tlib['sr_latch_high_tap'].generate(name='sr_latch',transform='MX')
sr_latch = tlib['time_comp_sr_latch_high_rst'].generate(name='sr_latch',transform='MX')


# 4. Place instances.
dsn.place(grid=pg, inst=[async_latch] ,mn=[0,0])
_width_async = pg.mn.width_vec(async_latch)[0]
_width_buffer = pg.mn.width_vec(buffer)[0]
_width_sr_latch = pg.mn.width_vec(sr_latch)[0]
height_pmos = 12
dsn.place(grid=pg, inst=[buffer], mn=[_width_async,height_pmos])
dsn.place(grid=pg, inst=[sr_latch], mn=[_width_async+_width_buffer,height_pmos])


# 5. Create and place wires.
print("Create wires")

_track = [r34(async_latch.p['OUTN'])[0,0]+7,None]
dsn.route(grid=r34, mn=[async_latch.p['OUTN'], buffer.p['CMP_OUTN']], track=_track )
_track = [r34(async_latch.p['OUTP'])[0,0]+7,None]
dsn.route(grid=r34, mn=[async_latch.p['OUTP'], buffer.p['CMP_OUTP']], track=_track )

# _mn = [r34(buffer.p['CMP_OUTPB'])[0], r34(sr_latch.p['INP'])[0]]
# dsn.route(grid=r34, mn= _mn, via_tag=[True, False])
# _mn = [r34(buffer.p['CMP_OUTNB'])[0], r34(sr_latch.p['INN'])[0]]
# dsn.route(grid=r34, mn= _mn, via_tag=[True, False])

# mn0 = r34.mn(sr_latch.p['INP'])[0]
# mn1 = [r34.mn(buffer.p['CMP_OUTPB'])[0,0], mn0[1]-1]
# dsn.route(grid=r34, mn=[mn1, mn0], via_tag=[True, False])

mn0 = [r34.mn(buffer.p['CMP_OUTNB'])[0,0], r34.mn(sr_latch.p['INN'])[1,1]]
mn1 = r34.mn(sr_latch.p['INN'])[0]
dsn.route(grid=r34, mn=[mn0, mn1], via_tag=[True, False])

mn0 = [r34.mn(buffer.p['CMP_OUTPB'])[0,0], r34.mn(sr_latch.p['INP'])[1,1]]
mn1 = r34.mn(sr_latch.p['INP'])[0]
dsn.route(grid=r34, mn=[mn0, mn1], via_tag=[True, False])


# Wires for VDD/VSS
mn0 = r23pw.mn.bbox(async_latch.p['VDD1'])[0]
mn1 = r23pw.mn.bbox(sr_latch.p['VDD0'])[1]
dsn.route(grid=r23pw, mn=[mn0, mn1], via_tag=[True, False])

mn0 = r23pw.mn.bbox(async_latch.p['VDD0'])[0]
mn1 = r23pw.mn.bbox(sr_latch.p['VDD1'])[1]
dsn.route(grid=r23pw, mn=[mn0, mn1], via_tag=[True, False])

mn0 = r23pw.mn.bbox(async_latch.p['VSS0'])[0]
mn1 = r23pw.mn.bbox(sr_latch.p['VSS0'])[1]
dsn.route(grid=r23pw, mn=[mn0, mn1], via_tag=[True, False])

mn0 = r23pw.mn.bbox(async_latch.p['VSS1'])[0]
mn1 = r23pw.mn.bbox(sr_latch.p['VSS1'])[1]
dsn.route(grid=r23pw, mn=[mn0, mn1], via_tag=[True, False])

mn0 = r23pw.mn.bbox(async_latch.p['VDD2'])[0]
mn1 = r23pw.mn.bbox(sr_latch.p['VDD2'])[1]
dsn.route(grid=r23pw, mn=[mn0, mn1], via_tag=[True, False])

mn0 = r23pw.mn.bbox(async_latch.p['VDD3'])[0]
mn1 = r23pw.mn.bbox(sr_latch.p['VDD3'])[1]
dsn.route(grid=r23pw, mn=[mn0, mn1], via_tag=[True, False])



# 6. Create pins.
async_pin0 = dsn.pin(name='INN', grid=r34, mn=async_latch.p['INN'])
async_pin1 = dsn.pin(name='INP', grid=r34, mn=async_latch.p['INP'])
async_pout_pre0 = dsn.pin(name='CMP_OUTP_PRE', grid=r12, mn=async_latch.p['OUTP_PRE'])
async_pout_pre1 = dsn.pin(name='CMP_OUTN_PRE', grid=r12, mn=async_latch.p['OUTN_PRE'])
async_pout0 = dsn.pin(name='CMP_OUTP', grid=r34, mn=async_latch.p['OUTP'])
async_pout1 = dsn.pin(name='CMP_OUTN', grid=r34, mn=async_latch.p['OUTN'])
buffer_pout0 = dsn.pin(name='CMP_OUTPB', grid=r34, mn=buffer.p['CMP_OUTPB'])
buffer_pout1 = dsn.pin(name='CMP_OUTNB', grid=r34, mn=buffer.p['CMP_OUTNB'])
srlatch_pout0 = dsn.pin(name='SR_OUTN', grid=r23pw, mn=sr_latch.p['OUTN'])
srlatch_pout1 = dsn.pin(name='SR_OUTP', grid=r23, mn=sr_latch.p['OUTP'])

srlatch_ppd = dsn.pin(name="PD", grid=r23pw, mn=sr_latch.p['PD'])
srlatch_pnd = dsn.pin(name="ND", grid=r23, mn=sr_latch.p['ND']) 
srlatch_prstb = dsn.pin(name="RSTB", grid=r45, mn=sr_latch.p['RSTB'])
srlatch_prst = dsn.pin(name="RST", grid=r45, mn=sr_latch.p['RST'])

# VDD, VSS pins
p_async_vdd0 = dsn.pin(name='VDD0', grid=r12, mn=r12.mn.bbox(async_latch.p['VDD0']), netname='VDD:')
p_async_vdd1 = dsn.pin(name='VDD1', grid=r12, mn=r12.mn.bbox(async_latch.p['VDD1']), netname='VDD:')
p_async_vdd2 = dsn.pin(name='VDD2', grid=r12, mn=r12.mn.bbox(async_latch.p['VDD2']), netname='VDD:')
p_async_vdd3 = dsn.pin(name='VDD3', grid=r12, mn=r12.mn.bbox(async_latch.p['VDD3']), netname='VDD:')
p_async_vss0 = dsn.pin(name='VSS0', grid=r12, mn=r12.mn.bbox(async_latch.p['VSS0']), netname='VSS:')
p_async_vss1 = dsn.pin(name='VSS1', grid=r12, mn=r12.mn.bbox(async_latch.p['VSS1']), netname='VSS:')

p_buffer_vdd0 = dsn.pin(name='VDD4', grid=r12, mn=r12.mn.bbox(buffer.p['VDD0']), netname='VDD:')
p_buffer_vdd1 = dsn.pin(name='VDD5', grid=r12, mn=r12.mn.bbox(buffer.p['VDD1']), netname='VDD:')
p_buffer_vss0 = dsn.pin(name='VSS2', grid=r12, mn=r12.mn.bbox(buffer.p['VSS0']), netname='VSS:')

p_srlatch_vdd0 = dsn.pin(name='VDD6', grid=r12, mn=r12.mn.bbox(sr_latch.p['VDD0']), netname='VDD:')
p_srlatch_vdd1 = dsn.pin(name='VDD7', grid=r12, mn=r12.mn.bbox(sr_latch.p['VDD1']), netname='VDD:')
p_srlatch_vdd2 = dsn.pin(name='VDD8', grid=r12, mn=r12.mn.bbox(sr_latch.p['VDD2']), netname='VDD:')
p_srlatch_vdd3 = dsn.pin(name='VDD9', grid=r12, mn=r12.mn.bbox(sr_latch.p['VDD3']), netname='VDD:')
p_srlatch_vss0 = dsn.pin(name='VSS3', grid=r12, mn=r12.mn.bbox(sr_latch.p['VSS0']), netname='VSS:')
p_srlatch_vss1 = dsn.pin(name='VSS4', grid=r12, mn=r12.mn.bbox(sr_latch.p['VSS1']), netname='VSS:')



# 7. Export to physical database.
print("Export design")
print("")
# laygo2.export(lib, tech=tech, filename=export_path_skill+libname+'_'+cellname+'.il')
    
# 8. Export to a template database file.
nat_temp = dsn.export_to_template()
laygo2.export_template(nat_temp, filename=export_path+libname+'_templates.yaml', mode='append')
print("")

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