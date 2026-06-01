if !isdefined(@__MODULE__, :_PRELVS_VIA_JL_)
const _PRELVS_VIA_JL_ = true

using OrderedCollections
import Base: ==, hash

include("laygo_origin.jl")

mutable struct VPoint
    xy::Vector{Int}
    extension::Vector{Int}
    layer::Vector{String}
    type::String
    netname::Union{String, Nothing}
    idx::Int
    laygo_origin::Union{LaygoOrigin, Nothing}
end

mutable struct VList
    type::String
    vpoints::Vector{VPoint}
end

mutable struct VData
    cellname::String
    libname::String
    vlists::OrderedDict{String, VList}
end

# constructor
function VPoint(
    ; xy::Vector{Int},
    extension::Vector{Int},
    layer::Vector{String},
    type::String,
    idx::Int=-1,
    laygo_origin::Union{LaygoOrigin, Nothing}=nothing
)
    return VPoint(xy, extension, layer, type, nothing, idx, laygo_origin)
end


function ==(a::VPoint, b::VPoint)
    return a.xy == b.xy &&
           a.extension == b.extension &&
           a.layer == b.layer &&
           a.type == b.type
end

function hash(v::VPoint, h::UInt)
    return hash(v.xy,
           hash(v.extension,
           hash(v.layer,
           hash(v.type, h))))
end


# Build VData (per-via-type point lists) from a cell's db `vias` field.
# Sub-cell vias are tagged laygo_origin="OBSTACLE"; top-cell vias keep their name.
function db_to_VData(
    libname::String,
    cellname::String,
    db_vias::Union{Vector, Dict},
    config_data,
    is_detailed::Bool=false,
    is_topcell::Bool=false,
    perform_sort::Bool=false
)::VData

    _unsorted_vdata = VData(cellname, libname, OrderedDict{String, VList}())

    for via in db_vias
        # detailed (key: name, value: via_data) / non-detailed (key: via_data)
        via_data = is_detailed ? last(via) : via
        current_name = is_detailed ? first(via) : nothing

        if is_topcell
            laygo_origin = LaygoOrigin(current_name)
        else
            laygo_origin = LaygoOrigin("OBSTACLE")
        end

        _type = via_data["cellname"]
        if !haskey(_unsorted_vdata.vlists, _type)
            _unsorted_vdata.vlists[_type] = VList(_type, Vector{VPoint}())
        end
        push!(_unsorted_vdata.vlists[_type].vpoints, VPoint(xy=map(Int, via_data["xy"]), extension=map(Int, config_data["Via"][_type]["extension"]), layer=map(String, via_data["layer"]), type=_type, idx=-1, laygo_origin=laygo_origin))
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


# Apply an affine transform to every via point (hierarchy flattening).
function transform_VData(vdata::VData, transform::Matrix{Int})
    new_vdata = VData(vdata.cellname, vdata.libname, OrderedDict{String, VList}())
    for (type, vlist) in vdata.vlists
        new_vlist = VList(type, Vector{VPoint}())
        for vpoint in vlist.vpoints
            new_xy = transform * [vpoint.xy[1]; vpoint.xy[2]; 1]
            push!(new_vlist.vpoints, VPoint(new_xy[1:2], vpoint.extension, vpoint.layer, vpoint.type, nothing, -1, vpoint.laygo_origin))
        end
        new_vdata.vlists[type] = new_vlist
    end
    return new_vdata
end

function set_via_idx(vp::VPoint, idx::Int)
    vp.idx = idx
    return vp
end

end # include guard
