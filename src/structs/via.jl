if !isdefined(@__MODULE__, :_STRUCT_VIA_JL_)
    # 가드 상수를 현재 모듈 스코프에 직접 정의
    # @eval 없이 const를 직접 사용. 모듈의 top-level에서 include될 때 동작합니다.
    const _STRUCT_VIA_JL_ = true

using OrderedCollections

mutable struct VPoint
    xy::Vector{Int}
    extension::Vector{Int}
    layer::Vector{String}
    type::String
    netname::Union{String, Nothing}
    idx::Int
end

mutable struct VList
    type::String
    vpoints::Vector{VPoint}
end

mutable struct VData
    cellname::String
    libname::String
    vlists::OrderedDict{String, VList}
    # vxlists::OrderedDict{String, Dict{Int, VList}}    # type -> x -> y 순서로 정렬된 리스트 (primary coord가 x인 경우)
    # vylists::OrderedDict{String, Dict{Int, VList}}    # type -> y -> x 순서로 정렬된 리스트 (primary coord가 y인 경우)
end

# constructor
function VPoint(
    ; xy::Vector{Int},
    extension::Vector{Int},
    layer::Vector{String},
    type::String,
    idx::Int
)
    return VPoint(xy, extension, layer, type, nothing, -1)
end


function json_to_VData(libname::String, cellname::String, json_path::String)::VData
    if !isfile(json_path)
        error("File not found at $json_path")
    end

    json_data = JSON.parse(read(json_path, String))

    vlists = OrderedDict{String, VList}()

    for (type, vlist) in json_data
        vpoints = Vector{VPoint}()
        for vpoint in vlist["vpoints"]
            push!(vpoints, VPoint(vpoint["xy"], vpoint["extension"], vpoint["layer"], vpoint["type"], nothing, -1))
        end
        vlists[vlist["type"]] = VList(vlist["type"], vpoints)
    end

    return VData(cellname, libname, vlists, OrderedDict{String, Dict{Int, VList}}(), OrderedDict{String, Dict{Int, VList}}())
end

function db_to_VData(libname::String, cellname::String, db_vias::Vector, config_data, perform_sort::Bool=false)

    # _unsorted_vdata = VData(cellname, libname, OrderedDict{String, VList}(), OrderedDict{String, Dict{Int, VList}}(), OrderedDict{String, Dict{Int, VList}}())
    _unsorted_vdata = VData(cellname, libname, OrderedDict{String, VList}())

    for via in db_vias
        _type = via["cellname"]
        if !haskey(_unsorted_vdata.vlists, _type)
            _unsorted_vdata.vlists[_type] = VList(_type, Vector{VPoint}())
        end
        # println("via[xy] = ", map(Int, via["xy"]))
        # println("type of via[xy] = ", typeof(map(Int, via["xy"])))
        # println("via[layer] = ", map(String, via["layer"]))
        # println("type of via[layer] = ", typeof(map(String, via["layer"])))
        # println("config_data[\"Via\"][_type][\"extension\"] = ", map(Int, config_data["Via"][_type]["extension"]))
        # println("type of config_data[\"Via\"][_type][\"extension\"] = ", typeof(map(Int, config_data["Via"][_type]["extension"])))
        push!(_unsorted_vdata.vlists[_type].vpoints, VPoint(xy=map(Int, via["xy"]), extension=map(Int, config_data["Via"][_type]["extension"]), layer=map(String, via["layer"]), type=_type, idx=-1))
    end

    if perform_sort
        _sorted_vdata = VData(cellname, libname, OrderedDict{String, VList}())
        type_list = sort(unique(keys(_unsorted_vdata.vlists)))
        for type in type_list
            vlist = _unsorted_vdata.vlists[type]
            _sorted_vpoints = sort(vlist.vpoints, by=x->(x.xy[1], x.xy[2]))
            _sorted_vdata.vlists[vlist.type] = VList(vlist.type, _sorted_vpoints)
        end
        return _sorted_vdata
    end

    return _unsorted_vdata
end


function VData_to_json(vdata::VData, json_path::String)
    json_data = OrderedDict{String, Any}()

    for (_type, vlist) in vdata.vlists
        vlist_data = OrderedDict{String, Any}()
        vlist_data["type"] = _type
        vlist_data["vpoints"] = Vector{OrderedDict{String, Any}}()
        for vpoint in vlist.vpoints
            vpoint_data = OrderedDict{String, Any}()
            vpoint_data["xy"] = vpoint.xy
            vpoint_data["extension"] = vpoint.extension
            vpoint_data["layer"] = vpoint.layer
            vpoint_data["type"] = vpoint.type
            push!(vlist_data["vpoints"], vpoint_data)
        end
        json_data[vlist.type] = vlist_data
    end

    open(json_path, "w") do f
        JSON.print(f, json_data, 2)
    end
end

function transform_VData(vdata::VData, transform::Matrix{Int})
    new_vdata = VData(vdata.cellname, vdata.libname, OrderedDict{String, VList}())
    for (type, vlist) in vdata.vlists
        new_vlist = VList(type, Vector{VPoint}())
        for vpoint in vlist.vpoints
            new_xy = transform * [vpoint.xy[1]; vpoint.xy[2]; 1]
            push!(new_vlist.vpoints, VPoint(new_xy[1:2], vpoint.extension, vpoint.layer, vpoint.type, nothing, -1))
        end
        new_vdata.vlists[type] = new_vlist
    end
    return new_vdata
end

function transfrom_VData_V2(vdata::VData, transform::Matrix{Int})
    new_vdata = deepcopy(vdata)
    for (type, vlist) in new_vdata.vlists
        for vpoint in vlist.vpoints
            vpoint.xy = affine_via(transform, vpoint.xy)
        end
    end
    return new_vdata
end

function affine_via(transform::Matrix{Int}, xy::Vector{Int})
    # affine 변환을 통해 xy 좌표를 변환
    # transform * [x; y; 1]
    new_xy = transform * [xy[1]; xy[2]; 1]
    return map(Int, new_xy[1:2])
end


# Sort 하면서 각각 x, y 좌표를 key로 하는 OrderedDict를 생성
# vlists -> vxlists, vylists
function sort_VData(vdata::VData)
    new_vdata = VData(vdata.cellname, vdata.libname, OrderedDict{String, VList}(), OrderedDict{String, Dict{Int, VList}}(), OrderedDict{String, Dict{Int, VList}}())
    type_list = sort(unique((keys(vdata.vlists))))

    for vtype in type_list
        new_vdata.vxlists[vtype] = Dict{Int, VList}()
        new_vdata.vylists[vtype] = Dict{Int, VList}()
        for vpoint in vdata.vlists[vtype].vpoints
            if !haskey(new_vdata.vxlists[vtype], vpoint.xy[1])
                new_vdata.vxlists[vtype][vpoint.xy[1]] = VList(vtype, Vector{VPoint}())
            end
            push!(new_vdata.vxlists[vtype][vpoint.xy[1]].vpoints, vpoint)
            if !haskey(new_vdata.vylists[vtype], vpoint.xy[2])
                new_vdata.vylists[vtype][vpoint.xy[2]] = VList(vtype, Vector{VPoint}())
            end
            push!(new_vdata.vylists[vtype][vpoint.xy[2]].vpoints, vpoint)
        end
        # sort vxlists, vylists
        for (x, vlist) in new_vdata.vxlists[vtype]
            new_vdata.vxlists[vtype][x].vpoints = sort(vlist.vpoints, by=x->x.xy[2])
        end
        for (y, vlist) in new_vdata.vylists[vtype]
            new_vdata.vylists[vtype][y].vpoints = sort(vlist.vpoints, by=x->x.xy[1])
        end
    end
    return new_vdata
end

function set_via_idx(vp::VPoint, idx::Int)
    vp.idx = idx
    return vp
end

end # endif