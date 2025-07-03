include("new_metal.jl")

using JSON


function get_grid(techname::String, config_data::Dict)
    # Get grid data
    out_grid_data = Dict()

    # Load grid data
    grid_file_path = "grids/$(techname)_grid.json"
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


function xy_to_mn(grid_data::Dict, layer_num::Int, xy::Int)
    if !haskey(grid_data, layer_num)
        error("Layer $(layer_num) not found in grid data")
    end
    track = rem(xy, grid_data[layer_num]["scope"][2])
    cycle_num = div(xy, grid_data[layer_num]["scope"][2])

    if !(track in grid_data[layer_num]["elements"])
        error("Track $(track) not found in layer $(layer_num) grid data
        elements: $(grid_data[layer_num]["elements"])")
    end

    # Find the index of track in elements array (1-based indexing)
    track_index = findfirst(x -> x == track, grid_data[layer_num]["elements"])
    mn = cycle_num * length(grid_data[layer_num]["elements"]) + track_index

    return mn
end

function mn_to_xy(grid_data::Dict, layer_num::Int, mn::Int)
    if !haskey(grid_data, layer_num)
        error("Layer $(layer_num) not found in grid data")
    end
    mn = mn - 1
    track = rem(mn, length(grid_data[layer_num]["elements"]))
    cycle_num = div(mn, length(grid_data[layer_num]["elements"]))


    return cycle_num * grid_data[layer_num]["scope"][2] + track

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
        end
    end

    return grid_occupation_result
end