##########################################################
#                                                        #
#              2-to-1 MUX Layout Gernerator              #
#     Contributors: T. Shin, S. Park, Y. Oh, T. Kang     #
#                 Last Update: 2022-05-27                #
#                                                        #
##########################################################

import numpy as np
import pprint
import laygo2
import laygo2.interface
import laygo2_tech as tech
from laygo2.object.netmap import NetMap

# Parameter definitions #############
# Design Variables
cell_type = ['mux2to1']#, 'mux2to1_ltap']
nf_list = [2]#,4,8]

# Templates
tpmos_name = 'pmos'
tnmos_name = 'nmos'
tpspc_name = 'pspace'
tnspc_name = 'nspace'
tntap_name = 'ntap'
tptap_name = 'ptap'

# Grids
pg_name = 'placement_basic'
r12_name = 'routing_12_cmos'
r23_name = 'routing_23_cmos'

# Design hierarchy
libname             = 'test_generated'
export_path         = './laygo2_generators_private/feature_test/export_raw_dict/' # Layout generation path: "export_path/libname/cellname"
export_path_skill   = export_path+'skill/' # SKILL file generation path: "export_path_skill/libname_cellname.il"
export_path_db      = './laygo2_generators_private/prj_db/'
# End of parameter definitions ######

# Generation start ##################
# 1. Load templates and grids.
print("Load templates")
templates = tech.load_templates()
tpmos, tnmos = templates[tpmos_name], templates[tnmos_name]
tpspc, tnspc = templates[tpspc_name], templates[tnspc_name]
tntap, tptap = templates[tntap_name], templates[tptap_name]
tlib = laygo2.interface.yaml.import_template(filename=export_path+libname+'_templates.yaml') # Uncomment if you use the logic templates
# print(templates[tpmos_name], templates[tnmos_name], sep="\n") # Uncomment if you want to print templates

print("Load grids")
grids = tech.load_grids(templates=templates)
pg, r12, r23 = grids[pg_name], grids[r12_name], grids[r23_name]
# print(grids[pg_name], grids[r12_name], grids[r23_name], sep="\n") # Uncomment if you want to print grids

for celltype in cell_type:
    for nf in nf_list:
        cellname = celltype+'_'+str(nf)+'x'
        print('--------------------')
        print('Now Creating '+cellname)
  
        # 2. Create a design hierarchy
        lib = laygo2.object.database.Library(name=libname)
        dsn = laygo2.object.database.Design(name=cellname, libname=libname)
        lib.append(dsn)
        
        # 3. Create istances.
        print("Create instances")
        tap0 = tlib['tap'].generate(name="TAP0")
        in0 = tnmos.generate(name='MN0',                 params={'nf': nf, 'tie': 'S'})
        in1 = tnmos.generate(name='MN1',                 params={'nf': nf})
        in2 = tnmos.generate(name='MN2',                 params={'nf': nf})
        in3 = tnmos.generate(name='MN3',                 params={'nf': nf, 'tie': 'S'})
        in4 = tnmos.generate(name='MN4',                 params={'nf': nf, 'tie': 'S'}) 
        ip0 = tpmos.generate(name='MP0', transform='MX', params={'nf': nf, 'tie': 'S'})
        ip1 = tpmos.generate(name='MP1', transform='MX', params={'nf': nf})
        ip2 = tpmos.generate(name='MP2', transform='MX', params={'nf': nf})
        ip3 = tpmos.generate(name='MP3', transform='MX', params={'nf': nf, 'tie': 'S'})
        ip4 = tpmos.generate(name='MP4', transform='MX', params={'nf': nf, 'tie': 'S'})
        inspc0 = tnspc.generate(name='nspace0', params={'nf':2})
        ipspc0 = tpspc.generate(name='pspace0', params={'nf':2}, transform='MX')

        # 4. Place instances.
        if celltype == 'mux2to1_ltap':
            dsn.place(grid=pg, inst=tap0, mn=[0,0])
            dsn.place(grid=pg, inst=[[in0, in1, inspc0, in2, in3, in4], 
                                     [ip0, ip1, ipspc0, ip2, ip3, ip4]], mn=pg.mn.bottom_right(tap0))
        else:
            dsn.place(grid=pg, inst=[[in0, in1, inspc0, in2, in3, in4], 
                                     [ip0, ip1, ipspc0, ip2, ip3, ip4]], mn=[0,0])
            

        # 5. Create and place wires.
        print("Create wires")
        
        # I0
        _mn = [r23.mn(in0.pins['G'])[0], r23.mn(ip0.pins['G'])[0]]
        vin00, rin00, vin01 = dsn.route(grid=r23, mn=_mn, via_tag=[True, True])
        
        # I1
        _mn = [r23.mn(in3.pins['G'])[1], r23.mn(ip3.pins['G'])[1]]
        vin10, rin10, vin11 = dsn.route(grid=r23, mn=_mn, via_tag=[True, True])
        
        # OUT
        _mn = [r23.mn(in4.pins['D'])[1], r23.mn(ip4.pins['D'])[1]]
        vout0, rout0, vout1 = dsn.route(grid=r23, mn=_mn, via_tag=[True, True])
       
        # EN0 
        _mn = [r12(in1.pins['G'])[1], r12(ip2.pins['G'])[0]]
        _branch_offset = [2, -2]
        #_track = [None, r12.mn(_mn[0])[1][1]-1]
        _track = [None, _mn[0][1]-1]
        r0 = dsn.route_via_track(grid=r12, mn=_mn, track=_track, branch_offset=_branch_offset)[-1]

        # EN0_via2M3
        _mn = [r23.mn.center(r0), r23.mn.center(r0)+[0,3]]
        dsn.route(grid=r23, mn=_mn, via_tag=[True, None])
        
        # EN1
        #_mn = [r23.mn(in2.pins['G'])[0], [r23.mn.bbox(ipspc0)[0,0], r23.mn(ip1.pins['D'])[0,1]]]
        _mn = [in2.pins['G'], [r23.mn.bbox(ipspc0)[0,0]+1, r23.mn(ip1.pins['D'])[0,1]]]
        _track = [r23.mn.bbox(inspc0)[1,0]-1, None]
        ren1 = dsn.route_via_track(grid=r23, mn=_mn, track=_track)
        
        #_mn = [r23.mn(ip1.pins['G'])[0], [r23.mn.bbox(ipspc0)[0,0], r23.mn(ip1.pins['D'])[0,1]]]
        _mn = [ip1.pins['G'], [r23.mn.bbox(inspc0)[1,0]-1, r23.mn(ip1.pins['D'])[0,1]]]
        _track = [r23.mn.bbox(inspc0)[0,0]+1, None]
        dsn.route_via_track(grid=r23, mn=_mn, track=_track)
        
        ################################ ADDED FOR DRC ################################
        _mn = [r23.mn.bbox(ren1[1][0])[0], r23.mn.bbox(ren1[1][0])[0]+[0,1]]
        dsn.route(grid=r23, mn=_mn)
        ############################## LINES FOR DRC END ##############################
        
        
        # Internal
        _mn = [r23.mn(in0.pins['D'])[0], r23.mn(in1.pins['D'])[0]]
        dsn.route(grid=r23, mn=_mn)
  
        _mn = [r23.mn(ip0.pins['D'])[0], r23.mn(ip1.pins['D'])[0]]
        dsn.route(grid=r23, mn=_mn)
        
        _mn = [in1.pins['S'], ip2.pins['S']]
        _track = [r23.mn(in2.pins['S'])[1,0], None]
        dsn.route_via_track(grid=r23, mn=_mn, track=_track)
  
        if nf == 2:
           _mn = [r23.mn(ip1.pins['S'])[1], r23.mn(in4.pins['G'])[0]]
           _track = [r23.mn(in4.pins['RAIL'])[0,0]+1, None]
           dsn.route_via_track(grid=r23, mn=_mn, track=_track)
  
           _mn = [r23.mn(ip4.pins['G'])[0], r23.mn(in4.pins['G'])[0]]
           dsn.route_via_track(grid=r23, mn=_mn, track=_track)
  
        else:
           _mn = [ip1.pins['S'], in4.pins['G']]
           _track = [r23.mn(in4.pins['G'])[0,0], None]
           dsn.route_via_track(grid=r23, mn=_mn, track=_track)
           dsn.via(grid=r23, mn=r23.mn(ip4.pins['G'])[0])
        
        _mn = [r23.mn(in2.pins['D'])[0], r23.mn(in3.pins['D'])[0]]
        dsn.route(grid=r23, mn=_mn)
  
        _mn = [r23.mn(ip2.pins['D'])[0], r23.mn(ip3.pins['D'])[0]]
        dsn.route(grid=r23, mn=_mn)
        
        # VSS & VDD
        if celltype == 'mux2to1_ltap':
            rvss0 = dsn.route(grid=r12, mn=[r12.mn(tap0.pins['VSS'])[0], r12.mn(in4.pins['RAIL'])[1]])
            rvdd0 = dsn.route(grid=r12, mn=[r12.mn(tap0.pins['VDD'])[0], r12.mn(ip4.pins['RAIL'])[1]]) 
        else:    
            rvss0 = dsn.route(grid=r12, mn=[r12.mn(in0.pins['RAIL'])[0], r12.mn(in4.pins['RAIL'])[1]])
            rvdd0 = dsn.route(grid=r12, mn=[r12.mn(ip0.pins['RAIL'])[0], r12.mn(ip4.pins['RAIL'])[1]])        
    

        
        # 6. Create pins.
        pin0 = dsn.pin(name='I0', grid=r23, mn=r23.mn.bbox(rin00))
        pin1 = dsn.pin(name='I1', grid=r23, mn=r23.mn.bbox(rin10))
        pen0 = dsn.pin(name='EN0', grid=r23, mn=[r23.mn.center(r0), r23.mn.center(r0)+[0,3]])
        pen1 = dsn.pin(name='EN1', grid=r23, mn=r23.mn.bbox(ren1[2]))
        pout0 = dsn.pin(name='O', grid=r23, mn=r23.mn.bbox(rout0))
        pvss0 = dsn.pin(name='VSS', grid=r12, mn=r12.mn.bbox(rvss0))
        pvdd0 = dsn.pin(name='VDD', grid=r12, mn=r12.mn.bbox(rvdd0))
        
        # 7. Export to physical database.
        # test jSON DB export
        grid_table = dict()
        grid_table['M1'] = r12
        grid_table['M2'] = r23
        grid_table['M3'] = r23
        exporter = laygo2.object.database.DesignExporter(dsn, grid_table, lib_ref = "laygo2_generators_private/prj_db/library.yaml")
        nat_dict = exporter.export_to_dict()
        laygo2.interface.json.export_dict(nat_dict, filename=export_path_db+libname+'_db.json', mode='append')
        # Pre-LVS test
        via_table = dict()
        via_table["via_M1_M2_0"] = ('M1','M2')
        via_table["via_M1_M2_1"] = ('M1','M2')
        via_table["via_M2_M3_0"] = ('M2','M3')
        via_table["via_M2_M3_1"] = ('M2','M3')
        mosList = ["nmos4_fast_center_nf2", "nmos4_fast_center_2stack","pmos4_fast_center_nf2", "pmos4_fast_center_2stack"]
        nMap = NetMap.import_from_design(dsn, grid_table, via_table, orient_first="vertical", layer_names=['M1','M2','M3'],
                                            net_ignore = [], lib_ref = "laygo2_generators_private/prj_db/library.yaml", core_templates=mosList)
    #    metal_num = nMap.count_metals()
    #    print("# of metal vectors =",metal_num)
        nat_temp = dsn.export_to_template(metal_table=grid_table, net_ignore = [], export_mask=False)
        laygo2.interface.yaml.export_template(nat_temp, filename=export_path+libname+'_templates.yaml', mode='append')
        # Filename example: ./laygo2_generators_private/logic/logic_generated_templates.yaml