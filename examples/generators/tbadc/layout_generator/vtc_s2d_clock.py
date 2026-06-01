##########################################################
#                                                      
# Single to Differential Layout Generator          
# Contributors: T. Shin, S. Park, Y. Oh, T. Kang 
# Last Updated: 2024-10-17
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
cell_name = 'vtc_s2d_clock'

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

# Design hierarchy

libname = 'tbadc_generated'
# Layout generation path: "export_path/libenaem/cellname"
export_path       = "./laygo2_generators_private/tbadc/" 
# SKILL file generation path: "export_path_skill/libenaem_cellname.il"
export_path_skill = export_path+'skill/' 
# End of parameter definitions ######

# Generation start ##################
# 1. Load templates and grids.
print("Load templates")
templates = tech.load_templates()
tpmos, tnmos = templates[tpmos_name], templates[tnmos_name]
tntap, tptap = templates[tntap_name], templates[tptap_name] 
tlib = laygo2.interface.yaml.import_template(filename='./laygo2_generators_private/logic/logic_generated_templates.yaml')
tlib_adc = laygo2.interface.yaml.import_template(filename=export_path+'tbadc_generated_templates.yaml')

print("Load grids")
grids = tech.load_grids(templates=templates)
pg, r12, r23, r34, r45 = grids[pg_name], grids[r12_name], grids[r23_name], grids[r34_name], grids[r45_name]
# print(grids[pg_name], grids[r12_name], grids[r23_name], grids[r34_name], sep="\n")

#cellname = cell_name+'_8x_6x4x_6x'
cellname = cell_name
print('------------------')
print('Now Creating '+cellname)

# 2. Create a design hierarchy
lib = laygo2.Library(name=libname)
dsn = laygo2.Design(name=cellname, libname=libname)
lib.append(dsn)

# 3. Create instances.
print("Create instances")
inv0 = tlib['inv_'+str(8)+'x'].generate(name='inv0', transform='MX', netmap={"I": "CLK_SE", "O": "CLKB_SE"})
inv1 = tlib['inv_'+str(6)+'x'].generate(name='inv1', netmap={"I": "CLKB_SE", "O": "B"})
inv2 = tlib['inv_'+str(6)+'x'].generate(name='inv2', netmap={"I": "B", "O": "CLK_N"})
inv3 = tlib['inv_'+str(6)+'x'].generate(name='inv3', transform='MX', netmap={"I": "A", "O": "CLK_P"})
inv4 = tlib['inv_'+str(2)+'x'].generate(name='inv4', transform='R180', netmap={"I": "CLK_N", "O": "CLK_P"})
inv5 = tlib['inv_'+str(2)+'x'].generate(name='inv5', netmap={"I": "CLK_P", "O": "CLK_N"})
tgate0 = tlib['tgate_'+str(4)+'x'].generate(name='tgate0', transform='MX', netmap={"I": "CLKB_SE", "O": "A", "EN": "EN", "ENB": "ENB"})

# 4. Place instances.
dsn.place(grid=pg, inst=[[None, inv1, inv2, inv5], [inv0, tgate0, inv3, inv4]], mn=[0,0])

# 5. Create and place wires.
print("Create wires")
_mn = [r23(tgate0.p['EN'])[1, 0], r23.bottom(tgate0)[1]]
dsn.route(grid=r23, mn=[tgate0.p['EN'], _mn], via_tag=[False, True])
_mn = [r23(tgate0.p['ENB'])[1, 0], r23.top(tgate0)[1]]
dsn.route(grid=r23, mn=[tgate0.p['ENB'], _mn], via_tag=[False, True])

rc = laygo2.RoutingMeshTemplate(grid=r34)
_trk = r34.center(inv0.p['O'])[0]
rc.add_trunk(name="CLKB_SE", index=[_trk, None], netname="CLKB_SE")
_trk = r34.center(inv0)[1]
rc.add_trunk(name="A",  index=[None, _trk], netname="A")
rc.add_trunk(name="CLK_P",  index=[None, _trk], netname="CLK_P")
_trk = r34.center(inv1)[1]
rc.add_trunk(name="B",  index=[None, _trk], netname="B")
rc.add_trunk(name="CLK_N",  index=[None, _trk], netname="CLK_N")

rc.add_node(list(dsn.instances.values()))
rinst = rc.generate()
dsn.place(grid=pg, inst=rinst)

# 6. Create pins.
pclkse0 = dsn.pin(name='CLK_SE', grid=r23, mn=inv0.p['I'])
pa0 = dsn.pin(name='A', grid=r23, mn=inv3.p['I'])
pb0 = dsn.pin(name='B', grid=r23, mn=inv2.p['I'])
pclkp0 = dsn.pin(name='CLKP', grid=r23, mn=inv3.p['O'])
pclkn0 = dsn.pin(name='CLKN', grid=r23, mn=inv2.p['O'])

# tech.fill_by_instance(dsn, grids, tlib, tlib, "space_1x" , iter_type=("R0","MX"))
tech.fill_by_instance(dsn, grids, tlib_adc, tlib_adc, "vtc_filler_dmy_2x" , iter_type=("R0","MX"))
# tech.fill_by_instance(dsn, grids, templates, templates, inst_name=("nmos4_fast_dmy_nf2", "pmos4_fast_dmy_nf2") , iter_type=("R0","MX"))
tech.generate_pwr_rail(dsn, grids, netname=['VSS', 'VDD'], vertical=False)  

# 7. Export to physical database.
print("Export design")
print("")
# laygo2.export(lib, tech=tech, filename=export_path_skill+libname+'_'+cellname+'.il')
# Filename example: ./laygo2_generators_private/logic/skill/logic_tap.il
 
# 8. Export to a template database file.
nat_temp = dsn.export_to_template()
laygo2.export_template(nat_temp, filename=export_path+libname+'_templates.yaml', mode='append')
# Filename example: ./laygo2_generators_private/logic/logic_generated_templates.yaml

# test jSON DB export
grid_table = dict()
grid_table['M1'] = r12
grid_table['M2'] = r23
grid_table['M3'] = r34
grid_table['M4'] = r45
grid_table['M5'] = r45
exporter = laygo2.object.database.DesignExporter(dsn, grid_table, lib_ref = "laygo2_generators_private/prj_db/tbadc/library.yaml")
nat_dict = exporter.export_to_dict()
laygo2.interface.json.export_dict(nat_dict, filename=export_path_db+libname+'_db.json', mode='append')