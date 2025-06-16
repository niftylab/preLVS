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

export_path_db      = './laygo2_generators_private/prj_db/tbadc/' # Path for JSON DB export

# Parameter definitions #############
# Design Variables
cell_type = ['vtc_crossing_detector_inv']
    # _ltap stands for tap on the left side
    # _hs stands for high-speed. (Output is connected with multiple wires to reduce R).
    # _hp stands for high-power. (hs + additional tap rows are placed to enhance power network).
    # _io stands for io. (hs + hp + additional tap rows btn p/n are placed for guardring).
nf_list = [4, 2]

# Templates
tpmos_name = 'pmos'
tnmos_name = 'nmos'
tntap_name = 'ntap'
tptap_name = 'ptap'

# Grids
pg_name = 'placement_basic'
r12m_name = 'routing_12_mos'
r23m_name = 'routing_23_mos'
r34m_name = 'routing_34_cmos'

# Design hierarchy
libname = 'tbadc_generated'
# Layout generation path is set to "export_path/libname/cellname".
export_path = './laygo2_generators_private/tbadc/' 
# SKILL file generation path is set to "export_path_skill/libname_cellname.il"
export_path_skill = export_path+'skill/' 
# End of parameter definitions ######

# Generation start ##################
# 1. Load templates and grids.
print("Load templates")
templates = tech.load_templates()
tpmos, tnmos = templates[tpmos_name], templates[tnmos_name]
tntap, tptap = templates[tntap_name], templates[tptap_name]
# Uncomment the following line if you use the logic templates in the generator code.
# tlib = laygo2.import_template(filename=export_path+'logic_generated_templates.yaml') 
# Uncomment if you want to print template information.
# print(templates[tpmos_name], templates[tnmos_name], sep="\n") 

print("Load grids")
grids = tech.load_grids(templates=templates)
pg, r12m, r23m, r34m = grids[pg_name], grids[r12m_name], grids[r23m_name], grids[r34m_name]
# Uncomment if you want to print grid information.
# print(grids[pg_name], grids[r12m_name], grids[r23m_name], sep="\n") 

for celltype in cell_type:
    for nf in nf_list:
        #if nf == 4:
        #    cellname = f'{celltype}_{nf}x_{nf//2}x'
        #elif nf == 2:
        #    cellname = f'{celltype}_{nf}x_{nf}x'
        cellname = f'{celltype}_{nf}x'
        print('--------------------')
        print(f'Creating {cellname}')
        
        # Routing grid generation
        r12 = laygo2.grid.vstack([r12m, r12m.vflip()])
        r23 = laygo2.grid.vstack([r23m, r23m.vflip()])
        r34 = laygo2.grid.vstack([r34m, r34m.vflip()])

        # 2. Create a design hierarchy
        lib = laygo2.Library(name=libname)
        dsn = laygo2.Design(name=cellname, libname=libname)
        lib.append(dsn)
        
        # 3. Create instances.
        print("Create instances")
        # core devices 
        if nf == 4:
            in0  = tnmos.generate(name='MN0',                 params={'nf': nf, 'nfdmyl': 2, 'tie': 'S'})
            ip0  = tpmos.generate(name='MP0', transform='MX', params={'nf': nf//2, 'nfdmyl': 2, 'nfdmyr' : 2, 'tie': 'S'})
        elif nf == 2:
            in0  = tnmos.generate(name='MN0',                 params={'nf': nf, 'nfdmyl': 2, 'nfdmyr' : 2,'tie': 'S'})
            ip0  = tpmos.generate(name='MP0', transform='MX', params={'nf': nf, 'nfdmyl': 2, 'nfdmyr' : 2, 'tie': 'S'})
        # taps
        ipt0 = tptap.generate(name='PT0',                 params={'nf': nf, 'tie': 'TAP0'})
        ipt1 = tptap.generate(name='PT1', transform='MX', params={'nf': nf, 'tie': 'TAP0'})
        ipt2 = tptap.generate(name='PT2',                 params={'nf': nf, 'tie': 'TAP0'})
        int2 = tntap.generate(name='NT2', transform='MX', params={'nf': nf, 'tie': 'TAP0'})
        int1 = tntap.generate(name='NT1',                 params={'nf': nf, 'tie': 'TAP0'})
        int0 = tntap.generate(name='NT0', transform='MX', params={'nf': nf, 'tie': 'TAP0'})
        
        # 4. Place instances.
        dsn.place(grid=pg, inst=[[in0], [ip0]], mn=[0,0])
        
        # 5. Create and place wires.
        print("Create wires")

        # IN
        _track = [r23(in0.p['G'])[0,0]-1, None]
        rin0 = dsn.route(grid=r23, mn=[in0.p['G'], ip0.p['G']], track=_track)
        rin0 = rin0[-1] # the last element corresponds to the trunk wire
        
        # OUT
        if nf == 4:
            _track = [r23(in0.p['D'])[-1,0]+1, None]
            rout0 = dsn.route(grid=r23, mn=[in0.p['D'], ip0.p['D']], track=_track)
        elif nf == 2:
            _track = [r23(in0.p['D'])[-1,0]+3, None]
            rout0 = dsn.route(grid=r23, mn=[in0.p['D'], ip0.p['D']], track=_track)
        # Rails
        tech.generate_pwr_rail(dsn, grids, netname=['VSS', 'VDD'], vertical=False)
        
        # 6. Create pins.
        pin0 = dsn.pin(name='I', grid=r23, mn=rin0)
        pout0 = dsn.pin(name='O', grid=r23, mn=rout0[-1])
        
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
        grid_table['M1'] = r12
        grid_table['M2'] = r23
        grid_table['M3'] = r23
        grid_table['M4'] = r34
        exporter = laygo2.object.database.DesignExporter(dsn, grid_table, lib_ref = "laygo2_generators_private/prj_db/tbadc/library.yaml")
        nat_dict = exporter.export_to_dict()
        laygo2.interface.json.export_dict(nat_dict, filename=export_path_db+libname+'_db.json', mode='append')