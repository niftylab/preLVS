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

# 0. Fetch input ARG
runset = "config/test_input.yaml"
# 1. Fetch input ARGS
if isa(runset, String)
    input_arg   = get_yaml(runset)
elseif isa(runset, Dict)
    input_arg = runset
else
    error("Invalid input type. Expected String or Dict.")
end

# Initialize variables
libname = input_arg["libname"]
cellname = input_arg["cellname"]
db_dir = input_arg["db_dir"]
metal_dir = input_arg["metal_dir"]
via_dir = input_arg["via_dir"]
visualized_dir = input_arg["visualized_dir"]
log_dir = input_arg["log_dir"]
netlog_dir = input_arg["netlog_dir"]
config_file_path = input_arg["config_file_path"]


# Check if database/config file exists
if !isfile("$(db_dir)/$(libname)_db.json")
    error("Database file '$(libname)_db.json' not found in $(db_dir)")
end
if !isfile(config_file_path)
    error("Config file not found at $config_file_path")
end

# Load config data
config_data = get_config(config_file_path)
equiv_net_sets = config_data["Equivalent_net_sets"]

events    = Vector{Event}()
hash_rect = Vector{Rect}()
overlaps  = Dict{Int, Vector{Int}}()
via_link  = Dict{Int, Tuple{Int, Int}}()
error_log = Vector{ErrorEvent}()
cgraph    = Dict{Int, GraphNode}()


# 2. Create tree structure from db
root, inst_flatten, cell_list, db_data = get_tree(libname, cellname, db_dir, equiv_net_sets)
println("Generated tree structure from db\n")

# 3. Flatten target cell
mflat, vflat, lflat = flatten_V2(inst_flatten, cell_list, db_data, config_data, equiv_net_sets)
println("Rect transform complete\n")

# 4. Create Events
events, hash_rect = create_events(inst_flatten, mflat, vflat, lflat, config_data)
events_sorted = sort(events, by=event_sort_priority)
println("Event align complete")

# 5. Process Events
djs, overlaps, via_link, error_log, pinNodes= process_events(events_sorted, hash_rect)
println("sweepline-based grouping complete\n")

# 6. Generate Graph
cgraph = generate_graph(overlaps, via_link, hash_rect, djs)
println("connectivity graph generation complete")

# 7. Check Connections
error_log, error_cnt, nets_visited = check_connections_bfs(cgraph, pinNodes, hash_rect, equiv_net_sets)
println("graph analysis using BFS complete")