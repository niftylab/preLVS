using StaticArrays
using DataStructures
# using CSV
# using DataFrames
using Printf
# --- 필요한 Struct 정의 (이전 답변 내용) ---
# Node, Path, MRect, VRect, RoutingGrid, ComponentInfo, MOVector, MPoint 등
# ...
include("RoutingGrid.jl")

"""
    generate_grid_maps(cinfo::Vector{ComponentInfo}, grid::RoutingGrid)

cinfo의 모든 넷네임을 사전순으로 정렬하여 고유한 16진수 ID를 부여하고,
이를 바탕으로 ASCII 슬라이스 맵을 생성하여 문자열과 ID 맵을 반환한다.
"""
function generate_grid_maps(cinfo::Vector{ComponentInfo}, grid::RoutingGrid, cellname::String)
    
    # --- 1. 넷네임 수집 및 사전순 정렬 ---
    all_netnames = Set{String}()
    for component in cinfo
        netname = component.netname
        if netname !== nothing && netname ∉ ["VDD:", "VSS:"]
            push!(all_netnames, netname)
        end
    end
    sorted_netnames = sort(collect(all_netnames))

    # --- 2. 넷네임 -> 16진수 ID 맵 생성 ---
    net_id_map = Dict{String, String}()
    for (i, netname) in enumerate(sorted_netnames)
        # 0-based 인덱스를 두 자리 16진수 문자열로 변환 (예: 9 -> "09", 10 -> "0A")
        net_id_map[netname] = uppercase(@sprintf("%02X", i - 1))
    end
    
    # --- 3. 그리드 및 맵 초기화 ---
    all_h_tracks = vcat(values(grid.h_tracks)...) |> unique |> sort
    all_v_tracks = vcat(values(grid.v_tracks)...) |> unique |> sort
    max_x = length(all_v_tracks)
    max_y = length(all_h_tracks)
    
    maps = Dict{Int, Matrix{String}}() # Char에서 String으로 변경
    all_layers = sort(unique(vcat(collect(keys(grid.h_tracks)), collect(keys(grid.v_tracks)))))
    for layer in all_layers
        maps[layer] = fill("..", (max_y, max_x)) # 2자리 ID이므로 ".."으로 초기화
    end
    
    # --- 4. 맵 위에 cinfo의 금속(장애물) 덮어쓰기 ---
    for component in cinfo
        netname = component.netname
        if haskey(net_id_map, netname)
            obs_id = net_id_map[netname]
            for mov in component.nodes
                layer = mov.layer
                if !haskey(maps, layer) continue end

                is_horizontal = haskey(grid.h_tracks, layer)
                
                p_idx = is_horizontal ? get_grid_index(all_h_tracks, mov.p_coord) : get_grid_index(all_v_tracks, mov.p_coord)
                s_start_idx = get_grid_index(is_horizontal ? all_v_tracks : all_h_tracks, mov.points[1].s_coord)
                s_end_idx   = get_grid_index(is_horizontal ? all_v_tracks : all_h_tracks, mov.points[2].s_coord)
                
                s_start_idx, s_end_idx = minmax(s_start_idx, s_end_idx)

                if is_horizontal && (1 <= p_idx <= max_y) && (1 <= s_end_idx <= max_x)
                    maps[layer][p_idx, s_start_idx:s_end_idx] .= obs_id
                elseif !is_horizontal && (1 <= p_idx <= max_x) && (1 <= s_end_idx <= max_y)
                    maps[layer][s_start_idx:s_end_idx, p_idx] .= obs_id
                end
            end
        end
    end

    # --- 5. Y축 레이블 정보 생성 ---
    y_idx_to_labels = DefaultDict{Int, Vector{String}}(() -> String[])
    for (layer_num, h_track_ys) in grid.h_tracks
        layer_name = grid.rev_layer_map[layer_num]
        sorted_layer_tracks = sort(h_track_ys)
        for (layer_track_idx, y_coord) in enumerate(sorted_layer_tracks)
            global_y_idx = get_grid_index(all_h_tracks, y_coord)
            push!(y_idx_to_labels[global_y_idx], "$(layer_name)_trk=$(layer_track_idx-1)")
        end
    end

    # --- 6. 최종 출력 문자열 생성 ---
    output_str = "--- Routing Grid Map ---\n"
    output_str *= "cell: $(cellname)\n"
    output_str *= "Origin Netname => Mapped Character: "    
    for (_netname, _id) in net_id_map
        output_str *= "$(_netname) => $(_id) , "   
    end
    output_str *= "\n"
    max_label_width = 0
    if !isempty(y_idx_to_labels)
        max_label_width = maximum(length(join(labels, ", ")) for labels in values(y_idx_to_labels))
    end
    
    for layer in all_layers
        layer_name = grid.rev_layer_map[layer]
        output_str *= "\n## Layer $(layer) ($(layer_name)):\n"
        
        for y_idx in max_y:-1:1
            labels = get(y_idx_to_labels, y_idx, [""])
            label_str = lpad(join(labels, ", "), max_label_width)
            
            output_str *= "$(label_str) | "
            output_str *= join(maps[layer][y_idx, :], " ")
            output_str *= " |\n"
        end
        
        output_str *= " "^(max_label_width+2) * "+" * "─"^(max_x*3 - 1) * "\n"
        x_labels = join([lpad(i-1, 2) for i in 1:max_x], " ")
        output_str *= " "^(max_label_width+3) * x_labels * "\n"
    end
    
    return output_str
end

"""
    generate_grid_maps_json(cinfo::Vector{ComponentInfo}, grid::RoutingGrid, cellname::String)

Creates a structured dictionary with routing map information and returns it as a JSON string.
"""
function generate_grid_maps_json(cinfo::Vector{ComponentInfo}, grid::RoutingGrid, cellname::String)

    # --- 1. Collect and sort netnames ---
    all_netnames = Set{String}()
    for component in cinfo
        netname = component.netname
        if netname !== nothing # && netname ∉ ["VDD:", "VSS:"]
            push!(all_netnames, netname)
        end
    end
    sorted_netnames = sort(collect(all_netnames))

    # --- 2. Create netname -> Hex ID map ---
    net_id_map = Dict{String, String}()
    for (i, netname) in enumerate(sorted_netnames)
        net_id_map[netname] = uppercase(@sprintf("%02X", i - 1))
    end
    
    # --- 3. Initialize grid and map data structures ---
    all_h_tracks = vcat(values(grid.h_tracks)...) |> unique |> sort
    all_v_tracks = vcat(values(grid.v_tracks)...) |> unique |> sort
    max_x = length(all_v_tracks)
    max_y = length(all_h_tracks)
    
    maps = Dict{Int, Matrix{String}}()
    all_layers = sort(unique(vcat(collect(keys(grid.h_tracks)), collect(keys(grid.v_tracks)))))

    # [수정] Via 레이어 추가 (-23, -34는 정렬 및 처리를 위한 임시 키)
    push!(all_layers, -23, -34) # via23, via34
    sort!(all_layers)

    for layer in all_layers
        maps[layer] = fill("..", (max_y, max_x))
    end
    
    # --- 4. Populate maps with obstacles from cinfo ---
    for component in cinfo
        netname = component.netname
        if haskey(net_id_map, netname)
            obs_id = net_id_map[netname]
            for mov in component.nodes
                layer = mov.layer
                if !haskey(maps, layer) continue end

                is_horizontal = haskey(grid.h_tracks, layer)
                
                p_idx = is_horizontal ? get_grid_index(all_h_tracks, mov.p_coord) : get_grid_index(all_v_tracks, mov.p_coord)
                s_start_idx = get_grid_index(is_horizontal ? all_v_tracks : all_h_tracks, mov.points[1].s_coord)
                s_end_idx   = get_grid_index(is_horizontal ? all_v_tracks : all_h_tracks, mov.points[2].s_coord)
                
                s_start_idx, s_end_idx = minmax(s_start_idx, s_end_idx)

                if is_horizontal && (1 <= p_idx <= max_y) && (1 <= s_end_idx <= max_x)
                    maps[layer][p_idx, s_start_idx:s_end_idx] .= obs_id
                elseif !is_horizontal && (1 <= p_idx <= max_x) && (1 <= s_end_idx <= max_y)
                    maps[layer][s_start_idx:s_end_idx, p_idx] .= obs_id
                end
            end
        end
    end

    # --- 4. Populate maps with via obstacles from cinfo ---
    for component in cinfo
        netname = component.netname
        if haskey(net_id_map, netname)
            obs_id = net_id_map[netname]
            if isdefined(component, :vias) && component.vias !== nothing
                for via in component.vias
                    # [FIX] Check if all layers for this via exist in the grid's layer_map
                    if !all(l -> haskey(grid.layer_map, l), via.layer)
                        continue # Skip this via if it connects to an unknown layer (like M1)
                    end

                    via_layers_num = sort([grid.layer_map[l] for l in via.layer])
                    
                    target_map_key = 0
                    if via_layers_num == [2, 3]; target_map_key = -23;
                    elseif via_layers_num == [3, 4]; target_map_key = -34;
                    else continue; end
                    
                    x_idx = get_grid_index(all_v_tracks, via.xy[1])
                    y_idx = get_grid_index(all_h_tracks, via.xy[2])
                    
                    if 1 <= y_idx <= max_y && 1 <= x_idx <= max_x
                        maps[target_map_key][y_idx, x_idx] = obs_id
                    end
                end
            end
        end
    end

    # --- 5. Generate Y-axis info ---
    y_idx_to_labels = DefaultDict{Int, Vector{String}}(() -> String[])
    for (layer_num, h_track_ys) in grid.h_tracks
        layer_name = grid.rev_layer_map[layer_num]
        sorted_layer_tracks = sort(h_track_ys)
        for (layer_track_idx, y_coord) in enumerate(sorted_layer_tracks)
            global_y_idx = get_grid_index(all_h_tracks, y_coord)
            push!(y_idx_to_labels[global_y_idx], "$(layer_name)_trk=$(layer_track_idx-1)")
        end
    end

    # --- 6. Construct the final JSON structure ---
    output_dict = Dict()
    output_dict["cell_name"] = cellname
    output_dict["legend"] = Dict(id => net for (net, id) in net_id_map)
    
    grid_maps_list = []
    special_layer_names = Dict(-23 => "viaM2M3", -34 => "viaM3M4")

    for layer in all_layers
        layer_map_dict = Dict()
        
        # Use a real layer number for the JSON output, not the temporary key
        layer_map_dict["layer"] = layer > 0 ? layer : replace(string(layer), "-" => "")

        layer_name = get(grid.rev_layer_map, layer, get(special_layer_names, layer, "unknown"))
        layer_map_dict["layer_name"] = layer_name
        
        # X-axis info (physical coordinates)
        layer_map_dict["x_axis_info"] = [0:max_x-1] # [all_v_tracks[i] for i in 1:max_x]
        
        # Y-axis info (track descriptions)
        y_info_col = [join(get(y_idx_to_labels, y_idx, [""]), ", ") for y_idx in max_y:-1:1]
        layer_map_dict["y_axis_info"] = y_info_col
        
        # Map data (array of strings)
        map_rows = [join(maps[layer][y_idx, :], " ") for y_idx in max_y:-1:1]
        layer_map_dict["map"] = map_rows
        
        push!(grid_maps_list, layer_map_dict)
    end
    output_dict["grid_maps"] = grid_maps_list
    
    # --- 7. Serialize to JSON string with pretty printing ---
    return JSON.json(output_dict, 2)
end

# currently not used
# function save_grid_maps_to_csv(cinfo::Vector{ComponentInfo}, grid::RoutingGrid, basename::String="routing_map")
    
#     # --- 1. 맵 데이터 및 레이블 생성 (이전과 동일) ---
#     all_h_tracks = vcat(values(grid.h_tracks)...) |> unique |> sort
#     all_v_tracks = vcat(values(grid.v_tracks)...) |> unique |> sort
#     max_x = length(all_v_tracks)
#     max_y = length(all_h_tracks)
    
#     maps = Dict{Int, Matrix{Char}}()
#     all_layers = sort(unique(vcat(collect(keys(grid.h_tracks)), collect(keys(grid.v_tracks)))))
#     for layer in all_layers; maps[layer] = fill('.', (max_y, max_x)); end

#     # 2. [핵심] 추상 y-인덱스 -> 물리 트랙 정보(레이블) 맵 생성
#     y_idx_to_labels = DefaultDict{Int, Vector{String}}(() -> String[])
#     for (layer_num, h_track_ys) in grid.h_tracks
#         layer_name = grid.rev_layer_map[layer_num]
#         for y_coord in h_track_ys
#             y_idx = get_grid_index(all_h_tracks, y_coord)
#             # 예시: "y=200(M2)" 형식의 레이블 생성
#             push!(y_idx_to_labels[y_idx], "y=$(y_coord)($(layer_name))")
#         end
#     end
    
#     # 3. 각 레이어별 맵(Canvas) 초기화 및 장애물 그리기
#     maps = Dict{Int, Matrix{Char}}()
#     all_layers = sort(unique(vcat(collect(keys(grid.h_tracks)), collect(keys(grid.v_tracks)))))
#     for layer in all_layers
#         maps[layer] = fill('.', (max_y, max_x)) # 빈 공간으로 초기화
#     end
    
#     # cinfo의 금속(장애물) 덮어쓰기 (이전과 동일)
#     net_char_map = Dict{String, Char}()
#     char_code = Int('A')
#     println("drawing intersect finish")
#     # --- 4. 맵 위에 cinfo의 금속(장애물) 덮어쓰기 ---
#     net_char_map = Dict{String, Char}()
#     char_code = Int('A')

#     for component in cinfo
#         netname = component.netname
#         if netname === nothing || netname in ["VDD:", "VSS:"] continue end
        
#         if !haskey(net_char_map, netname)
#             net_char_map[netname] = Char(char_code)
#             char_code += 1
#         end
#         obs_char = net_char_map[netname]

#         for mov in component.nodes
#             _layer = mov.layer
#             if !haskey(grid.rev_layer_map, _layer) && !haskey(grid.layer_map, _layer)
#                 continue
#             end
#             is_horizontal = _layer % 2 == 0

#             p_idx = is_horizontal ? get_grid_index(all_h_tracks, mov.p_coord) : get_grid_index(all_v_tracks, mov.p_coord)
#             s_start_idx = get_grid_index(is_horizontal ? all_v_tracks : all_h_tracks, mov.points[1].s_coord)
#             s_end_idx   = get_grid_index(is_horizontal ? all_v_tracks : all_h_tracks, mov.points[2].s_coord)

#             if is_horizontal
#                 maps[_layer][p_idx, s_start_idx:s_end_idx] .= obs_char
#             else # Vertical
#                 maps[_layer][s_start_idx:s_end_idx, p_idx] .= obs_char
#             end
#         end
#     end
#     println("overwrite cinfo finish")

#     # 2. [수정됨] y축 레이블을 새로운 형식으로 생성
#     y_idx_to_labels = DefaultDict{Int, Vector{String}}(() -> String[])
#     for (layer_num, h_track_ys) in grid.h_tracks
#         layer_name = grid.rev_layer_map[layer_num]
#         for y_coord in h_track_ys
#             y_idx = get_grid_index(all_h_tracks, y_coord)
#             # 형식: "y=좌표(레이어)"
#             push!(y_idx_to_labels[y_idx], "y=$(y_coord)($(layer_name))")
#         end
#     end
#     # 3. 각 레이어별로 DataFrame 생성 및 CSV 저장
#     for layer in all_layers
#         df = DataFrame()
        
#         # [수정됨] 1. y_info -> y_coordinate 헤더 변경 및 2. y값 형식 통합
#         y_info_col = String[]
#         for y_idx in max_y:-1:1
#             labels = get(y_idx_to_labels, y_idx, [])
#             if isempty(labels)
#                 push!(y_info_col, "y=$(all_h_tracks[y_idx])") # 트랙 정보가 없는 경우 좌표만 표시
#             else
#                 # y좌표별로 레이어 그룹화
#                 coord_to_layers = DefaultDict{Int, Vector{String}}(() -> String[])
#                 for label in labels
#                     m = match(r"y=(\d+)\((M\d+)\)", label)
#                     if m !== nothing
#                         push!(coord_to_layers[parse(Int, m[1])], m[2])
#                     end
#                 end
                
#                 # 그룹화된 정보를 "y=좌표(M2, M4)" 형식으로 조합
#                 label_parts = [ "y=$(coord)(" * join(layers, ", ") * ")" for (coord, layers) in coord_to_layers ]
#                 push!(y_info_col, join(label_parts, " "))
#             end
#         end
#         df.xy_coordinate = y_info_col
        
#         # [수정됨] 3. x축 헤더를 실제 좌표값으로 변경
#         for x_idx in 1:max_x
#             col_name = "x=$(all_v_tracks[x_idx])"
#             df[!, col_name] = maps[layer][max_y:-1:1, x_idx]
#         end

#         # 파일로 저장
#         filepath = "$(basename)_layer_$(layer).csv"
#         CSV.write(filepath, df)
#         println("라우팅 맵을 '$filepath'에 저장했습니다.")
#     end
# end