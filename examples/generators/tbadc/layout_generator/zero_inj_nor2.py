##########################################################
#                                                           
# NOR Layout Gernerator                 
# Contributors: T. Shin, S. Park, Y. Oh, T. Kang, J. Han 
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
nf = 6

# Design hierarchy
libname = 'tbadc_generated'
celltype_list = ['zero_inj_nor2_inp', 'zero_inj_nor2_inn']
export_path = './laygo2_generators_private/tbadc/' 
export_path_skill = export_path+'skill/' 
# End of parameter definitions ######

# Generation start ##################
# Load templates and grids.
templates, grids = tech.load_templates_and_grids()
tpmos, tnmos = templates['pmos'], templates['nmos']
pg, r12, r23 = grids['placement_basic'], grids['routing_12_cmos'], grids['routing_23_cmos']

for celltype in celltype_list:
    cellname = celltype+f'_{nf}x'
    print('--------------------')
    print(f'Creating {cellname}')
    
    # Create a design, generate and place instances. 
    dsn = laygo2.Design(name=cellname, libname=libname, pgrid=pg, rgrid=r23)
    in0  = tnmos.generate(name='MN0',                 params={'nf': nf, 'tie': 'S', 'rtrackswap': True},    netmap={'G':'B', 'D':'O', 'RAIL':'VSS:'})
    ip0  = tpmos.generate(name='MP0', transform='MX', params={'nf': nf, 'tie': 'S'},                        netmap={'G':'B', 'D':'net1', 'RAIL':'VDD:'})
    in1  = tnmos.generate(name='MN1',                 params={'nf': nf, 'tie': 'S', 'rtrackswap': True},    netmap={'G':'A', 'D':'O', 'RAIL':'VSS:'})
    ip1  = tpmos.generate(name='MP1', transform='MX', params={'nf': nf, 'rtrackswap': True},                netmap={'G':'A', 'D':'O', 'S':'net1', 'RAIL':'VDD:'})
    dsn.place(inst=[[in0, in1], [ip0, ip1]])
    
    # Create and place wires.
    # A
    if celltype.endswith('inp'):
        _track = [ip1.p['G'].left.m+1, None]
    else:
        _track = [ip1.p['G'].left.m+2, None]
    rA0 = dsn.route(mn=[in1.p['G'], ip1.p['G']], track=_track)[-1]

    # B
    _track = [ip0.p['G'].right.m, None]
    rB0 = dsn.route(mn=[in0.p['G'], ip0.p['G']], track=_track)[-1]
    
    # Internal
    dsn.route(grid=r12, mn=[ip0.p['D'], ip1.p['S']])
    dsn.route(grid=r12, mn=[in0.p['D'], in1.p['D']])
    
    # OUT
    _track = [ip1.p['D'].right.m, None]
    rout0 = dsn.route(mn=[in1.p['D'], ip1.p['D']], track=_track)[-1]
    
    # 6. Create pins.
    pinB  = dsn.pin(name='B', mn=rB0)
    pinA  = dsn.pin(name='A', mn=rA0)
    pout0 = dsn.pin(name='O', mn=rout0)
    tech.generate_pwr_rail(dsn, grids, netname=['VSS', 'VDD'], vertical=False)
    
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
    
