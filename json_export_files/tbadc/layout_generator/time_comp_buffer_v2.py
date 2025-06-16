#########################################################
#                                                        
# Time-domain ADC - Buffer
# Contributors: Jaeduk Han 
# Last Updated: 2025-04-25
#                                                        
#########################################################
import laygo2
import laygo2_tech as tech
import laygo2.object.database
import laygo2.interface.json

export_path_db      = './laygo2_generators_private/prj_db/tbadc/' # Path for JSON DB export

# Parameter definitions #############
# Design Variables
libname = 'tbadc_generated'
cellname = 'time_comp_buffer_v2'
p_nf = 4
n_nf = 2
tap_nf = 9
export_path = './laygo2_generators_private/tbadc/' 
export_path_skill = export_path+'skill/' 
# End of parameter definitions ######

# Generation start ##################
# Load templates and grids.
templates, grids = tech.load_templates_and_grids()
tpmos, tnmos = templates['pmos'], templates['nmos']
pg, r23 = grids['placement_basic'], grids['routing_23_cmos']
r12 = grids['routing_12_cmos']

print('--------------------')
print(f'Creating {cellname}')
# Create a design, generate and place instances. 
dsn = laygo2.Design(name=cellname, libname=libname, pgrid=pg, rgrid=r23)
# core devices 
in0 = tnmos.generate(name='IMN0', transform='MX', params={'nf': n_nf, 'tie': 'S', 'nfdmyl': 2, 'nfdmyr': 4, 'bndl':False, 'bndr':False},
                     netmap={'D':'CMP_OUTNB', 'G':'CMP_OUTN', 'RAIL':'VSS:'})  
ip0 = tpmos.generate(name='IMP0',                 params={'nf': p_nf, 'tie': 'S', 'nfdmyl': 2, 'nfdmyr': 2, 'bndl':False, 'bndr':False},
                     netmap={'D':'CMP_OUTNB', 'G':'CMP_OUTN', 'RAIL':'VDD:'})
in1 = tnmos.generate(name='IMN1',                 params={'nf': n_nf, 'tie': 'S', 'nfdmyl': 2, 'nfdmyr': 4, 'bndl':False, 'bndr':False},              
                     netmap={'D':'CMP_OUTPB', 'G':'CMP_OUTP', 'RAIL':'VSS:'})
ip1 = tpmos.generate(name='IMP1', transform='MX', params={'nf': p_nf, 'tie': 'S', 'nfdmyl': 2, 'nfdmyr': 2, 'bndl':False, 'bndr':False},
                     netmap={'D':'CMP_OUTPB', 'G':'CMP_OUTP', 'RAIL':'VDD:'})
dsn.place(inst=[[ip0],[in0],[in1],[ip1]])

# Route wires
#_trks = dsn.get_routing_tracks(grid=r23)[0]
rc = laygo2.RoutingMeshTemplate(grid=dsn.rgrid)
rc.add_trunk(name="rCMP_OUTP", index=[ip0.p['G'].left.m, None], netname="CMP_OUTP")
rc.add_trunk(name="rCMP_OUTN", index=[ip1.p['G'].left.m, None], netname="CMP_OUTN")
rc.add_trunk(name="rCMP_OUTPB", index=[ip0.p['D'].right.m, None], netname="CMP_OUTPB")
rc.add_trunk(name="rCMP_OUTNB", index=[ip1.p['D'].right.m, None], netname="CMP_OUTNB")
rc.add_node(dsn.virtual_instances)
rinst = rc.generate()
dsn.place(inst=rinst)

# Create pins.
pCMP_OUTP  = dsn.pin(name='CMP_OUTP', mn=rinst.p['rCMP_OUTP'])
pCMP_OUTN  = dsn.pin(name='CMP_OUTN', mn=rinst.p['rCMP_OUTN'])
pCMP_OUTPB = dsn.pin(name='CMP_OUTPB', mn=rinst.p['rCMP_OUTPB'])
pCMP_OUTNB = dsn.pin(name='CMP_OUTNB', mn=rinst.p['rCMP_OUTNB'])
tech.generate_pwr_rail(dsn, grids, netname=['VDD','VSS','VDD'], vertical=False)

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