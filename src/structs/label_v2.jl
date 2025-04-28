if !isdefined(@__MODULE__, :_STRUCT_LABELV2_JL_)
    # 가드 상수를 현재 모듈 스코프에 직접 정의
    # @eval 없이 const를 직접 사용. 모듈의 top-level에서 include될 때 동작합니다.
    const _STRUCT_LABELV2_JL_ = true

include("structure.jl")

mutable struct Label{NT} <: Rect
    netname_origin::NT
    netname::NT
    xy::SMatrix{2, 2, Int}
    layer::Int
    is_pin::Bool
end

function Label(netname_origin::NT, xy::SMatrix{2, 2, Int}, layer::Int, is_pin::Bool) where {NT}
    Label{NT}(netname_origin, netname_origin, xy, layer, is_pin)
end

mutable struct LLayer{NT}
    layer::Int
    labels::Vector{Label{NT}}   # key: main coord, value: MVectorList
end


mutable struct LData{NT}
    libname::String
    cellname::String
    instname::String
    layers::OrderedDict{Int, LLayer{NT}}
end

# TODO: LData -> LLayer -> Vector{Label} 구조로 refactoring
#       current: LData -> Vector{Label} 
"""
mutable struct _LData{NT}
    libname::String
    cellname::String
    instname::String
    layers::OrderedDict{_LLayer{NT}}   # key: main coord, value: MVectorList
end
"""

# db -> LData format    (netname, instname unmapped LData. Just original netname and original xy)    ( JSON -> LData )
function db_to_LData(db_json_data::Dict, libname::String, cellname::String)

    _ldata      = LData{String}(libname, cellname, cellname, OrderedDict{Int, LLayer{String}}()) # initialize instname with cellname
    db_labels   = db_json_data[libname][cellname]["labels"]
    db_pins     = db_json_data[libname][cellname]["pins"]
    for label in db_labels
        layerNum = metal_to_int(label["layer"])
        is_horizontal = layerNum % 2 == 0
        if !haskey(_ldata.layers, layerNum)
            _ldata.layers[layerNum] = LLayer(layerNum, Vector{Label{String}}())
        end
        xy_ll       = [min(label["xy"][1][1], label["xy"][2][1]), min(label["xy"][1][2], label["xy"][2][2])]
        xy_ur       = [max(label["xy"][1][1], label["xy"][2][1]), max(label["xy"][1][2], label["xy"][2][2])]
        hextension  = haskey(label, "hextension") ? label["hextension"] : EXTENSION
        vextension  = haskey(label, "vextension") ? label["vextension"] : EXTENSION
        _xy         = SMatrix{2, 2, Int}( [ xy_ll[1]-hextension xy_ll[2]-vextension; xy_ur[1]+hextension xy_ur[2]+vextension ] )
        if typeof(label["netname"]) !== String
            # println("Error!: type of ",label["netname"], " is not String! in [$(cellname)]")
            # _netname_origin = "UNKNOWN"
            continue
        else
            _netname_origin = label["netname"]
        end
        # Label(netname_origin::NT, xy::SMatrix{2, 2, Int}, layer::Int, is_pin::Bool)
        push!(_ldata.layers[layerNum].labels, Label(_netname_origin, _xy, layerNum, false))
    end
    for label in db_pins # this is iteration for pin db
        layerNum = metal_to_int(label["layer"])
        is_horizontal = layerNum % 2 == 0
        if !haskey(_ldata.layers, layerNum)
            _ldata.layers[layerNum] = LLayer(layerNum, Vector{Label{String}}())
        end
        xy_ll       = [min(label["xy"][1][1], label["xy"][2][1]), min(label["xy"][1][2], label["xy"][2][2])]
        xy_ur       = [max(label["xy"][1][1], label["xy"][2][1]), max(label["xy"][1][2], label["xy"][2][2])]
        hextension  = haskey(label, "hextension") ? label["hextension"] : EXTENSION
        vextension  = haskey(label, "vextension") ? label["vextension"] : EXTENSION
        _xy         = SMatrix{2, 2, Int}( [ xy_ll[1]-hextension xy_ll[2]-vextension; xy_ur[1]+hextension xy_ur[2]+vextension ] )
        _netname_origin = label["netname"]
        # Label(netname_origin::NT, xy::SMatrix{2, 2, Int}, layer::Int, is_pin::Bool)
        push!(_ldata.layers[layerNum].labels, Label(_netname_origin, _xy, layerNum, true))
    end
    return _ldata
end

end #endif