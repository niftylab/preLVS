import numpy as np
import pprint
import laygo2
import laygo2.interface
import laygo2_tech as tech
import laygo2.object.database
import laygo2.interface.json
#import laygo2_tech_quick_start as tech_quick

# Design Variables
#cell_type = ['ncap_psw_']
cell_type = ['ncap_psw_gen']
nf_list = [2]

# Templates
tpmos_name = 'pmos'
tnmos_name = 'nmos'
tptap_name = 'ptap'
tntap_name = 'ntap'

# Grids
pg_name = 'placement_basic'
r12_name = 'routing_12_cmos'
r23_name = 'routing_23_cmos'
r34_name = 'routing_34_cmos'
r45_name = 'routing_45_cmos'

# Design hierarchy
libname = 'tbadc_generated'

# Set export_path
export_path = './laygo2_generators_private/tbadc/'
export_path_skill = export_path + 'skill/'
export_path_db      = './laygo2_generators_private/prj_db/tbadc/' # Path for JSON DB export

# 1. Load templates and grids.
print("Load templates")
templates = tech.load_templates()
tpmos, tnmos = templates[tpmos_name], templates[tnmos_name]
tntap, tptap = templates[tntap_name], templates[tptap_name]

print("Load grids")
grids = tech.load_grids(templates=templates)
pg, r12, r23, r34, r45 = grids[pg_name], grids[r12_name], grids[r23_name], grids[r34_name], grids[r45_name]

for celltype in cell_type:
	for nf in nf_list:
		# Set Cell name
		cellname = celltype
		#cellname = celltype+str(nf)+'x'

		print('-----------------------------')
		print('Now Creating ' + cellname)

		# 2. Create a design hierarchy
		lib = laygo2.object.database.Library(name=libname)
		dsn = laygo2.object.database.Design(name=cellname, libname=libname)
		lib.append(dsn)
      
		# 3. Create instances.
		print("Create instances")
 		# ip0 = switch, in0 = cap
		ip0 = tpmos.generate(name='MP0_core', transform='MX', params={'nf': nf, "trackswap": True})
		in0 = tnmos.generate(name='MN0_core', params={'nf': nf, 'tie': 'S'})

		# 4. Place instances.
		print("Create instances")
		dsn.place(grid=pg, inst=[[in0], [ip0]], mn=[0,0])
      
		# 5. Create and place wires.
		print("Create wires")
		
		# CPLUS
		_mn = [r23(ip0.p['D'])[0], r23(in0.p['G'])[0]]
		_track = [r23(ip0.p['D'])[1][0], None]
		rCP0 = dsn.route_via_track(grid=r23, mn=_mn, track=_track)
		
		# Rail
		tech.generate_pwr_rail(dsn,grids,netname=['VSS','VDD'],vertical=False)
		
		# in0 to VSS
		_targetmn = [r23(in0.p['D'])[0][0], r23(in0.p['RAIL'])[0][1]]
		_mn = [r23(in0.p['D'])[0], _targetmn]
		dsn.route(grid=r12,mn=_mn,via_tag=[False,True])

		# 6. Create pins.
		_bbox = r23.mn.bbox(ip0.p['G'])
		if _bbox[0][0] == _bbox[1][0] and _bbox[0][1] == _bbox[1][1]:
			_bbox[0][0] -= 1
			_bbox[1][0] += 1
		else:
			pass
		pEN0 = dsn.pin(name='EN', grid=r23, mn=_bbox)

		_bbox = r23.mn.bbox(ip0.p['S'])
		if _bbox[0][0] == _bbox[1][0] and _bbox[0][1] == _bbox[1][1]:
			_bbox[0][0] -= 1
			_bbox[1][0] += 1
		else:
			pass
		pIN0 = dsn.pin(name='IN', grid=r23, mn=_bbox)
		
		pCPLUS0 = dsn.pin(name='CPLUS', grid=r23, mn=rCP0[-1])

		# 7. Export to physical database.
		print("Export design")
		print("")
		laygo2.interface.bag.export(lib, filename = export_path_skill+libname+'_'+cellname+'.il', cellname=None, scale=1e-3, reset_library=False, tech_library=tech.name)
		nat_temp = dsn.export_to_template()
		laygo2.interface.yaml.export_template(nat_temp, filename=export_path+libname+'_templates.yaml', mode='append') 

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
