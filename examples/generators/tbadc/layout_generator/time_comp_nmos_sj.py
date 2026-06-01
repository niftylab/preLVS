##########################################################
#                                                    
# NMOS-SJ Layout Gernerator             
# Contributors: Youjin Byun, J. Han
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
cellname = 'time_comp_nmos_sj'
# Design hierarchy
libname = 'tbadc_generated'
export_path       = './laygo2_generators_private/tbadc/' 
export_path_skill = export_path+'skill/' 
# End of parameter definitions ######

# Generation start ##################
# Load templates and grids.
templates, grids = tech.load_templates_and_grids()
pg, r12, r23 = grids['placement_basic'], grids['routing_12_cmos'], grids['routing_23_cmos']

print('--------------------')
print(f'Creating {cellname}')
# Create a design, generate and place instances. 
dsn = laygo2.Design(name=cellname, libname=libname, pgrid=pg, rgrid=r23)
in0 = templates['nmos4_fast_center_nf2'].generate(name='in0')
dsn.place(inst=[in0])
# Route wires
dsn.via(grid=r12, mn=[in0.p['G0'].left])
dsn.via(mn=[in0.p['G0'].left])
# Create pins.
pS1 = dsn.pin(name='S1', mn=in0.p['S1'])
pD0 = dsn.pin(name='D0', mn=in0.p['D0'])
pS0 = dsn.pin(name='S0', mn=in0.p['S0'])
# Export design
# laygo2.export(dsn, tech=tech, filename=export_path_skill+libname+'_'+cellname+'.il')
laygo2.export_template(dsn, filename=f"{export_path}{libname}_templates.yaml", mode='append')

# test jSON DB export
grid_table = dict()
grid_table['M1'] = r12
grid_table['M2'] = r23
grid_table['M3'] = r23
exporter = laygo2.object.database.DesignExporter(dsn, grid_table, lib_ref = "laygo2_generators_private/prj_db/tbadc/library.yaml")
nat_dict = exporter.export_to_dict()
laygo2.interface.json.export_dict(nat_dict, filename=export_path_db+libname+'_db.json', mode='append')