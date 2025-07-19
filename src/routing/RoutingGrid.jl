using StaticArrays

# A* 알고리즘의 상태(노드) 정의: x, y 좌표와 레이어(z)
struct Node
    x::Int
    y::Int
    z::Int # layer
end

# 라우팅 그리드 정보를 담을 구조체
struct RoutingGrid
    # layer_num => [track_coordinate1, track_coordinate2, ...]
    h_tracks::Dict{Int, Vector{Int}}
    v_tracks::Dict{Int, Vector{Int}}
    
    # Int(layer_num) <-> String(layer_name) 변환 맵
    layer_map::Dict{String, Int}
    rev_layer_map::Dict{Int, String}
    
    via_cost::Int
end
function parse_layout_data(filepath::String)
    nets = Dict{String, Vector{Pin}}()
    obstacles = Vector{Obstacle}()
    data = JSON.parsefile(filepath)

    for (cell_name, cell_data) in data["logic_generated"]
        # 셀의 바운딩 박스를 장애물로 추가
        if haskey(cell_data, "bbox") && cell_data["bbox"][1] != cell_data["bbox"][2]
            bbox = [cell_data["bbox"][1][1], cell_data["bbox"][1][2], cell_data["bbox"][2][1], cell_data["bbox"][2][2]]
            push!(obstacles, Obstacle(bbox))
        end
        
        # 핀 정보 추출
        if haskey(cell_data, "subblocks")
            for subblock in cell_data["subblocks"]
                if haskey(subblock, "pins")
                    for (pin_name, pin_data) in subblock["pins"]
                        net_name = pin_data["netname"]
                        if !haskey(nets, net_name)
                            nets[net_name] = []
                        end
                        xy = pin_data["xy_flatten"]
                        bbox = [min(xy[1][1], xy[2][1]), min(xy[1][2], xy[2][2]), max(xy[1][1], xy[2][1]), max(xy[1][2], xy[2][2])]
                        push!(nets[net_name], Pin(net_name, pin_data["layer"], bbox))
                    end
                end
            end
        end
    end
    return nets, obstacles
end

# YAML은 간단한 텍스트 파싱으로 처리 (외부 라이브러리 없이)
# 실제 구현 시에는 YAML.jl 패키지 사용을 권장합니다.
function create_grid_from_yaml(filepath::String, layout_bbox::Vector{Int})
    # 이 부분은 제공된 YAML 파일의 구조에 맞춰 간단히 구현합니다.
    # 여기서는 routing_23_cmos와 routing_34_cmos를 합쳐서 그리드를 생성한다고 가정합니다.
    
    h_tracks = Dict("M2" => [], "M4" => [])
    v_tracks = Dict("M3" => [])
    layer_map = Dict("M2" => 0, "M3" => 1, "M4" => 2)
    rev_layer_map = Dict(0 => "M2", 1 => "M3", 2 => "M4")

    # M2 트랙 생성 (예시)
    m2_scope = 1200
    m2_elements = [0, 200, 300, 485, 600, 715, 900, 1000]
    for y_base in 0:m2_scope:(layout_bbox[4])
        for y_el in m2_elements
            push!(h_tracks["M2"], y_base + y_el)
        end
    end

    # M3 트랙 생성 (예시)
    m3_scope = 130 # M3는 scope가 작고 주기적이지 않을 수 있음
    m3_elements = [0] # 예시 값이므로 실제 파일 값 사용 필요
    for x_base in 0:m3_scope:(layout_bbox[3])
         for x_el in m3_elements
            push!(v_tracks["M3"], x_base + x_el)
         end
    end
    # ... M4 트랙도 유사하게 추가 ...

    return RoutingGrid(h_tracks, v_tracks, layer_map, rev_layer_map, 10) # Via cost = 10
end

# --- 2. GEOMETRY CATEGORIZATION ---

"""
    categorize_geometry(hash_rect, id_to_netname, target_net)

hash_rect 벡터를 순회하며 각 객체를 핀, 포트, 장애물로 분류한다.
"""
function categorize_geometry(hash_rect::Vector{Rect}, id_to_netname::Dict{Int, String}, target_net::String)
    pins = Rect[]
    ports = Rect[]
    obstacles = Rect[]

    for (id, rect) in enumerate(hash_rect)
        net_of_rect = get(id_to_netname, id, "") # 넷 정보가 없으면 빈 문자열

        if net_of_rect == target_net
            # is_pin 레이블은 연결해야 할 최종 목표(핀)
            if rect isa Label && rect.is_pin
                push!(pins, rect)
            else # 그 외 같은 넷의 모든 지오메트리는 시작점(포트)
                push!(ports, rect)
            end
        else
            # 관심 넷이 아니면 모두 장애물
            push!(obstacles, rect)
        end
    end
    return pins, ports, obstacles
end

function create_id_to_netname_map(connectivity_graph::Dict{Int, GraphNode}, hash_rect::Vector{Rect})
    id_to_netname = Dict{Int, String}()

    # 1. connectivity_graph를 통해 ID와 netname 매핑
    for (node_id, node_data) in connectivity_graph
        # GraphNode에 netname이 있고, rect_ref 목록이 있는 경우
        if node_data.netname !== nothing && !isempty(node_data.rect_ref)
            for rect_id in node_data.rect_ref
                id_to_netname[rect_id] = node_data.netname
            end
        end
    end

    # 2. Label 객체 정보로 매핑 보완 (그래프에 포함되지 않은 핀 레이블을 위해)
    for (id, rect) in enumerate(hash_rect)
        if rect isa Label && !haskey(id_to_netname, id)
             if rect.netname !== nothing
                id_to_netname[id] = rect.netname
             end
        end
    end
    
    return id_to_netname
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
        
        all_h_track_ys = vcat(values(grid.h_tracks)...)
        unique!(sort!(all_h_track_ys))
        
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