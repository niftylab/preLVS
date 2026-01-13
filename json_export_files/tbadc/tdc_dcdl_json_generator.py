def execfile(filepath, globals=None, locals=None):
   if globals is None:
      globals = {}
   globals.update({
      "__file__": filepath,
      "__name__": "__main__",
   })
   import os
   with open(filepath, 'rb') as file:
      exec(compile(file.read(), filepath, 'exec'), globals, locals)

ref_dir = './laygo2_generators_private/export_files/tbadc/layout_generator/'
'''
files = [
   #ref_dir+'filler_dmy_2x_layout_generator.py',
   #ref_dir+'nand2.py',
   #ref_dir+'nand2_balanced.py',
   ref_dir+'mux_nand.py',
   ref_dir+'inv_chain_4x_1f.py',
   ref_dir+'ncap_psw_gen.py',
   #ref_dir+'inv_rdmy.py',
   #ref_dir+'inv_rdmy_space.py',
   #ref_dir+'nand_12x6x_half.py',
   #ref_dir+'nand_12x6x_2s.py',
   ref_dir+'inv_cc_2s.py',
   ref_dir+'inv_24x_2s.py',
   ref_dir+'pulse_delay.py',
   ref_dir+'ncap_nsw_2x_bot_layout_generator.py',
   #ref_dir+'dcdl_8x_nand2_psw_ncap_4bit_layout_generator.py',
   ref_dir+'nand_match_2x_for_xor.py',
   ref_dir+'xor_static_inv_v1.py',

   ]
'''
files = [
   # # space
   # ref_dir+'space.py',
   # # voltage-to-time converter
   # ref_dir+'vtc_filler_dmy_2x.py',
   # ref_dir+'vtc_inv.py',
   # ref_dir+'vtc_inv_rdmy.py',
   # ref_dir+'vtc_inv_rdmy_space.py',
   # ref_dir+'vtc_inv_cc_2s.py',
   # ref_dir+'vtc_inv_24x_2s.py',
   # ref_dir+'vtc_nand2_half.py',
   # ref_dir+'vtc_nand2.py',
   # ref_dir+'vtc_clk_pulse_gen_dcdl.py',
   # ref_dir+'vtc_s2d_clock.py',
   # ref_dir+'vtc_clk_vtc_buffer.py',
   # ref_dir+'vtc_crossing_detector_inv.py',
   # ref_dir+'vtc_crossing_detector_inv_feedback.py',
   # # zero-inj
   # ref_dir+'zero_inj_nor2.py',
   # ref_dir+'zero_inj_inv.py',
   # ref_dir+'zero_inj_tgate.py',
   # ref_dir+'zero_inj.py',
   # # time comparator
   # #ref_dir+'nmos4_generator.py',
   # ref_dir+'time_comp_filler_dmy_2x.py',
   # ref_dir+'time_comp_nmos_sj.py',
   # ref_dir+'time_comp_inv.py',
   # #ref_dir+'time_comp_sr_latch_half.py',
   # #ref_dir+'time_comp_sr_latch_half2.py',
   # #ref_dir+'time_comp_sr_latch_high_rst.py',
   # #ref_dir+'time_comp_buffer.py',
   # #ref_dir+'time_comp_async_latch_half.py',
   # #ref_dir+'time_comp_async_latch.py',
   # #ref_dir+'time_comp.py',
   # ref_dir+'time_comp_async_latch_v2_half.py',
   # ref_dir+'time_comp_async_latch_v2.py',
   # ref_dir+'time_comp_sr_latch_v2_half.py',
   # ref_dir+'time_comp_sr_latch_v2.py',
   # ref_dir+'time_comp_buffer_v2.py',
   # ref_dir+'time_comp_v2.py',
   # dcdl
   ref_dir+'tdc_dcdl_filler_dmy_2x.py',
   ref_dir+'tdc_dcdl_inv.py',
   ref_dir+'tdc_dcdl_ncap_psw_2x.py',
   ref_dir+'tdc_dcdl_ncap_psw_small.py',
   ref_dir+'tdc_dcdl_5bit.py',
   ref_dir+'tdc_dcdl.py',
   # # edge selector 
   # ref_dir+'edge_selector_nand2.py',
   # ref_dir+'edge_selector_nand2_balanced.py',  
   # ref_dir+'edge_selector_mux_nand.py',
   # ref_dir+'edge_selector.py',
   # # output mux
   # ref_dir+'outmux_inv.py',
   # ref_dir+'outmux_nand2.py',
   # ref_dir+'outmux_nand2_balanced.py',
   # ref_dir+'outmux.py',
   # # tdc 1-bit top
   # ref_dir+'tdc_1bit.py',
   ]
idx=0
for f in files:
   execfile(f)
   idx += 1
   print(str(round(idx/len(files)*100,2))+'% done')
