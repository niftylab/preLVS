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
include("utils/visualize.jl")
include("main_functions.jl") # main functions ver2
include("structs/connectivity.jl")
include("utils/log.jl")
include("structs/grid.jl")


# # command-line 입력 확인
# if length(ARGS) < 2
#     println("Usage: julia main.jl <libname> <cellname>")
#     println("Example: julia main.jl test_generated dff_2x")
#     exit(1)
# end

# REPL test 용으로  ARGS 없이 직접 변수를 넣어줌

# 0. Fetch input ARG
input_arg   = get_yaml("test_input.yaml")

is_detailed = true

# 1. Prepare JSON files and directories
libname     = input_arg["libname"] #"scan_generated"   # 라이브러리 이름
cellname    = input_arg["cellname"] #"scan_cell"  # cell 이름
techname    = input_arg["techname"] #"tsmcN28"  # tech 이름

db_dir = input_arg["db_dir"] #"db"
metal_dir = input_arg["metal_dir"] #"out/metal"
via_dir = input_arg["via_dir"] #"out/via"
visualized_dir = input_arg["visualized_dir"] #"out/visualized"
log_dir = input_arg["log_dir"] #"out/log"

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

grid_data = get_grid(techname, config_data)
println("grid_data: $(grid_data)")


println("xy_to_mn: $(xy_to_mn(grid_data, 3, 0))")


# 2. Create tree structure from the target cell
# 2.1. set equivalent net (needed to be taken over by config.yaml)
source_net_sets = [("VDD", Set(["VDD", "vdd", "VDD:"])), ("VSS", Set(["VSS", "VSS:", "vss"]))]
root, cell_data, db_data = get_tree(libname, cellname, db_dir, source_net_sets)
print_tree_root(root)



# flatten all metals + primitive pins + labels + pins without merging
mdata, vdata = flatten_v2(libname, cellname, cell_data, db_data, orientation_list, config_data, source_net_sets, is_detailed)

obstacle_mdata, top_mdata = get_metals_by_origin(grid_data, mdata)

println("obstacle_mdata: $(obstacle_mdata)")
println("top_mdata: $(top_mdata)")


merged_modata, nmetals = sort_n_merge_MData(mdata)

merged_combined_metals = get_merged_metals(grid_data, merged_modata)
println("merged_combined_metals: $(merged_combined_metals)")


top_bbox = db_data[libname][cellname]["bbox"][2]
println("top_bbox: $(top_bbox)")
# top_bbox_mn = [xy_to_mn(grid_data, 3, top_bbox[1]), xy_to_mn(grid_data, 2, top_bbox[2])]
# println("top_bbox_mn: $(top_bbox_mn)")
# top_bbox_xy = [mn_to_xy(grid_data, 3, top_bbox_mn[1]), mn_to_xy(grid_data, 2, top_bbox_mn[2])]
# println("top_bbox_xy: $(top_bbox_xy)")

grid_data["top_bbox"] = top_bbox
# grid_data["top_bbox_mn"] = top_bbox_mn
# grid_data["top_bbox_xy"] = top_bbox_xy


obstacle_modata, n_obstacle_metals = sort_n_merge_MData(obstacle_mdata)
top_modata, n_top_metals = sort_n_merge_MData(top_mdata)

merged_obstacle_metals = get_merged_metals(grid_data, obstacle_modata)
merged_top_metals = get_merged_metals(grid_data, top_modata)

# println("merged_combined_metals: $(merged_combined_metals)")
# println("top_metals: $(merged_top_metals)")
# println("obstacle_metals: $(merged_obstacle_metals)")

grid_occupation_result = analyze_grid_occupation(grid_data, merged_combined_metals)
# println("grid_occupation_result: $(grid_occupation_result)")



visualize_metals(merged_modata.metals, orientation_list, "$(visualized_dir)/$(cellname)_merged.png")
visualize_metals(top_modata.metals, orientation_list, "$(visualized_dir)/$(cellname)_top.png")
visualize_metals(obstacle_modata.metals, orientation_list, "$(visualized_dir)/$(cellname)_obstacle.png")









# cgraph = connect_metals_from_via(merged_mdata, vdata, nmetals)
# cinfo, error_info, error_cnt = check_and_report_connections_bfs(cgraph, source_net_sets)
# logfile_path = "$(log_dir)/$(libname)_$(cellname).txt"
# create_error_log_file(libname, cellname, logfile_path, error_info, cinfo, error_cnt)





# # 3. Visualize(optional)
# # visualize_metals_by_layer(merged_mdata.metals, orientation_list, "$(visualized_dir)/test_$(cellname)")
# visualize_metals(merged_mdata.metals, orientation_list, "$(visualized_dir)/$(cellname).png")



