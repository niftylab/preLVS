using preLVS
config = get_config("config/config_tsmcN28.yaml")
orient = get_orientation_list(config)
equiv  = config["Equivalent_net_sets"]
lib="nmos_lib"; cell="nmos_nf4_tie_s"
root, cell_data, db_data, top = get_tree(lib, cell, "db", equiv)
mdata, vdata = flatten_v2(lib, cell, cell_data, db_data, orient, config, equiv, true)

println("\n@@@ top_netnames = ", top)
println("\n@@@ M1 (layer 1) metals AFTER flatten (x => origins):")
if haskey(mdata.metals, 1)
  for pc in sort(collect(keys(mdata.metals[1].metals)))
    mvs = mdata.metals[1].metals[pc]
    println("   x=", pc, " : ", [ (mv.laygo_origin===nothing ? "nil" : mv.laygo_origin.traceback) for mv in mvs])
  end
end

modata, nmetals, short = sort_n_merge_MData(mdata)
println("\n@@@ M1 MERGED metals (MOVector idx):")
if haskey(modata.metals, 1)
  for pc in sort(collect(keys(modata.metals[1].metals)))
    for mv in modata.metals[1].metals[pc]
      println("   x=", pc, " idx=", mv.idx, " y=", mv.points[1].s_coord, "-", mv.points[2].s_coord,
              " net=", mv.netname, " origins=", [o.traceback for o in mv.laygo_origin_set])
    end
  end
end

println("\n@@@ ALL vias (type @ xy):")
for (vt, vl) in vdata.vlists, vp in vl.vpoints
  println("   ", vt, " @ ", vp.xy)
end

cgraph = connect_metals_from_via(modata, vdata, nmetals)
nodeidx = Int[]
for (k, _) in cgraph.adj; push!(nodeidx, k.idx); end
println("\n@@@ metal idx present in via-graph: ", sort(unique(nodeidx)))

cinfo, einfo, ecnt = check_and_report_connections_bfs(cgraph, equiv)
println("\n@@@ components:")
for ci in cinfo
  println("   comp#", ci.number, " net=", ci.netname,
          " (layer,x)=", sort([(n.layer, n.p_coord) for n in ci.nodes]))
end
println("\n@@@ error_cnt = ", ecnt)
