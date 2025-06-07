if !isdefined(@__MODULE__, :_STRUCT_CONN_JL_)
    # 가드 상수를 현재 모듈 스코프에 직접 정의
    # @eval 없이 const를 직접 사용. 모듈의 top-level에서 include될 때 동작합니다.
    const _STRUCT_CONN_JL_ = true

using DataStructures

include("via.jl")
include("new_metal.jl")

mutable struct MGraph
    adj::Dict{MOVector, Vector{MOVector}}   # adjacency list
end



function connect_metals_from_via(mdata::MOData, vdata::VData, nmetals::Int)
    # println("Number of metals: $nmetals")

    cgraph = MGraph(Dict{MOVector, Vector{MOVector}}())

    for (vtype, vlist) in vdata.vlists
        for vp in vlist.vpoints
            overlapping_metals = find_overlapping_metals(vp, mdata)

            if length(overlapping_metals) == 2
                mv1::MOVector, mv2::MOVector = overlapping_metals
                adj_list_mv1 = get!(cgraph.adj, mv1, Vector{MOVector}())
                adj_list_mv2 = get!(cgraph.adj, mv2, Vector{MOVector}())
                push!(adj_list_mv1, mv2)
                push!(adj_list_mv2, mv1)
            end
        end
    end
    return cgraph
end



# --- 각 컴포넌트 정보를 저장하기 위한 구조체 (선택사항, NamedTuple도 가능) ---
struct ComponentInfo
    nodes::Set{MOVector}            # 컴포넌트에 속한 노드(MOVector)들의 Set
    netname::Union{String, Nothing} # 컴포넌트의 대표 netname
    is_consistent::Bool             # 해당 컴포넌트의 netname 일관성 여부
end

@enum ErrorType SHORT OPEN FLOATING

struct ErrorInfo
    type::ErrorType
    start_node::MOVector
    current_node::Union{MOVector, Nothing}
    actual_netname::Union{String, Nothing}
    expected_netname::Union{String, Nothing}
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


function create_error_log_file(libname::String, cellname::String, logFileName::String, error_info::Vector{ErrorInfo}, all_components_info::Vector{ComponentInfo}, error_cnt::Dict{String, Int})
    open(logFileName, "w") do io
        println(io, "Total unique nodes found in graph: $(length(all_components_info))")
        println(io, "\nStarting Connectivity and Netname Consistency Check...")

        println(io, "Error Info:")
        for error_info in error_info
            println(io, get_error_string(error_info))
        end
        println(io, "\n--- Connectivity Check Report ---")
        println(io, "Total connected components found: $(length(all_components_info))")
        # --- 최종 결과 출력 ---
        overall_consistent = true
        # --- 최종 결과 출력 ---
        for (i, component) in enumerate(all_components_info)
            println(io, "\n--- Component $i ---")
    
            # 대표 Netname 출력
            netname_str = component.netname === nothing ? "None (all nodes had 'nothing' netname or component is empty)" : component.netname
            println(io, "Representative Net Name: $netname_str")
    
            # 일관성 여부 출력
            println(io, "Netname Consistency: $(component.is_consistent ? "Passed" : "Failed")")
            if !component.is_consistent
                overall_consistent = false
            end
    
            # Metal 목록 출력 (idx 사용 가정)
            if !isempty(component.nodes)
                # 모든 노드가 idx 속성을 가지고 있는지 간단히 확인 (선택 사항)
                if all(hasproperty(node, :idx) for node in component.nodes)
                    # idx 기준으로 정렬하여 출력
                    metal_indices = sort([node.idx for node in component.nodes])
                    println(io, "Metal Indices ($(length(metal_indices))): $metal_indices")
                else
                    println(io, "Metals ($(length(component.nodes))): [Cannot list indices, some nodes lack .idx property]")
                    # println("Metals: $(component.nodes)") # 전체 객체 출력 (길 수 있음)
                end
            else
                println(io, "Metals: (Empty component)")
            end
        end
        print_consistency_status(libname, cellname, io, overall_consistent, error_cnt)
    end # Close file
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
    for start_node in all_nodes_in_graph # 그래프 내 모든 노드를 시작점으로 시도
        if !(start_node in visited_metals)
            # --- 새 컴포넌트 발견 ---
            current_component_nodes = Set{MOVector}() # 현재 컴포넌트 노드 저장
            expected_netname_ref = Ref{Union{String, Nothing}}(nothing)
            component_consistent = Ref(true)

            q = Vector{MOVector}() # Queue of MOVector objects

            # 시작 노드 처리 및 큐에 추가
            push!(visited_metals, start_node)
            push!(current_component_nodes, start_node) # 컴포넌트에 시작 노드 추가
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
                                    push!(error_info, ErrorInfo(OPEN, u_node, start_node, current_netname, expected_netname_ref[]))
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
                            push!(error_info, ErrorInfo(SHORT, u_node, start_node, current_netname, expected_netname_ref[]))
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
                            push!(q, v_node) # 이웃 MOVector 객체를 큐에 추가
                        end
                    end
                end
                # --- 이웃 탐색 끝 ---
            end
            # --- BFS 종료 ---

            if expected_netname_ref[] === nothing
                # @warn "  FLOATING! : No netname found metals. Start node = $(start_node.layer), $(start_node.p_coord), $(start_node.points[1].s_coord) - $(start_node.points[2].s_coord)"
                push!(error_info, ErrorInfo(FLOATING, start_node, nothing, nothing, nothing))
                # println(io, "FLOATING: No netname found metals. Start node = $(start_node.layer), $(start_node.p_coord), $(start_node.points[1].s_coord) - $(start_node.points[2].s_coord)")
                error_cnt["floating"] += 1; error_cnt["total"] += 1;
            end

            # --- 현재 컴포넌트 정보 저장 ---
            push!(all_components_info, ComponentInfo(
                current_component_nodes,
                expected_netname_ref[],
                component_consistent[]
            ))
        end
    end

    println("\n--- Connectivity Check Report ---")
    println("Total connected components found: $(length(all_components_info))")

    println("\n---------------------------------")
    println("\nTotal Error Count: $(error_cnt["total"])")
    println("├─ Floating: $(error_cnt["floating"])")
    println("├─ Open: $(error_cnt["open"])")
    println("└─ Short: $(error_cnt["short"])")
    println("---------------------------------")

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


function print_consistency_status(libname::String, cellname::String, io::IO, overall_consistent::Bool, error_cnt::Dict{String, Int})
    println(io, "\n------------------------------------------------------------------\n")

    println(io, "Library: $libname")
    println(io, "Cell: $cellname\n")

    if overall_consistent
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


# function check_and_report_connections_bfs_wo_print(g::MGraph, logFileName::String)::Vector{ComponentInfo}
#     visited_metals = Set{MOVector}()
#     all_components_info = Vector{ComponentInfo}() # 컴포넌트 정보들을 저장할 벡터

#     # 그래프의 모든 노드들을 어떻게 얻을 것인가?
#     # 1. keys(g.adj) - 키로 등록된 노드만 순회 (연결된 간선이 있는 노드)
#     # 2. values(g.adj) 를 모두 펼쳐서 Set으로 만들기 - 그래프 내 모든 노드 포함 가능성 높음
#     # 여기서는 2번 방식 사용 (더 포괄적)
#     all_nodes_in_graph = Set{MOVector}()
#     for key_node in keys(g.adj)
#         push!(all_nodes_in_graph, key_node)
#         for neighbor_node in g.adj[key_node]
#             push!(all_nodes_in_graph, neighbor_node)
#         end
#     end
#     open(logFileName, "w") do io # "w": 쓰기 모드, 파일이 있으면 덮어씀

#     # println(io, "Total unique nodes found in graph: $(length(all_nodes_in_graph))")
#     # println(io, "\\nStarting Connectivity and Netname Consistency Check...")

#     # println("Total unique nodes found in graph: $(length(all_nodes_in_graph))")
#     # println("\\nStarting Connectivity and Netname Consistency Check...")
#     for start_node in all_nodes_in_graph # 그래프 내 모든 노드를 시작점으로 시도
#         if !(start_node in visited_metals)
#             # --- 새 컴포넌트 발견 ---
#             current_component_nodes = Set{MOVector}() # 현재 컴포넌트 노드 저장
#             expected_netname_ref = Ref{Union{String, Nothing}}(nothing)
#             component_consistent = Ref(true)

#             q = Vector{MOVector}() # Queue of MOVector objects

#             # 시작 노드 처리 및 큐에 추가
#             push!(visited_metals, start_node)
#             push!(current_component_nodes, start_node) # 컴포넌트에 시작 노드 추가
#             push!(q, start_node)

#             # 컴포넌트 시작 노드 정보 출력 (노드의 idx 필드가 있다고 가정)
#             start_node_id_str = hasproperty(start_node, :idx) ? " (idx=$(start_node.idx))" : ""
#             # println(io, "Starting BFS for new component from node$(start_node_id_str)...")
#     #        # println("Starting BFS for new component from node$(start_node_id_str)...")
#             # --- BFS 시작 ---
#             while !isempty(q)
#                 u_node::MOVector = popfirst!(q) # Dequeue MOVector

#                 # --- 노드 처리 로직 ---
#                 current_netname = nothing
#                 try
#                     current_netname = u_node.netname # MOVector에서 직접 netname 접근
#                 catch e
#                     node_id_str = hasproperty(u_node, :idx) ? " (idx=$(u_node.idx))" : ""
#                     @error "Failed to get netname for node$(node_id_str). Error: $e"
#                     # println(io, "Netname Fetch Error: Failed to get netname for node$(node_id_str). Error: $e")
#                     component_consistent[] = false
#                 end

#                 if current_netname !== nothing
#                     if expected_netname_ref[] === nothing
#                         expected_netname_ref[] = current_netname
#                         # # println("  Component expected netname set to '$(current_netname)' by node idx=$(u_node.idx)")
#                     elseif current_netname != expected_netname_ref[]
#                         if component_consistent[] # 첫 불일치 시 로그
#                              node_id_str = hasproperty(u_node, :idx) ? " (idx=$(u_node.idx))" : ""
#                              # @warn "  Netname inconsistency! Node$(node_id_str) has netname '$current_netname', but expected '$(expected_netname_ref[])' for this component."
#                             # println(io, "SHORT: Netname inconsistency! Node$(node_id_str) has netname '$current_netname', but expected '$(expected_netname_ref[])' for this component.")
#                         end
#                         component_consistent[] = false
#                     end
#                 end
#                 # --- 노드 처리 끝 ---

#                 # --- 이웃 탐색 및 Enqueue ---
#                 # 현재 노드(u_node)가 adj 딕셔너리의 키로 존재해야 이웃 탐색 가능
#                 if haskey(g.adj, u_node)
#                     for v_node in g.adj[u_node] # v_node는 이웃 MOVector 객체
#                         if !(v_node in visited_metals)
#                             push!(visited_metals, v_node)
#                             push!(current_component_nodes, v_node) # 컴포넌트에 이웃 노드 추가
#                             push!(q, v_node) # 이웃 MOVector 객체를 큐에 추가
#                         end
#                     end
#                 end
#                 # --- 이웃 탐색 끝 ---
#             end
#             # --- BFS 종료 ---

#             # --- 현재 컴포넌트 정보 저장 ---
#             push!(all_components_info, ComponentInfo(
#                 current_component_nodes,
#                 expected_netname_ref[],
#                 component_consistent[]
#             ))
#         end
#     end

#     # println(io, "\\n--- Connectivity Check Report ---")
#     # println(io, "Total connected components found: $(length(all_components_info))")
#     # println("\\n--- Connectivity Check Report ---")
#     # println("Total connected components found: $(length(all_components_info))")
#     overall_consistent = true
#     # --- 최종 결과 출력 ---
#     for (i, component) in enumerate(all_components_info)
#         # println(io, "\\n--- Component $i ---")

#         # 대표 Netname 출력
#         netname_str = component.netname === nothing ? "None (all nodes had 'nothing' netname or component is empty)" : component.netname
#         # println(io, "Representative Net Name: $netname_str")

#         # 일관성 여부 출력
#         # println(io, "Netname Consistency: $(component.is_consistent ? "Passed" : "Failed")")
#         if !component.is_consistent
#             overall_consistent = false
#         end

#         # Metal 목록 출력 (idx 사용 가정)
#         if !isempty(component.nodes)
#             # 모든 노드가 idx 속성을 가지고 있는지 간단히 확인 (선택 사항)
#             if all(hasproperty(node, :idx) for node in component.nodes)
#                  # idx 기준으로 정렬하여 출력
#                  metal_indices = sort([node.idx for node in component.nodes])
#                  # println(io, "Metal Indices ($(length(metal_indices))): $metal_indices")
#             else
#                  # println(io, "Metals ($(length(component.nodes))): [Cannot list indices, some nodes lack .idx property]")
#                  # # println("Metals: $(component.nodes)") # 전체 객체 출력 (길 수 있음)
#             end
#         else
#             # println(io, "Metals: (Empty component)")
#         end
#     end

#     # println(io, "\\n---------------------------------")
#     # println(io, "Overall Graph Netname Consistency: $overall_consistent")
#     # println(io, "---------------------------------")
#     # println("\\n---------------------------------")
#     # println("Overall Graph Netname Consistency: $overall_consistent")
#     # println("---------------------------------")
#     end # file close

#     return all_components_info # 수집된 컴포넌트 정보 반환
# end




# function generate_graph(mdata::MOData, vdata::VData, djs::IntDisjointSets)

#     cgraph = Dict{Int, GraphNode}()

#     for (vtype, vlist) in vdata.vlists
#         for vp in vlist.vpoints
#             overlapping_metals = find_overlapping_metals(vp, mdata)
#             if length(overlapping_metals) == 2
#                 root1 = find_root(djs, overlapping_metals[1].idx)
#                 root2 = find_root(djs, overlapping_metals[2].idx)

#                 edge_m1_v = GraphEdge(vp.idx, overlapping_metals[1].idx, vp.idx)
#                 # edge_v_m1 = GraphEdge(vp.idx, overlapping_metals[1], root1)
#                 edge_m2_v = GraphEdge(vp.idx, overlapping_metals[2].idx, vp.idx)
#                 # edge_v_m2 = GraphEdge(vp.idx, overlapping_metals[2], root2)
#                 if !haskey(cgraph, root1)
#                     cgraph[root1] = GraphNode(Vector{Int}(), Vector{GraphEdge}(), false)
#                 end
#                 if !haskey(cgraph, root2)
#                     cgraph[root2] = GraphNode(Vector{Int}(), Vector{GraphEdge}(), false)
#                 end
#                 push!(cgraph[root1].edges, edge_m1_v)
#                 push!(cgraph[root1].metals, overlapping_metals[1])
#                 push!(cgraph[root2].edges, edge_m2_v)
#                 push!(cgraph[root2].metals, overlapping_metals[2])
#             end
#         end
#     end
#     return cgraph
# end


##################################################################################


# Create connected sets


# NEW VERSION
# Searches 2 mvectors that are connected by vias
# Creates DisjointSets of MVectors



function check_connected_sets(djs::DisjointSets{MVector})
    elements = keys(djs.intmap)                  # 모든 MVector 요소
    groups   = Dict{MVector, Set{MVector}}()     # 대표 원소 → 집합

    for x in elements
        rep = find_root(djs, x)                  # rep: MVector (대표 원소)
        push!( get!(groups, rep, Set{MVector}()), x )
    end

    new_groups = Dict{String, Set{MVector}}()
    for (rep, mvector_set) in groups
        netname = unique([ mv.netname for mv in mvector_set if mv.netname !== nothing ])
        if length(netname) > 1
            # println("Multiple netnames found in the same set: $netname")
        end
        new_groups[string(netname)] = mvector_set
    end


    return new_groups
end




##################################################################################
# OLD VERSION
# Creates connectivity nets by traversing Pin -> MVector -> VPoint -> MVector ... 
##################################################################################


function create_connected_sets(mdata::MData, vdata::VData, named_mvectors::Vector{MVector})

    connected_sets = Dict{String, Set{MVector}}()

    for nmv in named_mvectors
        # Get the netname from the MVector
        netname = nmv.netname

        # println("CUR: $nmv")

        # Check if the netname already exists in the connected_sets dictionary
        if !haskey(connected_sets, netname)
            connected_sets[netname] = Set{MVector}()
        end
        if nmv in connected_sets[netname]
            # println("MVector $nmv already exists in the set for netname $netname")
            continue
        end


        # Perform BFS to find all connected MVectors & VPoints
        q = Queue{Union{MVector, VPoint}}()
        enqueue!(q, nmv)

        while !isempty(q)
            current = dequeue!(q)
            if current in connected_sets[netname]
                # println("Already visited $current")
                continue
            end
            # println("CURRENT node = $current")

            
            if current isa MVector
                # Check for overlapping vias
                overlapping_vias = find_overlapping_vias(current, vdata)

                # println("overlapping vias = $overlapping_vias")
                
                # Enqueue each overlapping via
                foreach(vpoint -> enqueue!(q, vpoint), overlapping_vias)
                
                # 일단 metal만 저장
                push!(connected_sets[netname], current)

            elseif current isa VPoint
                # Check for overlapping metals
                overlapping_metals = find_overlapping_metals(current, mdata)

                # println("overlapping metals = $overlapping_metals")
                
                # Enqueue each overlapping metal
                foreach(mvector -> enqueue!(q, mvector), overlapping_metals)
            end
        end
    end


    return connected_sets, mdata
end



# O(logn)으로 검색 (n = number of vias in the layer&pcoord)
function find_overlapping_vias(mv::MVector, vdata::VData)

    layer = mv.layer
    is_vertical = layer % 2 == 1


    pcoord = mv.p_coord
    srange = (mv.points[1].s_coord, mv.points[2].s_coord) 

    overlapping_vias = Vector{VPoint}()

    search_type = get_search_via_type(layer)

    
    for ty in search_type
        if is_vertical  # pcoord = x
            if haskey(vdata.vxlists, ty) && haskey(vdata.vxlists[ty], pcoord)
                vlist = vdata.vxlists[ty][pcoord]


                low_idx = searchsortedfirst(vlist.vpoints, srange[1], by = x -> (isa(x, VPoint) ? x.xy[2] : x))
                for i in low_idx:length(vlist.vpoints)
                    vpoint = vlist.vpoints[i]
                    if vpoint.xy[2] > srange[2]
                        break
                    end
                    if vpoint.xy[2] >= mv.points[1].s_coord && vpoint.xy[2] <= mv.points[2].s_coord
                        if vpoint.netname !== nothing && vpoint.netname != mv.netname
                            # error("VPoint netname $vpoint.netname is not equal to MVector netname $mv.netname")
                            # println("VPoint netname $vpoint.netname is not equal to MVector netname $mv.netname")
                        end
                        push!(overlapping_vias, vpoint)
                        # update vpoint.netname
                        vpoint.netname = mv.netname
                    end
                end
            else
                continue
            end
        else    # pcoord = y
            if haskey(vdata.vylists, ty) && haskey(vdata.vylists[ty], pcoord)
                vlist = vdata.vylists[ty][pcoord]

                low_idx = searchsortedfirst(vlist.vpoints, srange[1], by = x -> (isa(x, VPoint) ? x.xy[1] : x))
                for i in low_idx:length(vlist.vpoints)
                    vpoint = vlist.vpoints[i]
                    if vpoint.xy[1] > srange[2]
                        break
                    end
                    if vpoint.xy[1] >= mv.points[1].s_coord && vpoint.xy[1] <= mv.points[2].s_coord
                        if vpoint.netname !== nothing && vpoint.netname != mv.netname
                            # error("VPoint netname $vpoint.netname is not equal to MVector netname $mv.netname")
                            # println("VPoint netname $vpoint.netname is not equal to MVector netname $mv.netname")
                        end
                        push!(overlapping_vias, vpoint)
                        # update vpoint.netname
                        # uncomment to update netnames in original VPoints
                        # vpoint.netname = mv.netname
                    end
                end
            else
                continue
            end
        end

    end
    return overlapping_vias
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


# 검색해야 하는 via type을 반환
# ex) layer = 1 -> ["via_M1_M2_0", "via_M1_M2_1"]
# ex) layer = 2 -> ["via_M1_M2_0", "via_M1_M2_1", "via_M2_M3_0", "via_M2_M3_1"]
function get_search_via_type(layer::Int)
    type_list = ["via_M$(layer)_M$(layer+1)_0", "via_M$(layer)_M$(layer+1)_1"]

    if layer > 1
        push!(type_list, "via_M$(layer-1)_M$(layer)_0")
        push!(type_list, "via_M$(layer-1)_M$(layer)_1")
    end
    return type_list
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

end #endif


