using StaticArrays

# A* 알고리즘의 상태(노드) 정의: x, y 좌표와 레이어(z)
struct Node
    x::Int
    y::Int
    z::Int # layer Num
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

