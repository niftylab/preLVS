#########################################################
#                                                       
# VTC inverter generator            
# Contributors: H. Jeong, J. Han     
# Last Updated: 2025-05-02
#                                                        
#########################################################
import laygo2
import laygo2_tech as tech
import laygo2.object.database
import laygo2.interface.json

export_path_db      = './laygo2_generators_private/prj_db/tbadc/' # Path for JSON DB export

# Parameter definitions #############
# Design Variables
cellname = 'vtc_inv_24x_2s'
# Design hierarchy
libname = 'tbadc_generated'
export_path       = './laygo2_generators_private/tbadc/' 
export_path_skill = export_path+'skill/' 
# End of parameter definitions ######

# Generation start ##################
# Load templates and grids.
templates, grids = tech.load_templates_and_grids()
tpmos, tnmos = templates['pmos'], templates['nmos']
pg, r23 = grids['placement_basic'], grids['routing_23_cmos']
r12 = grids['routing_12_cmos']
logic_lib = laygo2.import_template(filename='./laygo2_generators_private/logic/logic_generated_templates.yaml')

print('--------------------')
print(f'Creating {cellname}')
# Create a design, generate and place instances. 
dsn = laygo2.Design(name=cellname, libname=libname, pgrid=pg, rgrid=r23)
inv_12x_0  = logic_lib['inv_12x'].generate(name='inv_12x_0', netmap={'I':'I', 'O':'O'})
inv_12x_1  = logic_lib['inv_12x'].generate(name='inv_12x_1', transform='MX', netmap={'I':'I', 'O':'O'})
dsn.place(inst=[[inv_12x_0], [inv_12x_1]])
               
# Create and place wires.
#_trks = dsn.get_routing_tracks(grid=r23)[0]
rc = laygo2.RoutingMeshTemplate(grid=dsn.rgrid)
rc.add_trunk(name="rin0", index=[inv_12x_0.p['I'].left.m, None], netname="I")
rc.add_trunk(name="rout0", index=[inv_12x_0.p['O'].right.m, None], netname="O")
rc.add_node(dsn.instances)
rinst = rc.generate()
dsn.place(inst=rinst)
# Rails
tech.generate_pwr_rail(dsn, grids, netname=['VSS', 'VDD'], vertical=False)

# Create pins.
pin0 = dsn.pin(name='I', mn=rinst.p['rin0'])
pout0 = dsn.pin(name='O', mn=rinst.p['rout0'])

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