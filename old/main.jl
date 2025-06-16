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
include("main_functions.jl")


# command-line 입력 확인
if length(ARGS) < 2
    println("Usage: julia main.jl <libname> <cellname>")
    println("Example: julia main.jl test_generated dff_2x")
    exit(1)
end



# 1. Prepare JSON files and directories
libname = ARGS[1]   # 라이브러리 이름
cellname = ARGS[2]  # cell 이름

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
db_json_path = "$(db_dir)/$(libname)_db.json"
db_json_data = JSON.parse(read(db_json_path, String))

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
root, cell_data = get_tree(libname, cellname, db_json_path, equivalent_net_sets)
print_tree_root(root)

# 3. Append and Merge the metal layers
flatten(root, cell_data, metal_dir, via_dir, db_json_path, config_file_path)


# 4. Visualize the merged metal layers
visualize_metals(cellname, "$(metal_dir)/$(cellname)_metals.json", "$(visualized_dir)/$(cellname)_metal_layout.png")
visualize_vias(cellname, "$(via_dir)/$(cellname)_vias.json", "$(visualized_dir)/$(cellname)_via_layout.png", scale_factor=5.0)

