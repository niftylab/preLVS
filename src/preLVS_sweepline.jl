module preLVS_sweepline

export loadDB, flatten, alignEvents, generate_graph, runLVS

using JSON
using YAML
using PrecompileTools: @setup_workload, @compile_workload
#include("utils/visualize.jl")
include("sweepline/flatten.jl")
include("sweepline/sweepline.jl")
include("sweepline/connectivity.jl")

function loadDB(path_runset::String)
    # 0. Fetch input ARG
    input_arg   = get_yaml(path_runset)
    # 1. Prepare JSON files and directories
    libname     = input_arg["libname"]#"test_generated"   # 라이브러리 이름
    cellname    = input_arg["cellname"]#"scan_cell"  # cell 이름
    
    db_dir = input_arg["db_dir"] #"db"
    metal_dir = input_arg["metal_dir"] #"out/metal"
    via_dir = input_arg["via_dir"] #"out/via"
    visualized_dir = input_arg["visualized_dir"] #"out/visualized"
    
    netlog_dir = input_arg["netlog_dir"]
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
    
    
    # 2. Create tree structure from the target cell
    # 2.1. set equivalent net (needed to be taken over by config.yaml)
    equivalent_net_sets = [("VDD", Set(["VDD", "vdd", "VDD:"])), ("VSS", Set(["VSS", "VSS:", "vss"]))]
    # pass this through config_data
    config_data["equivalent_net_sets"] = equivalent_net_sets
    # cell_data is currently deprecated (planned for hierarchical LVS which is dropped)
    # TODO: remove cell_data part
    # declare main func variables for preserve retuned data from @elapsed block
    
    events    = Vector{Event}()
    hash_rect = Vector{Rect}()
    overlaps  = Dict{Int, Vector{Int}}()
    via_link  = Dict{Int, Tuple{Int, Int}}()
    error_log = Vector{ErrorEvent}()
    cgraph    = Dict{Int, GraphNode}()
    
    root, inst_flatten, cell_list, db_data = get_tree(libname, cellname, db_dir, equivalent_net_sets)

    return root, inst_flatten, cell_list, db_data
end

function flatten(path_runset::String)
    # 0. Fetch input ARG
    input_arg   = get_yaml(path_runset)
    # 1. Prepare JSON files and directories
    libname     = input_arg["libname"]#"test_generated"   # 라이브러리 이름
    cellname    = input_arg["cellname"]#"scan_cell"  # cell 이름
    
    db_dir = input_arg["db_dir"] #"db"
    metal_dir = input_arg["metal_dir"] #"out/metal"
    via_dir = input_arg["via_dir"] #"out/via"
    visualized_dir = input_arg["visualized_dir"] #"out/visualized"
    
    netlog_dir = input_arg["netlog_dir"]
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
    
    
    # 2. Create tree structure from the target cell
    # 2.1. set equivalent net (needed to be taken over by config.yaml)
    equivalent_net_sets = [("VDD", Set(["VDD", "vdd", "VDD:"])), ("VSS", Set(["VSS", "VSS:", "vss"]))]
    # pass this through config_data
    config_data["equivalent_net_sets"] = equivalent_net_sets
    # cell_data is currently deprecated (planned for hierarchical LVS which is dropped)
    # TODO: remove cell_data part
    # declare main func variables for preserve retuned data from @elapsed block
    
    events    = Vector{Event}()
    hash_rect = Vector{Rect}()
    overlaps  = Dict{Int, Vector{Int}}()
    via_link  = Dict{Int, Tuple{Int, Int}}()
    error_log = Vector{ErrorEvent}()
    cgraph    = Dict{Int, GraphNode}()
    
    root, inst_flatten, cell_list, db_data = get_tree(libname, cellname, db_dir, equivalent_net_sets)
#    print_tree_root(root)
    
    # memory_metal, memory_via, memory_label = create_rect_table(cell_list, db_json_data, config_data)
    # root_rect = create_rect_tree(root, memory_metal, memory_label, memory_via, config_data)
    # println("rect transform complete\n")
    
    
    # for (lib, cells) in cell_data
    #     for (cell, cell_data) in cells
    #         println("lib: $lib, cell: $cell")
    #         for (idx, data) in cell_data
    #             println("idx: $idx, name: $(data["instname"])")
    #         end
    #     end
    # end
    
    mflat, vflat, lflat = flatten_V2(inst_flatten, cell_list, db_data, config_data, equivalent_net_sets)

    println("flatten complete\n")
    return mflat, vflat, lflat
end

function alignEvents(path_runset::String)
    # 0. Fetch input ARG
    input_arg   = get_yaml(path_runset)
    # 1. Prepare JSON files and directories
    libname     = input_arg["libname"]#"test_generated"   # 라이브러리 이름
    cellname    = input_arg["cellname"]#"scan_cell"  # cell 이름

    db_dir = input_arg["db_dir"] #"db"
    metal_dir = input_arg["metal_dir"] #"out/metal"
    via_dir = input_arg["via_dir"] #"out/via"
    visualized_dir = input_arg["visualized_dir"] #"out/visualized"

    netlog_dir = input_arg["netlog_dir"]
    config_file_path = input_arg["config_file_path"] #"config/config.yaml"

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
    equivalent_net_sets = [("VDD", Set(["VDD", "vdd", "VDD:"])), ("VSS", Set(["VSS", "VSS:", "vss"]))]
    # pass this through config_data
    config_data["equivalent_net_sets"] = equivalent_net_sets
    events    = Vector{Event}()
    hash_rect = Vector{Rect}()
    overlaps  = Dict{Int, Vector{Int}}()
    via_link  = Dict{Int, Tuple{Int, Int}}()
    error_log = Vector{ErrorEvent}()
    cgraph    = Dict{Int, GraphNode}()

    root, inst_flatten, cell_list, db_data = get_tree(libname, cellname, db_dir, equivalent_net_sets)
    #    print_tree_root(root)

    mflat, vflat, lflat = flatten_V2(inst_flatten, cell_list, db_data, config_data, equivalent_net_sets)
    println("Rect transform complete\n")
    #-------------------------------------------------------------
    # 3. Create Events
    events, hash_rect = create_events(inst_flatten, mflat, vflat, lflat, config_data)
    events_sorted = sort(events, by=event_sort_priority)
    println("Event align complete")
    return events_sorted, hash_rect
end

function generate_graph(path_runset::String)
    # 0. Fetch input ARG
    input_arg   = get_yaml(path_runset)
    # 1. Prepare JSON files and directories
    libname     = input_arg["libname"]#"test_generated"   # 라이브러리 이름
    cellname    = input_arg["cellname"]#"scan_cell"  # cell 이름

    db_dir = input_arg["db_dir"] #"db"
    metal_dir = input_arg["metal_dir"] #"out/metal"
    via_dir = input_arg["via_dir"] #"out/via"
    visualized_dir = input_arg["visualized_dir"] #"out/visualized"

    netlog_dir = input_arg["netlog_dir"]
    config_file_path = input_arg["config_file_path"] #"config/config.yaml"

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
    equivalent_net_sets = [("VDD:", Set(["VDD", "vdd", "VDD:"])), ("VSS:", Set(["VSS", "VSS:", "vss"]))]
    # pass this through config_data
    config_data["equivalent_net_sets"] = equivalent_net_sets
    events    = Vector{Event}()
    hash_rect = Vector{Rect}()
    overlaps  = Dict{Int, Vector{Int}}()
    via_link  = Dict{Int, Tuple{Int, Int}}()
    error_log = Vector{ErrorEvent}()
    cgraph    = Dict{Int, GraphNode}()

    root, inst_flatten, cell_list, db_data = get_tree(libname, cellname, db_dir, equivalent_net_sets)
    #    print_tree_root(root)

    mflat, vflat, lflat = flatten_V2(inst_flatten, cell_list, db_data, config_data, equivalent_net_sets)
    println("Rect transform complete\n")
    #-------------------------------------------------------------
    # 3. Create Events
    events, hash_rect = create_events(inst_flatten, mflat, vflat, lflat, config_data)
    events_sorted = sort(events, by=event_sort_priority)
    println("Event align complete")
    djs, overlaps, via_link, error_log, pinNodes = process_events(events_sorted, hash_rect) 
    println("sweepline-based grouping complete\n")
    cgraph = generate_graph(overlaps, via_link, hash_rect, djs)
    println("connectivity graph generation complete")
    return cgraph, hash_rect
end

function runLVS(path_runset::String)
    # 0. Fetch input ARG
    input_arg   = get_yaml(path_runset)
    # 1. Prepare JSON files and directories
    libname     = input_arg["libname"]#"test_generated"   # 라이브러리 이름
    cellname    = input_arg["cellname"]#"scan_cell"  # cell 이름

    db_dir = input_arg["db_dir"] #"db"
    metal_dir = input_arg["metal_dir"] #"out/metal"
    via_dir = input_arg["via_dir"] #"out/via"
    visualized_dir = input_arg["visualized_dir"] #"out/visualized"

    netlog_dir = input_arg["netlog_dir"]
    config_file_path = input_arg["config_file_path"] #"config/config.yaml"

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
    equivalent_net_sets = [("VDD:", Set(["VDD", "vdd", "VDD:"])), ("VSS:", Set(["VSS", "VSS:", "vss"]))]
    # pass this through config_data
    config_data["equivalent_net_sets"] = equivalent_net_sets
    events    = Vector{Event}()
    hash_rect = Vector{Rect}()
    overlaps  = Dict{Int, Vector{Int}}()
    via_link  = Dict{Int, Tuple{Int, Int}}()
    error_log = Vector{ErrorEvent}()
    cgraph    = Dict{Int, GraphNode}()

    root, inst_flatten, cell_list, db_data = get_tree(libname, cellname, db_dir, equivalent_net_sets)
    #    print_tree_root(root)

    mflat, vflat, lflat = flatten_V2(inst_flatten, cell_list, db_data, config_data, equivalent_net_sets)
    println("Rect transform complete\n")
    #-------------------------------------------------------------
    # 3. Create Events
    events, hash_rect = create_events(inst_flatten, mflat, vflat, lflat, config_data)
    events_sorted = sort(events, by=event_sort_priority)
    println("Event align complete")
    djs, overlaps, via_link, error_log, pinNodes = process_events(events_sorted, hash_rect) 
    println("sweepline-based grouping complete\n")
    cgraph = generate_graph(overlaps, via_link, hash_rect, djs)
    println("connectivity graph generation complete")
    error_log, nets_visited = check_connections_bfs(cgraph, pinNodes, hash_rect)
    println("graph analysis using BFS complete")

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
        println("Running preLVS_sweepline precompile workload...")
        # 실제 함수 호출 (샘플 데이터 사용)
        root, inst_flatten, cell_list, db_data = loadDB(sample_data_path)
        println("   Running loadDB compile script complete")
        mdata, vdata, ldata = flatten(sample_data_path)
        println("   Running flatten compile script complete")
        events_sorted, hash_rect = alignEvents(sample_data_path)
        println("   Running alignEvents compile script complete")
        cgraph, hash_rect = generate_graph(sample_data_path)
        println("   Running generate_graph compile script complete")
        cgraph, hash_rect = runLVS(sample_data_path)
        println("   Running runLVS compile script complete")
    #    events, hash_rect = genEvents(sample_data_path)
        # ... 다른 핵심 함수들 호출 ...
    end
    # ### `@setup_workload` 블록의 끝은 `@compile_workload` 블록 *뒤*에 와야 합니다. ###
    println("Finished preLVS_sweepline precompile workload setup.")
end # @setup_workload 블록의 끝
# --- 워크로드 끝 ---

end # module preLVS_sweepline
