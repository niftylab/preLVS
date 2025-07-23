using JSON
using Dates


# target lib/cell/directory is configured via python

# ex) python input
# libname = "logic_generated"
# cellname = "inv"
# workdir = "D:/dev/dev_nifty/laygo_mcp"
# manifest_dir = "D:/dev/dev_nifty/laygo_mcp/preLVS"
# config_path = "D:/dev/dev_nifty/laygo_mcp/preLVS/config/config_tsmcN28.yaml"

# variables
# db_dir = "D:/dev/dev_nifty/laygo_mcp/output/db/{libname}_generated_db.json"
# log_dir = "D:/dev/dev_nifty/laygo_mcp/output/out/log"
# outlogFilePath = "D:/dev/dev_nifty/laygo_mcp/output/out/log/$(libname)_$(cellname).txt"



# temp example
# libname = "logic_generated"
# cellname = "inv"
# workdir = "D:\\dev\\dev_nifty\\laygo_mcp"
# manifest_dir = "D:\\dev\\dev_nifty\\laygo_mcp\\preLVS"
# config_file_path = "D:\\dev\\dev_nifty\\laygo_mcp\\preLVS\\config\\config_tsmcN28.yaml"



# Set variables
log_dir = joinpath(workdir, "output", "out", "log")
outlogFilePath = joinpath(log_dir, "$(libname)_$(cellname).txt")

# Check if directory exists
if !isdir(manifest_dir)
    error("manifest_dir directory $manifest_dir does not exist")
end
if !isdir(log_dir)
    error("Log directory $log_dir does not exist")
end

# Include files
include(joinpath(manifest_dir, "main_functions.jl")) # main functions ver2
include(joinpath(manifest_dir, "structs", "connectivity.jl"))
include(joinpath(manifest_dir, "utils", "log.jl"))
include(joinpath(manifest_dir, "utils", "visualize.jl"))
include(joinpath(manifest_dir, "structs", "grid.jl"))



# Load config data
config_data = get_config(config_file_path)
is_detailed = true
is_manifest = true
orientation_list = get_orientation_list(config_data)
equiv_net_sets = config_data["Equivalent_net_sets"]


# 2. Create tree structure from db
root, cell_data, db_data, top_netname_list = get_tree(libname, cellname, db_dir, equiv_net_sets)

# 3. Flatten target cell
mdata, vdata = flatten_v2(libname, cellname, cell_data, db_data, orientation_list, config_data, equiv_net_sets, is_detailed)

# 3-1. Check grid consistency
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

# 4. Sort & Merge metals (vector merge)
merged_mdata, nmetals, short_error_data = sort_n_merge_MData(mdata)

# 5. Connect metals from via
cgraph = connect_metals_from_via(merged_mdata, vdata, nmetals)

# 6. Check & Report connections
cinfo, error_info, error_cnt = check_and_report_connections_bfs(cgraph, equiv_net_sets)

# 7. Create error log file
added_short_error_info = create_error_log_file(libname, cellname, outlogFilePath, error_info, cinfo, error_cnt, short_error_data)

techname = "tsmcN28"
grid_json_data = get_grid(techname, config_data, manifest_dir)
empty_grid_data = create_empty_grid_data(grid_json_data, cell_data, libname, cellname)
grid_data = get_grid_data(empty_grid_data, cinfo, top_netname_list, grid_json_data)

response = Dict{String, Any}()
response["target"] = "$libname - $cellname"
response["top_netnames"] = top_netname_list
response["grid_data"] = grid_data

JSON.json(response)