#########################################################
#                                                        
# Inverter Layout Generator              
# Contributors: T. Shin, S. Park, Y. Oh, T. Kang     
# Last Updated: 2024-09-16               
#                                                        
#########################################################

import numpy as np
import laygo2
import laygo2_tech as tech
import laygo2.object.database
import laygo2.interface.json

# Parameter definitions #############
# Design Variables
cell_type = ['buffer'] 
    # _ltap stands for tap on the left side
    # _hs stands for high-speed. (Output is connected with multiple wires to reduce R).
    # _hp stands for high-power. (hs + additional tap rows are placed to enhance power network).
    # _io stands for io. (hs + hp + additional tap rows btn p/n are placed for guardring).
p_nf = 4
n_nf = 2
tap_nf=9
nf_list = [1]

# Templates
tpmos_name = 'pmos'
tnmos_name = 'nmos'
tntap_name = 'ntap'
tptap_name = 'ptap'

ndum_name = 'nmos4_fast_dmy_nf2'
pdum_name = 'pmos4_fast_dmy_nf2'

# Grids

pg_name = 'placement_basic'
r12m_name = 'routing_12_mos'
r23m_name = 'routing_23_mos'
r12_name = 'routing_12_cmos'
r23_name = 'routing_23_cmos'
r12f_name   = 'routing_12_cmos_flipped'
r23f_name   = 'routing_23_cmos_flipped'

# pg_name = 'placement_basic'
# r12m_name = 'routing_12_mos'
# r23m_name = 'routing_23_mos'

# Design hierarchy
libname = 'tbadc_generated'
# Layout generation path is set to "export_path/libname/cellname".
export_path = './laygo2_generators_private/tbadc/' 
# SKILL file generation path is set to "export_path_skill/libname_cellname.il"
export_path_skill = export_path+'skill/' 
export_path_db      = './laygo2_generators_private/prj_db/tbadc/' # Path for JSON DB export
# End of parameter definitions ######

# Generation start ##################
# 1. Load templates and grids.
print("Load templates")
templates = tech.load_templates()
tpmos, tnmos = templates[tpmos_name], templates[tnmos_name]
tntap, tptap = templates[tntap_name], templates[tptap_name]

tndum = templates[ndum_name]
tpdum = templates[pdum_name]


##ndum = templates[ndum_name]
# Uncomment the following line if you use the logic templates in the generator code.
# tlib = laygo2.import_template(filename=export_path+'logic_generated_templates.yaml') 
# Uncomment if you want to print template information.
# print(templates[tpmos_name], templates[tnmos_name], sep="\n") 

print("Load grids")
grids = tech.load_grids(templates=templates)

pg, r12m, r23m = grids[pg_name], grids[r12m_name], grids[r23m_name]
r12cmf, r23cmf = grids[r12f_name], grids[r23f_name]
r12cm, r23cm = grids[r12_name], grids[r23_name]

r12 = laygo2.grid.vstack([r12m, r12cm])
r23 = laygo2.grid.vstack([r23m, r23cm])
r12f= laygo2.grid.vstack([r12cmf, r12m])
r23f= laygo2.grid.vstack([r23cmf, r23m])
#pg, r12m, r23m = grids[pg_name], grids[r12m_name], grids[r23m_name]
# Uncomment if you want to print grid information.
# print(grids[pg_name], grids[r12m_name], grids[r23m_name], sep="\n") 

for celltype in cell_type:
    for nf in nf_list:
        cellname = f'{celltype}'
        print('--------------------')
        print(f'Creating {cellname}')
        
        # Routing grid generation
        if celltype in ['buffer']:
            pass
        # 2. Create a design hierarchy
        lib = laygo2.Library(name=libname)
        dsn = laygo2.Design(name=cellname, libname=libname)
        lib.append(dsn)
        
        # 3. Create instances.
        print("Create instances")
        # core devices 
        in0  = tnmos.generate(name='MN0',   transform='MX',              params={'nf': n_nf, 'tie': 'S','nfdmyl': 2, 'nfdmyr' : 4,  'bndl':False, 'bndr':False})     
        ip0  = tpmos.generate(name='MP0', params={'nf': p_nf, 'tie': 'S', 'nfdmyl': 2, 'nfdmyr' : 2,'bndl':False, 'bndr':False})
        in1  = tnmos.generate(name='MN1',                params={'nf': n_nf, 'tie': 'S',  'nfdmyl': 2, 'nfdmyr' : 4,'bndl':False, 'bndr':False})              
        ip1  = tpmos.generate(name='MP1',transform='MX', params={'nf': p_nf, 'tie': 'S','nfdmyl': 2, 'nfdmyr' : 2, 'bndl':False, 'bndr':False})
        
        # taps
        int0 = tntap.generate(name='NT0', params={'nf': tap_nf, 'tie': 'TAP0'})
        ipt0 = tptap.generate(name='PT0', transform='MX', params={'nf': tap_nf, 'tie': 'TAP0'})
        int1 = tntap.generate(name='NT1', transform='MX', params={'nf': tap_nf, 'tie': 'TAP0'})
                
        # 4. Place instances.
        if celltype in ['buffer']:
                  
            _width      = pg.mn.width_vec(ip0)[0]
            _height     = pg.mn.height_vec(ip0)[1]
            _height_tap = pg.mn.height_vec(int0)[1]
            dsn.place(grid=pg, inst =   int0, mn=[-1,0])
            dsn.place(grid=pg, inst =   ip0, mn=[0,_height_tap])
            dsn.place(grid=pg, inst =   in0, mn=[0, _height*2+_height_tap])
            dsn.place(grid=pg, inst =   ipt0, mn=[-1, _height*3+_height_tap])   
            dsn.place(grid=pg, inst =   in1, mn=[0, _height*2+_height_tap*2])
            dsn.place(grid=pg, inst =   ip1, mn=[0, _height*4+_height_tap*2])
            dsn.place(grid=pg, inst =   int1, mn=[-1, _height*5+_height_tap*2])
        # 5. Create and place wires.
        print("Create wires")

        # IN
        _track = [r23(ip0.p['G'])[0,0]-1,None]
        rin0 = dsn.route(grid=r23, mn=[in0.p['G'], ip0.p['G']], track=_track )
        rin0 = rin0[-1] # the last element corresponds to the trunk wire
        
        _track = [r23(ip0.p['G'])[1,0],None]
        dsn.route(grid=r23, mn=[in0.p['G'], ip0.p['G']], track=_track )
        
        _track = [r23(ip1.p['G'])[0,0]-1,None]
        rin1 = dsn.route(grid=r23, mn=[in1.p['G'], ip1.p['G']], track=_track )
        rin1 = rin1[-1] # the last element corresponds to the trunk wire
        
        _track = [r23(ip1.p['G'])[1,0],None]
        dsn.route(grid=r23, mn=[in1.p['G'], ip1.p['G']], track=_track )

       
        
        # OUT
        
        _track = [r23(ip0.p['D'])[1,0]+6,None]
        rout0 = dsn.route(grid=r23, mn=[in0.p['D'],ip0.p['D']],track=_track)
        

        _track = [r23(ip1.p['D'])[1,0]+6,None]
        rout1 = dsn.route(grid=r23, mn=[in1.p['D'],ip1.p['D']],track=_track)

                
        
        # Rails
        #if celltype in ['inv', 'inv_ltap', 'inv_hs', 'inv_layvar_rtrackswap', 'inv_layvar_prtrackswap']:
        #tech.generate_pwr_rail(dsn, grids, netname=['VDD', 'VSS'], vertical=False)
        # elif celltype in ['inv_hp', 'inv_io']:
        #     rvss0 = dsn.route(grid=r12, mn=r12(in0.p['RAIL']))
        #     rvdd0 = dsn.route(grid=r12, mn=r12(ip0.p['RAIL']))
        #     rvss1 = dsn.route(grid=r12, mn=r12(ipt0.p['RAIL']))
        #     rvdd1 = dsn.route(grid=r12, mn=r12(int0.p['RAIL']))
        #     for i in range(int(nf/2)+1): # vertical route
        #        dsn.route(grid=r12, mn=[r12(ipt0.p['RAIL'])[0]+[2*i+1,0], 
        #                                r12(in0.p['RAIL'])[0] +[2*i+1,0]])
        #        dsn.route(grid=r12, mn=[r12(int0.p['RAIL'])[0]+[2*i+1,0], 
        #                                r12(ip0.p['RAIL'])[0] +[2*i+1,0]])
        # if celltype in ['inv_io']:
        #     rvss2 = dsn.route(grid=r12, mn=r12(ipt2.p['RAIL']))
        #     rvdd2 = dsn.route(grid=r12, mn=r12(int2.p['RAIL']))
        
        # 6. Create pins.
        pin0 = dsn.pin(name='CMP_OUTN', grid=r23, mn=rin0)
        pin1 = dsn.pin(name='CMP_OUTP', grid=r23, mn=rin1)
        
        pout0 = dsn.pin(name='CMP_OUTNB', grid=r23, mn=rout0[-1])
        pout1 = dsn.pin(name='CMP_OUTPB', grid=r23, mn=rout1[-1])

        pvdd0 = dsn.pin(name='VDD0', grid=r12, mn=r12.mn.bbox(int0.p['RAIL']), netname='VDD:')
        pvss0 = dsn.pin(name='VSS0', grid=r12, mn=r12.mn.bbox(ipt0.p['RAIL']), netname='VSS:')
        pvdd1 = dsn.pin(name='VDD1', grid=r12, mn=r12.mn.bbox(int1.p['RAIL']), netname='VDD:')
        # elif celltype in ['inv_hs', 'inv_hp', 'inv_io']:
        #     pout0 = dsn.pin(name='O'+str(i), grid=r23, mn=rout0, netname='O:')
        
        # # Power pins for inv, inv_ltap, inv_hs are auto-geneated by generate_pwr_rail.
        # if celltype in ['inv_hp']:
        #     pvss0 = dsn.pin(name='VSS0', grid=r12, mn=rvss0, netname='VSS:')
        #     pvdd0 = dsn.pin(name='VDD0', grid=r12, mn=rvdd0, netname='VDD:')
        #     pvss1 = dsn.pin(name='VSS1', grid=r12, mn=rvss1, netname='VSS:')
        #     pvdd1 = dsn.pin(name='VDD1', grid=r12, mn=rvdd1, netname='VDD:')
        # elif celltype in ['inv_io']:
        #     pvss0 = dsn.pin(name='VSS0', grid=r12, mn=rvss0, netname='VSS:')
        #     pvdd0 = dsn.pin(name='VDD0', grid=r12, mn=rvdd0, netname='VDD:')
        #     pvss1 = dsn.pin(name='VSS1', grid=r12, mn=rvss1, netname='VSS:')
        #     pvdd1 = dsn.pin(name='VDD1', grid=r12, mn=rvdd1, netname='VDD:')
        #     pvss2 = dsn.pin(name='VSS2', grid=r12, mn=rvss2, netname='VSS:')
        #     pvdd2 = dsn.pin(name='VDD2', grid=r12, mn=rvdd2, netname='VDD:')
        
        # 7. Export to physical database.
        print("Export design\n")
        # laygo2.export(lib, tech=tech, filename=export_path_skill+libname+'_'+cellname+'.il')
        # Filename example: ./laygo2_generators_private/logic/skill/logic_generated_inv_hs_2x.il
        
        # 8. Export to a template database file.
        nat_temp = dsn.export_to_template()
        laygo2.export_template(nat_temp, filename=f"{export_path}{libname}_templates.yaml", mode='append')
        # Filename example: ./laygo2_generators_private/logic/logic_generated_templates.yaml

        # test jSON DB export
        grid_table = dict()
        grid_table['M1'] = r12 # M1 uses r12 (r12m, r12cm)
        grid_table['M2'] = r23 # M2 uses r23 (r23m, r23cm)
        grid_table['M3'] = r23
        exporter = laygo2.object.database.DesignExporter(dsn, grid_table, lib_ref = "laygo2_generators_private/prj_db/tbadc/library.yaml")
        nat_dict = exporter.export_to_dict()
        laygo2.interface.json.export_dict(nat_dict, filename=export_path_db+libname+'_db.json', mode='append')
