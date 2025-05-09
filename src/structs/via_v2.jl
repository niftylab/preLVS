if !isdefined(@__MODULE__, :_STRUCT_VIA_V2_JL_)
    # 가드 상수를 현재 모듈 스코프에 직접 정의
    # @eval 없이 const를 직접 사용. 모듈의 top-level에서 include될 때 동작합니다.
    const _STRUCT_VIA_V2_JL_ = true

include("structure.jl")

mutable struct VRect <: Rect
    type::String
    layer::SVector{2,Int}
    xy::SVector{2,Int}
end

function VRect(;type::String, layer::SVector{2,Int}, xy::SVector{2,Int})
    VRect(type, layer, xy)
end
mutable struct VList
    type::String
    vias::Vector{VRect}
end

mutable struct VData
    cellname::String
    libname::String
    vlists::OrderedDict{String, VList}
end

function db_to_VData(db_json_data::Dict, libname::String, cellname::String, config_data::Dict)
    via_config = config_data["Via"]
    _unsorted_vdata = VData(libname, cellname, OrderedDict{String, VList}())
    for (vcellname, viacell) in via_config
        _unsorted_vdata.vlists[vcellname] = VList(vcellname, Vector{VRect}()) 
    end
    db_vias = db_json_data[libname][cellname]["vias"]
    for via in db_vias
        _type   = via["cellname"]
        _layer1  = metal_to_int(via_config[_type]["map"][1])
        _layer2  = metal_to_int(via_config[_type]["map"][2])
        push!(_unsorted_vdata.vlists[_type].vias, VRect(type=_type, layer=SVector{2,Int}(_layer1, _layer2), xy=SVector{2,Int}(via["xy"]) ) )
    end
    return _unsorted_vdata
end

function sort_VData(vdatas::VData...)
    new_vdata = VData(vdatas[1].cellname, vdatas[1].libname, OrderedDict{String, VList}())
    type_list = sort(unique(Iterators.flatten(keys(vdata.vlists) for vdata in vdatas)))
    for vtype in type_list
        new_vdata.vlists[vtype] = VList(vtype, Vector{VPoint}())
        for vdata in vdatas
            if haskey(vdata.vlists, vtype)
                for vpoint in vdata.vlists[vtype].vpoints
                    push!(new_vdata.vlists[vtype].vpoints, vpoint)
                end
            end
        end
        new_vdata.vlists[vtype].vpoints = sort(new_vdata.vlists[vtype].vpoints, by=x->(x.xy[1], x.xy[2]))
    end
    return new_vdata
end

end #endif