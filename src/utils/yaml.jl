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

end # endif