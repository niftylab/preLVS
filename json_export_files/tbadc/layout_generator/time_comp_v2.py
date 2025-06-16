##########################################################
#                                                      
# time_comp_v2 Layout Generator          
# Contributors: D. Lee, B. Lim, S. Lim, J. Han
# Last Updated: 2025-04-05
#                                                      
##########################################################
import laygo2
import laygo2_tech as tech
import laygo2.object.database
import laygo2.interface.json

export_path_db      = './laygo2_generators_private/prj_db/tbadc/' # Path for JSON DB export
# Parameter definitions #############
# Design Variables

# Design hierarchy
libname = 'tbadc_generated'
cellname = 'time_comp_v2'
export_path       = "./laygo2_generators_private/tbadc/" 
export_path_skill = export_path+'skill/' 
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
alch = tlib['time_comp_async_latch_v2'].generate(name='async_latch',
        netmap={'OUTP':'cmp_outp', 'OUTN':'cmp_outn', 'INP':'INP', 'INN':'INN', 'outp_pre':'cmp_outp_pre', 'outn_pre':'cmp_outn_pre',
                'outp_pre2':'cmp_outp_pre2', 'outn_pre2':'cmp_outn_pre2', 'VDD:':'VDD:', 'VSS:':'VSS:'})
buf = tlib['time_comp_buffer_v2'].generate(name='buffer',
        netmap={'CMP_OUTP':'cmp_outp', 'CMP_OUTN':'cmp_outn',
                'CMP_OUTPB':'cmp_outpb', 'CMP_OUTNB':'cmp_outnb', 'VDD:':'VDD:', 'VSS:':'VSS:'})
srlch = tlib['time_comp_sr_latch_v2'].generate(name='sr_latch',
        netmap={'INP':'cmp_outnb', 'INN':'cmp_outpb', 'pd':'pd', 'nd':'nd', 'VDD:':'VDD:', 'VSS:':'VSS:',
                'RST':'RST', 'RSTB':'RSTB', 'ES_PN':'ES_PN', 'ES_NP':'ES_NP', 'outp':'srp', 'outn':'srn'})
# Place instances.
dsn.place(inst=[alch, buf, srlch])

# Place wires.
#_trks = dsn.get_routing_tracks(grid=r23)[0]
rc = laygo2.RoutingMeshTemplate(grid=dsn.rgrid)
rc.add_trunk(name="rcmp_outp",  index=[None, alch.p['OUTP'].right.n+1],     netname="cmp_outp")
rc.add_trunk(name="rcmp_outn",  index=[None, alch.p['OUTN'].left.n-1],      netname="cmp_outn")
rc.add_trunk(name="rcmp_outpb", index=[None, buf.p['CMP_OUTPB'].right.n], netname="cmp_outpb")
rc.add_trunk(name="rcmp_outnb", index=[None, buf.p['CMP_OUTNB'].left.n],  netname="cmp_outnb")
rc.add_node(dsn.instances)  # Add all instances to the routing mesh as nodes
rinst = rc.generate()
dsn.place(inst=rinst)

# 6. Create pins.
pINP = dsn.pin(name='INP', mn=alch.p['INP'])
pINN = dsn.pin(name='INN', mn=alch.p['INN'])
pcmp_outp = dsn.pin(name='cmp_outp', mn=rinst.p['rcmp_outp'])
pcmp_outn = dsn.pin(name='cmp_outn', mn=rinst.p['rcmp_outn'])
pcmp_outpb = dsn.pin(name='cmp_outpb', mn=rinst.p['rcmp_outpb'])
pcmp_outnb = dsn.pin(name='cmp_outnb', mn=rinst.p['rcmp_outnb'])
pcmp_outp_pre = dsn.pin(name='cmp_outp_pre', mn=alch.p['outp_pre'])
pcmp_outn_pre = dsn.pin(name='cmp_outn_pre', mn=alch.p['outn_pre'])
pcmp_outp_pre2 = dsn.pin(name='cmp_outp_pre2', mn=alch.p['outp_pre2'])
pcmp_outn_pre2 = dsn.pin(name='cmp_outn_pre2', mn=alch.p['outn_pre2'])
pnd = dsn.pin(name='nd', mn=srlch.p['nd'])
ppd = dsn.pin(name='pd', mn=srlch.p['pd'])
#pvddg = dsn.pin(name='VDD:', mn=srlch.p['VDDG'])
#pvssg = dsn.pin(name='VSS:', mn=srlch.p['VSSG'])
prst = dsn.pin(name='RST', mn=srlch.p['RST'])
prstb = dsn.pin(name='RSTB', mn=srlch.p['RSTB'])
psr_outp = dsn.pin(name='srp', mn=srlch.p['outp'])
psr_outn = dsn.pin(name='srn', mn=srlch.p['outn'])
psr_es_pn = dsn.pin(name='ES_PN', mn=srlch.p['ES_PN'])
psr_es_np = dsn.pin(name='ES_NP', mn=srlch.p['ES_NP'])
tech.generate_pwr_rail(dsn, grids, netname=['VDD','VSS','VDD'], vertical=False)

# Export design
laygo2.export(dsn, tech=tech, filename=export_path_skill+libname+'_'+cellname+'.il')
laygo2.export_template(dsn, filename=f"{export_path}{libname}_templates.yaml", mode='append')

# lvs cell generation
# export_path_logic = "./laygo2_generators_private/logic/"
# tlib_logic = laygo2.import_template(filename=export_path_logic+'logic_generated_templates.yaml') 
# tap0 = tlib_logic['tap'].generate(name='tap0', transform='MX')
# tap1 = tlib_logic['tap'].generate(name='tap1')
# dsn.place(inst=[[tap0], [tap1]], mn=pg.bottom_right(srlch))
# dsn.cellname = dsn.cellname+'_lvs'
# laygo2.export(dsn, cellname=dsn.cellname, tech=tech, filename=export_path_skill+libname+'_'+cellname+'.il')

# test jSON DB export
grid_table = dict()
grid_table['M1'] = r12
grid_table['M2'] = r23
grid_table['M3'] = r23
exporter = laygo2.object.database.DesignExporter(dsn, grid_table, lib_ref = "laygo2_generators_private/prj_db/tbadc/library.yaml")
nat_dict = exporter.export_to_dict()
laygo2.interface.json.export_dict(nat_dict, filename=export_path_db+libname+'_db.json', mode='append')
