if !isdefined(@__MODULE__, :_PRELVS_GRID_JL_)
const _PRELVS_GRID_JL_ = true

include("new_metal.jl")
include("connectivity.jl")

using JSON

struct LineObject
    layer_num::Int
    scope::Tuple{Int, Int}  # (start, end) in xy
    netname::String
end

# GridLine: 1D grid line
mutable struct GridLine
    layer_num::Int
    orientation::String
    occupation::Union{Vector{LineObject}, Nothing}
    extension::Int
end

# GridLayer: 2D grid layer
mutable struct GridLayer
    layer_num::Int
    orientation::String
    lines::Dict{Int, GridLine}  # key: xy, value: GridLine
end

# GridData: total grid data of an cell
mutable struct GridData
    layers::Dict{Int, GridLayer}
    top_bbox::Tuple{Int, Int}  # (width, height) in xy
end



function create_empty_grid_data(grid_json_data::Dict, cell_data::Dict, libname::String, cellname::String)

    bbox = (cell_data[libname][cellname][1]["width"], cell_data[libname][cellname][1]["height"])
    bbox_mn = (xy_to_mn(grid_json_data, 3, bbox[1]), xy_to_mn(grid_json_data, 2, bbox[2]))
    out_grid_data = GridData(Dict{Int, GridLayer}(), bbox)

    # netmap-emit set = whichever layers grid.json actually defines.
    # M1 lands here once routing_12_cmos is present in the tech grid.
    current_layers = sort(collect(keys(grid_json_data)))

    for layer_num in current_layers
        orientation = grid_json_data[layer_num]["orientation"]
        max_mn = orientation == "vertical" ? bbox_mn[1] : bbox_mn[2]

        out_grid_data.layers[layer_num] = GridLayer(layer_num, orientation, Dict{Int, GridLine}())

        for mn in 1:max_mn
            xy = mn_to_xy(grid_json_data, layer_num, mn)
            extension = get_extension(grid_json_data, layer_num, mn)
            out_grid_data.layers[layer_num].lines[xy] = GridLine(layer_num, orientation, nothing, extension)
        end
    end
        
    return out_grid_data
end



function get_grid_data(
    empty_grid_data::GridData,
    cinfo::Vector{ComponentInfo}, 
    top_netname_list::Vector{String},
    grid_json_data::Dict
)

    for top_netname in top_netname_list

        net_cinfo = filter(ci -> ci.netname == top_netname, cinfo)

        for cur_cinfo in net_cinfo
            for node in cur_cinfo.nodes
                if !haskey(empty_grid_data.layers, node.layer)
                    continue
                end
                line_obj = LineObject(node.layer, (node.points[1].s_coord, node.points[2].s_coord), top_netname)
                xy = node.p_coord
                
                if empty_grid_data.layers[node.layer].lines[xy].occupation === nothing
                    empty_grid_data.layers[node.layer].lines[xy].occupation = [line_obj]
                else
                    push!(empty_grid_data.layers[node.layer].lines[xy].occupation, line_obj)
                end
            end
        end
    end


    obstacle_cinfo = filter(ci -> !(ci.netname in top_netname_list), cinfo)
    for cur_cinfo in obstacle_cinfo
        for node in cur_cinfo.nodes
            if !haskey(empty_grid_data.layers, node.layer)
                continue
            end
            line_obj = LineObject(node.layer, (node.points[1].s_coord, node.points[2].s_coord), "OBSTACLE")
            xy = node.p_coord
            
            if empty_grid_data.layers[node.layer].lines[xy].occupation === nothing
                empty_grid_data.layers[node.layer].lines[xy].occupation = [line_obj]
            else
                push!(empty_grid_data.layers[node.layer].lines[xy].occupation, line_obj)
            end
        end
    end

    return empty_grid_data
end




function get_grid(techname::String, config_data::Dict, dir_path::String)
    # Get grid data
    out_grid_data = Dict()

    # Load grid data
    grid_file_path = joinpath(dir_path, "grids", "$(techname)_grid.json")
    grid_tech_data = JSON.parse(read(grid_file_path, String))

    for (routing_grid, grid_data) in grid_tech_data["grid"]
        layer_num1 = parse(Int, match(r"routing_(\d)(\d)_cmos", routing_grid).captures[1])
        layer_num2 = parse(Int, match(r"routing_(\d)(\d)_cmos", routing_grid).captures[2])
        if !haskey(out_grid_data, layer_num1)
            orientation = config_data["Metal"]["M$(string(layer_num1))"] == "|" ? "vertical" : "horizontal"
            out_grid_data[layer_num1] = Dict(
                "orientation" => orientation,
                "scope" => grid_data[orientation]["scope"],
                "elements" => grid_data[orientation]["elements"],
                "extension" => grid_data[orientation]["extension"],
                "width" => grid_data[orientation]["width"]
            )
        end
        if !haskey(out_grid_data, layer_num2)
            orientation = config_data["Metal"]["M$(string(layer_num2))"] == "|" ? "vertical" : "horizontal"
            out_grid_data[layer_num2] = Dict(
                "orientation" => orientation,
                "scope" => grid_data[orientation]["scope"],
                "elements" => grid_data[orientation]["elements"],
                "extension" => grid_data[orientation]["extension"],
                "width" => grid_data[orientation]["width"]
            )
        end
    end
    
    return out_grid_data
end


# function xy_to_mn(grid_data::Dict, layer_num::Int, xy::Int)
#     if !haskey(grid_data, layer_num)
#         error("Layer $(layer_num) not found in grid data")
#     end
#     track = rem(xy, grid_data[layer_num]["scope"][2])
#     cycle_num = div(xy, grid_data[layer_num]["scope"][2])

#     if !(track in grid_data[layer_num]["elements"])
#         error("Track $(track) not found in layer $(layer_num) grid data
#         elements: $(grid_data[layer_num]["elements"])")
#     end

#     # Find the index of track in elements array (1-based indexing)
#     track_index = findfirst(x -> x == track, grid_data[layer_num]["elements"])
#     mn = cycle_num * length(grid_data[layer_num]["elements"]) + track_index

#     return mn
# end

# function mn_to_xy(grid_data::Dict, layer_num::Int, mn::Int)
#     if !haskey(grid_data, layer_num)
#         error("Layer $(layer_num) not found in grid data")
#     end
#     mn = mn - 1
#     track = rem(mn, length(grid_data[layer_num]["elements"]))
#     cycle_num = div(mn, length(grid_data[layer_num]["elements"]))


#     return cycle_num * grid_data[layer_num]["scope"][2] + track

# end

"""
정렬된 배열에서 주어진 값과 가장 가까운 값 및 그 인덱스를 찾습니다.
(closest_value, 1-based_index)를 반환합니다.
"""
function find_closest(sorted_array::Vector, value::Number)
    # searchsortedfirst는 value보다 크거나 같은 첫 번째 요소의 인덱스를 찾습니다.
    idx = searchsortedfirst(sorted_array, value)

    # 경계값 처리
    if idx == 1
        return (sorted_array[1], 1)
    end
    if idx > length(sorted_array)
        return (sorted_array[end], length(sorted_array))
    end

    # 인접한 두 값 중 어느 쪽이 더 가까운지 비교
    val_before = sorted_array[idx-1]
    val_after = sorted_array[idx]
    
    if abs(value - val_before) <= abs(value - val_after)
        return (val_before, idx - 1)
    else
        return (val_after, idx)
    end
end

function xy_to_mn(grid_data::Dict, layer_num::Int, xy::Int)
    if !haskey(grid_data, layer_num)
        error("Layer $(layer_num) not found in grid data")
    end
    
    layer_info = grid_data[layer_num]
    scope = layer_info["scope"]
    elements = layer_info["elements"]
    
    track = rem(xy, scope[2])
    cycle_num = div(xy, scope[2])

    # 가장 가까운 track 값과 그 인덱스(1-based)를 찾습니다.
    closest_track, track_index = find_closest(elements, track)

    # 원래의 track 값과 가장 가까운 값이 다르면 로그를 남깁니다.
    if closest_track != track
        @info "xy_to_mn: Snapped xy $(xy) to nearest track. Original track: $(track), Snapped track: $(closest_track) on layer $(layer_num)."
    end

    mn = cycle_num * length(elements) + track_index
    return mn
end

function mn_to_xy(grid_data::Dict, layer_num::Int, mn::Int)
    if !haskey(grid_data, layer_num)
        error("Layer $(layer_num) not found in grid data")
    end

    layer_info = grid_data[layer_num]
    scope = layer_info["scope"]
    elements = layer_info["elements"]
    num_elements = length(elements)

    # mn을 0-based로 변환하여 계산
    mn_0based = mn - 1
    
    # track의 인덱스(0-based)와 사이클 번호를 계산
    track_index_0based = rem(mn_0based, num_elements)
    cycle_num = div(mn_0based, num_elements)

    # [수정된 부분] 인덱스가 아닌 'elements' 배열의 실제 값을 사용합니다.
    track_value = elements[track_index_0based + 1] # Julia는 1-based 인덱싱

    return cycle_num * scope[2] + track_value
end


function get_extension(grid_data::Dict, layer_num::Int, mn::Int)
    if !haskey(grid_data, layer_num)
        error("Layer $(layer_num) not found in grid data")
    end

    circular_mn = rem(mn, length(grid_data[layer_num]["elements"]))

    return grid_data[layer_num]["extension"][circular_mn + 1]
end




function get_metals_by_origin(grid_data::Dict, mdata::MData)

    # Returns MData with only obstacle and top metals
    out_obstacle_mdata = MData(mdata.libname, mdata.cellname, Dict())
    out_top_mdata = MData(mdata.libname, mdata.cellname, Dict())

    for (layer_num, layer_data) in mdata.metals
        if !haskey(grid_data, layer_num)
            continue
        end
        for (p_coord, mvector_list) in layer_data.metals
            # mn = xy_to_mn(grid_data, layer_num, p_coord)
            for mvector in mvector_list
                if mvector.points[1].s_coord - mvector.points[2].s_coord == 0
                    # 크기 없는 metal들 (일부 label들) 제외외
                    continue
                end
                if mvector.laygo_origin === nothing
                    continue
                end
                if mvector.laygo_origin.traceback == "OBSTACLE" # sub cell metal
                    if !haskey(out_obstacle_mdata.metals, layer_num)
                        out_obstacle_mdata.metals[layer_num] = MLayer(layer_num, Dict())
                    end
                    if !haskey(out_obstacle_mdata.metals[layer_num].metals, p_coord)
                        out_obstacle_mdata.metals[layer_num].metals[p_coord] = [mvector]
                    else
                        push!(out_obstacle_mdata.metals[layer_num].metals[p_coord], mvector)
                    end
                elseif mvector.laygo_origin.traceback !== nothing   # top metal
                    if !haskey(out_top_mdata.metals, layer_num)
                        out_top_mdata.metals[layer_num] = MLayer(layer_num, Dict())
                    end
                    if !haskey(out_top_mdata.metals[layer_num].metals, p_coord)
                        out_top_mdata.metals[layer_num].metals[p_coord] = [mvector]
                    else
                        push!(out_top_mdata.metals[layer_num].metals[p_coord], mvector)
                    end
                end
            end
        end
    end

    return out_obstacle_mdata, out_top_mdata
end



function get_merged_metals(grid_data::Dict, merged_mdata::MOData)
    out_merged_metals = Dict()

    for (layer_num, layer_data) in merged_mdata.metals
        if !haskey(grid_data, layer_num)
            continue
        end
        for (p_coord, mvector_list) in layer_data.metals
            mn = xy_to_mn(grid_data, layer_num, p_coord)
            for mvector in mvector_list
                if mvector.points[1].s_coord - mvector.points[2].s_coord == 0
                    continue
                end
                if !haskey(out_merged_metals, layer_num)
                    out_merged_metals[layer_num] = Dict()
                end
                if !haskey(out_merged_metals[layer_num], mn)
                    out_merged_metals[layer_num][mn] = [mvector]
                else
                    push!(out_merged_metals[layer_num][mn], mvector)
                end
            end
        end
    end

    return out_merged_metals
end



function analyze_grid_occupation(grid_data::Dict, merged_metals::Dict)
    
    grid_occupation_result = Dict()

    for (layer_num, layer_data) in merged_metals
        if layer_num % 2 == 0   # horizontal layer
            used_metal_length = 0
            for (mn, mvector_list) in layer_data
                total_length = grid_data["top_bbox"][1]
                metal_length = 0
                circluler_mn = rem(mn, length(grid_data[layer_num]["elements"]))
                
                for mvector in mvector_list
                    cur_metal_length = mvector.points[2].s_coord - mvector.points[1].s_coord
                    cur_metal_length = cur_metal_length - 2 * grid_data[layer_num]["extension"][circluler_mn + 1]
                    metal_length += cur_metal_length
                end
                # println("layer_num: $(layer_num), mn: $(mn), metal_length: $(metal_length), total_length: $(total_length), occupation: $(metal_length / total_length)")
                if !haskey(grid_occupation_result, layer_num)
                    grid_occupation_result[layer_num] = Dict()
                end
                grid_occupation_result[layer_num][mn] = metal_length / total_length
                used_metal_length += metal_length
            end
            total_num_of_grids = div(grid_data["top_bbox"][2], grid_data[layer_num]["scope"][2]) * length(grid_data[layer_num]["elements"])

            rem_grid_num = rem(grid_data["top_bbox"][2], grid_data[layer_num]["scope"][2])
            if rem_grid_num != 0
                total_num_of_grids += findfirst(x -> x == rem_grid_num, grid_data[layer_num]["elements"])
            end
            println("total_num_of_grids: $(total_num_of_grids)")
            println("total_metal_length: $(total_num_of_grids * grid_data["top_bbox"][1])")
            println("used_metal_length: $(used_metal_length)")
            total_occupation = round(used_metal_length / (total_num_of_grids * grid_data["top_bbox"][1]) * 100, digits=2)
            println("occupation: $(total_occupation)%")
            grid_occupation_result[layer_num]["total_occupation"] = total_occupation
        else    # vertical layer
            used_metal_length = 0
            for (mn, mvector_list) in layer_data
                total_length = grid_data["top_bbox"][2]
                metal_length = 0
                circluler_mn = rem(mn, length(grid_data[layer_num]["elements"]))
                for mvector in mvector_list
                    cur_metal_length = mvector.points[2].s_coord - mvector.points[1].s_coord
                    cur_metal_length = cur_metal_length - 2 * grid_data[layer_num]["extension"][circluler_mn + 1]
                    metal_length += cur_metal_length
                end
                # println("layer_num: $(layer_num), mn: $(mn), metal_length: $(metal_length), total_length: $(total_length), occupation: $(metal_length / total_length)")
                if !haskey(grid_occupation_result, layer_num)
                    grid_occupation_result[layer_num] = Dict()
                end
                grid_occupation_result[layer_num][mn] = metal_length / total_length
                used_metal_length += metal_length
            end
            total_num_of_grids = div(grid_data["top_bbox"][1], grid_data[layer_num]["scope"][2]) * length(grid_data[layer_num]["elements"])
            rem_grid_num = rem(grid_data["top_bbox"][1], grid_data[layer_num]["scope"][2])
            if rem_grid_num != 0
                total_num_of_grids += findfirst(x -> x == rem_grid_num, grid_data[layer_num]["elements"])
            end
            println("total_num_of_grids: $(total_num_of_grids)")
            println("total_metal_length: $(total_num_of_grids * grid_data["top_bbox"][2])")
            println("used_metal_length: $(used_metal_length)")
            total_occupation = round(used_metal_length / (total_num_of_grids * grid_data["top_bbox"][2]) * 100, digits=2)
            println("occupation: $(total_occupation)%")
            grid_occupation_result[layer_num]["total_occupation"] = total_occupation
        end
    end

    return grid_occupation_result
end


function print_grid_occupation_result(grid_occupation_result::Dict, status::String)

    println("Grid Occupation Result: $(status)")

    total_occupation = 0

    layers = sort(collect(keys(grid_occupation_result)))
    for layer_num in layers
        println("Layer $(layer_num): $(grid_occupation_result[layer_num]["total_occupation"])%")
        total_occupation += grid_occupation_result[layer_num]["total_occupation"]
    end
    println("Total Occupation: $(round(total_occupation / length(layers), digits=2))%")
end

end # include guard