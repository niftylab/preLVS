if !isdefined(@__MODULE__, :_STRUCT_METAL_V2_JL_)
    # 가드 상수를 현재 모듈 스코프에 직접 정의
    # @eval 없이 const를 직접 사용. 모듈의 top-level에서 include될 때 동작합니다.
    const _STRUCT_METAL_V2_JL_ = true

include("structure.jl")
# Metal structures
@enum Direction HORZ VERT
# struct MPoint
#     coord::Int
#     pos::MPosition
# end

# mutable struct MVector
#     points::SVector{2, MPoint}                  # contains only two MPoints (start, end)
# end

# mutable struct MVectorList
#     main_coord::Int
#     sub_coords::Vector{MVector}
# end

# mutable struct MLayer
#     layer::Int
#     metals::OrderedDict{Int, MVectorList}   # key: main coord, value: MVectorList
# end

# mutable struct MData
#     libname::String
#     cellname::String
#     metals::OrderedDict{Int, MLayer}        # key: metal layer num, value: MLayer
# end

mutable struct MRect <: Rect
    layer::Int
    xy::SMatrix{2, 2, Int}
end

mutable struct MLayer
    layer::Int
    prefer_direction::Direction
    metals::Vector{MRect}   # key: main coord, value: MVectorList
end

mutable struct MData
    libname::String
    cellname::String
    layers::OrderedDict{Int, MLayer}        # key: metal layer num, value: MLayer
end



# db -> MData format    (outputs unmerged MData)    ( JSON -> MData )
# modified version of db_to_MData
# TODO: skip merge operation and make appliable into modified MData structure (see MData_ver2 definition)
function db_to_MData(db_json_data::Dict, libname::String, cellname::String, perform_sort::Bool=false)
    # ordinary metals
    db_metals           = db_json_data[libname][cellname]["metals"]
    # add primitive pin metals
    _primitives         = db_json_data[libname][cellname]["primitives"]
    db_metal_primitives = Vector()
    for _prim in _primitives
        _pins = _prim["pins"]
        for (pname, p) in _pins
            push!(db_metal_primitives, p)
        end
    end
    # concatnate the two vectors
    append!(db_metals, db_metal_primitives)
    _unmerged_mdata = MData(libname, cellname, OrderedDict{Int, MLayer}())

    for metal in db_metals
        layer = metal_to_int(metal["layer"])
        is_horizontal = layer % 2 == 0
        if !haskey(_unmerged_mdata.layers, layer)
            if is_horizontal
                _unmerged_mdata.layers[layer] = MLayer(layer, HORZ, Vector{MRect}())
            else
                _unmerged_mdata.layers[layer] = MLayer(layer, VERT, Vector{MRect}())
            end
        end

        xy_ll       = [min(metal["xy"][1][1], metal["xy"][2][1]), min(metal["xy"][1][2], metal["xy"][2][2])]
        xy_ur       = [max(metal["xy"][1][1], metal["xy"][2][1]), max(metal["xy"][1][2], metal["xy"][2][2])]
        hextension  = haskey(metal, "hextension") ? metal["hextension"] : EXTENSION
        vextension  = haskey(metal, "vextension") ? metal["vextension"] : EXTENSION
        _xy         = SMatrix{2, 2, Int}( [xy_ll[1]-hextension xy_ll[2]-vextension; xy_ur[1]+hextension xy_ur[2]+vextension] )
        push!(_unmerged_mdata.layers[layer].metals, MRect(layer, _xy))
    end
    if perform_sort
        return sort_n_merge_MData(_unmerged_mdata)
    end
    return _unmerged_mdata
end

################## MData Sorting & Merging functions ##################
end #endif