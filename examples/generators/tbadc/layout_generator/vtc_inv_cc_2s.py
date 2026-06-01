#########################################################
#
# Inverter for vtc                                                                   
# Contributors: H. Jeong     
# Last Updated: 2024-10-24              
#                                                        
#########################################################
import laygo2
import laygo2_tech as tech
import numpy as np
import laygo2.object.database
import laygo2.interface.json

export_path_db      = './laygo2_generators_private/prj_db/tbadc/' # Path for JSON DB export

# Parameter definitions #############
# Design Variables
nf_list = [4]
# Design hierarchy
libname = 'tbadc_generated'
export_path       = './laygo2_generators_private/tbadc/' 
export_path_skill = export_path+'skill/' 
# End of parameter definitions ######

# Load templates and grids.
templates, grids = tech.load_templates_and_grids()
tpmos, tnmos = templates['pmos'], templates['nmos']
pg, r23 = grids['placement_basic'], grids['routing_23_cmos']
r12 = grids['routing_12_cmos']
logic_lib = laygo2.import_template(filename='./laygo2_generators_private/logic/logic_generated_templates.yaml')

for nf in nf_list:
    cellname = f'vtc_inv_cc_2s_{nf}x'
    print('--------------------')
    print(f'Creating {cellname}')
    # Create a design, generate and place instances. 
    dsn = laygo2.Design(name=cellname, libname=libname, pgrid=pg, rgrid=r23)
    inv0 = logic_lib[f'inv_{nf}x'].generate(name='inv0', transform='MY', netmap={'I':'IN0','O':'IN1'})
    inv1 = logic_lib[f'inv_{nf}x'].generate(name='inv1', transform='MX', netmap={'I':'IN1','O':'IN0'})
    dsn.place(inst=[[inv0], [inv1]])
               
    # Create and place wires.
    #_trks = dsn.get_routing_tracks(grid=r23)[0]
    rc = laygo2.RoutingMeshTemplate(grid=dsn.rgrid)
    rc.add_trunk(name="rin0_0", index=[None, inv0.p['I'].top.n], netname="IN0")
    rc.add_trunk(name="rin0_1", index=[None, inv0.p['I'].bottom.n], netname="IN0")
    rc.add_trunk(name="rin0_2", index=[None, inv1.p['O'].top.n], netname="IN0")
    rc.add_trunk(name="rin0_3", index=[None, inv1.p['O'].bottom.n], netname="IN0")
    rc.add_trunk(name="rin1_0", index=[None, inv1.p['I'].top.n], netname="IN1")
    rc.add_trunk(name="rin1_1", index=[None, inv1.p['I'].bottom.n], netname="IN1")
    rc.add_trunk(name="rin1_2", index=[None, inv0.p['O'].top.n], netname="IN1")
    rc.add_trunk(name="rin1_3", index=[None, inv0.p['O'].bottom.n], netname="IN1")
    rc.add_node(dsn.instances)
    rinst = rc.generate()
    dsn.place(inst=rinst)

    # Rails
    tech.generate_pwr_rail(dsn, grids, netname=['VSS', 'VDD'], vertical=False)
    
    # Create pins.
    pin0_0 = dsn.pin(name='IN0_0', netname='IN0:', mn=r23(inv0.p['I']))
    pin0_1 = dsn.pin(name='IN0_1', netname='IN0:', mn=r23(inv0.p['I'])-np.array([[1,0],[1,0]]))
    pin1_0 = dsn.pin(name='IN1_0', netname='IN1:', mn=r23(inv1.p['I']))
    pin1_1 = dsn.pin(name='IN1_1', netname='IN1:', mn=r23(inv1.p['I'])+np.array([[1,0],[1,0]]))
     
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