if !isdefined(@__MODULE__, :_PRELVS_YAML_JL_)
const _PRELVS_YAML_JL_ = true

using YAML

function get_yaml(file_path::String)
    data = YAML.load_file(file_path)
    return data
end


function get_config(file_path::String)
    data = get_yaml(file_path)

    if !haskey(data, "Layer")
        error("Config file must have 'Layer' key")
    end
    if !haskey(data, "Via")
        error("Config file must have 'Via' key")
    end

    config_data = Dict()

    # Metal layer orientation; the order also defines the layer numbering (structure.jl).
    morien = Dict()
    for (i, m) in enumerate(data["Layer"]["order"])
        morien[m] = data["Layer"]["orientation"][i]
    end
    set_layer_order!(data["Layer"]["order"])

    # Equivalent net sets
    eq_net_sets = Vector{Tuple{String, Set{String}}}()
    for (key, value) in data["Equivalent_net_sets"]
        push!(eq_net_sets, (key, Set(value)))
    end

    config_data["Metal"] = morien
    config_data["Via"] = data["Via"]
    config_data["Equivalent_net_sets"] = eq_net_sets
    
    return config_data
end


function get_orientation_list(config_data::Dict)
    # Indexed by layer number = position in Layer.order (metal_to_int).
    orientation_list = Vector{String}(undef, length(config_data["Metal"]))
    for (layer, orient) in config_data["Metal"]
        orientation_list[metal_to_int(layer)] = orient == "|" ? "VERTICAL" : "HORIZONTAL"
    end
    return orientation_list
end

end # include guard