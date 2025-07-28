# Uncomment to Download nessesary packages
# using Pkg
# Pkg.add("JSON")
# Pkg.add("JSON3")
# Pkg.add("YAML")
# Pkg.add("StaticArrays")
# Pkg.add("DataStructures")
# Pkg.add("OrderedCollections")
# Pkg.add("Plots")


using JSON
using Dates
include("utils/visualize.jl")
include("main_functions.jl") # main functions ver2
include("structs/connectivity.jl")
include("utils/log.jl")
include("structs/grid.jl")
include("eval/SliceMap.jl")


# # command-line 입력 확인
# if length(ARGS) < 2
#     println("Usage: julia main.jl <libname> <cellname>")
#     println("Example: julia main.jl test_generated dff_2x")
#     exit(1)
# end

# REPL test 용으로  ARGS 없이 직접 변수를 넣어줌

# 0. Fetch input ARG
input_arg   = get_yaml("test_input.yaml")


# 1. Prepare JSON files and directories
libname     = input_arg["libname"] #"scan_generated"   # 라이브러리 이름
cellname    = input_arg["cellname"] #"scan_cell"  # cell 이름
techname    = input_arg["techname"] #"tsmcN28"  # tech 이름
is_detailed = input_arg["is_detailed"]
is_visualized = input_arg["is_visualized"]
is_manifest = input_arg["is_manifest"]

db_dir = input_arg["db_dir"] #"db"
metal_dir = input_arg["metal_dir"] #"out/metal"
via_dir = input_arg["via_dir"] #"out/via"
visualized_dir = input_arg["visualized_dir"] #"out/visualized"
log_dir = input_arg["log_dir"] #"out/log"
netlog_dir = input_arg["netlog_dir"] #"out/label"
dir_path = pwd()

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
orientation_list = get_orientation_list(config_data)

#     # libname, cellname이 db_json_data에 있는지 확인
# if !haskey(db_json_data, libname)
#     error("Library name '$libname' not found in database at $db_json_path")
#     exit(1)
# elseif !haskey(db_json_data[libname], cellname)
#     error("Cell name '$cellname' not found in library '$libname' at $db_json_path")
#     exit(1)
# end


# 2. Create tree structure from the target cell
# 2.1. set equivalent net (needed to be taken over by config.yaml)
source_net_sets = [("VDD", Set(["VDD", "vdd", "VDD:"])), ("VSS", Set(["VSS", "VSS:", "vss"]))]
root, cell_data, db_data, top_netname_list = get_tree(libname, cellname, db_dir, source_net_sets)
print_tree_root(root)



# flatten all metals + primitive pins + labels + pins without merging
mdata, vdata = flatten_v2(libname, cellname, cell_data, db_data, orientation_list, config_data, source_net_sets, is_detailed)


# Check grid consistency
grid_error_log = Vector{String}()
is_grid_consistent = check_grid_consistency(libname, cellname, db_data, orientation_list, grid_error_log, is_detailed)

if !is_grid_consistent
    for error in grid_error_log
        println(error) 
    end

    txt_path = "$(log_dir)/$(libname)_$(cellname)_grid_error_log.txt"
    open(txt_path, "w") do f
        for error in grid_error_log
            write(f, error * "\n")
        end
    end
    error("Grid consistency check failed.\n Error : $(grid_error_log)")
end



# merged_mdata, named_mvectors = sort_n_merge_MData(mdata)
merged_mdata, nmetals, short_error_data = sort_n_merge_MData(mdata)


cgraph = connect_metals_from_via(merged_mdata, vdata, nmetals)
cinfo, error_info, error_cnt = check_and_report_connections_bfs(cgraph, source_net_sets)
logfile_path = "$(log_dir)/$(libname)_$(cellname).txt"
added_short_error_info = create_error_log_file(libname, cellname, logfile_path, error_info, cinfo, error_cnt, short_error_data)


grid_json_data = get_grid(techname, config_data, dir_path)
empty_grid_data = create_empty_grid_data(grid_json_data, cell_data, libname, cellname)
grid_data = get_grid_data(empty_grid_data, cinfo, top_netname_list, grid_json_data)



# 3. Visualize(optional)
# visualize_metals_by_layer(merged_mdata.metals, orientation_list, "$(visualized_dir)/test_$(cellname)")
if @isdefined(is_visualized) && is_visualized
    timestamp = Dates.format(now(), "yyyy-mm-dd_HH-MM-SS")
    filepath = "$(visualized_dir)/$(cellname)_$(timestamp).png"
    visualize_metals(merged_mdata.metals, orientation_list, filepath)
else
    filepath = nothing
end

# response = create_mcp_lvs_response(libname, cellname, error_info, cinfo, error_cnt, is_visualized, filepath, added_short_error_info)




