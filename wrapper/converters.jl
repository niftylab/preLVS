# ============================================================================
# converters.jl - Convert between preLVS and laygo3-julia types
# ============================================================================

# ============================================================================
# L3MergedMetal Conversion
# ============================================================================

"""
    get_track_at_coord(tech_spec, layer::Int, p_coord::Int) -> (width::Int, track_index::Int)

Get track width and absolute track index at p_coord for a layer using GridSpec circular pattern.
Returns (width, track_index) tuple where track_index accounts for grid repetition.
"""
function get_track_at_coord(tech_spec, layer::Int, p_coord::Int)::Tuple{Int, Int}
    # Check if layer exists in grid
    if !haskey(tech_spec.grids.by_layer, layer) || isempty(tech_spec.grids.by_layer[layer])
        error("Layer $layer not found in tech_spec.grids.by_layer")
    end

    grid_spec = tech_spec.grids.by_layer[layer][1]

    # Handle circular pattern
    scope_start, scope_end = grid_spec.scope
    scope_size = scope_end - scope_start

    if scope_size <= 0
        error("Invalid scope size for layer $layer")
    end

    # Find which repetition we're in
    repetition = div(p_coord - scope_start, scope_size)

    # Get position within the current period
    local_coord = p_coord - (scope_start + repetition * scope_size)

    # Find closest track in base array (need 1-based position for calculation)
    min_dist = typemax(Int)
    closest_element_pos = 1  # 1-based position in tracks array
    best_track = nothing

    for (idx, track) in enumerate(grid_spec.tracks)
        dist = abs(track.coordinate - local_coord)
        if dist < min_dist
            min_dist = dist
            closest_element_pos = idx  # 1-based
            best_track = track
        end
    end

    if isnothing(best_track)
        error("No valid track found for layer $layer at p_coord $p_coord")
    end

    # Calculate absolute track index: (element_pos + num_elements * repetition) - 1
    # This matches the logic in LayoutExtractor.find_closest_repeated_track
    num_elements = length(grid_spec.tracks)
    track_index = (closest_element_pos + num_elements * repetition) - 1

    return (best_track.width, track_index)
end

"""
    convert_modata_to_merged_metals(modata, orientation_list, tech_spec) -> Vector{L3MergedMetal}

Convert preLVS MOData to Vector{L3MergedMetal}.
"""
function convert_modata_to_merged_metals(
    modata::MOData,
    orientation_list::Vector{String},
    tech_spec
)::Vector{L3MergedMetal}

    metals = L3MergedMetal[]

    for (layer_num, molayer) in modata.metals
        is_vertical = orientation_list[layer_num] == "VERTICAL"

        for (p_coord, movectors) in molayer.metals
            # Get track_index from tech_spec (still needed for MergedMetal constructor)
            _, track_index = get_track_at_coord(tech_spec, layer_num, p_coord)

            for mov in movectors
                # Use stored width from MOVector (calculated from original hextension/vextension)
                half_w = mov.width ÷ 2
                # Get s_coord range
                s_min = min(mov.points[1].s_coord, mov.points[2].s_coord)
                s_max = max(mov.points[1].s_coord, mov.points[2].s_coord)

                # Compute Rectangle based on orientation
                if is_vertical
                    # Vertical: p_coord is X, s_coord is Y
                    shape = Rectangle(
                        p_coord - half_w, s_min,
                        p_coord + half_w, s_max
                    )
                else
                    # Horizontal: p_coord is Y, s_coord is X
                    shape = Rectangle(
                        s_min, p_coord - half_w,
                        s_max, p_coord + half_w
                    )
                end

                push!(metals, L3MergedMetal(
                    mov.idx,           # id
                    layer_num,         # layer
                    shape,             # shape::Rectangle
                    mov.netname,       # net
                    [mov.idx],         # raw_metal_ids (just self)
                    track_index        # track_index from GridSpec
                ))
            end
        end
    end

    return metals
end

# ============================================================================
# Via Conversion
# ============================================================================

"""
    convert_vdata_to_vias(vdata, config_data) -> Vector{Via}

Convert preLVS VData to Vector{Via}.
Via size = (2*extension[1], 2*extension[2])
"""
function convert_vdata_to_vias(vdata::VData, config_data::Dict)::Vector{L3Via}
    vias = L3Via[]
    via_id = 1

    via_config = get(config_data, "Via", Dict())

    for (vtype, vlist) in vdata.vlists
        # Get via extension from config (e.g., [5, 13] -> size 10x26)
        type_config = get(via_config, vtype, Dict())
        ext = get(type_config, "extension", [10, 10])
        if ext isa Vector && length(ext) >= 2
            via_size = (2 * Int(ext[1]), 2 * Int(ext[2]))
        else
            via_size = (20, 20)  # default
        end

        for vpoint in vlist.vpoints
            # Parse layers from VPoint.layer (e.g., ["M2", "M3"])
            layer_nums = sort([metal_name_to_int(l) for l in vpoint.layer])
            bottom_layer = layer_nums[1]
            top_layer = layer_nums[2]

            # Position from xy
            position = Point(Int(vpoint.xy[1]), Int(vpoint.xy[2]))

            push!(vias, L3Via(
                via_id,
                position,
                bottom_layer,
                top_layer,
                via_size,
                nothing,      # net
                nothing,      # laygo_origin
                :standard,    # type
                0,            # source_cell_id
                0             # routing_stage_id
            ))
            via_id += 1
        end
    end

    return vias
end

# ============================================================================
# Pin Extraction
# ============================================================================

"""
    extract_pins(db_data, library, cell, orientation_list) -> Vector{Pin}

Extract pins from db_data following preLVS pattern.
"""
function extract_pins(
    db_data::Dict,
    library::String,
    cell::String,
    orientation_list::Vector{String}
)::Vector{L3Pin}
    pins = L3Pin[]
    pin_id = 1

    if !haskey(db_data, library) || !haskey(db_data[library], cell)
        return pins
    end

    cell_data = db_data[library][cell]
    db_pins = get(cell_data, "pins", [])

    for db_pin in db_pins
        layer_str = get(db_pin, "layer", "M2")
        layer = metal_name_to_int(layer_str)

        if layer > length(orientation_list)
            continue
        end

        is_vertical = orientation_list[layer] == "VERTICAL"

        # Extract coordinates
        xy = get(db_pin, "xy", [[0, 0], [0, 0]])
        x1, y1 = Int(xy[1][1]), Int(xy[1][2])
        x2, y2 = Int(xy[2][1]), Int(xy[2][2])

        # Add extension
        ext_key = is_vertical ? "vextension" : "hextension"
        ext = Int(get(db_pin, ext_key, 0))

        if is_vertical
            shape = Rectangle(min(x1, x2), min(y1, y2) - ext, max(x1, x2), max(y1, y2) + ext)
        else
            shape = Rectangle(min(x1, x2) - ext, min(y1, y2), max(x1, x2) + ext, max(y1, y2))
        end

        name = string(get(db_pin, "netname", get(db_pin, "name", "unnamed")))
        direction = parse_pin_direction_symbol(get(db_pin, "direction", "inout"))

        push!(pins, L3Pin(
            pin_id,
            name,
            layer,
            shape,
            direction,
            name,         # net = name
            :signal,      # pin_type
            0,            # source_cell_id
            0             # routing_stage_id
        ))
        pin_id += 1
    end

    return pins
end

"""
    parse_pin_direction_symbol(dir) -> Symbol

Parse pin direction string to Symbol.
"""
function parse_pin_direction_symbol(dir)::Symbol
    dir_str = lowercase(string(dir))
    if dir_str in ["input", "in", "i"]
        return :input
    elseif dir_str in ["output", "out", "o"]
        return :output
    elseif dir_str in ["inout", "io", "bidir"]
        return :inout
    elseif dir_str in ["power", "vdd"]
        return :power
    elseif dir_str in ["ground", "gnd", "vss"]
        return :ground
    else
        return :inout  # default
    end
end

# ============================================================================
# Label Extraction
# ============================================================================

"""
    extract_labels(db_data, library, cell, orientation_list) -> Vector{Label}

Extract labels from db_data following preLVS pattern.
"""
function extract_labels(
    db_data::Dict,
    library::String,
    cell::String,
    orientation_list::Vector{String}
)::Vector{L3Label}
    labels = L3Label[]

    if !haskey(db_data, library) || !haskey(db_data[library], cell)
        return labels
    end

    cell_data = db_data[library][cell]
    db_labels = get(cell_data, "labels", [])

    for db_label in db_labels
        layer_str = get(db_label, "layer", "M2")
        layer = metal_name_to_int(layer_str)

        # Extract position (center of xy)
        xy = get(db_label, "xy", [[0, 0], [0, 0]])
        x = (Int(xy[1][1]) + Int(xy[2][1])) ÷ 2
        y = (Int(xy[1][2]) + Int(xy[2][2])) ÷ 2
        position = Point(x, y)

        text = string(get(db_label, "netname", get(db_label, "text", "")))
        if isempty(text)
            continue
        end

        push!(labels, L3Label(
            text,
            position,
            layer,
            :horizontal,  # orientation
            :center,      # alignment
            10,           # size
            :net          # label_type
        ))
    end

    return labels
end

# ============================================================================
# LVS Result Conversion
# ============================================================================

"""
    convert_component_infos(prelvs_components) -> Vector{ConnectedComponent}

Convert preLVS ComponentInfo to laygo3-julia ConnectedComponent.
"""
function convert_component_infos(prelvs_components::Vector{ComponentInfo})::Vector{L3ConnectedComponent}
    return map(prelvs_components) do comp
        metal_ids = Set{Int}(mov.idx for mov in comp.nodes)
        via_ids = Set{Int}(vp.idx for vp in comp.vias)
        is_floating = isnothing(comp.netname)
        actual_nets = isnothing(comp.netname) ? Set{String}() : Set([comp.netname])

        L3ConnectedComponent(
            comp.number,
            metal_ids,
            via_ids,
            Set{Int}(),  # pin_ids
            Set{Int}(),  # label_ids
            comp.netname,
            actual_nets,
            comp.is_consistent,
            is_floating,
            nothing      # bounds
        )
    end
end

"""
    convert_error_infos(prelvs_errors) -> Vector{LVSError}

Convert preLVS ErrorInfo to laygo3-julia LVSError.
"""
function convert_error_infos(prelvs_errors::Vector{ErrorInfo})::Vector{LVSError}
    return map(prelvs_errors) do err
        # Map error type
        error_type = if err.type == SHORT
            :short
        elseif err.type == OPEN
            :open
        else
            :floating
        end

        LVSError(
            error_type,
            :error,
            "$(err.type): expected=$(err.expected_netname), actual=$(err.actual_netname)",
            [err.number],
            filter(!isnothing, [err.actual_netname, err.expected_netname]),
            nothing
        )
    end
end

"""
    build_merged_metal_net_map_from_components(prelvs_components) -> Dict{Int, String}

Build merged_metal_net_map from ComponentInfo.
Maps metal ID to net name.
"""
function build_merged_metal_net_map_from_components(
    prelvs_components::Vector{ComponentInfo}
)::Dict{Int, String}
    net_map = Dict{Int, String}()

    for comp in prelvs_components
        if !isnothing(comp.netname)
            for mov in comp.nodes
                net_map[mov.idx] = comp.netname
            end
        end
    end

    return net_map
end

"""
    create_empty_connectivity_graph() -> ConnectivityGraph

Create minimal empty ConnectivityGraph.
"""
function create_empty_connectivity_graph()
    ConnectivityGraph(
        Dict{Int, Set{Int}}(),  # metal_to_metal
        Dict{Int, Set{Int}}(),  # metal_to_via
        Dict{Int, Set{Int}}(),  # via_to_metal
        Dict{Int, L3MergedMetal}(),  # metals
        Dict{Int, L3Via}(),       # vias
        Dict{Int, L3Pin}()        # pins
    )
end
