using StaticArrays
using DataStructures
using JSON
# --- 1. DATA STRUCTURES ---
# A* 알고리즘의 상태(노드) 정의: x, y 좌표와 레이어(z)
abstract type Rect end

struct Node
    x::Int
    y::Int
    z::Int # layer Num
end

mutable struct MRect <: Rect
    layer::Int
    xy::SMatrix{2, 2, Int} # [xmin ymin; xmax ymax]
end
mutable struct VRect <: Rect
    type::String
    layer::SVector{2,Int}
    xy::SVector{2,Int}
end

function VRect(;type::String, layer::SVector{2,Int}, xy::SVector{2,Int})
    VRect(type, layer, xy)
end

# 라우팅 그리드 정보를 담을 구조체
# channel route 에 사용할 때는 H layer 하나, V layer 하나만 가능
struct RoutingGrid
    # layer_num => [track_coordinate1, track_coordinate2, ...]
    h_tracks::Dict{Int, Vector{Int}}
    v_tracks::Dict{Int, Vector{Int}}
    # Int(layer_num) <-> String(layer_name) 변환 맵
    layer_map::Dict{String, Int}
    rev_layer_map::Dict{Int, String}
    via_cost::Int
end

# --- 2. HELPER FUNCTIONS ---
# Rect 타입을 Dict로 변환하는 함수
function rect_to_dict(r::Rect, refGrid::RoutingGrid)
    if r isa MRect
        return Dict(
            "type" => "metal",
            "layer" => refGrid.rev_layer_map[r.layer],
            "xy" => transpose(r.xy)   # SMatrix는 JSON에서 배열의 배열로 자동 변환되고 이 경우, transpose해줘야 함.
        )
    elseif r isa VRect
        return Dict(
            "type" => "via",
            "via_type" => r.type,
        #    "layer" => r.layer, # SVector는 JSON에서 배열로 자동 변환됩니다.
            "xy" => r.xy
        )
    end
end

function save_routes_to_json(routes::Dict{String, Vector{Rect}}, refGrid::RoutingGrid, filepath::String)
    # JSON으로 저장 가능한 새로운 딕셔너리를 생성
    serializable_routes = Dict{String, Vector{Dict}}()
    for (netname, rect_list) in routes
        # 각 Rect를 Dict로 변환하여 새로운 리스트를 생성
        serializable_routes[netname] = [rect_to_dict(rect, refGrid) for rect in rect_list]
    end
    # 파일을 열고 JSON 데이터 쓰기
    open(filepath, "w") do f
        # indent=4 옵션으로 가독성 좋게 출력 (pretty printing)
        JSON.print(f, serializable_routes, 4)
    end
    
    println("라우팅 결과를 '$filepath'에 저장했습니다.")
end

const WIRE_HALF_WIDTH = 0 # 와이어 두께 (가정)

"""
    mov_to_rect(mov::MOVector)

MOVector를 A* 알고리즘이 사용할 수 있는 MRect로 변환한다.
"""
function mov_to_rect(mov::MOVector)
    # Layer 2, 4 등은 수평, 3은 수직이라고 가정
    is_horizontal = mov.layer % 2 == 0 

    if is_horizontal
        y = mov.p_coord
        x1 = mov.points[1].s_coord
        x2 = mov.points[2].s_coord
        return MRect(mov.layer, @SMatrix([min(x1, x2) y-WIRE_HALF_WIDTH; max(x1, x2) y+WIRE_HALF_WIDTH]))
    else # Vertical
        x = mov.p_coord
        y1 = mov.points[1].s_coord
        y2 = mov.points[2].s_coord
        return MRect(mov.layer, @SMatrix([x-WIRE_HALF_WIDTH min(y1, y2); x+WIRE_HALF_WIDTH max(y1, y2)]))
    end
end

#    path_to_rects(path::Vector{Node})
# A* 알고리즘이 반환한 Node 경로를 MRect와 VRect의 벡터로 변환한다.
function path_to_rects(path::Vector{Node}, refGrid::RoutingGrid)
    if length(path) < 2
        return Rect[]
    end

    rects = Rect[]
    i = 1
    while i < length(path)
        start_node = path[i]
        end_node = path[i+1]

        # --- Case 1: Via (레이어 변경) ---
        if start_node.x == end_node.x && start_node.y == end_node.y
            if start_node.z > end_node.z
                z_lower = end_node.z; z_upper = start_node.z
            else
                z_lower = start_node.z; z_upper = end_node.z
            end
            via_type = "via_$(refGrid.rev_layer_map[z_lower])_$(refGrid.rev_layer_map[z_upper])"
            layers = @SVector([z_lower, z_upper])
            xy = @SVector([start_node.x, start_node.y])
            push!(rects, VRect(via_type, layers, xy))
            i += 1
            continue
        end

        # --- Case 2: Metal (같은 레이어에서 직선 이동) ---
        is_horizontal = (start_node.y == end_node.y)
        
        # 직선 경로의 끝 찾기
        segment_end_idx = i + 1
        for j in (i + 2):length(path)
            # 현재 직선 경로가 계속 이어지는지 확인
            prev_segment_node = path[j-1]
            next_segment_node = path[j]
            
            # 레이어가 다르거나, (x,y)좌표가 직선을 벗어나면 중단
            if prev_segment_node.z != next_segment_node.z ||
               (is_horizontal && prev_segment_node.y != next_segment_node.y) ||
               (!is_horizontal && prev_segment_node.x != next_segment_node.x)
                break
            end
            segment_end_idx = j
        end
        
        final_node = path[segment_end_idx]
        
        # MRect 생성
        layer = start_node.z
        if is_horizontal
            xmin = min(start_node.x, final_node.x)
            xmax = max(start_node.x, final_node.x)
            y = start_node.y
            bbox = @SMatrix([xmin y - WIRE_HALF_WIDTH; xmax y + WIRE_HALF_WIDTH])
            push!(rects, MRect(layer, bbox))
        else # Vertical
            x = start_node.x
            ymin = min(start_node.y, final_node.y)
            ymax = max(start_node.y, final_node.y)
            bbox = @SMatrix([x - WIRE_HALF_WIDTH ymin; x + WIRE_HALF_WIDTH ymax])
            push!(rects, MRect(layer, bbox))
        end
        
        # 처리한 세그먼트만큼 인덱스 점프
        i = segment_end_idx
    end
    
    return rects
end

# YAML은 간단한 텍스트 파싱으로 처리 (외부 라이브러리 없이)
# 실제 구현 시에는 YAML.jl 패키지 사용을 권장합니다.
function create_grid(layout_bbox::Vector{Int})
    # 이 부분은 제공된 YAML 파일의 구조에 맞춰 간단히 구현합니다.
    # 여기서는 routing_23_cmos와 routing_34_cmos를 합쳐서 그리드를 생성한다고 가정합니다.
    
    h_tracks = Dict(2 => [])#, 4 => [])
    v_tracks = Dict(3 => [])
    layer_map = Dict("M2" => 2, "M3" => 3)#, "M4" => 4)
    rev_layer_map = Dict(2 => "M2", 3 => "M3")#, 4 => "M4")

    # M2 트랙 생성 (예시)
    m2_scope = 1200
    m2_elements = [0, 200, 300, 485, 600, 715, 900, 1000]
    for y_base in 0:m2_scope:(layout_bbox[4])
        for y_el in m2_elements
            push!(h_tracks[2], y_base + y_el)
        end
    end

    # # M4 트랙 생성 (예시)
    # m4_scope = 1200
    # m4_elements = [100, 200, 300, 400, 500, 700, 800, 900, 1000, 1100]
    # for y_base in 0:m4_scope:(layout_bbox[4])
    #     for y_el in m4_elements
    #         push!(h_tracks[4], y_base + y_el)
    #     end
    # end

    # M3 트랙 생성 (예시)
    m3_scope = 130 # M3는 scope가 작고 주기적이지 않을 수 있음
    m3_elements = [0] # 예시 값이므로 실제 파일 값 사용 필요
    for x_base in 0:m3_scope:(layout_bbox[3])
         for x_el in m3_elements
            push!(v_tracks[3], x_base + x_el)
         end
    end
    # ... M4 트랙도 유사하게 추가 ...
    return RoutingGrid(h_tracks, v_tracks, layer_map, rev_layer_map, 400) # Via cost = 10
end

# --- 2. GEOMETRY CATEGORIZATION ---

"""
    categorize_geometry(hash_rect, id_to_netname, target_net)

hash_rect 벡터를 순회하며 각 객체를 핀, 포트, 장애물로 분류한다.
"""
# function categorize_geometry(hash_rect::Vector{Rect}, id_to_netname::Dict{Int, String}, target_net::String)
#     pins = Rect[]
#     ports = Rect[]
#     obstacles = Rect[]

#     for (id, rect) in enumerate(hash_rect)
#         net_of_rect = get(id_to_netname, id, "") # 넷 정보가 없으면 빈 문자열

#         if net_of_rect == target_net
#             # is_pin 레이블은 연결해야 할 최종 목표(핀)
#             if rect isa Label && rect.is_pin
#                 push!(pins, rect)
#             else # 그 외 같은 넷의 모든 지오메트리는 시작점(포트)
#                 push!(ports, rect)
#             end
#         else
#             # 관심 넷이 아니면 모두 장애물
#             push!(obstacles, rect)
#         end
#     end
#     return pins, ports, obstacles
# end

# function create_id_to_netname_map(connectivity_graph::Dict{Int, GraphNode}, hash_rect::Vector{Rect})
#     id_to_netname = Dict{Int, String}()

#     # 1. connectivity_graph를 통해 ID와 netname 매핑
#     for (node_id, node_data) in connectivity_graph
#         # GraphNode에 netname이 있고, rect_ref 목록이 있는 경우
#         if node_data.netname !== nothing && !isempty(node_data.rect_ref)
#             for rect_id in node_data.rect_ref
#                 id_to_netname[rect_id] = node_data.netname
#             end
#         end
#     end

#     # 2. Label 객체 정보로 매핑 보완 (그래프에 포함되지 않은 핀 레이블을 위해)
#     for (id, rect) in enumerate(hash_rect)
#         if rect isa Label && !haskey(id_to_netname, id)
#              if rect.netname !== nothing
#                 id_to_netname[id] = rect.netname
#              end
#         end
#     end
    
#     return id_to_netname
# end


# function parse_layout_data(filepath::String)
#     nets = Dict{String, Vector{Pin}}()
#     obstacles = Vector{Obstacle}()
#     data = JSON.parsefile(filepath)

#     for (cell_name, cell_data) in data["logic_generated"]
#         # 셀의 바운딩 박스를 장애물로 추가
#         if haskey(cell_data, "bbox") && cell_data["bbox"][1] != cell_data["bbox"][2]
#             bbox = [cell_data["bbox"][1][1], cell_data["bbox"][1][2], cell_data["bbox"][2][1], cell_data["bbox"][2][2]]
#             push!(obstacles, Obstacle(bbox))
#         end
        
#         # 핀 정보 추출
#         if haskey(cell_data, "subblocks")
#             for subblock in cell_data["subblocks"]
#                 if haskey(subblock, "pins")
#                     for (pin_name, pin_data) in subblock["pins"]
#                         net_name = pin_data["netname"]
#                         if !haskey(nets, net_name)
#                             nets[net_name] = []
#                         end
#                         xy = pin_data["xy_flatten"]
#                         bbox = [min(xy[1][1], xy[2][1]), min(xy[1][2], xy[2][2]), max(xy[1][1], xy[2][1]), max(xy[1][2], xy[2][2])]
#                         push!(nets[net_name], Pin(net_name, pin_data["layer"], bbox))
#                     end
#                 end
#             end
#         end
#     end
#     return nets, obstacles
# end
