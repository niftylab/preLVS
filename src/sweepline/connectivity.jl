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
                                            hash_rect::Vector{Rect}) # ::Vector{ErrorEvent} # ::Vector{ComponentInfo}
    nets_visited = Dict{String, Vector{Int}}() # for tracing open error
    error_log = Vector{ErrorEvent}()
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
            if _netname !== nothing || _netname !== ""
                push!(source_net, _netname)
            end
        end
        if length(source_net) == 0  # no named labels
            push!(error_log, ErrorEvent(errorType=WARNING, event_type=LABEL, rect_ref=labels[1], rect_encounter=pnode_id))
            # pnode.netname = Union{String, Nothing}(nothing) # -> pnode.netname == nothing
            continue # KEEP pnode.netname == Nothing
        elseif length(source_net) > 1 # short error due to the overlap of labels w/ different netnames
            push!(error_log, ErrorEvent(errorType=SHORT, event_type=LABEL, rect_ref=pnode_id, rect_encounter=pnode_id)) # self short === label conlision at pnode
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
        end
        pnode.netname = repNet # set representive netname
    end
    println("setting pin netname complete")
    # Now every node containing labels has its netname.
    # First, checking Netnames w/o '__' ie, pass internal net this time
    label_passed = Vector{Int}()
    for (pnode_id, labels) in pinNodes
        pnode = cgraph[pnode_id]
        if pnode.visited || pnode.netname == nothing
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
    #        println("Open: Net w/ netname: \"$(repNet)\". Node: $(pnode_id), $(nets_visited[repNet][1])")
            push!(error_log, ErrorEvent(errorType=OPEN, event_type=NET, rect_ref=pnode_id, rect_encounter=nets_visited[repNet][1]))
        else
            nets_visited[repNet] = Vector{Int}()
        end
        push!(nets_visited[repNet], pnode_id)  # add source net to visited net list
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
            if neighbor.netname == nothing # check netname
                neighbor.netname = repNet
            elseif neighbor.netname != repNet
        #        println("Short: Net colision repNet: \"$(repNet)\", NodeNet: \"$(neighbor.netname)\" at nodeID: $(edge.to)")
                push!(error_log, ErrorEvent(errorType=SHORT, event_type=METAL, rect_ref=edge.to, rect_encounter=pnode_id))
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
            push!(error_log, ErrorEvent(errorType=OPEN, event_type=NET, rect_ref=pint_id, rect_encounter=nets_visited[repNet][1]))
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
            if neighbor.netname == nothing # check netname
                neighbor.netname = repNet
            elseif neighbor.netname != repNet
                push!(error_log, ErrorEvent(errorType=SHORT, event_type=METAL, rect_ref=edge.to, rect_encounter=pint_id))
            end
            for _edge in neighbor.edges
                enqueue!(queue, _edge)
            end
            neighbor.visited = true
        end
    end
    # check Floating Node
    for (node_id, node) in cgraph
        if node.netname == nothing
            push!(error_log, ErrorEvent(FLOATING, METAL, node_id))
        end
    end
    return error_log, nets_visited
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