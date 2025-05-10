module preLVS_sweepline

export loadDB, flatten, alignEvents, generate_graph, runLVS

using JSON
using YAML
using PrecompileTools: @setup_workload, @compile_workload

#include("utils/visualize.jl")
include("sweepline/flatten.jl")
include("sweepline/sweepline.jl")
include("sweepline/connectivity.jl")

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

    return root, inst_flatten, cell_list, db_data
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

    return mflat, vflat, lflat
end

function alignEvents(runset::Union{String, Dict})

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

    return events_sorted, hash_rect
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

    return cgraph, hash_rect
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
    error_log, error_cnt, hash_rect, nets_visited = check_connections_bfs(cgraph, pinNodes, hash_rect, equiv_net_sets)
    println("graph analysis using BFS complete")

    # 8. Create Error Log File
    create_error_log_file(error_log, error_cnt, log_dir, libname, cellname, hash_rect, nets_visited, djs)
    println("error log file created")

    return error_log, cgraph, hash_rect
end

# function visualize_result()
    # # 4. Visualize the merged metal layers
    # visualize_metals(cellname, "$(metal_dir)/$(cellname)_metals.json", "$(visualized_dir)/$(cellname)_metal_layout.png")
    # visualize_vias(cellname, "$(via_dir)/$(cellname)_vias.json", "$(visualized_dir)/$(cellname)_via_layout.png", scale_factor=5.0)
# end



# --- PrecompileTools 워크로드 ---
@setup_workload begin
    println("Setting up preLVS_sweepline precompile workload...")
    # 샘플 데이터/설정 생성 (파일 읽기 X)
    # sample_config = Dict("threshold" => 0.75, "mode" => "fast")
    # sample_db_string = """[{"id": "A", "value": 10}, {"id": "B", "value": 20}]"""
    # sample_type_data = [1.1, 2.2]

    # 워크로드 내에서 사용할 임시 파일 경로 (필요하다면)
    sample_data_path = joinpath(@__DIR__, "..", "config", "test_input.yaml")
    # @__DIR__ -> /path/to/preLVS_sweepline/src
    # .. -> /path/to/preLVS_sweepline
    # data -> /path/to/preLVS_sweepline/data
    # 결과: /path/to/preLVS_sweepline/data/sample_for_precompile.json
    # data = JSON.parsefile(sample_data_path) # 예시
    #   ...
    # ### 이 부분을 수정해야 합니다: `@compile_workload`는 `@setup_workload` 블록 안에 있어야 합니다. ###
    @compile_workload begin
        println("Running preLVS_sweepline precompile workload...\n")
        # 실제 함수 호출 (샘플 데이터 사용)
        root, inst_flatten, cell_list, db_data = loadDB(sample_data_path)
        println("   Running loadDB compile script complete")
        mdata, vdata, ldata = flatten(sample_data_path)
        println("   Running flatten compile script complete")
        events_sorted, hash_rect = alignEvents(sample_data_path)
        println("   Running alignEvents compile script complete")
        cgraph, hash_rect = generate_graph(sample_data_path)
        println("   Running generate_graph compile script complete")
        error_log, cgraph, hash_rect = runLVS(sample_data_path)
        println("   Running runLVS compile script complete")
    end
    # ### `@setup_workload` 블록의 끝은 `@compile_workload` 블록 *뒤*에 와야 합니다. ###
    println("Finished preLVS_sweepline precompile workload setup.")
end # @setup_workload 블록의 끝
# --- 워크로드 끝 ---

end # module preLVS_sweepline
