#########################################################
#                                                                   
# Inverter - RDMY generator for VTC
# Contributors: H. Jeong, J. Han 
# Last Updated: 2025-04-17
#                                                        
#########################################################
import laygo2
import laygo2_tech as tech
import laygo2.object.database
import laygo2.interface.json

export_path_db      = './laygo2_generators_private/prj_db/tbadc/' # Path for JSON DB export

# Parameter definitions #############
# Design Variables
celltype = 'vtc_inv_rdmy_space'
nf_list = [4]
# Design hierarchy
libname = 'tbadc_generated'
export_path = './laygo2_generators_private/tbadc/' 
export_path_skill = export_path+'skill/' 
# End of parameter definitions ######

# Generation start ##################
# Load templates and grids.
templates, grids = tech.load_templates_and_grids()
tpmos, tnmos = templates['pmos'], templates['nmos']
tlib = laygo2.import_template(filename=export_path+'tbadc_generated_templates.yaml')
pg, r23 = grids['placement_basic'], grids['routing_23_cmos']
r12 = grids['routing_12_cmos']

for nf in nf_list:
    cellname = celltype+f'_{nf}x'
    print('--------------------')
    print(f'Creating {cellname}')
    # Create a design, generate and place instances. 
    dsn = laygo2.Design(name=cellname, libname=libname, pgrid=pg, rgrid=r23)
    # core devices 
    in0  = tnmos.generate(name='MN0',                 params={'nf': nf, 'tie': 'S' , 'bndr' : False, 'bndl' : False, 'nfdmyr' : 2})
    ip0  = tpmos.generate(name='MP0', transform='MX', params={'nf': nf, 'tie': 'S' , 'bndr' : False, 'bndl' : False, 'nfdmyr' : 2})
    space0 = tlib['space_2x'].generate(name='space0')
    dsn.place(inst=[[in0], [ip0]])
    dsn.place(inst=space0, mn=-pg.mn.width_vec(space0))
            
    # 5. Create and place wires.
    print("Create wires")
    # IN
    _track = [in0.p['G'].left.m, None]
    rin0 = dsn.route(mn=[in0.p['G'], ip0.p['G']], track=_track)
    rin0 = rin0[-1] # the last element corresponds to the trunk wire
    
    # OUT
    _mn = [in0.p['D'].right, ip0.p['D'].right]
    _, rout0, _ = dsn.route(mn=_mn, via_tag=[True, True])
            
    # Rails
    tech.generate_pwr_rail(dsn, grids, netname=['VSS', 'VDD'], vertical=False)
    
    # 6. Create pins.
    pin0 = dsn.pin(name='I', mn=rin0)        
    pout0 = dsn.pin(name='O', mn=rout0)
    
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
