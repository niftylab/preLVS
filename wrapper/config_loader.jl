# ============================================================================
# config_loader.jl - Load preLVS configuration from YAML
# ============================================================================

using YAML

"""
    PreLVSConfig

Configuration for preLVS wrapper.
"""
struct PreLVSConfig
    db_dir::String
    source_net_sets::Vector{Tuple{String, Set{String}}}
    config_data::Dict
end

"""
    load_prelvs_config(config_path::String, db_dir::String) -> PreLVSConfig

Load preLVS configuration from YAML file.
"""
function load_prelvs_config(config_path::String, db_dir::String)::PreLVSConfig
    config_data = YAML.load_file(config_path)

    # Extract source net sets (net equivalences)
    source_net_sets = extract_source_net_sets(config_data)

    return PreLVSConfig(db_dir, source_net_sets, config_data)
end

"""
    build_orientation_list(tech_spec, max_layer::Int) -> Vector{String}

Build orientation list from TechnologySpec.
Returns ["VERTICAL", "HORIZONTAL", ...] indexed by layer number (1-based).
Errors if any layer's direction is not defined.
"""
function build_orientation_list(tech_spec, max_layer::Int)::Vector{String}
    orientation_list = Vector{String}(undef, max_layer)

    for layer in 1:max_layer
        # Get direction from tech_spec
        if !haskey(tech_spec.grids.by_layer, layer) || isempty(tech_spec.grids.by_layer[layer])
            error("Layer $layer not defined in tech_spec.grids.by_layer")
        end

        grid_spec = tech_spec.grids.by_layer[layer][1]
        dir = grid_spec.direction

        if dir == :vertical
            orientation_list[layer] = "VERTICAL"
        elseif dir == :horizontal
            orientation_list[layer] = "HORIZONTAL"
    else
            error("Invalid direction '$dir' for layer $layer. Expected :vertical or :horizontal")
        end
    end

    return orientation_list
end

"""
    extract_source_net_sets(config_data::Dict) -> Vector{Tuple{String, Set{String}}}

Extract net equivalence sets from config.
"""
function extract_source_net_sets(config_data::Dict)::Vector{Tuple{String, Set{String}}}
    # Check if config has net_equivalences section
    net_equiv = get(config_data, "net_equivalences", nothing)

    if !isnothing(net_equiv) && net_equiv isa Dict
        result = Vector{Tuple{String, Set{String}}}()
        for (canonical_name, equivalents) in net_equiv
            if equivalents isa Vector
                push!(result, (string(canonical_name), Set(string.(equivalents))))
            end
        end
        return result
    end

    # return [
    #     ("VDD", Set(["VDD", "vdd", "VDD:"])),
    #     ("VSS", Set(["VSS", "vss", "VSS:"]))
    # ]

    # 일단 source_net_sets만 정의
    return [
        ("VDD", Set(["VDD"])),
        ("VSS", Set(["VSS"]))
    ]
end

"""
    metal_name_to_int(metal_name) -> Int

Convert metal name (e.g., "M2", "M3") to layer number.
"""
function metal_name_to_int(metal_name)::Int
    name_str = string(metal_name)
    m = match(r"[Mm](\d+)", name_str)
    if m !== nothing
        return parse(Int, m.captures[1])
    end
    # Try direct number
    try
        return parse(Int, name_str)
    catch
        error("Invalid metal name: $metal_name")
    end
end
