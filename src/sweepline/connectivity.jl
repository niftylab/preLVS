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
    ref_metal::Int
    neighbor::Int
end

struct GraphNode
    layerType::EType # LABEL is not used, only METAL & VIA
    layerNum::Int
    rect_ref::Vector{Int}
    edges::Vector{GraphEdge}
    isvisited::Bool
end

function generate_graph(overlaps::Dict{Int, Vector{Int}}, via_link::Dict{Int, Tuple{Int, Int}}, hash_rect::Vector{Rect}, djs::IntDisjointSets{Int})
    # initializing Nodes
    cgraph = Dict{Int, GraphNode}()
    for (root, list_rect) in overlaps
        _rect = hash_rect[list_rect[1]]
        if typeof(_rect) == VRect
            _lytype = VIA
            _layerNum = minimum(_rect.layer)
        else
            _lytype = METAL
            _layerNum = _rect.layer
        end
        cgraph[root] = GraphNode(_lytype, _layerNum, list_rect, Vector{GraphEdge}(), false)
    end
    # connecting nodes wrt via_link
    for (via_id, pair) in via_link
        root_via = find_root(djs, via_id)
        root1    = find_root(djs, pair[1])
        root2    = find_root(djs, pair[2])
        # make 4 edges (r1-v, v-r2, r2-v, v-r1)
        edge_r1_v = GraphEdge(root_via, pair[1], root_via)
        edge_v_r1 = GraphEdge(root_via, pair[1], root1)
        edge_r2_v = GraphEdge(root_via, pair[2], root_via)
        edge_v_r2 = GraphEdge(root_via, pair[2], root2)
        push!(cgraph[root1].edges, edge_r1_v)
        push!(cgraph[root2].edges, edge_r2_v)
        push!(cgraph[root_via].edges, edge_v_r1)
        push!(cgraph[root_via].edges, edge_v_r2)
    end
    return cgraph
end

end #endif