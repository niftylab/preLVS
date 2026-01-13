##########################################################
#                                                    
# Dummy Filler 2X Layout Gernerator             
# Contributors: Youjin Byun, J. Han
# Last Updated: 2025-04-25
#                                                    
##########################################################
import laygo2
import laygo2_tech as tech
import laygo2.object.database
import laygo2.interface.json

export_path_db      = './laygo2_generators_private/prj_db/tbadc/' # Path for JSON DB export

# Parameter definitions #############
# Design Variables
cellname = 'vtc_filler_dmy_2x'
# Design hierarchy
libname = 'tbadc_generated'
export_path = './laygo2_generators_private/tbadc/'
export_path_skill = export_path+'skill/'
# End of parameter definitions ######

# Generation start ##################
# Load templates and grids.
templates, grids = tech.load_templates_and_grids()
pg, r12 = grids['placement_basic'], grids['routing_12_cmos']

print('--------------------')
print(f'Creating {cellname}')
# Create a design, generate and place instances. 
dsn = laygo2.Design(name=cellname, libname=libname, pgrid=pg, rgrid=r12)
ndmy0 = templates['nmos4_fast_dmy_nf2'].generate(name='ndmy0')
pdmy0 = templates['pmos4_fast_dmy_nf2'].generate(name='pdmy0', transform='MX')
dsn.place(inst=[[ndmy0], [pdmy0]])
# Route wires
# VSS
_mn = [ndmy0.p['D0'].left, ndmy0.p['S0'].left, ndmy0.p['S1'].left]
_track = [None, ndmy0.bottom_right.n]
rvss0 = dsn.route_via_track(mn=_mn, track=_track)
# VDD
_mn = [pdmy0.p['D0'].left, pdmy0.p['S0'].left, pdmy0.p['S1'].left]
_track = [None, pdmy0.top_right.n]
rvdd0 = dsn.route_via_track(mn=_mn, track=_track)
# Create pins.
tech.generate_pwr_rail(dsn, grids, netname=['VSS', 'VDD'], vertical=False)

# Export design
# laygo2.export(dsn, tech=tech, filename=export_path_skill+libname+'_'+cellname+'.il')
laygo2.export_template(dsn, filename=f"{export_path}{libname}_templates.yaml", mode='append')

# test jSON DB export
grid_table = dict()
grid_table['M1'] = r12
grid_table['M2'] = r12
exporter = laygo2.object.database.DesignExporter(dsn, grid_table, lib_ref = "laygo2_generators_private/prj_db/tbadc/library.yaml")
nat_dict = exporter.export_to_dict()
laygo2.interface.json.export_dict(nat_dict, filename=export_path_db+libname+'_db.json', mode='append')