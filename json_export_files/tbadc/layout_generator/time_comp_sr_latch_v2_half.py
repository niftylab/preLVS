##########################################################
#                                               
# sr_latch_high_half Layout Generator (v2)        
# Contributors: D. Lee, B. Lim, S. Lim, J. Han 
# Last Updated: 2025-04-17
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
cellname = 'time_comp_sr_latch_v2_half'
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
imbufn0 = tnmos.generate(name='IMBUFN0', params={'nf': 4, 'tie': 'S', 'nfdmyr': 2}, netmap={'D':'pd',   'G':'INP', 'RAIL':'VSS:'})
imfwdn0 = tnmos.generate(name='IMFWDN0', params={'nf': 6, 'tie': 'S'}, netmap={'D':'outn:', 'G':'INP', 'RAIL':'VSS:'})
imccpn0 = tnmos.generate(name='IMCCPN0', params={'nf': 2, 'tie': 'S'}, netmap={'D':'outn:', 'G':'outp:', 'RAIL':'VSS:'})
imrstn0 = tnmos.generate(name='IMRSTN0', params={'nf': 2, 'tie': 'S'}, netmap={'D':'outn:', 'G':'RST', 'RAIL':'VSS:'})
imbufp0 = tpmos.generate(name='IMBUFP0', params={'nf': 2, 'tie': 'S', 'nfdmyl': 2, 'nfdmyr': 2, 'rtrackswap':True}, netmap={'D':'pd', 'G':'INP', 'RAIL':'VDD:'}, transform='MX')
imfwdp0 = tpmos.generate(name='IMFWDP0', params={'nf': 6, 'tie': 'S'}, netmap={'D':'outn:', 'G':'nd', 'RAIL':'VDD:'}, transform='MX')
imccpp0 = tpmos.generate(name='IMCCPP0', params={'nf': 2, 'tie': 'S'}, netmap={'D':'outn:', 'G':'outp:', 'RAIL':'VDD:'}, transform='MX')     
imrstp0 = tpmos.generate(name='IMRSTP0', params={'nf': 2, 'tie': 'S'}, netmap={'D':'outn:', 'G':'RSTB', 'RAIL':'VDD:'}, transform='MX')     
dsn.place(inst=[[imbufn0, imfwdn0, imccpn0, imrstn0],
                [imbufp0, imfwdp0, imccpp0, imrstp0]], pattern='stripe_left')

# Route wires
#_trks = dsn.get_routing_tracks(grid=r23)[0]
rc = laygo2.RoutingMeshTemplate(grid=dsn.rgrid)
rc.add_trunk(name="rINP", index=[imbufn0.p['G'].left.m, None], netname="INP")
rc.add_trunk(name="rPD", index=[imbufn0.p['D'].right.m, None], netname="pd")
rc.add_trunk(name="rOUTN", index=[imfwdn0.p['D'].right.m, None], netname="outn")
rc.add_node(dsn.virtual_instances)  # Add all instances to the routing mesh as nodes
rinst = rc.generate()
dsn.place(inst=rinst)

# Create pins
pINP = dsn.pin(name='INP', mn=rinst.p['rINP'])
pPD = dsn.pin(name='pd', mn=imbufn0.p['D'])
pND = dsn.pin(name='nd', mn=imfwdp0.p['G'])
pOUTN0 = dsn.pin(name='outn0', mn=imccpn0.p['D'], netname='outn:')
pOUTP0 = dsn.pin(name='outp0', mn=imccpn0.p['G'], netname='outp:')
pOUTN1 = dsn.pin(name='outn1', mn=imccpp0.p['D'], netname='outn:')
pOUTP1 = dsn.pin(name='outp1', mn=imccpp0.p['G'], netname='outp:')
pRST = dsn.pin(name='RST', mn=imrstn0.p['G'])
pRSTB = dsn.pin(name='RSTB', mn=imrstp0.p['G'])
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