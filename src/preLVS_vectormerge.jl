module preLVS_vectormerge

export runLVS, loadDB, flatten, mergeVector, generate_graph #, runLVS_wo_print
# Uncomment to Download nessesary packages
# using Pkg
# Pkg.add("JSON")
# Pkg.add("JSON3")
# Pkg.add("YAML")
# Pkg.add("StaticArrays")
# Pkg.add("DataStructures")
# Pkg.add("OrderedCollections")

using JSON
using PrecompileTools
include("utils/visualize.jl")
include("main_functions.jl") # main functions ver2
include("structs/connectivity.jl")
include("utils/log.jl")


function runLVS(path_runset::String)
    # 0. Fetch input ARG
    input_arg   = get_yaml(path_runset)

    # 1. Prepare JSON files and directories
    libname     = input_arg["libname"] #"scan_generated"   # 라이브러리 이름
    cellname    = input_arg["cellname"] #"scan_cell"  # cell 이름

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
    outlogFile      = log_dir*'/'*libname*'_'*cellname*".out"

    # 2. Create tree structure from the target cell
    # 2.1. set equivalent net (needed to be taken over by config.yaml)
    # equivalent_net_sets = [("VDD", Set(["VDD", "vdd", "VDD:"])), ("VSS", Set(["VSS", "VSS:", "vss"]))]
    equivalent_net_sets = config_data["equivalent_net_sets"]
    root, cell_data, db_data = get_tree(libname, cellname, db_dir, equivalent_net_sets)
    # print_tree_root(root)



    # flatten all metals + primitive pins + labels + pins without merging
    mdata, vdata = flatten_v2(libname, cellname, cell_data, db_data, orientation_list, config_data)

    # println("Flattened metals: $(mdata.metals)")

# ----------- Deprecated ------------- #
    # merged_mdata, named_mvectors = sort_n_merge_MData(mdata)
    # djs = connect_metals_from_via(merged_mdata, vdata)
    # groups = check_connected_sets(djs)
# -----------Current Version-------------------
    merged_mdata, nmetals = sort_n_merge_MData(mdata)
    cgraph = connect_metals_from_via(merged_mdata, vdata, nmetals)
    cinfo = check_and_report_connections_bfs(cgraph, equivalent_net_sets, outlogFile, libname, cellname)
    # for (netname, mvector_set) in groups
    #     println("Netname: $netname")
    #     for mv in mvector_set
    #         println("  MVector: $mv")
    #     end
    # end
    return cinfo 
end


# function runLVS_wo_print(path_runset::String)
#     # 0. Fetch input ARG
#     input_arg   = get_yaml(path_runset)

#     # 1. Prepare JSON files and directories
#     libname     = input_arg["libname"] #"scan_generated"   # 라이브러리 이름
#     cellname    = input_arg["cellname"] #"scan_cell"  # cell 이름

#     db_dir = input_arg["db_dir"] #"db"
#     metal_dir = input_arg["metal_dir"] #"out/metal"
#     via_dir = input_arg["via_dir"] #"out/via"
#     visualized_dir = input_arg["visualized_dir"] #"out/visualized"
#     log_dir = input_arg["log_dir"] #"out/log"

#     config_file_path = input_arg["config_file_path"] #"config/config.yaml"

#     # Check if database/config file exists
#     if !isfile("$(db_dir)/$(libname)_db.json")
#         error("Database file '$(libname)_db.json' not found in $(db_dir)")
#     end
#     if !isfile(config_file_path)
#         error("Config file not found at $config_file_path")
#     end

#     config_data = get_config(config_file_path)
#     orientation_list = get_orientation_list(config_data)
#     outlogFile = log_dir*'/'*libname*'_'*cellname*".out"

#     equivalent_net_sets = config_data["equivalent_net_sets"]
#     root, cell_data, db_data = get_tree(libname, cellname, db_dir, equivalent_net_sets)

#     mdata, vdata = flatten_v2(libname, cellname, cell_data, db_data, orientation_list, config_data)
#     merged_mdata, nmetals = sort_n_merge_MData(mdata)
#     cgraph = connect_metals_from_via(merged_mdata, vdata, nmetals)
#     cinfo = check_and_report_connections_bfs_wo_print(cgraph, outlogFile)
#     return cinfo
# end    



function loadDB(path_runset::String)
    # 0. Fetch input ARG
    input_arg   = get_yaml(path_runset)

    # 1. Prepare JSON files and directories
    libname     = input_arg["libname"] #"scan_generated"   # 라이브러리 이름
    cellname    = input_arg["cellname"] #"scan_cell"  # cell 이름

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


    # 2. Create tree structure from the target cell
    # 2.1. set equivalent net (needed to be taken over by config.yaml)
    # equivalent_net_sets = [("VDD", Set(["VDD", "vdd", "VDD:"])), ("VSS", Set(["VSS", "VSS:", "vss"]))]
    equivalent_net_sets = config_data["equivalent_net_sets"]
    root, cell_data, db_data = get_tree(libname, cellname, db_dir, equivalent_net_sets)
    # print_tree_root(root)

    return root, cell_data, db_data 
end

function flatten(path_runset::String)
    # 0. Fetch input ARG
    input_arg   = get_yaml(path_runset)

    # 1. Prepare JSON files and directories
    libname     = input_arg["libname"] #"scan_generated"   # 라이브러리 이름
    cellname    = input_arg["cellname"] #"scan_cell"  # cell 이름

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


    # 2. Create tree structure from the target cell
    # 2.1. set equivalent net (needed to be taken over by config.yaml)
    # equivalent_net_sets = [("VDD", Set(["VDD", "vdd", "VDD:"])), ("VSS", Set(["VSS", "VSS:", "vss"]))]
    equivalent_net_sets = config_data["equivalent_net_sets"]
    root, cell_data, db_data = get_tree(libname, cellname, db_dir, equivalent_net_sets)
    # print_tree_root(root)

    # flatten all metals + primitive pins + labels + pins without merging
    mdata, vdata = flatten_v2(libname, cellname, cell_data, db_data, orientation_list, config_data)

    return mdata, vdata 
end

function mergeVector(path_runset::String)
    # 0. Fetch input ARG
    input_arg   = get_yaml(path_runset)

    # 1. Prepare JSON files and directories
    libname     = input_arg["libname"] #"scan_generated"   # 라이브러리 이름
    cellname    = input_arg["cellname"] #"scan_cell"  # cell 이름

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


    # 2. Create tree structure from the target cell
    # 2.1. set equivalent net (needed to be taken over by config.yaml)
    # equivalent_net_sets = [("VDD", Set(["VDD", "vdd", "VDD:"])), ("VSS", Set(["VSS", "VSS:", "vss"]))]
    equivalent_net_sets = config_data["equivalent_net_sets"]
    root, cell_data, db_data = get_tree(libname, cellname, db_dir, equivalent_net_sets)
    # print_tree_root(root)

    # flatten all metals + primitive pins + labels + pins without merging
    mdata, vdata = flatten_v2(libname, cellname, cell_data, db_data, orientation_list, config_data)

    # println("Flattened metals: $(mdata.metals)")

    merged_mdata, nmetals = sort_n_merge_MData(mdata)

    return merged_mdata, nmetals
end


function generate_graph(path_runset::String)
    # 0. Fetch input ARG
    input_arg   = get_yaml(path_runset)

    # 1. Prepare JSON files and directories
    libname     = input_arg["libname"] #"scan_generated"   # 라이브러리 이름
    cellname    = input_arg["cellname"] #"scan_cell"  # cell 이름

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


    # 2. Create tree structure from the target cell
    # 2.1. set equivalent net (needed to be taken over by config.yaml)
    # equivalent_net_sets = [("VDD", Set(["VDD", "vdd", "VDD:"])), ("VSS", Set(["VSS", "VSS:", "vss"]))]
    equivalent_net_sets = config_data["equivalent_net_sets"]
    root, cell_data, db_data = get_tree(libname, cellname, db_dir, equivalent_net_sets)
    # print_tree_root(root)

    # flatten all metals + primitive pins + labels + pins without merging
    mdata, vdata = flatten_v2(libname, cellname, cell_data, db_data, orientation_list, config_data)

    # println("Flattened metals: $(mdata.metals)")

    merged_mdata, nmetals = sort_n_merge_MData(mdata)

    cgraph = connect_metals_from_via(merged_mdata, vdata, nmetals)

    return cgraph
end

# 3. Visualize(optional)
# function visualize()
#    visualize_metals_by_layer(merged_mdata.metals, orientation_list, "$(visualized_dir)/test_$(cellname)")
#    visualize_metals(merged_mdata.metals, orientation_list, "$(visualized_dir)/test_$(cellname).png")
# end
# --- PrecompileTools 워크로드 ---
@setup_workload begin
    println("Setting up preLVS_vectorMerge precompile workload...")
    # 샘플 데이터/설정 생성 (파일 읽기 X)
    # sample_config = Dict("threshold" => 0.75, "mode" => "fast")
    # sample_db_string = """[{"id": "A", "value": 10}, {"id": "B", "value": 20}]"""
    # sample_type_data = [1.1, 2.2]

    # 워크로드 내에서 사용할 임시 파일 경로 (필요하다면)
    sample_data_path = joinpath(@__DIR__, "..", "benchmark", "bench_input.yaml")
    println("sample data path: $(sample_data_path)")
    # @__DIR__ -> /path/to/MyProject/src
    # .. -> /path/to/MyProject
    # data -> /path/to/MyProject/config
    # 결과: /path/to/MyProject/config/sample_for_precompile.yaml
    @compile_workload begin
        println("Running preLVS_vectorMerge precompile workload...")
        # 실제 함수 호출 (샘플 데이터 사용)
        cinfo                           = runLVS(sample_data_path)
        println("   Running runLVS precompile complete...")
        root, cell_data, db_data        = loadDB(sample_data_path)
        println("   Running loadDB precompile complete...")
        mdata, vdata                    = flatten(sample_data_path)
        println("   Running flatten precompile complete...")
        merged_mdata, named_mvectors    = mergeVector(sample_data_path)
        println("   Running mergeVector precompile complete...")
        cgraph                          = generate_graph(sample_data_path)
        println("   Running generate_graph precompile complete...")
        # ... 다른 핵심 함수들 호출 ...
    end
    # ### `@setup_workload` 블록의 끝은 `@compile_workload` 블록 *뒤*에 와야 합니다. ###
    println("Finished preLVS_vectorMerge precompile workload setup.")
end # @setup_workload 블록의 끝
# --- 워크로드 끝 ---

end # module preLVS_vectormerge
