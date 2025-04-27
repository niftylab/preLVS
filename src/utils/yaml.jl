if !isdefined(@__MODULE__, :_UTIL_YAML_JL_)
    # 가드 상수를 현재 모듈 스코프에 직접 정의
    # @eval 없이 const를 직접 사용. 모듈의 top-level에서 include될 때 동작합니다.
    const _UTIL_YAML_JL_ = true

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

    # Metal layer orientation
    morien = Dict()
    for (i, m) in enumerate(data["Layer"]["order"])
        morien[m] = data["Layer"]["orientation"][i]
    end

    config_data["Metal"] = morien
    config_data["Via"] = data["Via"]
    if haskey(data, "Equivalent_net_sets")
        config_data["equivalent_net_sets"] = Vector{Tuple{String, Set{String}}}()  #equivalent_net_sets = [( "VDD", Set(["VDD", "vdd", "VDD:"]) ), ( "VSS, Set(["VSS", "VSS:", "vss"]) )]
        for net_list in data["Equivalent_net_sets"]
            push!(config_data["equivalent_net_sets"], (net_list[1], Set(net_list)))
        end
    end
    return config_data
end


function get_orientation_list(config_data::Dict)

    max_idx = maximum([parse(Int, replace(lowercase(layer), r"(metal|m)" => "") |> strip) for layer in keys(config_data["Metal"])]) 
    orientation_list = Vector{String}(undef, max_idx)
    for (layer, orient) in config_data["Metal"]
        idx = parse(Int, replace(lowercase(layer), r"(metal|m)" => "") |> strip)
        orientation_list[idx] = orient == "|" ? "VERTICAL" : "HORIZONTAL"
    end
    return orientation_list
end

end # endif