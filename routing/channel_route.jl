include("channel.jl")

"""
    dogleg!(router, top_id, bottom_id, cycle_col)

VCG 순환을 감지했을 때, bottom_id 넷을 분할하여 순환을 해결한다.
"""
function dogleg!(router::ChannelRouter, top_id, bottom_id, cycle_col::Int)::Bool
    println("Dogleg 로직 실행: $top_id 와 $bottom_id 사이의 순환 해결 시도...")
    
    # 1. 순환 관계의 시작 column 찾기
    start_col = -1
    for j in 1:length(router.top_row)
        if router.top_row[j] == bottom_id && router.bottom_row[j] == top_id
            start_col = j
            break
        end
    end
    
    # 2. Dogleg를 삽입할 빈 column 탐색
    candidates = []
    for j in (start_col + 1):(cycle_col - 1)
        if router.top_row[j] == 0 || router.bottom_row[j] == 0
            push!(candidates, j)
        end
    end
    
    if isempty(candidates) # 순환 구간 내에 후보가 없으면 전체에서 탐색
        for j in 1:length(router.top_row)
            if router.top_row[j] == 0 || router.bottom_row[j] == 0
                push!(candidates, j)
            end
        end
    end
    @assert !isempty(candidates) "Dogleg를 위한 빈 공간을 찾지 못했습니다."
    router.dogleg_candidates[bottom_id] = candidates

    # 3. 순환을 유발한 넷(bottom_id)의 모든 핀 이름을 분할
    k = 0
    new_dogleg_names = []
    for j in 1:length(router.top_row)
        new_name = string(bottom_id) * "_dogleg_$(k)"
        if router.top_row[j] == bottom_id
            router.top_row[j] = new_name
            push!(new_dogleg_names, new_name)
            k += 1
        end
        if router.bottom_row[j] == bottom_id
            router.bottom_row[j] = new_name
            push!(new_dogleg_names, new_name)
            k += 1
        end
    end

    # 4. 빈 column에 가상 핀(연결점) 추가
    pos = first(router.dogleg_candidates[bottom_id]) # 첫 번째 후보 위치 사용
    if router.top_row[pos] == 0
        router.top_row[pos] =  new_dogleg_names
    elseif router.bottom_row[pos] == 0
        router.bottom_row[pos] =  new_dogleg_names
    end

    return true # 순환 해결 성공
end

"""
    build_vcg!(router::ChannelRouter)

핀 목록을 바탕으로 VCG를 생성한다. 
Dogleg로 인해 생성된 가상 핀(Vector)을 올바르게 처리한다.
"""
function build_vcg!(router::ChannelRouter)
    router.vcg = VCG() # VCG 초기화
    
    # 1. 모든 핀을 VCG 노드로 추가
    for (i, net_id) in enumerate(router.top_row)
        # [수정] 요소가 Vector인지 확인 (Dogleg 가상 핀 처리)
        if net_id isa AbstractVector
            for id in net_id
                add_node!(router.vcg, id, i-1)
            end
        elseif net_id != 0
            add_node!(router.vcg, net_id, i-1)
        end
    end
    for (i, net_id) in enumerate(router.bottom_row)
        # [수정] 요소가 Vector인지 확인 (Dogleg 가상 핀 처리)
        if net_id isa AbstractVector
            for id in net_id
                add_node!(router.vcg, id, i-1)
            end
        elseif net_id != 0
            add_node!(router.vcg, net_id, i-1)
        end
    end

    # 2. 수직 제약으로 간선 추가 및 순환 검사/해결 (이전과 동일)
    for i in 1:length(router.top_row)
        top_id = router.top_row[i]
        bottom_id = router.bottom_row[i]

        # (top_id나 bottom_id가 Vector인 경우에 대한 간선 추가 로직은 복잡하므로 여기서는 생략)
        # (간단한 예시로, Vector가 아닌 경우에만 간선을 추가)
        if !(top_id isa AbstractVector) && !(bottom_id isa AbstractVector)
            if top_id != 0 && bottom_id != 0 && top_id != bottom_id
                if add_edge!(router.vcg, top_id, bottom_id) # 순환 감지!
                    dogleg!(router, top_id, bottom_id, i)
                    build_vcg!(router) # Dogleg로 핀 정보가 바뀌었으므로 VCG 재생성
                    return # 재귀 호출 후 종료
                end
            end
        end
    end

    # 3. 모든 노드의 xmin, xmax 계산 (이전과 동일)
    for node in values(router.vcg.nodes)
        if !isempty(node.x_coords)
            node.xmin = minimum(node.x_coords)
            node.xmax = maximum(node.x_coords)
        end
    end
end

"""
    assign_tracks!(router::ChannelRouter, channel_y_start, increment)

VCG를 기반으로 Left-Edge 알고리즘을 실행하여 넷을 트랙에 할당한다.
"""
function assign_tracks!(router::ChannelRouter, channel_y_start::Int, increment::Int)
    println("Left-Edge 알고리즘으로 트랙 할당...")
    
    # 1. VCG로부터 넷들의 수평 구간 정보 추출
    intervals = []
    for (id, node) in router.vcg.nodes
        # x_coords가 비어있으면 라우팅 대상이 아님
        if !isempty(node.x_coords)
            push!(intervals, (id=id, xmin=minimum(node.x_coords), xmax=maximum(node.x_coords)))
        end
    end

    # 2. 구간들을 xmin (Left Edge) 기준으로 정렬
    sort!(intervals, by = x -> x.xmin)
    
    # 3. 탐욕적 트랙 할당
    tracks = Vector{Vector{Any}}() # 각 트랙에 할당된 넷 ID 목록
    
    for interval in intervals
        placed = false
        for (track_idx, track) in enumerate(tracks)
            # 현재 트랙에 있는 다른 넷들과 겹치는지 확인
            has_overlap = any(track) do placed_net_id
                placed_net_interval = first(filter(i -> i.id == placed_net_id, intervals))
                # 겹침 조건: 두 구간이 한 점이라도 공유하는 경우
                return interval.xmin <= placed_net_interval.xmax && interval.xmax >= placed_net_interval.xmin
            end
            
            if !has_overlap
                push!(track, interval.id)
                placed = true
                break
            end
        end
        
        if !placed
            push!(tracks, [interval.id]) # 새로운 트랙 생성
        end
    end
    
    # 4. 최종 결과(넷 => 트랙 좌표)를 router 객체에 저장
    for (track_idx, nets_in_track) in enumerate(tracks)
        track_y = channel_y_start + (track_idx - 1) * increment
        for net_id in nets_in_track
            if occursin("_dogleg_", string(net_id))
                router.dogleg_track_assignment[net_id] = track_y
            else
                router.track_assignment[net_id] = track_y
            end
        end
    end
end

"""
    run_channel_routing(pin_list, channels)

채널별로 라우팅 객체를 생성하고, VCG 빌드 및 트랙 할당을 순차적으로 실행한다.
Python core.py의 route_leftedge 메서드에 해당한다.
"""
function run_channel_routing(
    pin_list::Vector,
    channels::Vector{Int},
    grid::RoutingGrid, # 추가
    is_horizontal::Bool, # 추가
    obstacle_grid::Matrix # 추가
)
    
    # 1. 채널별 라우팅 객체(ChannelRouter) 생성
    routers = ChannelRouter[]
    if length(pin_list) == 1
        # 채널이 하나인 경우
        router = ChannelRouter(pin_list[1], []) # bottom_row는 비어있음
        push!(routers, router)
    else
        # 채널이 여러 개인 경우, 인접한 두 채널씩 묶어 라우터 생성
        for i in 1:(length(pin_list) - 1)
            router = ChannelRouter(pin_list[i], pin_list[i+1])
            push!(routers, router)
        end
    end

    # 2. 각 라우팅 객체에 대해 알고리즘 순차 실행
    for (i, router) in enumerate(routers)
        println("\n--- 채널 $(i) 라우팅 시작 ---")

        # 2A. VCG 생성 (내부적으로 dogleg를 통한 순환 해결 포함)
        build_vcg!(router)
        println("VCG 생성 완료. 노드 개수: $(length(router.vcg.nodes))")

        # 2B. Left-Edge 알고리즘으로 트랙 할당
        # channel_y_start: 현재 채널의 시작 y좌표
        # increment: 트랙 번호가 증가하는 방향 (+1은 위로, -1은 아래로)
        assign_tracks!(router, channels[i], 1)
        println("트랙 할당 완료:")
        for (net, track) in sort(collect(router.track_assignment), by=x->x[2])
            println("  - Net: $(net) -> Track Y: $(track)")
        end
        for (net, track) in sort(collect(router.dogleg_track_assignment), by=x->x[2])
            println("  - Net: $(net) -> Track Y: $(track)")
        end
    end
    println("\n--- 모든 채널 라우팅 완료 ---")

    # --- [추가된 부분] ---
    # 4. 할당된 트랙 정보를 바탕으로 Path 객체 생성
    println("\n--- 최종 배선 경로 생성 중 ---")
    successful_paths, failed_paths = generate_paths(routers, channels, grid, is_horizontal, obstacle_grid)

    println("라우팅 완료! 성공: $(length(successful_paths)), 실패: $(length(failed_paths))")
    return successful_paths, failed_paths # [수정] 튜플을 반환

end

"""
    is_path_blocked(path::Path, net_id, obstacle_grid::Matrix) -> Bool

주어진 경로(Path)가 obstacle_grid 상에서 다른 넷의 장애물에 막히는지 확인한다.
경로가 자신의 넷(net_id)이나 비어있는(""), RAIL을 지나는 것은 허용된다.
"""
function is_path_blocked(path::Path, net_id, obstacle_grid::Matrix)
    xmin = min(path.from.x, path.to.x)
    xmax = max(path.from.x, path.to.x)
    ymin = min(path.from.y, path.to.y)
    ymax = max(path.from.y, path.to.y)

    # 경로가 지나는 모든 그리드 셀을 순회
    for x in xmin:xmax
        for y in ymin:ymax
            # 그리드 범위 확인
            if 1 <= x <= size(obstacle_grid, 1) && 1 <= y <= size(obstacle_grid, 2)
                obs_net, _ = obstacle_grid[x, y]
                # 장애물이 있고, 그게 내 넷도 아니고, 빈 공간도 아니면
                if obs_net != "" && obs_net != net_id
                    return true # Blocked
                end
            end
        end
    end
    return false # Not blocked
end

"""
    generate_paths(routers, channels, grid, is_horizontal, obstacle_grid)

라우팅 결과를 바탕으로 Path 객체 리스트를 생성하되, 장애물에 막히는 경로는 실패 처리한다.
성공한 경로와 실패한 경로를 튜플로 반환한다.
"""
function generate_paths(
    routers::Vector{ChannelRouter}, 
    channels::Vector{Int}, 
    grid::RoutingGrid, 
    is_horizontal::Bool,
    obstacle_grid::Matrix
)
    successful_paths = Path[]
    failed_paths = Path[]
    
    h_layer, v_layer = 2, 3 # M2, M3

    for (i, router) in enumerate(routers)
        if i + 1 > length(channels) continue end
        ch_top_y, ch_bottom_y = channels[i], channels[i+1]

        # --- 1. 일반 넷 배선 ---
        for (net_id, track_y) in router.track_assignment
            top_cols = findall(x -> x == net_id, router.top_row)
            bottom_cols = findall(x -> x == net_id, router.bottom_row)
            pin_cols = vcat(top_cols, bottom_cols) # x좌표(column) 목록
            if isempty(pin_cols) continue end
            
            xmin, xmax = minimum(p -> p-1, pin_cols), maximum(p -> p-1, pin_cols)
            
            # Trunk 생성 (Trunk는 장애물 검사 없이 일단 생성)
            trunk = Path(Node(xmin, track_y, h_layer), Node(xmax, track_y, h_layer))
            push!(successful_paths, trunk)

            # Branch 생성
            for col in unique(pin_cols)
                x = col - 1
                pin_y = (net_id in router.top_row) ? ch_top_y : ch_bottom_y
                
                branch = Path(Node(x, pin_y, v_layer), Node(x, track_y, v_layer))

                # [수정] Branch 경로에 대한 장애물 검사
                if is_path_blocked(branch, net_id, obstacle_grid)
                    println("  -> 실패: Net '$net_id'의 Branch가 장애물에 막힘 (pos: $x)")
                    push!(failed_paths, branch)
                else
                    push!(successful_paths, branch)
                    # Via는 Branch가 성공해야 추가
                    push!(successful_paths, Path(Node(x, track_y, h_layer), Node(x, track_y, v_layer)))
                end
            end
        end
        
        # --- 2. Dogleg 넷 배선 (장애물 검사 로직 완성) ---
        
        # 2A: Dogleg 넷들을 base_name 기준으로 그룹화
        dogleg_groups = DefaultDict{String, Vector{Any}}(() -> [])
        for (d_net_id, track_y) in router.dogleg_track_assignment
            base_name = split(string(d_net_id), "_dogleg_")[1]
            push!(dogleg_groups[base_name], (id=d_net_id, track=track_y))
        end

        # 2B: 각 Dogleg 그룹에 대해 수직/수평 경로 생성
        for (base_name, segments) in dogleg_groups
            if isempty(segments) continue end

            dogleg_x = first(router.dogleg_candidates[base_name]) - 1
            all_tracks = [s.track for s in segments]
            min_track_y, max_track_y = minimum(all_tracks), maximum(all_tracks)
            
            # [수정됨] 수직 Dogleg 경로 생성 및 장애물 검사
            vertical_dogleg = Path(Node(dogleg_x, min_track_y, v_layer), Node(dogleg_x, max_track_y, v_layer))
            if is_path_blocked(vertical_dogleg, base_name, obstacle_grid)
                println("  -> 실패: Net '$base_name'의 수직 Dogleg가 장애물에 막힘 (pos: $dogleg_x)")
                push!(failed_paths, vertical_dogleg)
                continue # 수직선이 막히면 하위 경로들은 의미 없으므로 다음 넷으로 넘어감
            else
                push!(successful_paths, vertical_dogleg)
            end

            # 각 세그먼트의 수평 경로 및 연결 Via 생성
            for seg in segments
                d_net_id, track_y = seg.id, seg.track

                pin_col = findfirst(x -> x == d_net_id, router.top_row)
                pin_y = (pin_col !== nothing) ? ch_top_y : ch_bottom_y
                if pin_col === nothing
                    pin_col = findfirst(x -> x == d_net_id, router.bottom_row)
                end
                pin_x = pin_col - 1

                # 1. 핀 -> 수평 트랙 (수직 Branch) + Via
                branch = Path(Node(pin_x, pin_y, v_layer), Node(pin_x, track_y, v_layer))
                if is_path_blocked(branch, base_name, obstacle_grid)
                    println("  -> 실패: Net '$d_net_id'의 Branch가 장애물에 막힘 (pos: $pin_x)")
                    push!(failed_paths, branch)
                    continue # 이 Branch가 실패하면 Trunk도 생성할 수 없음
                else
                    push!(successful_paths, branch)
                    push!(successful_paths, Path(Node(pin_x, track_y, h_layer), Node(pin_x, track_y, v_layer)))
                end
                
                # 2. 수평 트랙 -> Dogleg 연결점 (수평 Trunk) + Via
                trunk = Path(Node(pin_x, track_y, h_layer), Node(dogleg_x, track_y, h_layer))
                if is_path_blocked(trunk, base_name, obstacle_grid)
                    println("  -> 실패: Net '$d_net_id'의 Trunk가 장애물에 막힘 (track: $track_y)")
                    push!(failed_paths, trunk)
                else
                    push!(successful_paths, trunk)
                    push!(successful_paths, Path(Node(dogleg_x, track_y, h_layer), Node(dogleg_x, track_y, v_layer)))
                end
            end
        end
    end
    
    return successful_paths, failed_paths
end

# """
#     generate_paths(routers, channels, grid, is_horizontal)

# 모든 채널의 라우팅 결과를 종합하여 최종 Path 객체 리스트를 생성한다.
# """
# function generate_paths(routers::Vector{ChannelRouter}, channels::Vector{Int}, grid::RoutingGrid, is_horizontal::Bool)
#     all_paths = Path[]
    
#     # --- 채널 방향에 따른 레이어 설정 ---
#     # 주 트랙(Trunk)은 수평, 핀으로의 연결(Branch)과 Dogleg는 수직으로 가정
#     h_layer = 2 # M2
#     v_layer = 3 # M3

#     for (i, router) in enumerate(routers)
#         ch_top_y, ch_bottom_y = channels[i], channels[i+1]

#         # --- 1. 일반 넷 배선 (Trunk & Branch 방식) ---
#         for (net_id, track_y) in router.track_assignment
#             pin_cols = findall(x -> x == net_id, router.top_row)
#             append!(pin_cols, findall(x -> x == net_id, router.bottom_row))
            
#             if isempty(pin_cols) continue end
            
#             xmin, xmax = minimum(pin_cols) - 1, maximum(pin_cols) - 1

#             # Trunk (수평 주 배선) Path 생성
#             trunk_start = Node(xmin, track_y, h_layer)
#             trunk_end   = Node(xmax, track_y, h_layer)
#             push!(all_paths, Path(trunk_start, trunk_end))

#             # Branch (핀으로의 수직 연결) Path 생성
#             for col in unique(pin_cols)
#                 x = col - 1
#                 # Top 핀 연결
#                 if router.top_row[col] == net_id
#                     push!(all_paths, Path(Node(x, ch_top_y, v_layer), Node(x, track_y, v_layer)))
#                     # Via 추가 (점 -> 점, 레이어만 다름)
#                     push!(all_paths, Path(Node(x, track_y, h_layer), Node(x, track_y, v_layer)))
#                 end
#                 # Bottom 핀 연결
#                 if router.bottom_row[col] == net_id
#                     push!(all_paths, Path(Node(x, ch_bottom_y, v_layer), Node(x, track_y, v_layer)))
#                     push!(all_paths, Path(Node(x, track_y, h_layer), Node(x, track_y, v_layer)))
#                 end
#             end
#         end

#         # --- 2. Dogleg 넷 배선 (로직 수정됨) ---
        
#         # 2A: Dogleg 넷들을 base_name 기준으로 그룹화
#         dogleg_groups = DefaultDict{String, Vector{Any}}(() -> [])
#         for (d_net_id, track_y) in router.dogleg_track_assignment
#             base_name = split(string(d_net_id), "_dogleg_")[1]
#             push!(dogleg_groups[base_name], (id=d_net_id, track=track_y))
#         end

#         # 2B: 각 Dogleg 그룹에 대해 수직/수평 경로 생성
#         for (base_name, segments) in dogleg_groups
#             if isempty(segments) continue end

#             # Dogleg 연결점의 x좌표
#             dogleg_x = first(router.dogleg_candidates[base_name]) - 1

#             # 이 넷의 모든 세그먼트가 사용하는 트랙들의 min/max 찾기
#             all_tracks = [s.track for s in segments]
#             min_track_y = minimum(all_tracks)
#             max_track_y = maximum(all_tracks)
            
#             # [누락되었던 로직] 수직 Dogleg 경로 생성
#             v_dogleg_start = Node(dogleg_x, min_track_y, v_layer)
#             v_dogleg_end   = Node(dogleg_x, max_track_y, v_layer)
#             push!(all_paths, Path(v_dogleg_start, v_dogleg_end))

#             # 각 세그먼트의 수평 경로 및 연결 Via 생성
#             for seg in segments
#                 d_net_id = seg.id
#                 track_y = seg.track

#                 # 핀 좌표 찾기
#                 pin_col = findfirst(x -> x == d_net_id, router.top_row)
#                 pin_y = (pin_col !== nothing) ? ch_top_y : ch_bottom_y
#                 if pin_col === nothing
#                     pin_col = findfirst(x -> x == d_net_id, router.bottom_row)
#                 end
#                 pin_x = pin_col - 1

#                 # Path 생성: (핀 -> 수평 트랙 -> 수직 Dogleg)
#                 # 1. 핀에서 수평 트랙까지 수직 Branch
#                 push!(all_paths, Path(Node(pin_x, pin_y, v_layer), Node(pin_x, track_y, v_layer)))
#                 push!(all_paths, Path(Node(pin_x, track_y, h_layer), Node(pin_x, track_y, v_layer))) # Via @ Pin-X
                
#                 # 2. 수평 트랙에서 Dogleg 연결점까지 수평 Trunk
#                 push!(all_paths, Path(Node(pin_x, track_y, h_layer), Node(dogleg_x, track_y, h_layer)))
#                 push!(all_paths, Path(Node(dogleg_x, track_y, h_layer), Node(dogleg_x, track_y, v_layer))) # Via @ Dogleg-X
#             end
#         end
#     end
    
#     return all_paths
# end
