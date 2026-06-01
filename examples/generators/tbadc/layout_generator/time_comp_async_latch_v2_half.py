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

# Parameter definitions ##############
# Design parameters
nf_in = 8
nf_rgnn = 6
nf_rgnp = 4
nf_rst = 2

# Design hierarchy
libname  = 'tbadc_generated'
cellname = 'time_comp_async_latch_v2_half' 
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

print('--------------------')
print(f'Creating {cellname}')
# Create a design, generate and place instances. 
dsn = laygo2.Design(name=cellname, libname=libname, pgrid=pg, rgrid=r23)
imin0  = tnmos.generate(name='IMIN0',  params={'nf': nf_in, 'tie': 'S'}, netmap={'D':'outn_pre','G':'INP','S':'VSS', 'RAIL':'VSS:'})
imrgn0 = tnmos.generate(name='IMRGN0', params={'nf': nf_rgnn, 'trackswap': True}, netmap={'D':'OUTN','G':'OUTP','S':'outn_pre', 'RAIL':'VSS:'})
imrgp0 = tpmos.generate(name='IMRGP0', params={'nf': nf_rgnp, 'trackswap': True, 'tie': 'S'}, transform='MX', netmap={'D':'OUTN','G':'OUTP','S':'VDD', 'RAIL':'VDD:'})
imrsp0 = tpmos.generate(name='IMRSP0', params={'nf': nf_rst, 'tie': 'S'}, transform='MX', netmap={'D':'outn_pre2','G':'INN','S':'VDD', 'RAIL':'VDD:'})
imrsp2 = tpmos.generate(name='IMRSP2', params={'nf': nf_rst, 'trackswap': True}, transform='MX', netmap={'D':'OUTN','G':'INP','S':'outn_pre2', 'RAIL':'VDD:'})
imrsp4 = tpmos.generate(name='IMRSP4', params={'nf': nf_rst, 'trackswap': True}, transform='MX', netmap={'D':'outn_pre','G':'INP','S':'outn_pre2', 'RAIL':'VDD:'})
dsn.place(inst=[[imin0, imrgn0, None, None], [imrsp4, imrsp0, imrsp2, imrgp0]], pattern='stripe_left')

# Create and place wires.
#_trks = dsn.get_routing_tracks(grid=r23)[0]
rc = laygo2.RoutingMeshTemplate(grid=dsn.rgrid)
rc.add_trunk(name="routn_pre", index=[r23(imrsp4.p['G'])[0, 0] - 1, None], netname="outn_pre")
rc.add_trunk(name="rINP", index=[None, r23(imin0.p['G'])[0, 1]], netname="INP", dedicated=[imin0, imrsp2, imrsp4])
rc.add_trunk(name="rOUTN0", index=[None, r23(imrgp0.p['D'])[0, 1]], netname="OUTN", dedicated=[imrgp0, imrsp2])
rc.add_trunk(name="routn_pre2", index=[None, r23(imrsp2.p['S'])[0, 1]], netname="outn_pre2") #, dedicated=[imrgp0, imrsp2])
rc.add_node(dsn.virtual_instances)  # Add all instances to the routing mesh as nodes
rinst = rc.generate()
dsn.place(inst=rinst)

# 6. Create pins.
pINP     = dsn.pin(name='INP',       mn=imin0.p['G'])
pINN     = dsn.pin(name='INN',       mn=imrsp0.p['G'])
pOUTN0   = dsn.pin(name='OUTN0',     mn=imrgn0.p['D'], netname='OUTN')
pOUTN1   = dsn.pin(name='OUTN1',     mn=imrgp0.p['D'], netname='OUTN')
pOUTP0   = dsn.pin(name='OUTP0',     mn=imrgn0.p['G'], netname='OUTP')
pOUTP1   = dsn.pin(name='OUTP1',     mn=imrgp0.p['G'], netname='OUTP')
pOUTPRE  = dsn.pin(name='outn_pre',  mn=imin0.p['D'])
pOUTPRE2 = dsn.pin(name='outn_pre2', mn=imrsp4.p['S'])
tech.generate_pwr_rail(dsn, grids, netname=['VSS','VDD'], vertical=False)

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
