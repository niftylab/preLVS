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



# YAML은 간단한 텍스트 파싱으로 처리 (외부 라이브러리 없이)
# 실제 구현 시에는 YAML.jl 패키지 사용을 권장합니다.
function create_grid(layout_bbox::Vector{Int})
    # 이 부분은 제공된 YAML 파일의 구조에 맞춰 간단히 구현합니다.
    # 여기서는 routing_23_cmos와 routing_34_cmos를 합쳐서 그리드를 생성한다고 가정합니다.
    
    h_tracks = Dict(2 => [], 4 => [])
    v_tracks = Dict(3 => [])
    layer_map = Dict("M2" => 2, "M3" => 3, "M4" => 4)
    rev_layer_map = Dict(2 => "M2", 3 => "M3", 4 => "M4")

    # M2 트랙 생성 (예시)
    m2_scope = 1200
    m2_elements = [0, 200, 300, 485, 600, 715, 900, 1000]
    for y_base in 0:m2_scope:(layout_bbox[4])-m2_scope
        for y_el in m2_elements
            push!(h_tracks[2], y_base + y_el)
        end
    end

    # M4 트랙 생성 (예시)
    m4_scope = 1200
    m4_elements = [100, 200, 300, 400, 500, 700, 800, 900, 1000, 1100]
    for y_base in 0:m4_scope:(layout_bbox[4])-m4_scope
        for y_el in m4_elements
            push!(h_tracks[4], y_base + y_el)
        end
    end

    # M3 트랙 생성 (예시)
    m3_scope = 130 # M3는 scope가 작고 주기적이지 않을 수 있음
    m3_elements = [0] # 예시 값이므로 실제 파일 값 사용 필요
    for x_base in 0:m3_scope:(layout_bbox[3])-m3_scope
         for x_el in m3_elements
            push!(v_tracks[3], x_base + x_el)
         end
    end
    # ... M4 트랙도 유사하게 추가 ...
    return RoutingGrid(h_tracks, v_tracks, layer_map, rev_layer_map, 400) # Via cost = 10
end


"""
    get_grid_index(tracks::Vector{Int}, coord::Int) -> Int

실제 좌표(coord)를 가장 가까운 그리드 트랙의 인덱스(1-based)로 변환한다.
"""
function get_grid_index(tracks::Vector{Int}, coord::Int)
    idx = searchsortedfirst(tracks, coord)
    if idx == 1; return 1; end
    if idx > length(tracks); return length(tracks); end
    if abs(tracks[idx-1] - coord) < abs(tracks[idx] - coord)
        return idx - 1
    else
        return idx
    end
end