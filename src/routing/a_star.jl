include("RoutingGrid.jl")

# A* 알고리즘
function a_star_route(start_node::Node, goal_node::Node, grid::RoutingGrid, obstacles::Vector{Obstacle})
    
    # 휴리스틱 함수 (맨해튼 거리)
    heuristic(a::Node, b::Node) = abs(a.x - b.x) + abs(a.y - b.y) + grid.via_cost * abs(a.z - b.z)

    # 이웃 노드 탐색 함수 (가장 중요한 부분)
    function get_neighbors(node::Node)
        neighbors = Vector{Node}()
        current_layer_name = grid.rev_layer_map[node.z]

        # 1. 같은 레이어에서 이동 (Horizontal/Vertical)
        if current_layer_name in keys(grid.h_tracks) # 수평 레이어 (M2, M4)
            # 현재 노드의 y 좌표가 수평 트랙에 있는지 확인
            # 실제로는 현재 트랙에서 좌/우로 연결된 모든 v_track 교차점을 이웃으로 추가
            # ... (x좌표를 기준으로 v_tracks의 교차점 탐색)
        elseif current_layer_name in keys(grid.v_tracks) # 수직 레이어 (M3)
            # 현재 노드의 x 좌표가 수직 트랙에 있는지 확인
            # ... (y좌표를 기준으로 h_tracks의 교차점 탐색)
        end

        # 2. 다른 레이어로 이동 (Via)
        # M2 <-> M3, M3 <-> M4 간의 Via 연결 추가
        if node.z > 0 # 아래 레이어로 이동
            push!(neighbors, Node(node.x, node.y, node.z - 1))
        end
        if node.z < length(grid.layer_map) - 1 # 위 레이어로 이동
            push!(neighbors, Node(node.x, node.y, node.z + 1))
        end
        
        # (간략화된 예시로 실제 구현은 그리드 교차점을 정확히 찾아야 합니다)
        return neighbors
    end

    open_set = PriorityQueue{Node, Float64}()
    open_set[start_node] = heuristic(start_node, goal_node)
    
    came_from = Dict{Node, Node}()
    g_score = Dict{Node, Float64}(start_node => 0)

    while !isempty(open_set)
        current = dequeue!(open_set)

        if current == goal_node
            # 경로 재구성
            path = [current]
            while haskey(came_from, current)
                current = came_from[current]
                pushfirst!(path, current)
            end
            return path
        end

        for neighbor in get_neighbors(current)
            # 장애물 충돌 검사 (구현 필요)
            
            # 이동 비용 계산 (via 사용 시 cost 증가)
            move_cost = (current.z == neighbor.z) ? abs(current.x-neighbor.x) + abs(current.y-neighbor.y) : grid.via_cost
            tentative_g_score = g_score[current] + move_cost

            if tentative_g_score < get(g_score, neighbor, Inf)
                came_from[neighbor] = current
                g_score[neighbor] = tentative_g_score
                f_score = tentative_g_score + heuristic(neighbor, goal_node)
                open_set[neighbor] = f_score
            end
        end
    end

    return [] # 경로 탐색 실패
end

# --- 3. A* ROUTING ALGORITHM ---

# 점이 Rect 내부에 있는지 확인하는 헬퍼 함수
function is_inside(x, y, rect::Rect)
    return (rect.xy[1,1] <= x <= rect.xy[2,1]) && (rect.xy[1,2] <= y <= rect.xy[2,2])
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
        all_v_track_xs = vcat(values(grid.v_tracks)...)
        unique!(sort!(all_v_track_xs)) # 정렬 및 중복 제거
        
        # 현재 x 위치의 인덱스를 이진 탐색으로 찾음
        idx = searchsortedfirst(all_v_track_xs, x)

        # 왼쪽 이웃
        if idx > 1
            push!(neighbors, Node(all_v_track_xs[idx-1], y, z))
        end
        # 오른쪽 이웃
        if idx < length(all_v_track_xs)
            push!(neighbors, Node(all_v_track_xs[idx+1], y, z))
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
            track_lower = sort(vcat(grid.h_tracks[z+1]))
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
        # all_h_track_ys = vcat(values(grid.h_tracks)...)
        # unique!(sort!(all_h_track_ys))
        
        idx = searchsortedfirst(all_h_track_ys, y)

        # 아래쪽 이웃
        if idx > 1
            push!(neighbors, Node(x, all_h_track_ys[idx-1], z))
        end
        # 위쪽 이웃
        if idx < length(all_h_track_ys)
            push!(neighbors, Node(x, all_h_track_ys[idx+1], z))
        end
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
            # 현재 y좌표가 M2의 h_track에 존재하는지 확인
            if binarysearch(grid.h_tracks[m2_layer], y) > 0
                push!(neighbors, Node(x, y, m2_layer))
            end
        end
        
        # M3에서 M4로 이동 조건 확인
        m4_layer = get(grid.layer_map, "M4", -1)
        if m4_layer != -1 && haskey(grid.h_tracks, m4_layer)
            # 현재 y좌표가 M4의 h_track에 존재하는지 확인
            if binarysearch(grid.h_tracks[m4_layer], y) > 0
                push!(neighbors, Node(x, y, m4_layer))
            end
        end
    end

    return neighbors
end

# A* 알고리즘
function a_star_route(
    start_regions::Vector{Rect},
    goal_regions::Vector{Rect},
    grid::RoutingGrid,
    obstacles::Vector{Rect}
)
    # 목표 영역의 중심점 계산 (휴리스틱용)
    goal_center_x = round(Int, mean(r.xy[1,1] + r.xy[2,1] for r in goal_regions) / 2)
    goal_center_y = round(Int, mean(r.xy[1,2] + r.xy[2,2] for r in goal_regions) / 2)
    goal_layer = goal_regions[1].layer
    
    heuristic(n) = abs(n.x - goal_center_x) + abs(n.y - goal_center_y) + grid.via_cost * abs(n.z - goal_layer)

    # ... (A* 알고리즘의 나머지 부분: 우선순위 큐, g_score, f_score 등)
    # 이전 답변의 줄리아 A* 코드를 여기에 통합하고,
    # 시작점과 목표점 검사 로직을 단일 노드에서 영역(Region)으로 확장합니다.

    # 1. 시작점들을 open_set에 추가
    # 2. 루프 내 목표 도달 조건: current 노드가 goal_regions 중 하나에 포함되는지 확인
    # 3. 이웃 노드 탐색 시 장애물 검사: get_neighbors에서 반환된 이웃이 obstacles와 충돌하는지 확인

    println("A* 라우팅을 수행합니다 (시작점: $(length(start_regions))개, 목표: $(length(goal_regions))개)")
    # (알고리즘 구현 생략, 이전 답변의 코드와 유사)
    
    # 임시로 경로 반환 (테스트용)
    start_node = Node(start_regions[1].xy[1,1], start_regions[1].xy[1,2], start_regions[1].layer)
    goal_node = Node(goal_regions[1].xy[1,1], goal_regions[1].xy[1,2], goal_regions[1].layer)
    
    return [start_node, goal_node] # 실제로는 탐색된 경로 반환
end