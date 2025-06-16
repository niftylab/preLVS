# Uncomment to Download nessesary packages
# using Pkg
# Pkg.add("JSON")
# Pkg.add("JSON3")
# Pkg.add("YAML")
# Pkg.add("StaticArrays")
# Pkg.add("DataStructures")
# Pkg.add("OrderedCollections")

using JSON
include("utils/visualize.jl")
include("main_functions_test.jl") # main functions ver2


# # command-line 입력 확인
# if length(ARGS) < 2
#     println("Usage: julia main.jl <libname> <cellname>")
#     println("Example: julia main.jl test_generated dff_2x")
#     exit(1)
# end

# REPL test 용으로  ARGS 없이 직접 변수를 넣어줌

# 1. Prepare JSON files and directories
libname = "test_generated"   # 라이브러리 이름
cellname = "scan_cell"  # cell 이름

db_dir = "db"
metal_dir = "out/metal"
via_dir = "out/via"
visualized_dir = "out/visualized"

config_file_path = "config/config.yaml"

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
equivalent_net_sets = [Set(["VDD", "vdd", "VDD:"]), Set(["VSS", "VSS:", "vss"])]
root, cell_data = get_tree(libname, cellname, db_json_data, equivalent_net_sets)
print_tree_root(root)

# New: flatten and remapping label db
# TODO: integrate this part into label.jl function
memory_label            = Dict()
memory_label[libname]   = Dict()
memory_label[libname][cellname] = db_to_LData(db_json_data, libname, cellname)
root_top    = TreeNode(memory_label[libname][cellname])
create_label_tree!(root, root_top, memory_label, db_json_data, config_data)                 # -> tree of labels

# 3. Append and Merge the metal layers
metals, vias = flatten(root, cell_data, metal_dir, via_dir, db_json_data, config_data)      # -> metals + pins + primitives, vias

MData_to_merged_json(metals, "$(metal_dir)/test_$(cellname)_metals.json")


# TODO: metals(flattened) + labels -> merged metals with netname


# # 4. Visualize the merged metal layers
visualize_metals(cellname, "$(metal_dir)/test_$(cellname)_metals.json", "$(visualized_dir)/test_$(cellname)_metal_layout.png")
# visualize_vias(cellname, "$(via_dir)/$(cellname)_vias.json", "$(visualized_dir)/$(cellname)_via_layout.png", scale_factor=5.0)

