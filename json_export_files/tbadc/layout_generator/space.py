##########################################################
#                                                    
#                 Space Layout Gernerator            
#     Contributors: T. Shin, S. Park, Y. Oh, T. Kang, J.Han
#                 Last Update: 2022-05-27            
#                                                    
##########################################################
import laygo2
import laygo2_tech as tech
import laygo2.object.database
import laygo2.interface.json

# Parameter definitions #############
# Design Variables
cell_type = 'space'
nf_list = [2, 4, 8, 13, 17, 18, 31, 36, 49, 54, 67, 72, 85, 90, 103, 121]

# Templates
tpmos_name = 'pmos'
tnmos_name = 'nmos'

# Grids
pg_name = 'placement_basic'
r12_name = 'routing_12_cmos'
r23_name = 'routing_23_cmos'

# Design hierarchy
libname = 'tbadc_generated'
export_path       = './laygo2_generators_private/tbadc/' # Layout generation path: "export_path/libname/cellname"
export_path_skill = export_path+'skill/' # SKILL file generation path: "export_path_skill/libname_cellname.il"
export_path_db      = './laygo2_generators_private/prj_db/tbadc/' # Path for JSON DB export
# End of parameter definitions ######

# Generation start ##################
# Load templates and grids.
templates, grids = tech.load_templates_and_grids()
tpmos, tnmos = templates[tpmos_name], templates[tnmos_name]
pg, r12, r23 = grids[pg_name], grids[r12_name], grids[r23_name]

for nf in nf_list:
   cellname = cell_type+'_'+str(nf)+'x'
   print('--------------------')
   print('Now Creating '+cellname)

   # Create a design hierarchy
   dsn = laygo2.Design(name=cellname, libname=libname, pgrid=pg, rgrid=r12)
   
   # Create instances.
   nspace = templates['nmos4_fast_space_1x'].generate(name='nspace',                 shape=[nf, 1], netmap={'RAIL':'VSS:'})
   pspace = templates['pmos4_fast_space_1x'].generate(name='pspace', transform='MX', shape=[nf, 1], netmap={'RAIL':'VDD:'})
   
   # Place and route
   dsn.place(inst=[[nspace], [pspace]])
   # VSS
   rvss0 = dsn.route(mn=[nspace.bottom_left, nspace.bottom_right])
   # VDD
   rvdd0 = dsn.route(mn=[pspace.top_left, pspace.top_right])

   # Create pins.
   pvss0 = dsn.pin(name='VSS', mn=rvss0)
   pvdd0 = dsn.pin(name='VDD', mn=rvdd0)
   
   # Export to physical database.
   # laygo2.export(dsn, tech=tech, filename=export_path_skill+libname+'_'+cellname+'.il')
   laygo2.export_template(dsn, filename=export_path+libname+'_templates.yaml', mode='append')

   # test jSON DB export
   grid_table = dict()
   grid_table['M1'] = r12
   grid_table['M2'] = r23
   grid_table['M3'] = r23
   exporter = laygo2.object.database.DesignExporter(dsn, grid_table, lib_ref = "laygo2_generators_private/prj_db/tbadc/library.yaml")
   nat_dict = exporter.export_to_dict()
   laygo2.interface.json.export_dict(nat_dict, filename=export_path_db+libname+'_db.json', mode='append')
