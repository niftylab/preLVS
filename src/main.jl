# Uncomment to Download nessesary packages
# using Pkg
# Pkg.add("JSON")
# Pkg.add("JSON3")
# Pkg.add("YAML")
# Pkg.add("StaticArrays")
# Pkg.add("DataStructures")
# Pkg.add("OrderedCollections")

using BenchmarkTools
using JSON
using YAML
#include("utils/visualize.jl")
#include("main_functions_test.jl") # main functions ver2

include("sweepline/flatten.jl")
include("sweepline/sweepline.jl")
include("sweepline/connectivity.jl")

# # command-line 입력 확인
# if length(ARGS) < 2
#     println("Usage: julia main.jl <libname> <cellname>")
#     println("Example: julia main.jl test_generated dff_2x")
#     exit(1)
# end

# REPL test 용으로  ARGS 없이 직접 변수를 넣어줌
# 0. Fetch input ARG
input_arg   = get_yaml("config/test_input.yaml")
# 1. Prepare JSON files and directories
libname     = input_arg["libname"]#"test_generated"   # 라이브러리 이름
cellname    = input_arg["cellname"]#"scan_cell"  # cell 이름

db_dir = input_arg["db_dir"] #"db"
metal_dir = input_arg["metal_dir"] #"out/metal"
via_dir = input_arg["via_dir"] #"out/via"
visualized_dir = input_arg["visualized_dir"] #"out/visualized"

netlog_dir = input_arg["netlog_dir"]
config_file_path = input_arg["config_file_path"] #"config/config.yaml"

    # Check if database/config file exists
if !isfile("$(db_dir)/$(libname)_db.json")
    error("Database file '$(libname)_db.json' not found in $(db_dir)")
end
if !isfile(config_file_path)
    error("Config file not found at $config_file_path")
end

    # Load db_json_data
# db_json_path    = "$(db_dir)/$(libname)_db.json"
# db_json_data    = JSON.parse(read(db_json_path, String))
config_data     = get_config(config_file_path)


# 2. Create tree structure from the target cell
# 2.1. set equivalent net (needed to be taken over by config.yaml)
equivalent_net_sets = [("VDD", Set(["VDD", "vdd", "VDD:"])), ("VSS", Set(["VSS", "VSS:", "vss"]))]
# pass this through config_data
config_data["equivalent_net_sets"] = equivalent_net_sets
# cell_data is currently deprecated (planned for hierarchical LVS which is dropped)
# TODO: remove cell_data part
# declare main func variables for preserve retuned data from @elapsed block

events    = Vector{Event}()
hash_rect = Vector{Rect}()
overlaps  = Dict{Int, Vector{Int}}()
via_link  = Dict{Int, Tuple{Int, Int}}()
error_log = Vector{ErrorEvent}()
cgraph    = Dict{Int, GraphNode}()
nets      = Dict{Int, Vector{Int}}()


global root
global root_rect
root, inst_flatten::FlatInstTable, cell_list, db_data = get_tree(libname, cellname, db_dir, equivalent_net_sets)
# print_tree_root(root)

# memory_metal, memory_via, memory_label = create_rect_table(cell_list, db_json_data, config_data)
# root_rect = create_rect_tree(root, memory_metal, memory_label, memory_via, config_data)
# println("rect transform complete\n")


# for (libname, inst_groups) in inst_flatten
#     for (cellname, inst_group) in inst_groups
#         println("lib: $libname, cell: $cellname")
#         for (idx, data) in inst_group
#             println("   idx: $idx, name: $(data["instname"])")
#         end
#     end
# end

mflat, vflat, lflat = flatten_V2(inst_flatten, cell_list, db_data, config_data, equivalent_net_sets)

# println("Metal data: ", mdata)
# println("Via data: ", vdata)
# println("Label data: ", ldata)
println("flatten complete\n")

#-------------------------------------------------------------
# 3. Create Events and Group Rects with Sweepline 
events, hash_rect = create_events(inst_flatten, mflat, vflat, lflat, config_data)
# println("event align complete")
events_sorted = sort(events, by=event_sort_priority)

djs, overlaps, via_link, error_log, nets = process_events(events_sorted, hash_rect)
println("sweepline-based grouping complete\n")


cgraph = generate_graph(overlaps, via_link, hash_rect, djs)
println("connectivity graph generation complete")

#-------------------------------------------------------------
# 3(OUTDATED). Create Events and Group Rects with Sweepline 

# events, events_sorted, hash_rect = create_events(root, root_rect, config_data)
# println("event align complete")


# djs, overlaps, via_link, error_log, nets = process_events(events_sorted, hash_rect)
# println("sweepline-based grouping complete\n")


# cgraph = generate_graph(overlaps, via_link, hash_rect, djs)
# println("connectivity graph generation complete")


#------------------------------------------------------------------
# 4. check each net group and write log file
# 파일이 이미 존재하면 내용을 덮어씁니다. 파일이 없으면 새로 생성합니다.
# @time begin
# logFile_w = "$(netlog_dir)/$(libname)_$(cellname)_log.txt"
# try
#     open(logFile_w, "w") do io # "w"는 쓰기 모드를 의미
#         for (_root, elems) in nets
#             metalInclude = false
#             for elem in elems
#                 if typeof(hash_rect[elem]) == MRect
#                     metalInclude = true
#                     break
#                 end
#             end
#             if !metalInclude # Problem -> no metal in the net
#                 println(io,"Error: No metal on net $(_root), size of net: $(length(elems)) ")
#                 for elem in elems
#                     _event_idx = elem*2-1
#                     _etype = events[_event_idx].etype
#                     _layer = events[_event_idx].layer
#                     _range = events[_event_idx].range
#                     _xvec  = (events[_event_idx].xy[1], events[_event_idx+1].xy[1]) 
#                     print(io,"type:$(_etype), layer:$(_layer), range:$(_range) ")
#                     if _etype == VIA
#                         print(io,"via overlap: ")
#                         _layer1 = _layer; _layer2 = _layer+1
#                         for idx in 1:Int(length(events)/2)
#                             _start = events[idx*2-1]
#                             _end   = events[idx*2]
#                             if ( _start.etype == METAL && (_start.layer == _layer1 || _start.layer == _layer2)
#                                 && (_start.xy[1] <= _xvec[1] && _xvec[2] <= _end.xy[1])
#                                 && (_start.range[1] <= _range[1] && _range[2] <= _start.range[2]) )
#                                 print(io,"metal layer:$(_start.layer) xy:$(_start.xy), range:$(_start.range); ")
#                             end
#                         end
#                     end
#                     println(io,"")
#                 end
#             else
#                 println(io,"net$(_root):")
#                 for elem in elems
#                     _event_idx = elem*2-1
#                     _rect = hash_rect[elem]
#                     if events[_event_idx].etype == LABEL
#                         println(io,"   $(events[_event_idx].etype), layer:$(_rect.layer), xy:$(_rect.xy), netname:$(_rect.netname)")
#                     end
#                 end
#             end
#         end
#         println(io)
#         println(io, "Elaped Time for Flatten: ", elapsed_time_flatten)
#         println(io, "Elaped Time for SweepLine: ", elapsed_time_sweepline)
#     end # do 블록이 끝나면 io 객체(파일)는 자동으로 닫힘
#     println("'", "WORK_DIR/",logFile_w, "' 파일 쓰기 완료.")
#     catch e
#     println(stderr, "파일 쓰기 중 오류 발생: ", e)
#     end
# end
println("finish main")


# # 4. Visualize the merged metal layers
# visualize_metals(cellname, "$(metal_dir)/$(cellname)_metals.json", "$(visualized_dir)/$(cellname)_metal_layout.png")
# visualize_vias(cellname, "$(via_dir)/$(cellname)_vias.json", "$(visualized_dir)/$(cellname)_via_layout.png", scale_factor=5.0)

# @elapsed는 코드 블록의 결과값을 반환하지 않고 시간만 반환합니다.
# 결과값도 필요하면 다음과 같이 할 수 있습니다.
# result_val = 0.0 # 외부 스코프에 변수 선언
# elapsed_time_with_result = @elapsed begin
#     result_val = my_calculation(10^6)
#     # 다른 작업들...
# end
# println("소요 시간 (초): ", elapsed_time_with_result)
# println("저장된 결과값: ", result_val)