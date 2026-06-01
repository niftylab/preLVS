##########################################################
#                                                      
# sr_latch_high_half Layout Generator          
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
cellname = 'time_comp_sr_latch_v2'
export_path = './laygo2_generators_private/tbadc/' 
export_path_skill = export_path+'skill/' 
# End of parameter definitions ######

# Generation start ##################
# Load templates and grids.
templates, grids = tech.load_templates_and_grids()
tpmos, tnmos = templates['pmos'], templates['nmos']
pg, r12, r23 = grids['placement_basic'], grids['routing_12_cmos'], grids['routing_23_cmos']
tlib = laygo2.interface.yaml.import_template(filename=export_path+'tbadc_generated_templates.yaml')

print('--------------------')
print(f'Creating {cellname}')
# Create a design, generate and place instances. 
dsn = laygo2.Design(name=cellname, libname=libname, pgrid=pg, rgrid=r23)
isr0 = tlib['time_comp_sr_latch_v2_half'].generate(name='ISR0', transform='MX',
         netmap={'INP':'INP', 'INN':'INN', 'pd':'pd', 'nd':'nd', 'outn:':'outn', 'outp:':'outp', 'RST':'RST', 'RSTB':'VDD:', 'VDD:':'VDD:', 'VSS:':'VSS:'})
isr1 = tlib['time_comp_sr_latch_v2_half'].generate(name='ISR1',
         netmap={'INP':'INN', 'INN':'INP', 'pd':'nd', 'nd':'pd', 'outn:':'outp', 'outp:':'outn', 'RST':'VSS:', 'RSTB':'RSTB', 'VDD:':'VDD:', 'VSS:':'VSS:'})
iinv0 = tlib['time_comp_inv_4x'].generate(name='IINV0', transform='MX', netmap={'I':'outn', 'O':'ES_PN', 'VDD:':'VDD:', 'VSS:':'VSS:'})
iinv1 = tlib['time_comp_inv_4x'].generate(name='IINV1', netmap={'I':'outp', 'O':'ES_NP', 'VDD:':'VDD:', 'VSS:':'VSS:'})

# Place instances.
dsn.place(inst = [[isr0, iinv0], [isr1, iinv1]])

# Route wires
#_trks = dsn.get_routing_tracks(grid=r23)[0]
rc = laygo2.RoutingMeshTemplate(grid=dsn.rgrid)
rc.add_trunk(name="rPD", index=[isr0.p['pd'].right.m+3, None], netname="pd")
rc.add_trunk(name="rND", index=[isr0.p['pd'].right.m+4, None], netname="nd")
rc.add_trunk(name="rOUTP", index=[isr0.p['outn0'].left.m-1, None], netname="outp")
rc.add_trunk(name="rOUTN", index=[isr0.p['outn0'].left.m+1, None], netname="outn")
rc.add_node(dsn.instances)  # Add all instances to the routing mesh as node
rinst = rc.generate()
dsn.place(inst=rinst)
dsn.route(mn=[rinst.p['rOUTN'], iinv0.p['I']], track=[None, rinst.p['rOUTN'].bottom.n])
dsn.route(mn=[rinst.p['rOUTP'], iinv1.p['I']], track=[None, rinst.p['rOUTP'].top.n])

# dummy gate to VDD/VSS routes
_mn = r23(isr0.p['RSTB'])[0] - [1, 0]
_mn[1] = r23(isr0)[0, 1]
dsn.route(mn=[r23(isr0.p['RSTB'])[0], _mn], track=[_mn[0], None], via_tag=[False, True])
_mn = r23(isr1.p['RST'])[0] - [1, 0]
_mn[1] = r23(isr1)[0, 1]
dsn.route(mn=[r23(isr1.p['RST'])[0], _mn], track=[_mn[0], None], via_tag=[False, True])

# Create pins
pINP = dsn.pin(name='INP', mn=isr0.p['INP'])
pINN = dsn.pin(name='INN', mn=isr1.p['INP'])
pPD = dsn.pin(name='pd', mn=rinst.p['rPD'])
pND = dsn.pin(name='nd', mn=rinst.p['rND'])
pOUTP = dsn.pin(name='outp', mn=rinst.p['rOUTP'])
pOUTN = dsn.pin(name='outn', mn=rinst.p['rOUTN'])
pRST = dsn.pin(name='RST', mn=isr0.p['RST'])
#pVDD0 = dsn.pin(name='VDDG', mn=isr0.p['RSTB'], netname='VDD:')
#pVSS0 = dsn.pin(name='VSSG', mn=isr1.p['RST'], netname='VSS:')
pRSTB = dsn.pin(name='RSTB', mn=isr1.p['RSTB'])
pES_PN = dsn.pin(name='ES_PN', mn=iinv0.p['O'])
pES_NP = dsn.pin(name='ES_NP', mn=iinv1.p['O'])
tech.generate_pwr_rail(dsn, grids, netname=['VDD','VSS'], vertical=False)

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
