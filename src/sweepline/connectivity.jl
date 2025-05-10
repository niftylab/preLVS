if !isdefined(@__MODULE__, :_SWEEPLINE_CONNECTIVITY_JL_)
    # 가드 상수를 현재 모듈 스코프에 직접 정의
    # @eval 없이 const를 직접 사용. 모듈의 top-level에서 include될 때 동작합니다.
    const _SWEEPLINE_CONNECTIVITY_JL_ = true

using DataStructures
using IntervalTrees
include("../structs/tree.jl")
include("../structs/rect.jl")
include("../structs/event.jl")
include("../utils/yaml.jl")

struct GraphEdge
    ref_via::Int
    from::Int
    to::Int
end

mutable struct GraphNode
#    layerType::EType # LABEL is not used, only METAL & VIA
    layerNum::Int
    rect_ref::Vector{Int}
    netname::Union{String, Nothing} # Ref{ Union{String, Nothing} } # 해당 Node의 대표 netname String or Nothing type
    edges::Vector{GraphEdge}
    visited::Bool
end

function GraphNode(layerNum::Int, list_rect::Vector{Int})
    # return GraphNode(layerNum, list_rect, Ref{ Union{String, Nothing} }(nothing), Vector{GraphEdge}(), false)
    return GraphNode(layerNum, list_rect, nothing, Vector{GraphEdge}(), false)
end

# --- 각 컴포넌트(Connected subGraph) 정보를 저장하기 위한 구조체 (선택사항, NamedTuple도 가능) ---
# struct ComponentInfo
#     nodes::Set{GraphNode}            # 컴포넌트에 속한 노드(MOVector)들의 Set
#     netname::Union{String, Nothing} # 컴포넌트의 대표 netname
#     is_consistent::Bool             # 해당 컴포넌트의 netname 일관성 여부
# end

function generate_graph(overlaps::Dict{Int, Vector{Int}}, via_link::Dict{Int, Tuple{Int, Int}}, hash_rect::Vector{Rect}, djs::IntDisjointSets{Int})
    # initializing Nodes
    cgraph = Dict{Int, GraphNode}()
    for (root, list_rect) in overlaps
        _rect = hash_rect[root]
        if typeof(_rect) == VRect
            # _lytype = VIA
            # _layerNum = minimum(_rect.layer)
            continue
        else
            # _lytype = METAL
            _layerNum = _rect.layer
            cgraph[root] = GraphNode(_layerNum, list_rect)
        end
    end
    # connecting nodes wrt via_link
    for (via_id, pair) in via_link
        root_via = find_root(djs, via_id)
        root1    = find_root(djs, pair[1])
        root2    = find_root(djs, pair[2])
        # make 4 edges (r1-v, v-r2, r2-v, v-r1)
        # edge_r1_v = GraphEdge(root_via, pair[1], root_via)
        # edge_v_r1 = GraphEdge(root_via, pair[1], root1)
        # edge_r2_v = GraphEdge(root_via, pair[2], root_via)
        # edge_v_r2 = GraphEdge(root_via, pair[2], root2)
        edge_r1_r2 = GraphEdge(root_via, root1, root2)
        edge_r2_r1 = GraphEdge(root_via, root2, root1)
        # push!(cgraph[root1].edges, edge_r1_v)
        # push!(cgraph[root2].edges, edge_r2_v)
        push!(cgraph[root1].edges, edge_r1_r2)
        push!(cgraph[root2].edges, edge_r2_r1)
    end
    return cgraph
end

end #endif

function check_connections_bfs(cgraph::Dict{Int, GraphNode}, pinNodes::Dict{Int, Vector{Int}},
                                            hash_rect::Vector{Rect}, equiv_net_sets::Vector{Tuple{String, Set{String}}}) # ::Vector{ErrorEvent} # ::Vector{ComponentInfo}
    nets_visited = Dict{String, Vector{Int}}() # for tracing open error
    error_log = Vector{ErrorEvent}()
    error_cnt = Dict{String, Int}(
        "short" => 0,
        "open" => 0,
        "floating" => 0,
        "total" => 0
    )

            
    # merge labels and determine representive netname for each pin node
    for (pnode_id, labels) in pinNodes
        # declare main variables
        pnode = cgraph[pnode_id]
        source_net = Set{String}()
        repNet = ""
        # initialize reference pin net
        for label_id in labels
            _label = hash_rect[label_id]
            _netname = _label.netname
            if _netname !== nothing && _netname !== ""
                push!(source_net, _netname)
            end
        end
        if length(source_net) == 0  # no named labels
            push!(error_log, ErrorEvent(errorType=WARNING, event_type=LABEL, rect_ref=labels[1], rect_encounter=pnode_id))
            println("WARNING: No named labels at pin node: $(hash_rect[pnode_id])")
            error_cnt["label"] += 1; error_cnt["total"] += 1
            # pnode.netname = Union{String, Nothing}(nothing) # -> pnode.netname == nothing
            continue # KEEP pnode.netname == Nothing
        elseif length(source_net) > 1 # short error due to the overlap of labels w/ different netnames
            push!(error_log, ErrorEvent(errorType=SHORT, event_type=LABEL, rect_ref=pnode_id, rect_encounter=pnode_id)) # self short === label conlision at pnode
            # println("Short: Net colision repNet: \"$(repNet)\", NodeNet: \"$(pnode_id)\" at nodeID: $(edge.to)")
            error_cnt["short"] += 1; error_cnt["total"] += 1
            # get Representive Netname. If top level net included, pick it
            repNet = first(source_net)
            for nname in source_net
                if !occursin("__", nname) # '__' not included in nname <=> Top level Net
                    repNet = nname
                    break
                end
            end
        else
            repNet = first(source_net)
            # println("repNet = $(repNet) for pnode_id = $(pnode_id)")
        end
        pnode.netname = repNet # set representive netname
    end
    println("setting pin netname complete")

    # Now every node containing labels has its netname.
    # First, checking Netnames w/o '__' ie, pass internal net this time
    label_passed = Vector{Int}()
    for (pnode_id, labels) in pinNodes
        pnode = cgraph[pnode_id]
        if pnode.visited || pnode.netname isa Nothing
            continue
        elseif occursin("__", pnode.netname)
    #        println("Pass: Internal Net \"$(pnode.netname)\" will be checked later")
            push!(label_passed, pnode_id)
            continue
        end
        # declare main variables
        repNet::String = pnode.netname
#        println("Current repNet: $(repNet)")
        queue = Queue{GraphEdge}()
        if haskey(nets_visited, repNet)
            # equiv net sets 에서 정의된 동일한 netname인 경우 open error 무시 
            if !(repNet in equiv_net_sets[1][2]) && !(repNet in equiv_net_sets[2][2])
                # colon 으로 끝나는 netname 인 경우 open error 무시
                if check_coloned_netname(repNet, nets_visited)
                    # println("Open: Net w/ netname: \"$(repNet)\". Node: $(hash_rect[pnode_id]), $(hash_rect[nets_visited[repNet][1]])")
                    push!(error_log, ErrorEvent(errorType=OPEN, event_type=NET, rect_ref=pnode_id, rect_encounter=nets_visited[repNet][1]))
                    error_cnt["open"] += 1; error_cnt["total"] += 1
                end
            end
            # println("Open: Net w/ netname: \"$(repNet)\". Node: $(hash_rect[pnode_id]), $(hash_rect[nets_visited[repNet][1]])")
            # push!(error_log, ErrorEvent(errorType=OPEN, event_type=NET, rect_ref=pnode_id, rect_encounter=nets_visited[repNet][1]))
            # error_cnt["open"] += 1; error_cnt["total"] += 1
        else
            nets_visited[repNet] = Vector{Int}()
        end
        push!(nets_visited[repNet], pnode_id)  # add source net to visited net list
        # START BFS -> PUSH EDGES into Q
        for _edge in pnode.edges
            enqueue!(queue, _edge)
        end
        pnode.visited = true
        while !isempty(queue)
            edge = dequeue!(queue)
            neighbor = cgraph[edge.to]
            if neighbor.visited
                continue
            end
            if neighbor.netname isa Nothing # check netname
                neighbor.netname = repNet
            elseif neighbor.netname != repNet
                println("Short: Net colision repNet: \"$(repNet)\", NodeNet: \"$(neighbor.netname)\" at nodeID: $(edge.to)")
                push!(error_log, ErrorEvent(errorType=SHORT, event_type=METAL, rect_ref=edge.to, rect_encounter=pnode_id))
                error_cnt["short"] += 1; error_cnt["total"] += 1
            end
            for _edge in neighbor.edges
                enqueue!(queue, _edge)
            end
            neighbor.visited = true
        end
    end
    println("Top level Net traverse complete")
    # traverse Internal Pin Nodes
    for pint_id in label_passed
        pnode = cgraph[pint_id]
        if pnode.visited
            continue
        end
        # declare main variables
        repNet = pnode.netname
#        println("Current repNet: $(repNet)")
        queue = Queue{GraphEdge}()
        if haskey(nets_visited, repNet)
            # equiv net sets 에서 정의된 동일한 netname인 경우 open error 무시 
            if !(repNet in equiv_net_sets[1][2]) && !(repNet in equiv_net_sets[2][2])
                # colon 으로 끝나는 netname 인 경우 open error 무시
                if check_coloned_netname(repNet, nets_visited)
                    # println("Open: Net w/ netname: \"$(repNet)\". Node: $(hash_rect[pint_id]), $(hash_rect[nets_visited[repNet][1]])")
                    push!(error_log, ErrorEvent(errorType=OPEN, event_type=NET, rect_ref=pint_id, rect_encounter=nets_visited[repNet][1]))
                    error_cnt["open"] += 1; error_cnt["total"] += 1
                end
            end
            # println("Open: Net w/ netname: \"$(repNet)\". Node: $(hash_rect[pint_id]), $(hash_rect[nets_visited[repNet][1]])")
            # push!(error_log, ErrorEvent(errorType=OPEN, event_type=NET, rect_ref=pint_id, rect_encounter=nets_visited[repNet][1]))
            # error_cnt["open"] += 1; error_cnt["total"] += 1
        else
            nets_visited[repNet] = Vector{Int}()
        end
        push!(nets_visited[repNet], pint_id)  # add source net to visited net list
        # add pnode id to netname table
        # if !haskey(group_pins, repNet)
        #     group_pins[repNet] = Vector{Int}()
        # end
        # push!(group_pins[repNet], pnode_id)
        # START BFS -> PUSH EDGES into Q
        for _edge in pnode.edges
            enqueue!(queue, _edge)
        end
        pnode.visited = true
        while !isempty(queue)
            edge = dequeue!(queue)
            neighbor = cgraph[edge.to]
            if neighbor.visited
                continue
            end
            if neighbor.netname isa Nothing # check netname
                neighbor.netname = repNet
            elseif neighbor.netname != repNet
                println("Short: Net colision repNet: \"$(repNet)\", NodeNet: \"$(neighbor.netname)\" at nodeID: $(edge.to)")
                push!(error_log, ErrorEvent(errorType=SHORT, event_type=METAL, rect_ref=edge.to, rect_encounter=pint_id))
                error_cnt["short"] += 1; error_cnt["total"] += 1
            end
            for _edge in neighbor.edges
                enqueue!(queue, _edge)
            end
            neighbor.visited = true
        end
    end
    # check Floating Node
    noname_cnt = 0
    for (node_id, node) in cgraph
        if node.netname isa Nothing
            push!(error_log, ErrorEvent(FLOATING, METAL, node_id))
            println("Floating Node: $node_id, $(hash_rect[node.rect_ref])")
            error_cnt["floating"] += 1; error_cnt["total"] += 1
        end
    end
    println("\n--- Connectivity Check Report ---")
    println("Total connected components found: $(length(keys(hash_rect)))")
    println("\nTotal Error Count: $(error_cnt["total"])")
    println("├─ Floating: $(error_cnt["floating"])")
    println("├─ Open: $(error_cnt["open"])")
    println("└─ Short: $(error_cnt["short"])")
    println("--------------------------------")
           
    return error_log, error_cnt, hash_rect, nets_visited
end

function check_coloned_netname(netname::String, nets_visited::Dict{String, Vector{Int}})
    # netname이 : 으로 끝나면 open무시
    #
    # 자신 netname 혹은 다른 netname이 : 으로 끝나면 false
    # 그 외는 true

    # 자신 netname이 : 으로 끝나면 open무시
    if endswith(netname, ":")
        return false
    end

    for visited_net_key in keys(nets_visited)
        if endswith(visited_net_key, ":")
            base_name_of_visited_key = visited_net_key[1:end-1]
            # 탐색했던 netname중 같은 이름이면서 colon으로 끝나는 경우 존재 -> open무시
            if base_name_of_visited_key == netname
                return false
            end
        end
    end

    return true
end


function create_error_log_file(error_log::Vector{ErrorEvent}, error_cnt::Dict{String, Int}, log_dir::String, libname::String, cellname::String, hash_rect::Vector{Rect}, nets_visited::Dict{String, Vector{Int}}, djs::IntDisjointSets{Int})
    # create log file
    log_file = joinpath(log_dir, "$(libname)_$(cellname).txt")
    open(log_file, "w") do io
        for error in error_log
            println(io, error)
        end

        # print nets_visited
        for (i, (netname, nodes)) in enumerate(nets_visited)
            println(io, "\n--- Component $i ---")
            println(io, "Representive Net Name: $netname")
            root_idx = find_root(djs, nodes[1])
            metal_indices = sort(get_elements_for_root(djs, root_idx))
            println(io, "Metal Indices ($(length(metal_indices))): $metal_indices")
        end

        # print total result
        println()
        println(io, "\n------------------------------------------------------------------\n")
        println(io, "Library: $libname")
        println(io, "Cell: $cellname\n")
        if length(error_log) == 0
            println(io, """
       _ (`-.   ('-.      .-')     .-')      ('-.  _ .-') _   
      ( (OO  ) ( OO ).-. ( OO ).  ( OO ).  _(  OO)( (  OO) )  
     _.`     | / . --. /(_)---|_)(_)---|_)(,------.|     .'_  
    (__...--'' | |-.   |/    _ | /    _ |  |  .---',`'--..._) 
     |  /  | | | |  |  ||  (` `  |  (` `   |  |    |  |   | ' 
     |  |_.' | | |_.'  | '..`''.  '..`''.  |  '--. |  |   ' | 
     |  .___.' |  .-.  |.-._)   |.-._)   | |  .--' |  |   / : 
     |  |      |  | |  ||       /|       / |  `---.|  '--'  / 
     `--'      `--' `--' `-----'  `-----'  `------'`-------'    
            """)
            println(io, "Overall Graph Netname Consistency: PASSED ✔️")
        else
            println(io, """
                ('-.                          ('-.  _ .-') _   
               ( OO ).-.                    _(  OO)( (  OO) )  
       ,------./ . --. /  ,-.-')  ,--.     (,------.|     .'_  
    ('-| _.---'| |-.  |   |  |OO) |  |.-')  |  .---',`'--..._) 
    (OO|(_|  . | |  |  |  |  |  | |  | OO ) |  |    |  |   | ' 
    /  |  '--. | |_.'  |  |  |(_/ |  |`-' |(|  '--. |  |   ' | 
    |_)|  .--' |  .-.  | ,|  |_.'(|  '---.' |  .--' |  |   / : 
      ||  |    |  | |  |(_|  |    |      |  |  `---.|  '--'  / 
       `--'    `--' `--'  `--'    `------'  `------'`-------'  
            """)
            println(io, "Overall Graph Netname Consistency: FAILED ❌")
        end

        println(io, "\nTotal Error Count: $(error_cnt["total"])")
        println(io, "├─ Floating: $(error_cnt["floating"])")
        println(io, "├─ Open: $(error_cnt["open"])")
        println(io, "└─ Short: $(error_cnt["short"])")
        println(io, "\n------------------------------------------------------------------\n")
    end
end

# Find all elements in the set(djs) with the given root
function get_elements_for_root(ds::IntDisjointSets{Int}, known_root::Int)
    elements_in_set = Int[] # 결과를 담을 배열

    # IntDisjointSet은 생성될 때 다루는 최대 정수(n)를 알며, 1부터 n까지의 원소를 다룹니다.
    # 이 n은 내부적으로 ds.parents 배열의 길이로 알 수 있습니다.
    num_total_elements = length(ds.parents)

    # 1부터 모든 가능한 원소들을 순회합니다.
    for i in 1:num_total_elements
        # 각 원소 i의 현재 루트를 찾습니다.
        # find_root 함수는 경로 압축을 수행하여 효율성을 높입니다.
        if find_root(ds, i) == known_root
            # 원소 i의 루트가 우리가 찾는 known_root와 같다면,
            # 이 원소는 해당 집합에 속합니다.
            push!(elements_in_set, i)
        end
    end
    return elements_in_set
end

