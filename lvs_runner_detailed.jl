using JSON



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
db_dir = joinpath(workdir, "output", "db")
log_dir = joinpath(workdir, "output", "out", "log")
outlogFilePath = joinpath(log_dir, "$(libname)_$(cellname).txt")

# Check if directory exists
if !isdir(lvsdir)
    error("LVS directory $lvsdir does not exist")
end
if !isdir(db_dir)
    error("DB directory $db_dir does not exist")
end
if !isdir(log_dir)
    error("Log directory $log_dir does not exist")
end

# Include files
include(joinpath(lvsdir, "main_functions.jl")) # main functions ver2
include(joinpath(lvsdir, "structs", "connectivity.jl"))
include(joinpath(lvsdir, "utils", "log.jl"))



# Load config data
config_data = get_config(config_file_path)
is_detailed = true
orientation_list = get_orientation_list(config_data)
equiv_net_sets = config_data["Equivalent_net_sets"]


# 2. Create tree structure from db
root, cell_data, db_data = get_tree(libname, cellname, db_dir, equiv_net_sets)

# 3. Flatten target cell
mdata, vdata = flatten_v2(libname, cellname, cell_data, db_data, orientation_list, config_data, equiv_net_sets, is_detailed)

# 4. Sort & Merge metals (vector merge)
merged_mdata, nmetals = sort_n_merge_MData(mdata)

# 5. Connect metals from via
cgraph = connect_metals_from_via(merged_mdata, vdata, nmetals)

# 6. Check & Report connections
cinfo, error_info, error_cnt = check_and_report_connections_bfs(cgraph, equiv_net_sets)

# 7. Create error log file
create_error_log_file(libname, cellname, outlogFilePath, error_info, cinfo, error_cnt)


# Return results as JSON string
result = Dict{String, Any}(
    "status" => "completed",
    "target" => "$libname - $cellname",
    "error_count" => error_cnt,
    "error_info" => error_info,
    "cgraph" => cinfo
)

JSON.json(result)

# println(result)