#########################################################
#                                                        
# Time-domain ADC - Asynchronous Latch
# Contributors: J. Han 
# Last Updated:2025-04-05 
#                                                        
#########################################################
import laygo2
import laygo2_tech as tech
import laygo2.object.database
import laygo2.interface.json

# Parameter definitions #############
# Design Variables

# Design hierarchy
libname  = 'tbadc_generated'
cellname = 'time_comp_async_latch_v2'
export_path = './laygo2_generators_private/tbadc/' 
export_path_skill = export_path+'skill/' 
export_path_db      = './laygo2_generators_private/prj_db/tbadc/' # Path for JSON DB export
# End of parameter definitions ######

# Generation start ##################
# Load templates and grids.
templates, grids = tech.load_templates_and_grids()
tpmos, tnmos = templates['pmos'], templates['nmos']
pg, r23 = grids['placement_basic'], grids['routing_23_cmos']
r12 = grids['routing_12_cmos']
tlib = laygo2.interface.yaml.import_template(filename=export_path+'tbadc_generated_templates.yaml')

print('--------------------')
print(f'Creating {cellname}')
# Create a design, generate and place instances. 
dsn = laygo2.Design(name=cellname, libname=libname, pgrid=pg, rgrid=r23)
cmp0 = tlib['time_comp_async_latch_v2_half'].generate(name='cmp0', transform='MX',
    netmap={'INP':'INP', 'INN':'INN', 'OUTN':'OUTN', 'OUTP':'OUTP', 'outn_pre':'outn_pre', 'outn_pre2':'outn_pre2', 'VSS:':'VSS:', 'VDD:':'VDD:'})
cmp1 = tlib['time_comp_async_latch_v2_half'].generate(name='cmp1',
    netmap={'INP':'INN', 'INN':'INP', 'OUTN':'OUTP', 'OUTP':'OUTN', 'outn_pre':'outp_pre', 'outn_pre2':'outp_pre2', 'VSS:':'VSS:', 'VDD:':'VDD:'})
dsn.place(inst = [[cmp0], [cmp1]])

# Route wires
#_trks = dsn.get_routing_tracks(grid=r23)[0]
rc = laygo2.RoutingMeshTemplate(grid=dsn.rgrid)
rc.add_trunk(name="rINP",  index=[cmp0.p['INP'].left.m + 4, None],   netname="INP")
rc.add_trunk(name="rINN",  index=[cmp0.p['INP'].left.m + 2, None],   netname="INN")
rc.add_trunk(name="rOUTN", index=[cmp0.p['OUTN0'].left.m + 4, None], netname="OUTN")
rc.add_trunk(name="rOUTP", index=[cmp0.p['OUTN0'].left.m + 2, None], netname="OUTP")
rc.add_node(dsn.instances)  # Add all instances to the routing mesh as nodes
rc.add_constraint(name="in_wire_matching", type="matching", trunk=["rINP", "rINN"])
rc.add_constraint(name="out_wire_matching", type="matching", trunk=["rOUTP", "rOUTN"])
rinst = rc.generate()
dsn.place(grid=pg, inst=rinst)

# Create pins
pINP       = dsn.pin(name='INP',       mn=rinst.p['rINP'])
pINN       = dsn.pin(name='INN',       mn=rinst.p['rINN'])
pOUTP      = dsn.pin(name='OUTP',      mn=rinst.p['rOUTP'])
pOUTN      = dsn.pin(name='OUTN',      mn=rinst.p['rOUTN'])
pOUTP_PRE  = dsn.pin(name='outn_pre',  mn=cmp0.p['outn_pre'])
pOUTN_PRE  = dsn.pin(name='outp_pre',  mn=cmp1.p['outn_pre'])
pOUTP_PRE2 = dsn.pin(name='outn_pre2', mn=cmp0.p['outn_pre2'])
pOUTN_PRE2 = dsn.pin(name='outp_pre2', mn=cmp1.p['outn_pre2'])
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
