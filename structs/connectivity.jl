if !isdefined(@__MODULE__, :_PRELVS_CONNECTIVITY_JL_)
const _PRELVS_CONNECTIVITY_JL_ = true


include("via.jl")
include("new_metal.jl")

mutable struct MGraph
    adj::Dict{MOVector, Vector{MOVector}}   # adjacency list
    adj_v::Dict{MOVector, Vector{VPoint}}
end



function connect_metals_from_via(mdata::MOData, vdata::VData, nmetals::Int)
    # println("Number of metals: $nmetals")

    cgraph = MGraph(Dict{MOVector, Vector{MOVector}}(), Dict{MOVector, Vector{VPoint}}())

    # 계측 (2026-08-11, vtc_core M3/M4 섬 진단): PRELVS_DEBUG_FILE 이
    # 설정되면 링크에 실패한 via (겹침 ≠ 2) 의 probe 상세를 기록.
    # 미설정 시 완전 무동작 — 프로덕션 경로 불변.
    _dbgpath = get(ENV, "PRELVS_DEBUG_FILE", "")
    _dbg = _dbgpath == "" ? nothing : open(_dbgpath, "a")

    for (vtype, vlist) in vdata.vlists
        for vp in vlist.vpoints
            overlapping_metals = find_overlapping_metals(vp, mdata)

            if _dbg !== nothing && length(overlapping_metals) != 2
                println(_dbg, "VIA_FAIL $(vp.type) xy=$(vp.xy) n=$(length(overlapping_metals))")
                for layer in get_layer_from_via_type(vp.type)
                    is_vertical = layer % 2 == 1
                    pcoord = is_vertical ? vp.xy[1] : vp.xy[2]
                    scoord = is_vertical ? vp.xy[2] : vp.xy[1]
                    if !haskey(mdata.metals, layer)
                        println(_dbg, "  L$(layer): layer 없음")
                        continue
                    end
                    if !haskey(mdata.metals[layer].metals, pcoord)
                        ks = sort(collect(keys(mdata.metals[layer].metals)))
                        near = [k for k in ks if abs(k - pcoord) <= 300]
                        println(_dbg, "  L$(layer): bin p=$(pcoord) 없음 (근방 키: $(near))")
                        continue
                    end
                    mvlist = mdata.metals[layer].metals[pcoord]
                    idx = searchsortedfirst(mvlist, scoord, by = x -> (isa(x, MOVector) ? x.points[1].s_coord : x)) - 1
                    spans = [(mv.points[1].s_coord, mv.points[2].s_coord) for mv in mvlist]
                    println(_dbg, "  L$(layer): p=$(pcoord) s=$(scoord) idx=$(idx)/$(length(mvlist)) spans=$(spans)")
                end
            end

            if length(overlapping_metals) == 2
                mv1::MOVector, mv2::MOVector = overlapping_metals
                adj_list_mv1 = get!(cgraph.adj, mv1, Vector{MOVector}())
                adj_list_mv2 = get!(cgraph.adj, mv2, Vector{MOVector}())
                push!(adj_list_mv1, mv2)
                push!(adj_list_mv2, mv1)

                adj_list_v = get!(cgraph.adj_v, mv1, Vector{VPoint}())
                push!(adj_list_v, vp)
                adj_list_v = get!(cgraph.adj_v, mv2, Vector{VPoint}())
                push!(adj_list_v, vp)
            end
        end
    end
    if _dbg !== nothing
        close(_dbg)
    end
    return cgraph
end



# --- 각 컴포넌트 정보를 저장하기 위한 구조체 (선택사항, NamedTuple도 가능) ---
struct ComponentInfo
    number::Int
    nodes::Set{MOVector}            # 컴포넌트에 속한 노드(MOVector)들의 Set
    vias::Set{VPoint}
    netname::Union{String, Nothing} # 컴포넌트의 대표 netname
    laygo_origin_set::Set{LaygoOrigin} # 컴포넌트의 대표 laygo_origin
    is_consistent::Bool             # 해당 컴포넌트의 netname 일관성 여부
end

@enum ErrorType SHORT OPEN FLOATING

struct ErrorInfo
    type::ErrorType
    start_node::MOVector
    current_node::Union{MOVector, Nothing}
    actual_netname::Union{String, Nothing}
    expected_netname::Union{String, Nothing}
    number::Int
end

function get_error_string(error_info::ErrorInfo)
    if error_info.type == OPEN
        return "OPEN: netname $(error_info.expected_netname) is already visited\n$(error_info.start_node.netname) : layer=$(error_info.start_node.layer), p_coord=$(error_info.start_node.p_coord), s_coord=$(error_info.start_node.points[1].s_coord) - $(error_info.start_node.points[2].s_coord)\n$(error_info.current_node.netname) : layer=$(error_info.current_node.layer), p_coord=$(error_info.current_node.p_coord), s_coord=$(error_info.current_node.points[1].s_coord) - $(error_info.current_node.points[2].s_coord)"
    elseif error_info.type == SHORT
        return "SHORT: Netname inconsistency! Node $(error_info.current_node.netname) has netname '$(error_info.actual_netname)', but expected '$(error_info.expected_netname)' for this component.
        layer=$(error_info.current_node.layer), p_coord=$(error_info.current_node.p_coord), s_coord=$(error_info.current_node.points[1].s_coord) - $(error_info.current_node.points[2].s_coord)"
    elseif error_info.type == FLOATING
        return "FLOATING: No netname found metals. Start node = $(error_info.start_node.layer), $(error_info.start_node.p_coord), $(error_info.start_node.points[1].s_coord) - $(error_info.start_node.points[2].s_coord)"
    end
end

function check_and_report_connections_bfs(g::MGraph, source_net_sets::Vector{Tuple{String, Set{String}}})
    visited_metals = Set{MOVector}()
    all_components_info = Vector{ComponentInfo}() # 컴포넌트 정보들을 저장할 벡터

    # 그래프의 모든 노드들을 어떻게 얻을 것인가?
    # 1. keys(g.adj) - 키로 등록된 노드만 순회 (연결된 간선이 있는 노드)
    # 2. values(g.adj) 를 모두 펼쳐서 Set으로 만들기 - 그래프 내 모든 노드 포함 가능성 높음
    # 여기서는 2번 방식 사용 (더 포괄적)
    all_nodes_in_graph = Set{MOVector}()
    visited_netnames = Set{String}()

    error_info = Vector{ErrorInfo}()
    error_cnt = Dict{String, Int}(
        "short" => 0,
        "open" => 0,
        "floating" => 0,
        "total" => 0
    )
    # bfs_log = String[]

    for key_node in keys(g.adj)
        push!(all_nodes_in_graph, key_node)
        for neighbor_node in g.adj[key_node]
            push!(all_nodes_in_graph, neighbor_node)
        end
    end

    println("Total unique nodes found in graph: $(length(all_nodes_in_graph))")
    println("\nStarting Connectivity and Netname Consistency Check...")
    component_number = 1
    # Iterate start nodes in a deterministic order (by merged-metal idx) so
    # component numbering, start-node selection, and the resulting netmap /
    # error ordering are reproducible run-to-run. (Set iteration order in
    # Julia is otherwise unspecified.)
    for start_node in sort(collect(all_nodes_in_graph), by = n -> n.idx) # 그래프 내 모든 노드를 시작점으로 시도
        if !(start_node in visited_metals)
            # --- 새 컴포넌트 발견 ---
            current_component_nodes = Set{MOVector}() # 현재 컴포넌트 노드 저장
            current_component_vpoints = Set{VPoint}()
            expected_netname_ref = Ref{Union{String, Nothing}}(nothing)
            component_consistent = Ref(true)
            component_laygo_origin_set = Set{LaygoOrigin}()

            q = Vector{MOVector}() # Queue of MOVector objects

            # 시작 노드 처리 및 큐에 추가
            push!(visited_metals, start_node)
            push!(current_component_nodes, start_node)  # 컴포넌트에 시작 노드 추가
            for vp in g.adj_v[start_node]
                if !(vp in current_component_vpoints)
                    push!(current_component_vpoints, vp)
                end
            end
            union!(component_laygo_origin_set, start_node.laygo_origin_set)
            push!(q, start_node)

            # 컴포넌트 시작 노드 정보 출력 (노드의 idx 필드가 있다고 가정)
            start_node_id_str = hasproperty(start_node, :idx) ? " (idx=$(start_node.idx))" : ""
            # push!(bfs_log, "Starting BFS for new component from node$(start_node_id_str)...")
            # --- BFS 시작 ---
            while !isempty(q)
                u_node::MOVector = popfirst!(q) # Dequeue MOVector

                # --- 노드 처리 로직 ---
                current_netname = u_node.netname

                # 만난 node의 netname이 있으면
                if current_netname !== nothing
                    if expected_netname_ref[] === nothing
                        expected_netname_ref[] = current_netname
                        # 만난 netname이 이미 방문한 netname 중 하나면 open일 수 있다
                        if current_netname in visited_netnames
                            # VDD, VSS는 open 무시
                            if !(current_netname in source_net_sets[1][2]) && !(current_netname in source_net_sets[2][2])
                                # 같은 이름이지만, 콜론이 있는 경우 open 무시
                                if check_coloned_netname(current_netname, visited_netnames)
                                    # @warn " OPEN! : netname $current_netname is already visited
                                    # $(u_node.netname) : layer=$(u_node.layer), p_coord=$(u_node.p_coord), s_coord=$(u_node.points[1].s_coord) - $(u_node.points[2].s_coord)
                                    # $(start_node.netname) : layer=$(start_node.layer), p_coord=$(start_node.p_coord), s_coord=$(start_node.points[1].s_coord) - $(start_node.points[2].s_coord)"
                                    push!(error_info, ErrorInfo(OPEN, u_node, start_node, current_netname, expected_netname_ref[], component_number))
                                    # println(io, "OPEN: netname $current_netname is already visited\n$(u_node.netname) : layer=$(u_node.layer), p_coord=$(u_node.p_coord), s_coord=$(u_node.points[1].s_coord) - $(u_node.points[2].s_coord)\n$(start_node.netname) : layer=$(start_node.layer), p_coord=$(start_node.p_coord), s_coord=$(start_node.points[1].s_coord) - $(start_node.points[2].s_coord)")
                                    error_cnt["open"] += 1; error_cnt["total"] += 1;
                                end
                            end
                        end
                        push!(visited_netnames, current_netname)
                    # current_netname 이 nothing이 아니고, expected_netname_ref[] 이 nothing이 아니고, current_netname != expected_netname_ref[] 이면 short
                    elseif current_netname != expected_netname_ref[] && expected_netname_ref[] !== nothing
                        if component_consistent[] # 첫 불일치 시 로그
                            # node_id_str = hasproperty(u_node, :idx) ? " (idx=$(u_node.idx))" : ""
                            # @warn "  Netname inconsistency! Node$(node_id_str) has netname '$current_netname', but expected '$(expected_netname_ref[])' for this component."
                            push!(error_info, ErrorInfo(SHORT, u_node, start_node, current_netname, expected_netname_ref[], component_number))
                            # println(io, "SHORT: Netname inconsistency! Node$(node_id_str) has netname '$current_netname', but expected '$(expected_netname_ref[])' for this component.")
                            error_cnt["short"] += 1; error_cnt["total"] += 1;
                        end
                        component_consistent[] = false
                    end
                end
                # --- 노드 처리 끝 ---

                # --- 이웃 탐색 및 Enqueue ---
                # 현재 노드(u_node)가 adj 딕셔너리의 키로 존재해야 이웃 탐색 가능
                if haskey(g.adj, u_node)
                    for v_node in g.adj[u_node] # v_node는 이웃 MOVector 객체
                        if !(v_node in visited_metals)
                            push!(visited_metals, v_node)
                            push!(current_component_nodes, v_node) # 컴포넌트에 이웃 노드 추가
                            for vp in g.adj_v[v_node]
                                if !(vp in current_component_vpoints)
                                    push!(current_component_vpoints, vp)
                                end
                            end
                            union!(component_laygo_origin_set, v_node.laygo_origin_set)
                            push!(q, v_node) # 이웃 MOVector 객체를 큐에 추가
                        end
                    end
                end
                # --- 이웃 탐색 끝 ---
            end
            # --- BFS 종료 ---

            if expected_netname_ref[] === nothing
                # @warn "  FLOATING! : No netname found metals. Start node = $(start_node.layer), $(start_node.p_coord), $(start_node.points[1].s_coord) - $(start_node.points[2].s_coord)"
                push!(error_info, ErrorInfo(FLOATING, start_node, nothing, nothing, nothing, component_number))
                # println(io, "FLOATING: No netname found metals. Start node = $(start_node.layer), $(start_node.p_coord), $(start_node.points[1].s_coord) - $(start_node.points[2].s_coord)")
                error_cnt["floating"] += 1; error_cnt["total"] += 1;
            end

            # --- 현재 컴포넌트 정보 저장 ---
            push!(all_components_info, ComponentInfo(
                component_number,
                current_component_nodes,
                current_component_vpoints,
                expected_netname_ref[],
                component_laygo_origin_set,
                component_consistent[]
            ))
            component_number += 1
        end
    end

    return all_components_info, error_info, error_cnt
end

function check_coloned_netname(netname::String, net_sets::Set{String})
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


# O(logn)으로 검색 (n = number of metals in the layer&pcoord)
function find_overlapping_metals(vpoint::VPoint, mdata::MOData)
    
    overlapping_metals = Vector{MOVector}()
    
    layers = get_layer_from_via_type(vpoint.type)
    
    for layer in layers
        is_vertical = layer % 2 == 1
        pcoord = is_vertical ? vpoint.xy[1] : vpoint.xy[2]
        scoord = is_vertical ? vpoint.xy[2] : vpoint.xy[1]
        
        
        if haskey(mdata.metals, layer) && haskey(mdata.metals[layer].metals, pcoord)
            mvlist = mdata.metals[layer].metals[pcoord]
        else
            continue
        end
            
        idx = searchsortedfirst(mvlist, scoord, by = x -> (isa(x, MOVector) ? x.points[1].s_coord : x)) - 1
        if idx >= 1 && idx <= length(mvlist) && mvlist[idx].points[2].s_coord >= scoord && mvlist[idx].points[1].s_coord <= scoord
            mv = mvlist[idx]
            if mv.netname !== nothing && mv.netname != vpoint.netname
                # error("VPoint netname $vpoint.netname is not equal to MVector netname $mv.netname")
                # println("VPoint netname $vpoint.netname is not equal to MVector netname $mv.netname")
            end
            push!(overlapping_metals, mv)
            # update mv.netname
            # uncomment to update netnames in original MVectors
            # mv.netname = vpoint.netname
            # mv.points[1].netname = vpoint.netname
            # mv.points[2].netname = vpoint.netname
        end
    end
    
    return overlapping_metals
end

function get_layer_from_via_type(via_type::String)
    # Extract the layer numbers from the via type string
    # Example: "via_M1_M2_0" -> (1, 2)
    m = match(r"via_M(\d+)_M(\d+)_\d+", via_type)
    if m !== nothing
        layer1 = parse(Int, m.captures[1])
        layer2 = parse(Int, m.captures[2])
        return (layer1, layer2)
    else
        error("Invalid via type format: $via_type")
    end
end

end # include guard
