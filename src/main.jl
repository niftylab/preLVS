# Uncomment to Download nessesary packages
# using Pkg
# Pkg.add("JSON")
# Pkg.add("JSON3")
# Pkg.add("YAML")
# Pkg.add("StaticArrays")
# Pkg.add("DataStructures")
# Pkg.add("OrderedCollections")

using JSON
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
path_runset = "config/test_input.yaml"
input_arg   = get_yaml(path_runset)
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
db_json_path    = "$(db_dir)/$(libname)_db.json"
db_json_data    = JSON.parse(read(db_json_path, String))
config_data     = get_config(config_file_path)

    # libname, cellname이 db_json_data에 있는지 확인
if !haskey(db_json_data, libname)
    error("Library name '$libname' not found in database at $db_json_path")
    exit(1)
elseif !haskey(db_json_data[libname], cellname)
    error("Cell name '$cellname' not found in library '$libname' at $db_json_path")
    exit(1)
end


# 2. Create tree structure from the target cell
# 2.1. set equivalent net (needed to be taken over by config.yaml)
equivalent_net_sets = [("VDD:", Set(["VDD", "vdd", "VDD:"])), ("VSS:", Set(["VSS", "VSS:", "vss"]))]
# pass this through config_data
config_data["equivalent_net_sets"] = equivalent_net_sets
events    = Vector{Event}()
hash_rect = Vector{Rect}()
overlaps  = Dict{Int, Vector{Int}}()
via_link  = Dict{Int, Tuple{Int, Int}}()
cgraph    = Dict{Int, GraphNode}()

root, inst_flatten, cell_list, db_data = get_tree(libname, cellname, db_dir, equivalent_net_sets)
#    print_tree_root(root)

mflat, vflat, lflat = flatten_V2(inst_flatten, cell_list, db_data, config_data, equivalent_net_sets)
println("Rect transform complete\n")
#-------------------------------------------------------------
# 3. Create Events
events, hash_rect = create_events(inst_flatten, mflat, vflat, lflat, config_data)
events_sorted = sort(events, by=event_sort_priority)
println("Event align complete")
djs, overlaps, via_link, error_log, pinNodes = process_events(events_sorted, hash_rect) 
println("sweepline-based grouping complete\n")
cgraph = generate_graph(overlaps, via_link, hash_rect, djs)
println("connectivity graph generation complete")
error_log, nets_visited = check_connections_bfs(cgraph, pinNodes, hash_rect)
println("graph analysis using BFS complete")
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