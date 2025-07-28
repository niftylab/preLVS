using JSON
using Dates


# target lib/cell/directory is configured via python

# ex) python input
# libname = "logic_generated"
# cellname = "inv"
# workdir = "D:/dev/dev_nifty/laygo_mcp"
# lvsdir = "D:/dev/dev_nifty/laygo_mcp/preLVS"
# config_path = "D:/dev/dev_nifty/laygo_mcp/preLVS/config/config_tsmcN28.yaml"

# variables
# db_dir = "D:/dev/dev_nifty/laygo_mcp/output/db/{libname}_generated_db.json"
# log_dir = "D:/dev/dev_nifty/laygo_mcp/output/out/log"
# outlogFilePath = "D:/dev/dev_nifty/laygo_mcp/output/out/log/$(libname)_$(cellname).txt"



# temp example
# libname = "logic_generated"
# cellname = "inv"
# workdir = "D:\\dev\\dev_nifty\\laygo_mcp"
# lvsdir = "D:\\dev\\dev_nifty\\laygo_mcp\\preLVS"
# config_file_path = "D:\\dev\\dev_nifty\\laygo_mcp\\preLVS\\config\\config_tsmcN28.yaml"



# Set variables
log_dir = joinpath(workdir, "output", "out", "log")
outlogFilePath = joinpath(log_dir, "$(libname)_$(cellname).txt")

# Check if directory exists
if !isdir(lvsdir)
    error("LVS directory $lvsdir does not exist")
end
if !isdir(log_dir)
    error("Log directory $log_dir does not exist")
end

# Include files
include(joinpath(lvsdir, "main_functions.jl")) # main functions ver2
include(joinpath(lvsdir, "structs", "connectivity.jl"))
include(joinpath(lvsdir, "utils", "log.jl"))
include(joinpath(lvsdir, "utils", "visualize.jl"))
include(joinpath(lvsdir, "eval", "SliceMap.jl"))


# Load config data
config_data = get_config(config_file_path)
is_detailed = true
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

_bbox = db_data[libname][cellname]["bbox"]
rgrid = create_grid([_bbox[1][1],_bbox[1][2], _bbox[2][1], _bbox[2][2]])
grid_map_string = generate_grid_maps_json(cinfo, rgrid, cellname)


# 7. Create error log file
added_short_error_info = create_error_log_file(libname, cellname, outlogFilePath, error_info, cinfo, error_cnt, short_error_data)

filepath = nothing
# 8. Visualize(optional)
if @isdefined(is_visualized) && is_visualized
    timestamp = Dates.format(now(), "yyyy-mm-dd_HH-MM-SS")
    filepath = "$(visualized_dir)/$(cellname)_$(timestamp).png"
    visualize_metals(merged_mdata.metals, orientation_list, filepath)
end

# 9. Create MCP response
response = create_mcp_lvs_response(libname, cellname, error_info, cinfo, error_cnt, is_visualized, filepath, added_short_error_info, grid_map_string)

JSON.json(response)