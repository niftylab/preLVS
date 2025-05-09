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
                                            hash_rect::Vector{Rect}, source_net_sets::Vector{Tuple{String, Set{String}}}, logFileName::String, libname::String, cellname::String) # ::Vector{ErrorEvent} # ::Vector{ComponentInfo}
    nets_visited = Dict{String, Vector{Int}}() # for tracing open error
    error_log = Vector{ErrorEvent}()
    error_cnt = Dict{String, Int}(
        "short" => 0,
        "open" => 0,
        "floating" => 0,
        "total" => 0
    )

    open(logFileName, "w") do io
            
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
                println(io, "WARNING: No named labels at pin node: $(hash_rect[pnode_id])")
                error_cnt["label"] += 1; error_cnt["total"] += 1
                # pnode.netname = Union{String, Nothing}(nothing) # -> pnode.netname == nothing
                continue # KEEP pnode.netname == Nothing
            elseif length(source_net) > 1 # short error due to the overlap of labels w/ different netnames
                push!(error_log, ErrorEvent(errorType=SHORT, event_type=LABEL, rect_ref=pnode_id, rect_encounter=pnode_id)) # self short === label conlision at pnode
                # println(io, "Short: Net colision repNet: \"$(repNet)\", NodeNet: \"$(pnode_id)\" at nodeID: $(edge.to)")
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
        println(io, "setting pin netname complete")

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
                # if !(repNet in source_net_sets[1][2]) && !(repNet in source_net_sets[2][2])
                #     if check_coloned_netname(repNet, nets_visited)
                #         println(io, "Open: Net w/ netname: \"$(repNet)\". Node: $(hash_rect[pnode_id]), $(hash_rect[nets_visited[repNet][1]])")
                #         push!(error_log, ErrorEvent(errorType=OPEN, event_type=NET, rect_ref=pnode_id, rect_encounter=nets_visited[repNet][1]))
                #         error_cnt["open"] += 1; error_cnt["total"] += 1
                #     end
                # end
                println(io, "Open: Net w/ netname: \"$(repNet)\". Node: $(hash_rect[pnode_id]), $(hash_rect[nets_visited[repNet][1]])")
                push!(error_log, ErrorEvent(errorType=OPEN, event_type=NET, rect_ref=pnode_id, rect_encounter=nets_visited[repNet][1]))
                error_cnt["open"] += 1; error_cnt["total"] += 1
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
                    println(io, "Short: Net colision repNet: \"$(repNet)\", NodeNet: \"$(neighbor.netname)\" at nodeID: $(edge.to)")
                    push!(error_log, ErrorEvent(errorType=SHORT, event_type=METAL, rect_ref=edge.to, rect_encounter=pnode_id))
                    error_cnt["short"] += 1; error_cnt["total"] += 1
                end
                for _edge in neighbor.edges
                    enqueue!(queue, _edge)
                end
                neighbor.visited = true
            end
        end
        println(io, "Top level Net traverse complete")
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
                # if !(repNet in source_net_sets[1][2]) && !(repNet in source_net_sets[2][2])
                #     if check_coloned_netname(repNet, nets_visited)
                #         println(io, "Open: Net w/ netname: \"$(repNet)\". Node: $(hash_rect[pint_id]), $(hash_rect[nets_visited[repNet][1]])")
                #         push!(error_log, ErrorEvent(errorType=OPEN, event_type=NET, rect_ref=pint_id, rect_encounter=nets_visited[repNet][1]))
                #         error_cnt["open"] += 1; error_cnt["total"] += 1
                #     end
                # end
                println(io, "Open: Net w/ netname: \"$(repNet)\". Node: $(hash_rect[pint_id]), $(hash_rect[nets_visited[repNet][1]])")
                push!(error_log, ErrorEvent(errorType=OPEN, event_type=NET, rect_ref=pint_id, rect_encounter=nets_visited[repNet][1]))
                error_cnt["open"] += 1; error_cnt["total"] += 1
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
                    println(io, "Short: Net colision repNet: \"$(repNet)\", NodeNet: \"$(neighbor.netname)\" at nodeID: $(edge.to)")
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
                println(io, "Floating Node: $node_id, $(hash_rect[node.rect_ref])")
                error_cnt["floating"] += 1; error_cnt["total"] += 1
            end
        end
        println(io, "\n--- Connectivity Check Report ---")
        println(io, "Total connected components found: $(length(keys(hash_rect)))")
        println(io, "\nTotal Error Count: $(error_cnt["total"])")
        println(io, "├─ Floating: $(error_cnt["floating"])")
        println(io, "├─ Open: $(error_cnt["open"])")
        println(io, "└─ Short: $(error_cnt["short"])")
        println(io, "--------------------------------")


            
    end #end io
    return error_log, nets_visited
end

function check_coloned_netname(netname::String, net_sets::Vector{String})
    # netname이 : 으로 끝나면 open무시
    #
    # 자신 netname 혹은 다른 netname이 : 으로 끝나면 false
    # 그 외는 true

    is_colon = endswith(netname, ":")
    if is_colon
        return false
    end
    for net in net_sets
        is_colon_set = endswith(net, ":")
        if is_colon_set
            net = net[1:end-1]
        end
        if net == netname
            if is_colon_set
                return false
            else
                return true
            end
        end
    end
    return true
end



# struct GraphEdge
#     ref_via::Int
#     from::Int
#     to::Int
# end

# struct GraphNode
# #    layerType::EType # LABEL is not used, only METAL & VIA
#     layerNum::Int
#     rect_ref::Vector{Int}
#     netname::Union{String, Nothing} # 컴포넌트의 대표 netname
#     edges::Vector{GraphEdge}
#     isvisited::Bool
# end


# struct ErrorEvent
#     errorType::ErrorType
#     event_type::EType
#     rect_ref::Int
#     rect_encounter::Int
# end