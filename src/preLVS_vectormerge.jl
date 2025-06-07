module preLVS_vectormerge

export loadDB, flatten, mergeVector, generate_graph, runLVS, runLVS_wo_log
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



function loadDB(runset::Union{String, Dict})

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
    outlogFilePath      = log_dir*'/'*libname*'_'*cellname*".txt"


    # Check if database/config file exists
    if !isfile("$(db_dir)/$(libname)_db.json")
        error("Database file '$(libname)_db.json' not found in $(db_dir)")
    end
    if !isfile(config_file_path)
        error("Config file not found at $config_file_path")
    end

    # Load config data
    config_data = get_config(config_file_path)
    orientation_list = get_orientation_list(config_data)
    equiv_net_sets = config_data["Equivalent_net_sets"]


    # 2. Create tree structure from db
    root, cell_data, db_data = get_tree(libname, cellname, db_dir, equiv_net_sets)

    return root, cell_data, db_data
end

function flatten(runset::Union{String, Dict})

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
    outlogFilePath      = log_dir*'/'*libname*'_'*cellname*".txt"


    # Check if database/config file exists
    if !isfile("$(db_dir)/$(libname)_db.json")
        error("Database file '$(libname)_db.json' not found in $(db_dir)")
    end
    if !isfile(config_file_path)
        error("Config file not found at $config_file_path")
    end

    # Load config data
    config_data = get_config(config_file_path)
    orientation_list = get_orientation_list(config_data)
    equiv_net_sets = config_data["Equivalent_net_sets"]


    # 2. Create tree structure from db
    root, cell_data, db_data = get_tree(libname, cellname, db_dir, equiv_net_sets)

    # 3. Flatten target cell
    mdata, vdata = flatten_v2(libname, cellname, cell_data, db_data, orientation_list, config_data, equiv_net_sets)

    return mdata, vdata 
end

function mergeVector(runset::Union{String, Dict})
    
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
    outlogFilePath      = log_dir*'/'*libname*'_'*cellname*".txt"


    # Check if database/config file exists
    if !isfile("$(db_dir)/$(libname)_db.json")
        error("Database file '$(libname)_db.json' not found in $(db_dir)")
    end
    if !isfile(config_file_path)
        error("Config file not found at $config_file_path")
    end

    # Load config data
    config_data = get_config(config_file_path)
    orientation_list = get_orientation_list(config_data)
    equiv_net_sets = config_data["Equivalent_net_sets"]


    # 2. Create tree structure from db
    root, cell_data, db_data = get_tree(libname, cellname, db_dir, equiv_net_sets)

    # 3. Flatten target cell
    mdata, vdata = flatten_v2(libname, cellname, cell_data, db_data, orientation_list, config_data, equiv_net_sets)

    # 4. Sort & Merge metals (vector merge)
    merged_mdata, nmetals = sort_n_merge_MData(mdata)

    return merged_mdata, nmetals
end


function generate_graph(runset::Union{String, Dict})

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
    outlogFilePath      = log_dir*'/'*libname*'_'*cellname*".txt"


    # Check if database/config file exists
    if !isfile("$(db_dir)/$(libname)_db.json")
        error("Database file '$(libname)_db.json' not found in $(db_dir)")
    end
    if !isfile(config_file_path)
        error("Config file not found at $config_file_path")
    end

    # Load config data
    config_data = get_config(config_file_path)
    orientation_list = get_orientation_list(config_data)
    equiv_net_sets = config_data["Equivalent_net_sets"]


    # 2. Create tree structure from db
    root, cell_data, db_data = get_tree(libname, cellname, db_dir, equiv_net_sets)

    # 3. Flatten target cell
    mdata, vdata = flatten_v2(libname, cellname, cell_data, db_data, orientation_list, config_data, equiv_net_sets)

    # 4. Sort & Merge metals (vector merge)
    merged_mdata, nmetals = sort_n_merge_MData(mdata)

    # 5. Connect metals from via
    cgraph = connect_metals_from_via(merged_mdata, vdata, nmetals)

    return cgraph
end

function runLVS(runset::Union{String, Dict})

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
    outlogFilePath      = log_dir*'/'*libname*'_'*cellname*".txt"


    # Check if database/config file exists
    if !isfile("$(db_dir)/$(libname)_db.json")
        error("Database file '$(libname)_db.json' not found in $(db_dir)")
    end
    if !isfile(config_file_path)
        error("Config file not found at $config_file_path")
    end

    # Load config data
    config_data = get_config(config_file_path)
    orientation_list = get_orientation_list(config_data)
    equiv_net_sets = config_data["Equivalent_net_sets"]


    # 2. Create tree structure from db
    root, cell_data, db_data = get_tree(libname, cellname, db_dir, equiv_net_sets)

    # 3. Flatten target cell
    mdata, vdata = flatten_v2(libname, cellname, cell_data, db_data, orientation_list, config_data, equiv_net_sets)

    # 4. Sort & Merge metals (vector merge)
    merged_mdata, nmetals = sort_n_merge_MData(mdata)

    # 5. Connect metals from via
    cgraph = connect_metals_from_via(merged_mdata, vdata, nmetals)

    # 6. Check & Report connections
    cinfo, error_info, error_cnt = check_and_report_connections_bfs(cgraph, equiv_net_sets)

    # 7. Create error log file
    create_error_log_file(libname, cellname, outlogFilePath, error_info, cinfo, error_cnt)

    return cinfo, error_info, error_cnt
end

function runLVS_wo_log(runset::Union{String, Dict})

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
    outlogFilePath      = log_dir*'/'*libname*'_'*cellname*".txt"


    # Check if database/config file exists
    if !isfile("$(db_dir)/$(libname)_db.json")
        error("Database file '$(libname)_db.json' not found in $(db_dir)")
    end
    if !isfile(config_file_path)
        error("Config file not found at $config_file_path")
    end

    # Load config data
    config_data = get_config(config_file_path)
    orientation_list = get_orientation_list(config_data)
    equiv_net_sets = config_data["Equivalent_net_sets"]


    # 2. Create tree structure from db
    root, cell_data, db_data = get_tree(libname, cellname, db_dir, equiv_net_sets)

    # 3. Flatten target cell
    mdata, vdata = flatten_v2(libname, cellname, cell_data, db_data, orientation_list, config_data, equiv_net_sets)

    # 4. Sort & Merge metals (vector merge)
    merged_mdata, nmetals = sort_n_merge_MData(mdata)

    # 5. Connect metals from via
    cgraph = connect_metals_from_via(merged_mdata, vdata, nmetals)

    # 6. Check & Report connections
    cinfo, error_info, error_cnt = check_and_report_connections_bfs(cgraph, equiv_net_sets)

    return cinfo, error_info, error_cnt
end



# Visualize(optional)
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
    sample_data_path = joinpath(@__DIR__, "..", "config", "example_input.yaml")
    println("sample data path: $(sample_data_path)")
    # @__DIR__ -> /path/to/MyProject/src
    # .. -> /path/to/MyProject
    # data -> /path/to/MyProject/config
    # 결과: /path/to/MyProject/config/sample_for_precompile.yaml
    @compile_workload begin
        println("Running preLVS_vectorMerge precompile workload...")
        # 실제 함수 호출 (샘플 데이터 사용)
        root, cell_data, db_data        = loadDB(sample_data_path)
        println("   Running loadDB precompile complete...")
        mdata, vdata                    = flatten(sample_data_path)
        println("   Running flatten precompile complete...")
        merged_mdata, nmetals           = mergeVector(sample_data_path)
        println("   Running mergeVector precompile complete...")
        cgraph                          = generate_graph(sample_data_path)
        println("   Running generate_graph precompile complete...")
        cinfo, error_info, error_cnt    = runLVS(sample_data_path)
        println("   Running runLVS precompile complete...")
        cinfo, error_info, error_cnt    = runLVS_wo_log(sample_data_path)
        println("   Running runLVS_wo_log precompile complete...")
    end
    # ### `@setup_workload` 블록의 끝은 `@compile_workload` 블록 *뒤*에 와야 합니다. ###
    println("Finished preLVS_vectorMerge precompile workload setup.")
end # @setup_workload 블록의 끝
# --- 워크로드 끝 ---

end # module preLVS_vectormerge
