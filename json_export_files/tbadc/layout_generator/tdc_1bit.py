##########################################################
#                                                      
# tdc_1bit Layout Generator          
# Contributors: J. Han
# Last Updated: 2025-04-30
#                                                      
##########################################################
import laygo2
import laygo2_tech as tech
import laygo2.object.database
import laygo2.interface.json

# Parameter definitions #############
# Design Variables

# Templates
tpmos_name = 'pmos'
tnmos_name = 'nmos'

# Grids
pg_name = 'placement_basic'
r12_name = 'routing_12_cmos'
r23_name = 'routing_23_cmos'
r34_name = 'routing_34_cmos'

# Design hierarchy
libname = 'tbadc_generated'
cellname = 'tdc_1bit'
export_path = './laygo2_generators_private/tbadc/' 
export_path_skill = export_path+'skill/' 
export_path_logic = "./laygo2_generators_private/logic/"
export_path_db      = './laygo2_generators_private/prj_db/tbadc/' # Path for JSON DB export
# End of parameter definitions ######

# Generation start ##################
# 1. Load templates and grids.
print("Load templates")
templates, grids = tech.load_templates_and_grids()
tlib = laygo2.import_template(filename=export_path + 'tbadc_generated_templates.yaml')
tlib_logic = laygo2.import_template(filename=export_path_logic+'logic_generated_templates.yaml') 
pg, r23, r34 = grids['placement_basic'], grids['routing_23_cmos'], grids['routing_34_cmos']
r12 = grids['routing_12_cmos']

print('--------------------')
print(f'Creating {cellname}')
# Create a design, generate and place instances. 
dsn = laygo2.Design(name=cellname, libname=libname, pgrid=pg, rgrid=r23)
IZINJ0 = tlib['zero_inj'].generate(name='IZINJ0', netmap={'INP':'INP', 'INN':'INN', 'ORP':'dp', 'ORN':'dn', 'CLKREF':'CLKREF', 'SHORT':'SHORT', 
                                                          'norp':'izinj0_norp', 'norn':'izinj0_norn', 'VDD:':'VDD:', 'VSS:':'VSS:'})
ITCOMP0 = tlib['time_comp_v2'].generate(name='ITCOMP0', netmap={'INP':'INP', 'INN':'INN', 'ES_PN':'es_pn', 'ES_NP':'es_np', 'RST':'RST', 'RSTB':'RSTB',
                                                                'cmp_outp_pre':'itcomp0_cmp_outp_pre', 'cmp_outn_pre':'itcomp0_cmp_outn_pre',
                                                                'cmp_outp_pre2':'itcomp0_cmp_outp_pre2', 'cmp_outn_pre2':'itcomp0_cmp_outn_pre2',
                                                                'cmp_outp':'itcomp0_cmp_outp', 'cmp_outn':'itcomp0_cmp_outn',
                                                                'cmp_outpb':'itcomp0_cmp_outpb', 'cmp_outnb':'itcomp0_cmp_outnb',
                                                                'srn':'itcomp0_srn', 'srp':'itcomp0_srp', 'pd':'itcomp0_pd', 'nd':'itcomp0_nd',
                                                                'VDD:':'VDD:', 'VSS:':'VSS:'})
IDCDL0 = tlib['tdc_dcdl'].generate(name='IDCDL0', netmap={'DP':'dp', 'DN':'dn', 'DP_PN':'dp_pn', 'DP_NP':'dp_np', 'DN_PN':'dn_pn', 'DN_NP':'dn_np',
                                                          'C_POS<0>':'C_POS<0>', 'C_POS<1>':'C_POS<1>', 'C_POS<2>':'C_POS<2>', 'C_POS<3>':'C_POS<3>', 'C_POS<4>':'C_POS<4>',
                                                          'C_NEG<0>':'C_NEG<0>', 'C_NEG<1>':'C_NEG<1>', 'C_NEG<2>':'C_NEG<2>', 'C_NEG<3>':'C_NEG<3>', 'C_NEG<4>':'C_NEG<4>',
                                                          'dp_pre':'idcdl0_dp_pre', 'dn_pre':'idcdl0_dn_pre',
                                                          'intp_np<0>':'idcdl0_intp_np<0>', 'intp_np<1>':'idcdl0_intp_np<1>', 'intp_np<2>':'idcdl0_intp_np<2>', 'intp_np<3>':'idcdl0_intp_np<3>', 'intp_np<4>':'idcdl0_intp_np<4>',
                                                          'intp_pn<0>':'idcdl0_intp_pn<0>', 'intp_pn<1>':'idcdl0_intp_pn<1>', 'intp_pn<2>':'idcdl0_intp_pn<2>', 'intp_pn<3>':'idcdl0_intp_pn<3>', 'intp_pn<4>':'idcdl0_intp_pn<4>',
                                                          'intn_np<0>':'idcdl0_intn_np<0>', 'intn_np<1>':'idcdl0_intn_np<1>', 'intn_np<2>':'idcdl0_intn_np<2>', 'intn_np<3>':'idcdl0_intn_np<3>', 'intn_np<4>':'idcdl0_intn_np<4>',
                                                          'intn_pn<0>':'idcdl0_intn_pn<0>', 'intn_pn<1>':'idcdl0_intn_pn<1>', 'intn_pn<2>':'idcdl0_intn_pn<2>', 'intn_pn<3>':'idcdl0_intn_pn<3>', 'intn_pn<4>':'idcdl0_intn_pn<4>',
                                                          'VDD:':'VDD:', 'VSS:':'VSS:'})
IESEL0 = tlib['edge_selector'].generate(name='IESEL0', netmap={'ES_NP':'es_np', 'ES_PN':'es_pn', 'DP_PN':'dp_pn', 'DP_NP':'dp_np', 'DN_PN':'dn_pn', 'DN_NP':'dn_np',
                                                               'AND_OUT':'AND_OUT', 'OR_OUT':'OR_OUT', 
                                                               'mid0_and':'iesel0_mid0_and', 'mid1_and':'iesel0_mid1_and', 'mid0_or':'iesel0_mid0_or', 'mid1_or':'iesel0_mid1_or',
                                                               'VDD:':'VDD:', 'VSS:':'VSS:'})
IOMUX0 = tlib['outmux'].generate(name='OMUX0', netmap={'IN0':'es_pn', 'IN1':'es_np', 'EN1':'SEL_BOUT', 'OUT':'BOUT', 'mid0':'iomux0_mid0', 'mid1':'iomux0_mid1',
                                                        'VDD:':'VDD:', 'VSS:':'VSS:'})
dsn.place(inst=[[None, ITCOMP0, IOMUX0],[IZINJ0, IDCDL0, IESEL0]])
# taps
# tap0 = tlib_logic['tap'].generate(name='tap0', transform='MX')
# tap1 = tlib_logic['tap'].generate(name='tap1')
# tap2 = tlib_logic['tap'].generate(name='tap2', transform='MX')
# tap3 = tlib_logic['tap'].generate(name='tap3')
# tap4 = tlib_logic['tap'].generate(name='tap4', transform='MX')
# tap5 = tlib_logic['tap'].generate(name='tap5')
# dsn.place(inst=[[tap0],[tap1],[tap2],[tap3],[tap4],[tap5]], mn=IOMUX0.bottom_right)
tech.fill_by_instance(dsn, grids, tlib, tlib, 'space_2x', iter_type=('MX', 'R0'))

# Create and place wires.
print("Create wires")
rc = laygo2.RoutingMeshTemplate(grid=dsn.rgrid)
rc.add_trunk(name="rdp", index=[None, IZINJ0.p['ORP'].top.n], netname="dp")
rc.add_trunk(name="rdn", index=[None, IZINJ0.p['ORN'].bottom.n], netname="dn")
rc.add_trunk(name="rinp", index=[None, ITCOMP0.p['INP'].bottom.n + 2], netname="INP")
rc.add_trunk(name="rinn", index=[None, ITCOMP0.p['INN'].top.n - 2], netname="INN")
rc.add_trunk(name="res_pn", index=[None, IOMUX0.p['IN0'].top.n + 1], netname="es_pn")
rc.add_trunk(name="res_np", index=[None, IOMUX0.p['IN1'].bottom.n - 1], netname="es_np")
rc.add_trunk(name="rdp_np", index=[None, IDCDL0.p['DP_NP'].bottom.n], netname="dp_np")
rc.add_trunk(name="rdp_pn", index=[None, IDCDL0.p['DP_PN'].bottom.n], netname="dp_pn")
rc.add_trunk(name="rdn_pn", index=[None, IDCDL0.p['DN_PN'].top.n], netname="dn_pn")
rc.add_trunk(name="rdn_np", index=[None, IDCDL0.p['DN_NP'].top.n], netname="dn_np")
rc.add_node(dsn.instances)
rinst0 = rc.generate()
dsn.place(grid=pg, inst=rinst0)
      
# Create pins.
pinp0 = dsn.pin(name='INP', mn=IZINJ0.p['INP'])
pinn0 = dsn.pin(name='INN', mn=IZINJ0.p['INN'])
pclkref0 = dsn.pin(name='CLKREF', mn=IZINJ0.p['CLKREF'])
pshort0 = dsn.pin(name='SHORT', mn=IZINJ0.p['SHORT'])
prst0 = dsn.pin(name='RST', mn=ITCOMP0.p['RST'])
prstb0 = dsn.pin(name='RSTB', mn=ITCOMP0.p['RSTB'])
pand_out0 = dsn.pin(name='AND_OUT', mn=IESEL0.p['AND_OUT'])
por_out0 = dsn.pin(name='OR_OUT', mn=IESEL0.p['OR_OUT'])
psel_bout0 = dsn.pin(name='SEL_BOUT', mn=IOMUX0.p['EN1'])
pbout0 = dsn.pin(name='BOUT', mn=IOMUX0.p['OUT'])
pdlyp0 = dsn.pin(name='C_POS<0>', grid=r34, mn=r34(IDCDL0.p['C_POS<0>']))
pdlyp1 = dsn.pin(name='C_POS<1>', grid=r34, mn=r34(IDCDL0.p['C_POS<1>']))
pdlyp2 = dsn.pin(name='C_POS<2>', grid=r34, mn=r34(IDCDL0.p['C_POS<2>']))
pdlyp3 = dsn.pin(name='C_POS<3>', grid=r34, mn=r34(IDCDL0.p['C_POS<3>']))
pdlyp4 = dsn.pin(name='C_POS<4>', grid=r34, mn=r34(IDCDL0.p['C_POS<4>']))
pdlyn0 = dsn.pin(name='C_NEG<0>', grid=r34, mn=r34(IDCDL0.p['C_NEG<0>']))
pdlyn1 = dsn.pin(name='C_NEG<1>', grid=r34, mn=r34(IDCDL0.p['C_NEG<1>']))
pdlyn2 = dsn.pin(name='C_NEG<2>', grid=r34, mn=r34(IDCDL0.p['C_NEG<2>']))
pdlyn3 = dsn.pin(name='C_NEG<3>', grid=r34, mn=r34(IDCDL0.p['C_NEG<3>']))
pdlyn4 = dsn.pin(name='C_NEG<4>', grid=r34, mn=r34(IDCDL0.p['C_NEG<4>']))

# probes
dsn.pin(name='izinj0_norp', mn=IZINJ0.p['norp'])
dsn.pin(name='izinj0_norn', mn=IZINJ0.p['norn'])
dsn.pin(name='itcomp0_cmp_outp_pre', mn=ITCOMP0.p['cmp_outp_pre'])
dsn.pin(name='itcomp0_cmp_outn_pre', mn=ITCOMP0.p['cmp_outn_pre'])
dsn.pin(name='itcomp0_cmp_outp_pre2', mn=ITCOMP0.p['cmp_outp_pre2'])
dsn.pin(name='itcomp0_cmp_outn_pre2', mn=ITCOMP0.p['cmp_outn_pre2'])
dsn.pin(name='itcomp0_cmp_outp', mn=ITCOMP0.p['cmp_outp'])
dsn.pin(name='itcomp0_cmp_outn', mn=ITCOMP0.p['cmp_outn'])
dsn.pin(name='itcomp0_cmp_outpb', mn=ITCOMP0.p['cmp_outpb'])
dsn.pin(name='itcomp0_cmp_outnb', mn=ITCOMP0.p['cmp_outnb'])
dsn.pin(name='itcomp0_srn', mn=ITCOMP0.p['srn'])
dsn.pin(name='itcomp0_srp', mn=ITCOMP0.p['srp'])
dsn.pin(name='itcomp0_pd', mn=ITCOMP0.p['pd'])
dsn.pin(name='itcomp0_nd', mn=ITCOMP0.p['nd'])
dsn.pin(name='idcdl0_dp_pre', mn=IDCDL0.p['dp_pre'])
dsn.pin(name='idcdl0_dn_pre', mn=IDCDL0.p['dn_pre'])
dsn.pin(name='idcdl0_intp_np<0>', mn=IDCDL0.p['intp_np<0>'])
dsn.pin(name='idcdl0_intp_np<1>', mn=IDCDL0.p['intp_np<1>'])
dsn.pin(name='idcdl0_intp_np<2>', mn=IDCDL0.p['intp_np<2>'])
dsn.pin(name='idcdl0_intp_np<3>', mn=IDCDL0.p['intp_np<3>'])
dsn.pin(name='idcdl0_intp_np<4>', mn=IDCDL0.p['intp_np<4>'])
dsn.pin(name='idcdl0_intp_pn<0>', mn=IDCDL0.p['intp_pn<0>'])
dsn.pin(name='idcdl0_intp_pn<1>', mn=IDCDL0.p['intp_pn<1>'])
dsn.pin(name='idcdl0_intp_pn<2>', mn=IDCDL0.p['intp_pn<2>'])
dsn.pin(name='idcdl0_intp_pn<3>', mn=IDCDL0.p['intp_pn<3>'])
dsn.pin(name='idcdl0_intp_pn<4>', mn=IDCDL0.p['intp_pn<4>'])
dsn.pin(name='idcdl0_intn_np<0>', mn=IDCDL0.p['intn_np<0>'])
dsn.pin(name='idcdl0_intn_np<1>', mn=IDCDL0.p['intn_np<1>'])
dsn.pin(name='idcdl0_intn_np<2>', mn=IDCDL0.p['intn_np<2>'])
dsn.pin(name='idcdl0_intn_np<3>', mn=IDCDL0.p['intn_np<3>'])
dsn.pin(name='idcdl0_intn_np<4>', mn=IDCDL0.p['intn_np<4>'])
dsn.pin(name='idcdl0_intn_pn<0>', mn=IDCDL0.p['intn_pn<0>'])
dsn.pin(name='idcdl0_intn_pn<1>', mn=IDCDL0.p['intn_pn<1>'])
dsn.pin(name='idcdl0_intn_pn<2>', mn=IDCDL0.p['intn_pn<2>'])
dsn.pin(name='idcdl0_intn_pn<3>', mn=IDCDL0.p['intn_pn<3>'])
dsn.pin(name='idcdl0_intn_pn<4>', mn=IDCDL0.p['intn_pn<4>'])
dsn.pin(name='iesel0_mid0_and', mn=IESEL0.p['mid0_and'])
dsn.pin(name='iesel0_mid1_and', mn=IESEL0.p['mid1_and'])
dsn.pin(name='iesel0_mid0_or', mn=IESEL0.p['mid0_or'])
dsn.pin(name='iesel0_mid1_or', mn=IESEL0.p['mid1_or'])
dsn.pin(name='iomux0_mid0', mn=IOMUX0.p['mid0'])
dsn.pin(name='iomux0_mid1', mn=IOMUX0.p['mid1'])

tech.generate_pwr_rail(dsn, grids, netname=['VDD', 'VSS'], vertical=False)
    
# Export design
# laygo2.export(dsn, tech=tech, filename=export_path_skill+libname+'_'+cellname+'.il')
laygo2.export_template(dsn, filename=f"{export_path}{libname}_templates.yaml", mode='append')

# test jSON DB export
grid_table = dict()
grid_table['M1'] = r12
grid_table['M2'] = r23
grid_table['M3'] = r34
grid_table['M4'] = r34
exporter = laygo2.object.database.DesignExporter(dsn, grid_table, lib_ref = "laygo2_generators_private/prj_db/tbadc/library.yaml")
nat_dict = exporter.export_to_dict()
laygo2.interface.json.export_dict(nat_dict, filename=export_path_db+libname+'_db.json', mode='append')

