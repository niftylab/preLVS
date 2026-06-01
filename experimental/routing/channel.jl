using StaticArrays
using Statistics
using DataStructures
using LinearAlgebra # transpose
include("RoutingGrid.jl")

struct Path
    from::Node
    to::Node
end

# --- VCG(수직 제약 그래프) 구성을 위한 구조체 (수정됨) ---

# [추가됨] 넷의 타입을 나타내기 위한 Enum 정의
@enum RouteType SINGLE TOP TOPANDBOTTOM BOTTOM NO_TRK MULTI_NO_TRK

mutable struct VCGNode
    id::Any 
    parents::Vector{Any}
    children::Vector{Any}
    x_coords::Vector{Int}
    xmin::Int               # [추가됨] 넷의 수평 구간 시작점
    xmax::Int               # [추가됨] 넷의 수평 구간 끝점
    route_type::RouteType   # [추가됨] 넷의 타입 (TOP, BOTTOM 등)
    
    function VCGNode(id)
        # xmin은 최대값으로, xmax는 최소값으로 초기화하여 min/max 업데이트 용이
        new(id, [], [], [], typemax(Int), typemin(Int), SINGLE)
    end
end

mutable struct VCG
    nodes::Dict{Any, VCGNode}
    VCG() = new(Dict())
end

# --- 채널 라우팅 알고리즘 메인 구조체 (수정됨) ---
mutable struct ChannelRouter
    top_row::Vector
    bottom_row::Vector
    vcg::VCG
    dogleg_candidates::Dict{Any, Vector{Int}}

    # 라우팅 결과
    track_assignment::Dict{Any, Int}
    dogleg_track_assignment::Dict{Any, Int} # [추가됨] Dogleg 넷 트랙 할당
    no_track_nets::Vector{Int}              # [추가됨] 직선 연결 넷
    
    function ChannelRouter(top, bottom)
        new(top, bottom, VCG(), Dict(), Dict(), Dict(), [])
    end
end
# 입력으로 받는 Pin 구조체 (사용자 제공)

# 라우팅에 사용하기 위해 가공된 Pin 정보
struct ProcessedPin
    netname::String
    layer::String
    bbox::SMatrix{2, 2, Int} # [xmin ymin; xmax ymax] (추상 좌표)
    channel::Int             # 채널의 추상 좌표
    position::Int            # 채널 내 위치의 추상 좌표
end

# for channel router output
function path_to_rects(paths::Vector{Path}, refGrid::RoutingGrid)
    rects = Rect[]
    for path in paths
        # from과 to의 x,y가 같으면 Via
        if path.from.x == path.to.x && path.from.y == path.to.y
            if path.from.z > path.to.z
                z_lower = path.to.z; z_upper = path.from.z
            else
                z_lower = path.from.z; z_upper = path.to.z
            end
            via_type = "via_$(refGrid.rev_layer_map[z_lower])_$(refGrid.rev_layer_map[z_upper])"
            layers = @SVector([path.from.z, path.to.z])
            xy = @SVector([path.from.x, path.from.y])
            push!(rects, VRect(via_type, layers, xy))
        # 아니면 Metal
        else
            layer = path.from.z # from과 to의 레이어는 같다고 가정
            xmin = min(path.from.x, path.to.x)
            xmax = max(path.from.x, path.to.x)
            ymin = min(path.from.y, path.to.y)
            ymax = max(path.from.y, path.to.y)
            
            # # 두께 적용
            # if ymin == ymax # Horizontal
            #      ymin -= WIRE_HALF_WIDTH; ymax += WIRE_HALF_WIDTH
            # else # Vertical
            #      xmin -= WIRE_HALF_WIDTH; xmax += WIRE_HALF_WIDTH
            # end
            push!(rects, MRect(layer, @SMatrix([xmin ymin; xmax ymax])))
        end
    end
    return rects
end

# VCG 관련 함수들
function add_node!(vcg::VCG, id, x_coord)
    if !haskey(vcg.nodes, id)
        vcg.nodes[id] = VCGNode(id)
    end
    push!(vcg.nodes[id].x_coords, x_coord)
end

function add_edge!(vcg::VCG, from_id, to_id)
    # 순환(cycle)이 발생하는지 확인: to -> from 경로가 이미 존재하는가?
    if has_path(vcg, to_id, from_id)
        return true # Cycle detected
    end
    
    if !(to_id in vcg.nodes[from_id].children)
        push!(vcg.nodes[from_id].children, to_id)
        push!(vcg.nodes[to_id].parents, from_id)
    end
    return false # No cycle
end

# DFS(깊이 우선 탐색)를 이용한 경로 존재 확인 함수
function has_path(vcg::VCG, start_id, end_id, visited=Set())
    push!(visited, start_id)
    for child_id in vcg.nodes[start_id].children
        if child_id == end_id || has_path(vcg, child_id, end_id, visited)
            return true
        end
    end
    return false
end

"""
    get_grid_index(tracks::Vector{Int}, coord::Int) -> Int

실제 좌표(coord)를 가장 가까운 그리드 트랙의 인덱스(1-based)로 변환한다.
"""
function get_grid_index(tracks::Vector{Int}, coord::Int)
    # searchsortedfirst는 값이 삽입될 위치를 반환
    idx = searchsortedfirst(tracks, coord)
    if idx == 1; return 1; end
    if idx > length(tracks); return length(tracks); end
    
    # 더 가까운 쪽의 인덱스를 선택
    if abs(tracks[idx-1] - coord) < abs(tracks[idx] - coord)
        return idx - 1
    else
        return idx
    end
end

"""
    process_pins(pins, grid, main_track_layer) -> (Vector{ProcessedPin}, Vector{Int})

입력 Pin 목록을 분석하여 ProcessedPin 목록과 파워 레일 위치를 반환한다. (cc 함수 대체)
"""
function process_pins(pins::Vector{Pin}, grid::RoutingGrid, main_track_layer::String)
    processed_pins = ProcessedPin[]
    power_rail_channels = Int[]
    
    is_horizontal = main_track_layer == "M2" # M2면 수평, M3면 수직 채널로 가정
    
    # 그리드 트랙 정보 추출
    h_tracks = vcat(values(grid.h_tracks)...) |> unique |> sort
    v_tracks = vcat(values(grid.v_tracks)...) |> unique |> sort

    for pin in pins
        # 1. 실제 좌표 bbox 계산
        real_bbox = [
            pin.xy[1][1] - pin.hextension, pin.xy[1][2] - pin.vextension \
            pin.xy[2][1] + pin.hextension, pin.xy[2][2] + pin.vextension ]

        # 2. 파워 레일 처리
        if pin.netname in ["VDD:", "VSS:"]
            # 파워 레일의 채널 위치(추상 좌표)를 저장
            rail_center_y = round(Int, (real_bbox[2] + real_bbox[4]) / 2)
            rail_channel_idx = get_grid_index(h_tracks, rail_center_y)
            push!(power_rail_channels, rail_channel_idx)
            continue
        end

        # 3. 실제 좌표를 추상 좌표로 변환
        abs_xmin = get_grid_index(v_tracks, real_bbox[1])
        abs_ymin = get_grid_index(h_tracks, real_bbox[2])
        abs_xmax = get_grid_index(v_tracks, real_bbox[3])
        abs_ymax = get_grid_index(h_tracks, real_bbox[4])
        abstract_bbox = @SMatrix([abs_xmin abs_ymin; abs_xmax abs_ymax])
        
        # 4. 채널 및 위치 계산 (Python 로직과 동일)
        if is_horizontal
            channel  = round(Int, (abs_ymin + abs_ymax) / 2)
            position = round(Int, (abs_xmin + abs_xmax) / 2)
        else # Vertical
            channel  = round(Int, (abs_xmin + abs_xmax) / 2)
            position = round(Int, (abs_ymin + abs_ymax) / 2)
        end
        
        push!(processed_pins, ProcessedPin(pin.netname, pin.layer, abstract_bbox, channel, position))
    end
    
    return processed_pins, unique(sort(power_rail_channels))
end

"""
    create_obstacle_grid(cinfo, processed_pins, power_rails, grid_size, grid, is_horizontal)

cinfo의 모든 금속과 processed_pins의 핀 정보를 종합하여 장애물 지도를 생성한다.
"""
function create_obstacle_grid(
    cinfo::Vector{ComponentInfo},
    processed_pins::Vector{ProcessedPin},
    power_rails::Vector{Int},
    grid_size::Tuple{Int, Int},
    grid::RoutingGrid,
    is_horizontal::Bool
)
    # 넷 이름과 레이어 정보를 담는 2차원 배열 생성
    obstacle_grid = fill(("", ""), grid_size)
    
    # 그리드 트랙 정보 추출
    h_tracks = vcat(values(grid.h_tracks)...) |> unique |> sort
    v_tracks = vcat(values(grid.v_tracks)...) |> unique |> sort

    # --- 1. cinfo의 모든 금속을 기본 장애물로 등록 ---
    for component in cinfo
        netname = component.netname
        if netname === nothing continue end

        for mov in component.nodes
            rect = mov_to_rect(mov) # MRect 객체로 변환
            # 실제 좌표를 추상 좌표로 변환
            abs_bbox = [
                get_grid_index(v_tracks, rect.xy[1,1]), get_grid_index(h_tracks, rect.xy[1,2]),
                get_grid_index(v_tracks, rect.xy[2,1]), get_grid_index(h_tracks, rect.xy[2,2])
            ]
            
            # 장애물 그리드에 기록
            for x in abs_bbox[1]:abs_bbox[3]
                for y in abs_bbox[2]:abs_bbox[4]
                    if 1 <= x <= grid_size[1] && 1 <= y <= grid_size[2]
                        obstacle_grid[x, y] = (netname, "M" * string(mov.layer))
                    end
                end
            end
        end
    end

    # --- 2. processed_pins 정보로 덮어쓰기 (extension 규칙 적용) ---
    for pin in processed_pins
        # 수평 채널에서 수직 핀은 x방향으로 1 확장
        extension = (is_horizontal && pin.bbox[1,1] == pin.bbox[2,1]) ? 1 : 0
        
        xmin, ymin = pin.bbox[1,1], pin.bbox[1,2]
        xmax, ymax = pin.bbox[2,1], pin.bbox[2,2]

        for x in (xmin - extension):(xmax + extension)
            for y in ymin:ymax
                if 1 <= x <= grid_size[1] && 1 <= y <= grid_size[2]
                    obstacle_grid[x, y] = (pin.netname, pin.layer)
                end
            end
        end
    end

    # --- 3. 파워 레일 처리 ---
    for rail_ch in power_rails
        for pos in 1:grid_size[1] # 채널의 전체 폭에 대해
             if is_horizontal
                 if 1 <= pos <= grid_size[1] && 1 <= rail_ch <= grid_size[2]
                     obstacle_grid[pos, rail_ch] = ("RAIL", "M2")
                 end
             else # Vertical
                 if 1 <= rail_ch <= grid_size[1] && 1 <= pos <= grid_size[2]
                     obstacle_grid[rail_ch, pos] = ("RAIL", "M3")
                 end
             end
        end
    end
    
    return obstacle_grid
end

"""
    add_virtual_pins!(pin_list, channels, obstacle_grid, processed_pins)

하나의 net이 여러 채널에 걸쳐 끊어져 있을 때, 그 사이를 연결하는 가상 핀을 추가한다.
pin_list를 직접 수정한다.
"""
function add_virtual_pins!(
    pin_list::Vector{Vector{Any}}, 
    channels::Vector{Int}, 
    obstacle_grid::Matrix, 
    processed_pins::Vector{ProcessedPin}
)
    # 1. 전체 넷 이름 목록 생성
    netname_list = unique([p.netname for p in processed_pins])

    # 2. 각 넷에 대해 끊어진 채널 찾기
    virtual_pin_channels = DefaultDict{Any, Vector{Int}}(() -> Int[])
    
    for netname in netname_list
        last_seen_channel_idx = 0
        for (i, nets_on_channel) in enumerate(pin_list)
            if netname in nets_on_channel
                # 이전에 넷이 발견되었고, 바로 인접한 채널이 아니라면
                if last_seen_channel_idx > 0 && last_seen_channel_idx + 1 != i
                    # 그 사이의 모든 채널을 가상 핀 추가 대상으로 지정
                    for j in (last_seen_channel_idx + 1):(i - 1)
                        push!(virtual_pin_channels[netname], j)
                    end
                end
                last_seen_channel_idx = i
            end
        end
    end

    # 3. 찾은 채널에 가상 핀 삽입
    for (netname, ch_indices) in virtual_pin_channels
        for ch_idx in ch_indices
            
            # 이전 채널(ch_idx-1)에 있는 동일 넷의 핀 위치들을 후보로 삼음
            candidate_positions = findall(x -> x == netname, pin_list[ch_idx-1])
            
            is_placed = false
            # 후보 위치 바로 아래가 비어있는지 먼저 확인
            for pos in candidate_positions
                # 장애물 그리드를 확인하여 비어있거나 같은 넷이면 배치 가능
                # (obstacle_grid의 차원과 is_horizontal 플래그에 따라 인덱싱 주의)
                if obstacle_grid[pos, channels[ch_idx]][1] == "" || obstacle_grid[pos, channels[ch_idx]][1] == netname
                    pin_list[ch_idx][pos] = netname
                    is_placed = true
                    break
                end
            end

            # 바로 아래에 놓지 못했다면, 사용 가능한 첫 번째 빈 공간에 배치
            if !is_placed
                # obstacle_grid의 해당 채널 행(또는 열)에서 빈 공간 찾기
                empty_pos = findfirst(x -> x[1] == "", obstacle_grid[:, channels[ch_idx]])
                if empty_pos !== nothing
                    pin_list[ch_idx][empty_pos[1]] = netname
                else
                    @warn "가상 핀을 추가할 빈 공간을 찾지 못했습니다: Net $netname, Channel Idx $ch_idx"
                end
            end
        end
    end
end

function initialize_routing_data(cinfo::Vector{ComponentInfo}, pins::Vector{Pin}, grid::RoutingGrid, main_track_layer::String)
    
    println("1. 핀 정보 처리 및 추상 좌표로 변환 중...")
    is_horizontal = main_track_layer == "M2"
    processed_pins, power_rails = process_pins(pins, grid, main_track_layer)
    
    println("2. 채널 경계 정의 중...")
    channels = unique(sort([p.channel for p in processed_pins]))

    # 그리드 전체 크기 결정 (추상 좌표 기준)
    max_pos = maximum(p -> p.position, processed_pins)
    max_ch = maximum(channels)
    grid_size = is_horizontal ? (max_pos, max_ch) : (max_ch, max_pos)
    
    println("3. 장애물 그리드 생성 중...")
#    obstacle_grid = create_obstacle_grid(cinfo, processed_pins, power_rails, grid_size, is_horizontal)
    obstacle_grid = create_obstacle_grid(cinfo, processed_pins, power_rails, grid_size, grid, is_horizontal) # grid 추가
    
    println("4. Left-Edge 알고리즘용 핀 목록 생성 중...")
    pin_list = [fill(0, grid_size[1]) for _ in 1:length(channels)]
    channel_map = Dict(ch => i for (i, ch) in enumerate(channels)) # 채널 좌표 -> pin_list 인덱스

    for pin in processed_pins
        ch_idx = channel_map[pin.channel]
        pos_idx = pin.position
        pin_list[ch_idx][pos_idx] = pin.netname
    end

    println("5. 가상 핀 추가 중...")
    add_virtual_pins!(pin_list, channels, obstacle_grid, processed_pins)
    println("초기화 완료!")
    return pin_list, obstacle_grid, channels
end
