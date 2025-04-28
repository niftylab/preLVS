if !isdefined(@__MODULE__, :_STRUCT_STRUCTURE_JL_)
    # 가드 상수를 현재 모듈 스코프에 직접 정의
    # @eval 없이 const를 직접 사용. 모듈의 top-level에서 include될 때 동작합니다.
    const _STRUCT_STRUCTURE_JL_ = true

using StaticArrays
using OrderedCollections
const EXTENSION::Int = 35
const FlatInstTable = Dict{String, Dict{String, Dict{Int, Dict}}}


abstract type Rect end

mutable struct Metal
    layer::String
    xy::Vector{Vector{Int}}
    hextension::Int
    vextension::Int
    netname::String
    Mname::String
end

mutable struct Via
    layer_pair::Tuple{String,String}
    xy::Vector{Int}
    extension::Vector{Int}
    Mname::String
end

mutable struct Pin
    name::String
    xy::Vector{Vector{Int}}
    hextension::Int
    vextension::Int
    netname::String
    Mname::String
end

# 일단은 Cell은 사용하지 않았고, db는 Dict로 작성했습니다.

# mutable struct Cell
#     lib::String
#     sub_cells::Vector{Cell}
#     metals::Vector{Metal}
#     vias::Vector{Via}
# end

# mutable struct Database
#     libs::Dict
#     microtemplates::String
#     metals::Vector{Metal}
#     vias::Vector{Via}
#     pin::Vector{Pin}
# end


# Global table for 2-D affine transformation matrix
_Mt_ = Dict(
    "R0"    => [1 0 0; 0 1 0; 0 0 1],     # Rotate 0
    "R90"   => [0 -1 0; 1 0 0; 0 0 1],    # Rotate 90
    "R180"  => [-1 0 0; 0 -1 0; 0 0 1],  # Rotate 180
    "R270"  => [0 1 0; -1 0 0; 0 0 1],   # Rotate 270
    "MX"    => [1 0 0; 0 -1 0; 0 0 1],     # Mirror X
    "MY"    => [-1 0 0; 0 1 0; 0 0 1],     # Mirror Y
    "MXY"   => [0 1 0; 1 0 0; 0 0 1],     # Mirror XY (Reflection across y=x)
)

function affineMat(trans::String, move::Vector{Int})::Matrix{Int}
    # matrix for transformation + translation
    affine = _Mt_[trans]
    affine += [0 0 move[1]; 0 0 move[2]; 0 0 0]
    return affine
end

function get_bottom_left(Mtransform::Matrix{Int}, xy::Union{Vector{Int}, Tuple{Int, Int}}, width::Int, height::Int)::Tuple{Int, Int}
    # cell_data의 key는 좌측하단 (x, y) 좌표
    # "MX", "MY, "R180" 변환은 width, height를 바꿔줘야 함
    # "MX"      =>  x = x,      y = y - h
    # "MY"      =>  x = x - w,  y = y
    # "R180"    =>  x = x - w,  y = y - h

    mt2x2 = Mtransform[1:2, 1:2]

    if mt2x2 == [1 0; 0 1]                      # "R0"
        return (xy[1], xy[2])
    elseif mt2x2 == [1 0; 0 -1]                 # "MX"
        return (xy[1], xy[2] - height)
    elseif mt2x2 == [-1 0; 0 1]                 # "MY"
        return (xy[1] - width, xy[2])
    elseif mt2x2 == [-1 0; 0 -1]                # "R180"
        return (xy[1] - width, xy[2] - height)
    end
end


function get_bottom_left_by_transString(trans::String, xy::Union{Vector{Int}, Tuple{Int, Int}}, width::Int, height::Int)::Tuple{Int, Int}
    # cell_data의 key는 좌측하단 (x, y) 좌표
    # "MX", "MY, "R180" 변환은 width, height를 바꿔줘야 함
    # "MX"      =>  x = x,      y = y - h
    # "MY"      =>  x = x - w,  y = y
    # "R180"    =>  x = x - w,  y = y - h

    # mt2x2 = Mtransform[1:2, 1:2]

    if trans == "R0"                      # "R0"
        return (xy[1], xy[2])
    elseif trans == "MX"                 # "MX"
        return (xy[1], xy[2] - height)
    elseif trans == "MY"                 # "MY"
        return (xy[1] - width, xy[2])
    elseif trans == "R180"                # "R180"
        return (xy[1] - width, xy[2] - height)
    end

end

function get_xy(Mtransform::Matrix{Int}, bottom_left_xy::Union{Vector{Int}, Tuple{Int, Int}}, width::Int, height::Int)::Tuple{Int, Int}
    # cell_data의 key는 좌측하단 (x, y) 좌표
    # "MX", "MY, "R180" 변환은 width, height를 바꿔줘야 함
    # "MX"      =>  x = x,      y = y + h
    # "MY"      =>  x = x + w,  y = y
    # "R180"    =>  x = x + w,  y = y + h

    mt2x2 = Mtransform[1:2, 1:2]

    if mt2x2 == [1 0; 0 1]                      # "R0"
        return (bottom_left_xy[1], bottom_left_xy[2])
    elseif mt2x2 == [1 0; 0 -1]                 # "MX"
        return (bottom_left_xy[1], bottom_left_xy[2] + height)
    elseif mt2x2 == [-1 0; 0 1]                 # "MY"
        return (bottom_left_xy[1] + width, bottom_left_xy[2])
    elseif mt2x2 == [-1 0; 0 -1]                # "R180"
        return (bottom_left_xy[1] + width, bottom_left_xy[2] + height)
    end
end


metal_map = Dict(
    "M1" => "Metal1",
    "M2" => "Metal2",
    "M3" => "Metal3",
    "M4" => "Metal4",
    "M5" => "Metal5",
)

function metal_to_int(layer::String)
    return parse(Int, replace(lowercase(layer), r"(metal|m)" => "") |> strip)
end


function get_metal(metal::Dict, Mname::String, Mtransform::Matrix{Int})
    _layer          = "Metal" * replace(lowercase(metal["layer"]), r"(metal|m)" => "") |> strip
    _xy             = map(row -> map(x -> Int(x), row), metal["xy"])    # convert to Int
    _bbox_affine    = Mtransform * [[_xy[1];1] [ _xy[2];1]]             # affine transformation
    _bbox           = [collect(row) for row in eachrow(transpose(_bbox_affine[1:2,1:2]))]   # convert to 2-D array
    _hextension     = metal["hextension"]
    _vextension     = metal["vextension"]
    # _hextension        = get(metal, "hextension", 35)
    # _vextension        = get(metal, "vextension", 35)
    if haskey(metal, "netname")
        _netname    = metal["netname"]
    else
        _netname    = "OBSTACLE"
    end
    return Metal(_layer, _bbox, _hextension, _vextension, _netname, Mname)
end


function get_via(via::Dict, Mname::String, Mtransform::Matrix{Int})
    _layer_pair     = Tuple{String, String}(via["layer"])
    _xy             = Int.(via["xy"])
    _xy_affine      = Mtransform * [_xy ; 1]
    return Via(_layer_pair, _xy_affine[1:2], [],  Mname)
end

function get_pin(pin::Dict, Mname::String, Mtransform::Matrix{Int}, net_extern::Dict)
    _name           = pin["name"]
    _xy             = map(row -> map(x -> Int(x), row), pin["xy"])
    _bbox_affine    = Mtransform * [[_xy[1];1] [ _xy[2];1]]
    _bbox           = [collect(row) for row in eachrow(transpose(_bbox_affine[1:2,1:2]))]
    _hextension     = pin["hextension"]
    _vextension     = pin["vextension"]
    # _hextension        = get(pin, "hextension", 35)
    # _vextension        = get(pin, "vextension", 35)
    _netname        = get(pin, "netname", "")
    
    # if the netname is in the net_extern, replace it with the value
    if haskey(net_extern, _netname)
        _netname = net_extern[_netname]
    end
    return Pin(_name, _bbox, _hextension, _vextension, _netname, Mname)
end

# metal의 xy좌표를 affine transformation을 적용하여 반환
function get_metal_xy(xy::Vector{Vector{Int}}, Mtransform::Matrix{Int})
    _bbox_affine    = Mtransform * [[xy[1];1] [ xy[2];1]]
    _bbox           = [collect(row) for row in eachrow(transpose(_bbox_affine[1:2,1:2]))]
    return _bbox
end
function affine_transform(bbox::SMatrix{2, 2, Int}, Mtransform::Matrix{Int})
    _bbox_affine    = Mtransform * [[bbox[1,:];1] [ bbox[2,:];1]]
    _bbox           = transpose(_bbox_affine[1:2,1:2])
    return _bbox
end

function affine_transform(xy::SVector{2, Int}, Mtransform::Matrix{Int})
    _xy_affine    = Mtransform * [xy; 1]
    _xy           = transpose(_xy_affine[1:2])
    return _xy
end

function get_via_xy(xy::Vector{Int}, Mtransform::Matrix{Int})
    _xy_affine      = Mtransform * [xy ; 1]
    return _xy_affine[1:2]
end

end #endif