include("RoutingGrid.jl")
using Statistics
# --- 3. A* ROUTING ALGORITHM ---

# --- 헬퍼 함수 (이전과 동일) ---
function is_inside(node::Node, rect::Rect)
    # VRect는 점이므로 별도 처리
    if rect isa VRect
        return rect.layer[1] == node.z && rect.xy[1] == node.x && rect.xy[2] == node.y
    end
    # MRect와 Label 처리
    return rect.layer == node.z && 
           (rect.xy[1,1] <= node.x <= rect.xy[2,1]) && 
           (rect.xy[1,2] <= node.y <= rect.xy[2,2])
end

"""
    get_neighbors(current_node::Node, grid::RoutingGrid)

주어진 노드에서 이동 가능한 모든 이웃 노드(다음 교차점)를 반환한다.
M3 -> M2/M4 이동 시, 현재 y좌표가 목표 레이어의 h_track에 존재하는지 확인한다.
"""
function get_neighbors(current_node::Node, grid::RoutingGrid)
    neighbors = Vector{Node}()
    x, y, z = current_node.x, current_node.y, current_node.z

    is_horizontal = haskey(grid.h_tracks, z)
    is_vertical = haskey(grid.v_tracks, z)

    # --- 1. 같은 레이어 내에서의 이동 ---
    if is_horizontal
        # 현재 레이어는 수평 트랙 레이어 (M2, M4 등)
        # 이웃은 현재 y트랙을 따라 다음 x 교차점(v_track)으로 이동한 노드
        
        # 교차점을 만들 수 있는 모든 수직 트랙 목록 (보통 M3)
        # 여기서는 모든 v_track을 합쳐서 사용한다고 가정
        vert_track = collect(values(grid.v_tracks))[1]
        # unique!(sort!(all_v_track_xs)) # 정렬 및 중복 제거
        
        # 현재 x 위치의 인덱스를 이진 탐색으로 찾음
        idx = searchsortedfirst(vert_track, x)

        # 왼쪽 이웃
        if idx > 1
            push!(neighbors, Node(vert_track[idx-1], y, z))
        end
        # 오른쪽 이웃
        if idx < length(vert_track)
            push!(neighbors, Node(vert_track[idx+1], y, z))
        end

    elseif is_vertical
        # 현재 레이어는 수직 트랙 레이어 (M3 등)
        # 이웃은 현재 x트랙을 따라 다음 y 교차점(h_track)으로 이동한 노드

        if haskey(grid.h_tracks, z+1)
            track_upper = grid.h_tracks[z+1] # already sorted
            idx_upper   = searchsortedfirst(track_upper, y)
            if idx_upper < 1 # this current y val is not alogned with upper layer
                push!(neighbors, Node(x, track_upper[1], z))
            elseif idx_upper > length(track_upper) # this current y val is not alogned with upper layer
                push!(neighbors, Node(x, track_upper[end], z))
            elseif y != track_upper[idx_upper] # this current y val is not alogned with upper layer
                push!(neighbors, Node(x, track_upper[idx_upper], z))
                if idx_upper > 1
                    push!(neighbors, Node(x, track_upper[idx_upper-1], z))
                end
            else
                if idx_upper > 1
                    push!(neighbors, Node(x, track_upper[idx_upper-1], z))
                end
                if idx_upper < length(track_upper)
                    push!(neighbors, Node(x, track_upper[idx_upper+1], z))
                end                
            end
        end
        if haskey(grid.h_tracks, z-1)
            track_lower = sort(vcat(grid.h_tracks[z-1]))
            idx_lower   = searchsortedfirst(track_lower, y)
            if idx_lower < 1 # this current y val is not alogned with upper layer
                push!(neighbors, Node(x, track_lower[1], z))
            elseif idx_lower > length(track_lower) # this current y val is not alogned with upper layer
                push!(neighbors, Node(x, track_lower[end], z))
            elseif y != track_lower[idx_lower] # this current y val is not alogned with upper layer
                push!(neighbors, Node(x, track_lower[idx_lower], z))
                if idx_lower > 1
                    push!(neighbors, Node(x, track_lower[idx_lower-1], z))
                end
            else
                if idx_lower > 1
                    push!(neighbors, Node(x, track_lower[idx_lower-1], z))
                end
                if idx_lower < length(track_lower)
                    push!(neighbors, Node(x, track_lower[idx_lower+1], z))
                end                
            end
        end
        # # all_h_track_ys = vcat(values(grid.h_tracks)...)
        # # unique!(sort!(all_h_track_ys))
        
        # idx = searchsortedfirst(all_h_track_ys, y)

        # # 아래쪽 이웃
        # if idx > 1
        #     push!(neighbors, Node(x, all_h_track_ys[idx-1], z))
        # end
        # # 위쪽 이웃
        # if idx < length(all_h_track_ys)
        #     push!(neighbors, Node(x, all_h_track_ys[idx+1], z))
        # end
    end

    # --- 2. 다른 레이어로의 이동 (Via) [로직 수정됨] ---
    if is_horizontal # M2 -> M3 또는 M4 -> M3
        # 현재 노드(x,y)는 유효한 교차점이므로, M3로의 이동은 항상 가능
        m3_layer = get(grid.layer_map, "M3", -1)
        if m3_layer != -1
            push!(neighbors, Node(x, y, m3_layer))
        end
    elseif is_vertical # M3 -> M2 또는 M3 -> M4
        # M3에서 M2로 이동 조건 확인
        m2_layer = get(grid.layer_map, "M2", -1)
        if m2_layer != -1 && haskey(grid.h_tracks, m2_layer)
            m2_tracks = grid.h_tracks[m2_layer]
            # searchsortedfirst로 찾은 위치의 값이 실제 y와 같은지 확인
            idx = searchsortedfirst(m2_tracks, y)
            if idx <= length(m2_tracks) && m2_tracks[idx] == y
                push!(neighbors, Node(x, y, m2_layer))
            end
        end
        
        # M3에서 M4로 이동 조건 확인
        m4_layer = get(grid.layer_map, "M4", -1)
        if m4_layer != -1 && haskey(grid.h_tracks, m4_layer)
            m4_tracks = grid.h_tracks[m4_layer]
            # searchsortedfirst로 찾은 위치의 값이 실제 y와 같은지 확인
            idx = searchsortedfirst(m4_tracks, y)
            if idx <= length(m4_tracks) && m4_tracks[idx] == y
                push!(neighbors, Node(x, y, m4_layer))
            end
        end
    end

    return neighbors
end


# --- 통합된 A* 라우팅 함수 ---
function a_star_route(
    start_regions::Vector{Rect},
    goal_regions::Vector{Rect},
    grid::RoutingGrid,
    obstacles::Vector{Rect},
    fid
)
    # 1. 휴리스틱 함수 정의
    goal_center_x = round(Int, mean((r.xy[1,1] + r.xy[2,1])/2 for r in goal_regions))
    goal_center_y = round(Int, mean((r.xy[1,2] + r.xy[2,2])/2 for r in goal_regions))
    goal_layer = first(goal_regions).layer
    
    heuristic(n) = abs(n.x - goal_center_x) + abs(n.y - goal_center_y) + grid.via_cost * abs(n.z - goal_layer)

    # 2. A* 알고리즘 자료구조 초기화
    open_set = PriorityQueue{Node, Float64}()
    came_from = Dict{Node, Node}()
    g_score = Dict{Node, Float64}()

    # # 3. 시작 영역 내 모든 유효 그리드 노드를 open_set에 추가
    # for region in start_regions
    #     # (이 부분은 시작 영역 내 그리드 노드를 찾는 로직이 필요, 여기서는 중심점으로 단순화)
    #     start_node = Node(round(Int, (region.xy[1,1] + region.xy[2,1])/2), 
    #                       round(Int, (region.xy[1,2] + region.xy[2,2])/2),
    #                       region.layer)
    #     g_score[start_node] = 0
    #     open_set[start_node] = heuristic(start_node)
    #     println(fid, "open_set: ", open_set)
    # end
    # 3. 시작 영역 내 모든 유효 그리드 노드를 open_set에 추가 (수직 영역 로직 추가됨)
    println("Initializing A* with $(length(start_regions)) start regions...")
    all_h_tracks = vcat(values(grid.h_tracks)...) |> unique |> sort
    all_v_tracks = vcat(values(grid.v_tracks)...) |> unique |> sort
    
    for region in start_regions
        layer = region.layer
        xmin, ymin = region.xy[1,1], region.xy[1,2]
        xmax, ymax = region.xy[2,1], region.xy[2,2]
        
        # 수평 영역 처리
        if haskey(grid.h_tracks, layer)
            for y in grid.h_tracks[layer]
                if ymin <= y <= ymax
                    # 영역 내에 있는 수직 트랙들을 찾아 교차점을 노드로 추가
                    for x in all_v_tracks
                         if xmin <= x <= xmax
                            start_node = Node(x, y, layer)
                            if !haskey(g_score, start_node)
                                g_score[start_node] = 0
                                open_set[start_node] = heuristic(start_node)
                            end
                        end
                    end
                end
            end
        # 수직 영역 처리
        elseif haskey(grid.v_tracks, layer)
            for x in grid.v_tracks[layer]
                if xmin <= x <= xmax
                    # 영역 내에 있는 수평 트랙들을 찾아 교차점을 노드로 추가
                    for y in all_h_tracks
                        if ymin <= y <= ymax
                            start_node = Node(x, y, layer)
                            if !haskey(g_score, start_node)
                                g_score[start_node] = 0
                                open_set[start_node] = heuristic(start_node)
                            end
                        end
                    end
                end
            end
        end
    end
    
    println(fid, "A* search started with $(length(open_set)) initial nodes.")
    println(fid, "open_set: $(open_set)")
    # 4. A* 메인 루프
    while !isempty(open_set)
        current = dequeue!(open_set)
        println(fid, "current Node: ", current)

        # 5. 목표 도달 확인: 현재 노드가 목표 영역 중 하나에 속하는가?
        for region in goal_regions
            if is_inside(current, region)
                println(fid, "path found!")
                path = [current]
                while haskey(came_from, current)
                    current = came_from[current]
                    pushfirst!(path, current)
                end
                println(fid, "path: ", path)
                return path # 경로 재구성 및 반환
            end
        end 
        # 6. 이웃 노드 탐색 및 평가
        for neighbor in get_neighbors(current, grid)
            # 7. 장애물 충돌 검사
            is_blocked = any(obs -> is_inside(neighbor, obs), obstacles)
            if is_blocked
                println(fid, neighbor,"is blocked")
                continue
            end
            println(fid, "current neighbor: ",neighbor)
            # 8. 이동 비용 계산 및 경로 업데이트
            move_cost = (current.z == neighbor.z) ? (abs(current.x-neighbor.x) + abs(current.y-neighbor.y)) : grid.via_cost
            tentative_g_score = get(g_score, current, Inf) + move_cost
            println(fid, "tentative_g_score: ",tentative_g_score)

            if tentative_g_score < get(g_score, neighbor, Inf)
                came_from[neighbor] = current
                g_score[neighbor] = tentative_g_score
                f_score = tentative_g_score + heuristic(neighbor)
                open_set[neighbor] = f_score
            end

            println(fid, "g_score of neighbor: ",get(g_score, neighbor, Inf))
            println(fid, "open_set[neighbor]: ",get(open_set, neighbor, -1))
        end
    end
    return [] # 경로 탐색 실패
end

# # --- 4. MAIN ROUTING LOGIC ---

# """
#     route_single_net(target_net, components, grid, all_obstacles)

# 하나의 넷에 속한 모든 컴포넌트들을 데이지 체인 방식으로 연결한다.
# """
# function route_single_net(target_net::String, components::Vector{ComponentInfo}, grid::RoutingGrid, all_obstacles::Vector{Rect}, fid)
#     println("\n--- Routing Net: $target_net ---")
    
#     if length(components) <= 1
#         println(fid, "컴포넌트가 1개 이하이므로 라우팅이 필요 없습니다.")
#         return Rect[]
#     end
#     # 첫 번째 컴포넌트를 시작점으로 설정
#     source_geometry = Rect[mov_to_rect(mov) for mov in components[1].nodes]
    
#     total_new_routes = Rect[]

#     # 나머지 컴포넌트들을 순차적으로 연결
#     for i in 2:length(components)
#         println(fid, "Connecting component $(components[i].number) to the main group...")
        
#         target_geometry = Rect[mov_to_rect(mov) for mov in components[i].nodes]
        
#         # 현재까지 라우팅된 경로도 장애물에 포함시켜야 자기 자신을 가로지르지 않음
#         current_obstacles = [all_obstacles; total_new_routes]

#         path_nodes = a_star_route(source_geometry, target_geometry, grid, current_obstacles, fid)

#         if isempty(path_nodes)
#             println(fid,"Warn:  -> Failed to connect component $(components[i].number) for net $(target_net)")
#             @warn":  -> Failed to connect component $(components[i].number) for net $(target_net)"
#             continue
#         end

#         # 경로를 MRect 객체로 변환 (구현 필요)
#         new_path_rects = path_to_rects(path_nodes) 
#         # new_path_rects = Rect[] # 임시
#         println(fid, "  -> Path found with $(length(path_nodes)) nodes.")
        
#         # 새로 생성된 경로를 전체 경로와 소스 지오메트리에 추가
#         append!(total_new_routes, new_path_rects)
#         append!(source_geometry, target_geometry, new_path_rects)
#     end
    
#     return total_new_routes
# end

function route_single_net(target_net::String, components::Vector{ComponentInfo}, grid::RoutingGrid, all_obstacles::Vector{Rect}, fid)
    println("\n--- Routing Net: $target_net ---")
    
    if length(components) <= 1
        println("컴포넌트가 1개 이하이므로 라우팅이 필요 없습니다.")
        return Rect[]
    end

    # 첫 번째 컴포넌트를 시작점으로 설정
    source_components = [components[1]]
    remaining_components = components[2:end]
    
    total_new_routes = Rect[]

    # 모든 컴포넌트가 연결될 때까지 반복
    while !isempty(remaining_components)
        # # 현재 연결된 모든 컴포넌트의 모든 MOVector를 시작 영역으로 설정
        # start_regions = Rect[mov_to_rect(mov) for comp in source_components for mov in comp.nodes]
        # --- [핵심 수정 부분] ---
        # 1. 소스 컴포넌트들의 원본 지오메트리를 Rect로 변환
        start_regions_from_comps = Rect[mov_to_rect(mov) for comp in source_components for mov in comp.nodes]
        # 2. 원본 지오메트리와 이전 라우팅에서 생성된 경로를 합쳐서 새로운 시작 영역으로 설정
        start_regions = [start_regions_from_comps; total_new_routes]
        # --- [수정 완료] ---        
        # 아직 연결되지 않은 모든 컴포넌트의 모든 MOVector를 목표 영역으로 설정
        goal_regions = Rect[mov_to_rect(mov) for comp in remaining_components for mov in comp.nodes]

        println(fid, "$(target_net): Connecting $(length(source_components)) components to $(length(remaining_components)) components...")
        
        # 현재까지 라우팅된 경로도 장애물에 포함
        current_obstacles = [all_obstacles; total_new_routes]

        path_nodes = a_star_route(start_regions, goal_regions, grid, current_obstacles, fid)

        if isempty(path_nodes)
            @warn "  -> Path not found for net $target_net. Aborting."
            break 
        end
        
        # 새로 찾은 경로를 Rect 객체로 변환
        new_path_rects = path_to_rects(path_nodes) 
        println(fid, "  -> Path found. Adding $(length(new_path_rects)) new rectangles.")
        append!(total_new_routes, new_path_rects)

        # 경로가 연결된 목표 컴포넌트를 찾아 소스 그룹으로 이동
        hit_node = last(path_nodes)
        hit_component_idx = -1
        for (i, comp) in enumerate(remaining_components)
            if any(mov -> is_inside(hit_node, mov_to_rect(mov)), comp.nodes)
                hit_component_idx = i
                break
            end
        end

        if hit_component_idx != -1
            push!(source_components, remaining_components[hit_component_idx])
            deleteat!(remaining_components, hit_component_idx)
        else
            @warn "Could not identify which component was hit. Routing may be incorrect."
        end
    end
    
    return total_new_routes
end

"""
    route_all_nets(cinfo, grid)

전체 cinfo 데이터를 기반으로 라우팅이 필요한 모든 넷을 찾아 실행한다.
"""
# function route_all_nets(cinfo::Vector{ComponentInfo}, grid::RoutingGrid)
#     savefilename = "/Users/hjpark97/WORK/laygo_mcp/preLVS/out/log/pathFind_log.out"
#     fid = open(savefilename, "w")
#     # 1. 넷 이름별로 컴포넌트 그룹화
#     net_to_components = Dict{String, Vector{ComponentInfo}}()
#     for component in cinfo
#         netname = component.netname
#         if netname !== nothing && netname ∉ ["VDD:", "VSS:"]
#             if !haskey(net_to_components, netname)
#                 net_to_components[netname] = []
#             end
#             push!(net_to_components[netname], component)
#         end
#     end

#     all_routes = Dict{String, Vector{Rect}}()

#     # 2. 각 넷에 대해 라우팅 실행
#     for (netname, components) in net_to_components
#         # 현재 넷을 제외한 모든 컴포넌트를 장애물로 설정
#         obstacle_components = filter(c -> c.netname != netname, cinfo)
#         all_obstacles = Rect[mov_to_rect(mov) for comp in obstacle_components for mov in comp.nodes]

#         new_routes = route_single_net(netname, components, grid, all_obstacles, fid)
#         all_routes[netname] = new_routes
#     end
#     close(fid)
#     return all_routes
# end

function route_all_nets(cinfo::Vector{ComponentInfo}, grid::RoutingGrid, logfile=nothing)
    savefilename::String
    if isnothing(logfile)
        savefilename = "out/log/pathFind_log.out"
    else
        savefilename = logfile
    end
    # savefilename = "/Users/hjpark97/WORK/laygo_mcp/preLVS/out/log/pathFind_log.out"
    fid = open(savefilename, "w")
    # 1. 모든 컴포넌트의 지오메트리를 넷 이름별로 미리 변환하여 저장
    net_to_geometry = Dict{String, Vector{Rect}}()
    for component in cinfo
        netname = component.netname
        if netname === nothing continue end
        if !haskey(net_to_geometry, netname)
            net_to_geometry[netname] = []
        end
        for mov in component.nodes
            push!(net_to_geometry[netname], mov_to_rect(mov))
        end
    end
    # 2. 넷 이름별로 ComponentInfo 객체를 그룹화
    net_to_components = Dict{String, Vector{ComponentInfo}}()
    for component in cinfo
        netname = component.netname
        if netname !== nothing
            if !haskey(net_to_components, netname)
                net_to_components[netname] = []
            end
            push!(net_to_components[netname], component)
        end
    end
    # 라우팅할 넷 목록 (VDD, VSS 제외)
    nets_to_route = filter(k -> k ∉ ["VDD:", "VSS:"], keys(net_to_components))
    
    # 최종 라우팅 결과를 저장할 딕셔너리
    final_routes = Dict{String, Vector{Rect}}()
    # 이전에 완료된 라우팅 경로를 누적할 벡터
    all_newly_routed_rects = Rect[]

    # 3. 각 넷에 대해 순차적으로 라우팅 실행
    for target_net in nets_to_route
        # 현재 라우팅할 넷의 컴포넌트들을 가져옴
        components = net_to_components[target_net]

        # 3.1. 장애물 목록 생성 (핵심 수정)
        #   - 다른 넷의 모든 원본 지오메트리
        #   - 이전에 라우팅되어 새로 생성된 모든 경로
        current_obstacles = Rect[]
        for (net, geom_list) in net_to_geometry
            if net != target_net
                append!(current_obstacles, geom_list)
            end
        end
        append!(current_obstacles, all_newly_routed_rects)

        # 3.2. 현재 넷 라우팅 실행
        new_routes_for_current_net = route_single_net(target_net, components, grid, current_obstacles, fid)
        
        # 3.3. 라우팅 결과를 누적
        final_routes[target_net] = new_routes_for_current_net
        append!(all_newly_routed_rects, new_routes_for_current_net)
    end
    
    return final_routes
end