import numpy as np
import pprint
import laygo2
import laygo2.interface
import laygo2_tech as tech
import yaml
import laygo2.object.database
import laygo2.interface.json

export_path_db      = './laygo2_generators_private/prj_db/tbadc/' # Path for JSON DB export

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
r23m_name   = 'routing_23_mos'
r23f_name   = 'routing_23_cmos_flipped'
r34_name    = 'routing_34_cmos'
r34t_name   = 'routing_34_basic_thick'

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
#cellname = 'async_latch_'+str(nf_in)+'x_'+str(nf_rgnp)+'x'+str(nf_rgnn)+'x_'+str(nf_rst_out_bot)+'x'+str(nf_rst_out_top)+'x_'+str(nf_rst_pre_bot)+'x'+str(nf_rst_pre_top)+'x'
cellname = 'time_comp_async_latch'
ref_dir_template     = './laygo2_generators_private/tbadc/'       # Reference path for generated cell template yaml
ref_dir_BAG_exported = './laygo2_generators_private/tbadc/skill/' # Reference path for SKILL script
# End of parameter definitions ######

### GENERATION START
# 1. Load templates and grids.
print("Load templates")
templates = tech.load_templates()
tpmos, tnmos = templates[tpmos_name], templates[tnmos_name]
tptap, tntap = templates[tptap_name], templates[tntap_name]
tlib = laygo2.interface.yaml.import_template(filename='./laygo2_generators_private/tbadc/tbadc_generated_templates.yaml')
# Filename Example: ./laygo2_generators_private/scan/scan_generated_templates.yaml

print("Load grids")
grids = tech.load_grids(templates=templates)
#pg, r12, r12f, r23, r23f, r34, r34t = grids[pg_name], grids[r12_name], grids[r12f_name], grids[r23_name], grids[r23f_name], grids[r34_name], grids[r34t_name]
pg, r12cm, r12cmf, r23cm, r23cmf, r34, r34t = grids[pg_name], grids[r12_name], grids[r12f_name], grids[r23_name], grids[r23f_name], grids[r34_name], grids[r34t_name]
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
#cmp0 = tlib['async_latch_half_'+str(nf_in)+'x_'+str(nf_rgnp)+'x'+str(nf_rgnn)+'x_'+str(nf_rst_out_bot)+'x'+str(nf_rst_out_top)+'x_'+str(nf_rst_pre_bot)+'x'+str(nf_rst_pre_top)+'x'].generate(name='cmp0', transform='MY')
#cmp1 = tlib['async_latch_half_'+str(nf_in)+'x_'+str(nf_rgnp)+'x'+str(nf_rgnn)+'x_'+str(nf_rst_out_bot)+'x'+str(nf_rst_out_top)+'x_'+str(nf_rst_pre_bot)+'x'+str(nf_rst_pre_top)+'x'].generate(name='cmp1', transform='R180')
cmp0 = tlib['time_comp_async_latch_half'].generate(name='cmp0', transform='MY')
cmp1 = tlib['time_comp_async_latch_half'].generate(name='cmp1', transform='R180')
_nf_tap = pg.mn.width_vec(cmp0)[0] - 2
ipt0 = tptap.generate(name='PT0', params={'nf': _nf_tap})#, 'tie': 'TAP0'})

# 4. Place instances.
_width      = pg.mn.width_vec(cmp0)[0]-1
_height     = pg.mn.height_vec(cmp1)[1]
_height_tap = pg.mn.height_vec(ipt0)[1]
dsn.place(grid=pg, inst =   cmp0, mn=[_width,0])
dsn.place(grid=pg, inst =   ipt0, mn=[0,_height])
dsn.place(grid=pg, inst =   cmp1, mn=[_width, _height*2+_height_tap])
#dsn.place(grid=pg, inst=[[cmp0], [ipt0],[cmp1]], mn=[0,0])
#dsn.place(grid=pg, inst=ipt0, mn=[0,0]+pg.mn.height_vec(space0))

# 5. Create and place wires.
print("Create wires")

# INP
_mn = []
_n = int(4/3*r34.mn.height_vec(cmp0)[1])
_mn.append([r34.left(cmp1)[0], _n])
_mn.append([r34.right(cmp1.p['INP'])[0], _n])
rinp = dsn.route(grid=r34, mn=_mn, via_tag=[False, False])

_mn[0] = np.array(_mn[1]) + [2,0]
_mn[1] = r34.top(cmp1.p['INP']) + [2,0]
dsn.route(grid=r34, mn=_mn, via_tag=[True, False])
_mn[1] = _mn[0] - [2,0]
dsn.route(grid=r34, mn=_mn, via_tag=[False, False])

_mn = []
_mn.append(r23f.top(cmp1.p['INP']))
_mn.append(_mn[0]+[2,0])
dsn.route(grid=r23f, mn=_mn, via_tag=[False, True])
_mn[0] = _mn[1] - [0,2]
dsn.route(grid=r23f, mn=_mn, via_tag=[False, False])

_mn = []
_mn.append(r23f.top(cmp0.p['INN'])-[1,0])
_mn.append([_mn[0][0], r23f.center(rinp)[1]])
dsn.route(grid=r23f, mn=_mn, via_tag=[True, False])
_mn = [[r34.top(cmp0.p['INN'])[0]-1, r34.center(rinp)[1]]]
dsn.via(grid=r34, mn=_mn)

_mn = []
_mn.append(r23f.top(cmp0.p['INN'])-[2,0])
_mn.append([_mn[0][0], r23f.center(rinp)[1]])
dsn.route(grid=r23f, mn=_mn, via_tag=[True, False])
_mn = [[r34.top(cmp0.p['INN'])[0]-2, r34.center(rinp)[1]]]
dsn.via(grid=r34, mn=_mn)

# INN
_mn = []
_n = int(2/3*r34.mn.height_vec(cmp0)[1])
_mn.append([r34.left(cmp0)[0], _n])
_mn.append([r34.right(cmp0.p['INP'])[0], _n])
rinn, v0 = dsn.route(grid=r34, mn=_mn, via_tag=[False, True])

_mn[0] = np.array(_mn[1]) + [2,0]
_mn[1] = r34.bottom(cmp0.p['INP']) + [2,0]
dsn.route(grid=r34, mn=_mn, via_tag=[True, False])
_mn[1] = _mn[0] - [2,0]
dsn.route(grid=r34, mn=_mn, via_tag=[False, False])
_mn = []
_mn.append(r23f.bottom(cmp0.p['INP']))
_mn.append(_mn[0]+[2,0])
dsn.route(grid=r23f, mn=_mn, via_tag=[False, True])
_mn[0] = _mn[1] + [0,2]
dsn.route(grid=r23f, mn=_mn, via_tag=[False, False])

_mn = []
_mn.append(r23f.bottom(cmp1.p['INN'])+[1,0])
_mn.append([_mn[0][0], r23f.center(rinn)[1]])
dsn.route(grid=r23f, mn=_mn, via_tag=[True, False])
_mn = []
_mn.append(r23f.bottom(cmp1.p['INN'])+[2,0])
_mn.append([_mn[0][0], r23f.center(rinn)[1]])
dsn.route(grid=r23f, mn=_mn, via_tag=[True, False])

_mn = [_mn[0]-[2,0], _mn[0]]
dsn.route(grid=r23f, mn=_mn, via_tag=[False, False])

_mn = []
_mn.append([r34.bottom(cmp1.p['INN'])[0]+1, r34.center(rinn)[1]])
dsn.via(grid=r34, mn=_mn)

_mn = []
_mn.append([r34.bottom(cmp1.p['INN'])[0]+2, r34.center(rinn)[1]])
dsn.via(grid=r34, mn=_mn)



# OUTP
'''
_mn_list = []

# new
_n_ref   = int( 2/3 * r34.mn.height_vec(cmp0)[1] ) 
_mn_temp = [ r34.right(cmp0)[0], _n_ref ]
_mn_list.append(_mn_temp)
'''
# old
_mn = []
#_n = int( 2/3 * r34.mn.height_vec(cmp0)[1] )
_n = r34.mn.bottom(cmp0.p['OUTN'])[1] + 1
_mn.append([r34.left(cmp0.p['OUTP'])[0]-1, _n])
_mn.append([r34.bottom(cmp0.p['OUTN'])[0], _n])
routp, _vop1 = dsn.route(grid=r34, mn=_mn, via_tag=[False, True])
# _mn = [r34.center(cmp0.p['OUTN'])[0], _mn[0][1]]
# dsn.via(grid=r34, mn=_mn)

_mn = []
_mn.append( r23f.bottom(cmp1.p['OUTP'])-[1,0] )
_mn.append([_mn[0][0], r23f.center(routp)[1]])
dsn.route(grid=r23f, mn=_mn, via_tag=[True, False])

#_mn = []
#_mn.append() [r34.bottom(cmp1.p['OUTP'])[0]-1, r34.center(routp)[1]]]
_mn = [r34.bottom(cmp1.p['OUTP'])[0]-1, r34.center(routp)[1]]
dsn.via(grid=r34, mn=_mn)

# OUTN
_mn = []
_n = int(4/3*r34.mn.height_vec(cmp0)[1])
_mn.append([r34.left(cmp1.p['OUTP'])[0]-1, _n])
_mn.append([r34.bottom(cmp1.p['OUTN'])[0], _n])
routn = dsn.route(grid=r34, mn=_mn, via_tag=[False, False])
_mn = [r34.center(cmp1.p['OUTN'])[0], _mn[0][1]]
dsn.via(grid=r34, mn=_mn)

_mn = []
_mn.append(r23f.top(cmp0.p['OUTP'])+[1,0])
_mn.append([_mn[0][0], r23f.center(routn)[1]])
dsn.route(grid=r23f, mn=_mn, via_tag=[True, False])
_mn = [_mn[0]-[1,0], _mn[0]]
dsn.route(grid=r23f, mn=_mn, via_tag=[False, False])
_mn = []
_mn.append([r34.top(cmp0.p['OUTP'])[0]+1, r34.center(routn)[1]])
dsn.via(grid=r34, mn=_mn)

# # VSS
# _mn = []
# _mn.append(r12f.top_left(cmp0))
# _mn.append(r12f.top_right(cmp0))
# rvss0 = dsn.route(grid=r12f, mn=_mn)

# # VDD
# _mn = []
# _n = int(1/3*r12f.mn.height_vec(cmp0)[1])
# _mn.append([r12f.left(cmp0)[0], _n])
# _mn.append([r12f.right(cmp0)[0], _n])
# rvdd0 = dsn.route(grid=r12f, mn=_mn)

# _mn = []
# _n = int(5/3*r12f.mn.height_vec(cmp0)[1])
# _mn.append([r12f.left(cmp1)[0], _n])
# _mn.append([r12f.right(cmp1)[0], _n])
# rvdd1 = dsn.route(grid=r12f, mn=_mn)


# 6. Create pins.
pvss0 = dsn.pin(name='VSS0', grid=r12f, mn=r12f.mn.bbox(cmp0.p['VSS0']),netname='VSS:')
pvdd0 = dsn.pin(name='VDD0', grid=r12f, mn=r12f.mn.bbox(cmp0.p['VDD0']), netname='VDD:')
pvdd1 = dsn.pin(name='VDD1', grid=r12f, mn=r12f.mn.bbox(cmp0.p['VDD1']), netname='VDD:')
pvss1 = dsn.pin(name='VSS1', grid=r12f, mn=r12f.mn.bbox(cmp1.p['VSS0']),netname='VSS:')
pvdd2 = dsn.pin(name='VDD2', grid=r12f, mn=r12f.mn.bbox(cmp1.p['VDD0']), netname='VDD:')
pvdd3 = dsn.pin(name='VDD3', grid=r12f, mn=r12f.mn.bbox(cmp1.p['VDD1']), netname='VDD:')
pINP  = dsn.pin(name='INP', grid=r34, mn=[r34.left(rinp), r34.center(rinp)])
pINN  = dsn.pin(name='INN', grid=r34, mn=[r34.left(rinn), r34.center(rinn)])
pOUTP = dsn.pin(name='OUTP', grid=r34, mn=r34.bbox(routp))
pOUTN = dsn.pin(name='OUTN', grid=r34, mn=r34.bbox(routn))
pOUTP_PRE  = dsn.pin(name='OUTP_PRE', grid=r23, mn=r23.bbox( cmp0.p['OUT_PRE'] ))
pOUTN_PRE  = dsn.pin(name='OUTN_PRE', grid=r23, mn=r23.bbox( cmp1.p['OUT_PRE'] ))

# 7. Export to physical database.
print("Export design")
### EXPORT TO BAG
# SKILL script for load in Virtuoso
laygo2.interface.bag.export(lib, filename=ref_dir_BAG_exported+libname+'_'+cellname+'.il', cellname=None, scale=1e-3, reset_library=False, tech_library=tech.name)
# Filename example: ./laygo2_generators_private/scan/skill/scan_generated_scan_cell.il

# YAML script for generating new template library
nat_temp = dsn.export_to_template() 
laygo2.interface.yaml.export_template(nat_temp, filename=ref_dir_template+libname+'_templates.yaml', mode='append')
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
