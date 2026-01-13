import numpy as np
import pprint
import laygo2
import laygo2.interface
import laygo2_tech as tech
import yaml

### PARAMETER DEFINITION
# Templates
tpmos_name = 'pmos'
tnmos_name = 'nmos'
tntap_name = 'ntap'
tptap_name = 'ptap'
# Grids
pg_name     = 'placement_basic'
r12_name    = 'routing_12_cmos'
r12m_name   = 'routing_12_mos'
r12f_name   = 'routing_12_cmos_flipped'
r23_name    = 'routing_23_cmos'
r23m_name    = 'routing_23_mos'
r23f_name   = 'routing_23_cmos_flipped'
r34_name    = 'routing_34_cmos'

import laygo2.object.database
import laygo2.interface.json

export_path_db      = './laygo2_generators_private/prj_db/tbadc/' # Path for JSON DB export

# Read spec.yaml
param_fname = './laygo2_generators_private/tbadc/tbadc_spec.yaml'
with open(param_fname, 'r') as stream:
    try:
        spec_params = yaml.safe_load(stream)
    except yaml.YAMLError as exc:
        print(exc)

#nf_in = spec_params['nf_in']
#nf_rgnn = spec_params['nf_rgnn']
#nf_rgnp = spec_params['nf_rgnp']
#nf_rst_pre_bot = spec_params['nf_rst_pre_bot']
#nf_rst_pre_top = spec_params['nf_rst_pre_top']
#nf_rst_out_bot = spec_params['nf_rst_out_bot']
#nf_rst_out_top = spec_params['nf_rst_out_top']

nf_in = 12
nf_rgnn = 8
nf_rgnp = 4
nf_rst_pre_bot = 2
nf_rst_pre_top = 2
nf_rst_out_bot = 10
nf_rst_out_top = 10

# Design hierarchy
libname  = 'tbadc_generated'
#cellname = 'async_latch_half_'+str(nf_in)+'x_'+str(nf_rgnp)+'x'+str(nf_rgnn)+'x_'+str(nf_rst_out_bot)+'x'+str(nf_rst_out_top)+'x_'+str(nf_rst_pre_bot)+'x'+str(nf_rst_pre_top)+'x'
cellname = 'time_comp_async_latch_half' 
ref_dir_template     = './laygo2_generators_private/tbadc/'       # Reference path for generated cell template yaml
ref_dir_BAG_exported = './laygo2_generators_private/tbadc/skill/' # Reference path for SKILL script
# End of parameter definitions ######

### GENERATION START
# 1. Load templates and grids.
print("Load templates")
templates = tech.load_templates()
tpmos, tnmos = templates[tpmos_name], templates[tnmos_name]
tptap, tntap = templates[tptap_name], templates[tntap_name]
tlib = laygo2.interface.yaml.import_template(filename='./laygo2_generators_private/logic/logic_generated_templates.yaml')
# Filename Example: ./laygo2_generators_private/scan/scan_generated_templates.yaml

print("Load grids")
grids = tech.load_grids(templates=templates)
pg, r12cm, r12cmf, r23cm, r23cmf, r34 = grids[pg_name], grids[r12_name], grids[r12f_name], grids[r23_name], grids[r23f_name], grids[r34_name]
r12m, r23m = grids[r12m_name], grids[r23m_name]

r12 = laygo2.grid.vstack([r12cm, r12m])
r23 = laygo2.grid.vstack([r23cm, r23m])
r12f= laygo2.grid.vstack([r12cmf, r12m])
r23f= laygo2.grid.vstack([r23cmf, r23m])

# 2. Create a design hierarchy
lib = laygo2.object.database.Library(name=libname)
dsn = laygo2.object.database.Design(name=cellname, libname=libname)
lib.append(dsn)

# 3. Create istances.

# INSTACNES
in0 = tnmos.generate(name='MN0', params={'nf': nf_in, 'tie': 'S'}, transform='MX')
in1 = tnmos.generate(name='MN1', params={'nf': nf_rgnn, 'trackswap': True}, transform='MX')
ip0 = tpmos.generate(name='MP0', params={'nf': nf_rst_pre_top, 'tie': 'S'}, transform='MX')
ip1 = tpmos.generate(name='MP1', params={'nf': nf_rst_pre_bot, 'trackswap': True}, transform='MX')
ip2 = tpmos.generate(name='MP2', params={'nf': nf_rst_out_top, 'tie': 'S'})
ip3 = tpmos.generate(name='MP3', params={'nf': nf_rst_out_bot, 'trackswap': True})
ip4 = tpmos.generate(name='MP4', params={'nf': nf_rgnp, 'trackswap': True, 'tie': 'S'})

# TAP
# ptap_bot_left = templates['pmos4_fast_tap'].generate(name='ptap_bot_left', transform='MX')
# ptap_bot_right = templates['pmos4_fast_tap'].generate(name='ptap_bot_right', transform='MX')
# ptap_mid_left = templates['pmos4_fast_tap'].generate(name='ptap_mid_left')
# ptap_mid_right = templates['pmos4_fast_tap'].generate(name='ptap_mid_right')
# ntap_top_left = templates['nmos4_fast_tap'].generate(name='ntap_top_left', transform='MX')
# ntap_top_right = templates['nmos4_fast_tap'].generate(name='ntap_top_right', transform='MX')


# 4. Place instances.
_heigth_vec = pg.mn.height_vec(tntap.generate(name='__TMP__', params={'nf': 2, 'tie': 'TAP0'}))
_heigth_vec_cmos = _heigth_vec*2
#dsn.place(grid=pg, inst=ptap_bot_left, mn=[0,0]+pg.mn.height_vec(ptap_bot_left))
#dsn.place(grid=pg, inst=ptap_mid_left, mn=pg.top_left(ptap_bot_left)+_heigth_vec)
#dsn.place(grid=pg, inst=ntap_top_left, mn=pg.top_left(ptap_mid_left)+pg.mn.height_vec(ntap_top_left))

#dsn.place(grid=pg, inst=ip4, mn=pg.bottom_right(ptap_mid_left))
dsn.place(grid=pg, inst=ip4, mn=[0,0]+_heigth_vec_cmos)
dsn.place(grid=pg, inst=ip3, mn=pg.bottom_right(ip4))
dsn.place(grid=pg, inst=ip2, mn=pg.bottom_right(ip3))

#dsn.place(grid=pg, inst=in1, mn=pg.top_right(ntap_top_left))
dsn.place(grid=pg, inst=in1, mn=pg.top_left(ip4)+pg.mn.height_vec(in1))
dsn.place(grid=pg, inst=in0, mn=pg.top_right(in1))


dsn.place(grid=pg, inst=ip1, mn=pg.bottom_left(ip3)-_heigth_vec)
dsn.place(grid=pg, inst=ip0, mn=pg.bottom_left(ip2)-_heigth_vec)

############################ FILLING FUNCTION ####################################
space0 = templates['pmos4_fast_space_1x'].generate(name='space0', shape=[nf_rgnp+2, 1])
#dsn.place(grid=pg, inst=space0, mn=pg.mn.bottom_right(ptap_bot_left))
dsn.place(grid=pg, inst=space0, mn=[0,0])
space1 = templates['pmos4_fast_space_1x'].generate(name='space1', shape=[nf_rst_out_bot - nf_rst_pre_bot, 1])
dsn.place(grid=pg, inst=space1, mn=pg.mn.bottom_right(ip1))

if (nf_rgnp + nf_rst_out_top + nf_rst_out_bot + 5) == (nf_in + nf_rgnn + 3):
    space2 = templates['pmos4_fast_space_1x'].generate(name='space2', shape=[nf_rst_out_top - nf_rst_pre_top, 1])
    dsn.place(grid=pg, inst=space2, mn=pg.mn.bottom_right(ip0))

if (nf_rgnp + nf_rst_out_top + nf_rst_out_bot + 5) > (nf_in + nf_rgnn + 3):
    nf_space = (nf_rgnp + nf_rst_out_top + nf_rst_out_bot + 5) - (nf_in + nf_rgnn + 3)
    space3 = templates['nmos4_fast_space_1x'].generate(name='space3', shape=[nf_space, 1])
    dsn.place(grid=pg, inst=space3, mn=pg.mn.bottom_right(in0))

    space2 = templates['pmos4_fast_space_1x'].generate(name='space2', shape=[nf_rst_out_top - nf_rst_pre_top, 1])
    dsn.place(grid=pg, inst=space2, mn=pg.mn.bottom_right(ip0))

if (nf_rgnp + nf_rst_out_top + nf_rst_out_bot + 5) < (nf_in + nf_rgnn + 3):
    nf_space = (nf_in + nf_rgnn + 3) - (nf_rgnp + nf_rst_out_top + nf_rst_out_bot + 5)
    space3 = templates['pmos4_fast_space_1x'].generate(name='space3', shape=[nf_space, 1])
    dsn.place(grid=pg, inst=space3, mn=pg.mn.bottom_right(ip2))

    space2 = templates['pmos4_fast_space_1x'].generate(name='space2', shape=[nf_rst_out_top - nf_rst_pre_top + nf_space, 1])
    dsn.place(grid=pg, inst=space2, mn=pg.mn.bottom_right(ip0))

# TAP FILLING
_width = pg.top_right(space2)[0]
_nf_tap = _width-2
int0 = tntap.generate(name='NT0', params={'nf': _nf_tap})#, 'tie': 'TAP0'})
dsn.place(grid=pg, inst=int0, mn=[0,0]+pg.mn.height_vec(space0))
######################### FILLING FUNCTION END ###################################

#dsn.place(grid=pg, inst=ptap_bot_right, mn=pg.top_right(space2))
#dsn.place(grid=pg, inst=ptap_mid_right, mn=pg.top_left(ptap_bot_right))
#dsn.place(grid=pg, inst=ntap_top_right, mn=pg.top_left(ptap_mid_right)+pg.mn.height_vec(ntap_top_right))


# 5. Create and place wires.
print("Create wires")

# INP
_mn = []
_mn.append(r23f.bottom_left(ip1.p['G']))
_mn.append(r23f.bottom_left(ip3.p['G']))
v0, r0, v1 = dsn.route(grid=r23f, mn=_mn, via_tag=[True, True])

if r23f(in0.p['G'])[0][0] >= r23f(ip3.p['G'])[0][0] and r23f(in0.p['G'])[0][0] <= r23f(ip3.p['G'])[1][0]:
    _mn = []
    _mn.append(r23f.bottom_left(in0.p['G'])-[0,2])
    _mn.append(r23f.bottom_left(in0.p['G']))
    dsn.route(grid=r23f, mn=_mn, via_tag=[True,True])

if r23f(in0.p['G'])[1][0] >= r23f(ip3.p['G'])[0][0] and r23f(in0.p['G'])[1][0] <= r23f(ip3.p['G'])[1][0]:
    _mn = []
    _mn.append(r23f.bottom_right(in0.p['G'])-[0,2])
    _mn.append(r23f.bottom_right(in0.p['G']))
    dsn.route(grid=r23f, mn=_mn, via_tag=[True,True])

if r23f(in0.p['G'])[0][0] > r23f(ip3.p['G'])[1][0]:
    _mn = []
    _mn.append(r23f.bottom_right(ip3.p['G']))
    _mn.append(r23f.bottom_left(in0.p['G']))
    _track = [None, r23f.bottom_left(in0.p['G'])[1]-1]
    dsn.route_via_track(grid=r23f, mn=_mn, track=_track)

if r23f(in0.p['G'])[1][0] < r23f(ip3.p['G'])[0][0]:
    _mn = []
    _mn.append(r23f.bottom_right(in0.p['G']))
    _mn.append(r23f.bottom_left(ip3.p['G']))
    _track = [None, r23f.bottom_right(in0.p['G'])[1]-1]
    dsn.route_via_track(grid=r23f, mn=_mn, track=_track)

# INN
_mn = []
_mn.append(r23f.bottom_left(ip0.p['G']))
_mn.append(r23f.bottom_left(ip2.p['G']))
v0, r1, v1 = dsn.route(grid=r23f, mn=_mn, via_tag=[True, True])

# OUTP
_mn = []
_mn.append(r23f.bottom_left(ip4.p['G']))
_mn.append(r23f.bottom_left(in1.p['G']))
v0, r2, v1 = dsn.route(grid=r23f, mn=_mn, via_tag=[True, True])

# OUTN
_mn = []
_mn.append(r23f.bottom_left(ip4.p['D']))
_mn.append(r23f.bottom_right(ip3.p['D']))
dsn.route(grid=r23f, mn=_mn, via_tag=[False, False])

_mn = []
_mn.append(r23f.bottom_left(ip4.p['D']))
_mn.append(r23f.bottom_left(in1.p['D']))
_track = [r23f.bottom_left(ip4.p['D'])[0]-2, None]
r3 = dsn.route_via_track(grid=r23f, mn=_mn, track=_track)

# OUT_PRE
_mn = []
_mn.append(r23f.bottom_left(in1.p['S']))
_mn.append(r23f.bottom_right(in0.p['D']))
r4 = dsn.route(grid=r23f, mn=_mn, via_tag=[False, False])

_mn = []
_mn.append(r23f.bottom_left(ip1.p['D']))
_mn.append(r23f.bottom_left(in1.p['S']))
_track = [r23f.bottom_left(in1.p['D'])[0]-1, None]
dsn.route_via_track(grid=r23f, mn=_mn, track=_track)

# rst_pre_internal
_mn = []
_mn.append(r23f.bottom_left(ip1.p['S']))
_mn.append(r23f.bottom_right(ip0.p['D']))
dsn.route(grid=r23f, mn=_mn, via_tag=[False, False])

# rst_out_internal
_mn = []
_mn.append(r23f.bottom_left(ip3.p['S']))
_mn.append(r23f.bottom_right(ip2.p['D']))
dsn.route(grid=r23f, mn=_mn, via_tag=[False, False])

# VSS
_mn = []
_mn.append(r12f.top_left(in1))
_mn.append(r12f.top_right(space3))
rvss0 = dsn.route(grid=r12f, mn=_mn)

# _mn = []
# _mn.append(r12f.bottom_left(ntap_top_left.p['TAP0']))
# _mn.append(r12f.top_left(ntap_top_left.p['TAP0']) + [0,1])
# dsn.route(grid=r12f, mn=_mn, via_tag=[False, True])

# _mn = []
# _mn.append(r12f.bottom_left(ntap_top_right.p['TAP0']))
# _mn.append(r12f.top_left(ntap_top_right.p['TAP0']) + [0,1])
# dsn.route(grid=r12f, mn=_mn, via_tag=[False, True])

# VDD
_mn = []
_mn.append(r12f.bottom_left(ip4))
_mn.append(r12f.bottom_right(ip2))
rvdd0 = dsn.route(grid=r12f, mn=_mn)
_mn = []
_mn.append(r12f.top_left(space0))
_mn.append(r12f.top_right(space2))
rvdd1 = dsn.route(grid=r12f, mn=_mn)
# _mn = []
# _mn.append(r12f.bottom_left(ptap_bot_left.p['TAP0']))
# _mn.append(r12f.top_left(ptap_mid_left.p['TAP0']))
# r = dsn.route(grid=r12f, mn=_mn, via_tag=[False, False])
# dsn.via(grid=r12f, mn=r12f.center(r))

# _mn = []
# _mn.append(r12f.bottom_left(ptap_bot_right.p['TAP0']))
# _mn.append(r12f.top_left(ptap_mid_right.p['TAP0']))
# r = dsn.route(grid=r12f, mn=_mn, via_tag=[False, False])
# dsn.via(grid=r12f, mn=r12f.center(r))


# 6. Create pins.
pvss0 = dsn.pin(name='VSS0',netname='VSS:', grid=r12f, mn=r12f.mn.bbox(rvss0))
pvdd0 = dsn.pin(name='VDD0',netname='VDD:', grid=r12f, mn=r12f.mn.bbox(rvdd0))
pvdd1 = dsn.pin(name='VDD1',netname='VDD:', grid=r12f, mn=r12f.mn.bbox(rvdd1))
pINP  = dsn.pin(name='INP', grid=r23f, mn=r23f.bbox(r0))
pINN  = dsn.pin(name='INN', grid=r23f, mn=r23f.bbox(r1))
pOUTP  = dsn.pin(name='OUTP', grid=r23f, mn=r23f.bbox(r2))
pOUTN  = dsn.pin(name='OUTN', grid=r23f, mn=r23f.bbox(r3[-1]))
pOUTPRE  = dsn.pin(name='OUT_PRE', grid=r23f, mn=r23f.bbox(r4))

# 7. Export to physical database.
print("Export design")
### EXPORT TO BAG
# SKILL script for load in Virtuoso
laygo2.interface.bag.export(lib, filename=ref_dir_BAG_exported+libname+'_'+cellname+'.il', cellname=None, scale=1e-3, reset_library=False, tech_library=tech.name)
# Filename example: ./laygo2_generators_private/scan/skill/scan_generated_scan_cell.il

# YAML script for generating new template library
nat_temp = dsn.export_to_template() # nat_temp = native template ??
laygo2.interface.yaml.export_template(nat_temp, filename=ref_dir_template+libname+'_templates.yaml', mode='append')
# Filename example: ./laygo2_generators_private/scan/scan_generated_templates.yaml 

# test jSON DB export
grid_table = dict()
grid_table['M1'] = r12
grid_table['M2'] = r23
grid_table['M3'] = r34
grid_table['M4'] = r34
exporter = laygo2.object.database.DesignExporter(dsn, grid_table, lib_ref = "laygo2_generators_private/prj_db/tbadc/library.yaml")
nat_dict = exporter.export_to_dict()
laygo2.interface.json.export_dict(nat_dict, filename=export_path_db+libname+'_db.json', mode='append')
