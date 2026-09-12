if !isdefined(@__MODULE__, :_PRELVS_STRUCTURE_JL_)
const _PRELVS_STRUCTURE_JL_ = true

# 2-D affine transform helpers used during hierarchy flattening.
# (Layout geometry itself is carried as 1-D MVectors in new_metal.jl; this
#  file only provides the transform matrices and the layer-name parser.)

# Global table for 2-D affine transformation matrices (rotation / mirror).
_Mt_ = Dict(
    "R0"    => [1 0 0; 0 1 0; 0 0 1],     # Rotate 0
    "R90"   => [0 -1 0; 1 0 0; 0 0 1],    # Rotate 90
    "R180"  => [-1 0 0; 0 -1 0; 0 0 1],   # Rotate 180
    "R270"  => [0 1 0; -1 0 0; 0 0 1],    # Rotate 270
    "MX"    => [1 0 0; 0 -1 0; 0 0 1],    # Mirror X
    "MY"    => [-1 0 0; 0 1 0; 0 0 1],    # Mirror Y
    "MXY"   => [0 1 0; 1 0 0; 0 0 1],     # Mirror XY (reflection across y=x)
)

# Build a 3x3 affine matrix combining a named transform with a translation.
function affineMat(trans::String, move::Vector{Int})::Matrix{Int}
    affine = _Mt_[trans]
    affine += [0 0 move[1]; 0 0 move[2]; 0 0 0]
    return affine
end

# Layer name -> layer number, from the tech config's `Layer.order` (position, 1-based):
# names are whatever the tech declares (M1, C4, K1 ...), never parsed for a digit.
# Filled by get_config (utils/yaml.jl); an unknown name is an error, not a guess.
const _LAYER_INDEX_ = Dict{String, Int}()
const _LAYER_ORDER_ = String[]

function set_layer_order!(order::Vector)
    empty!(_LAYER_INDEX_)
    empty!(_LAYER_ORDER_)
    for (i, name) in enumerate(order)
        _LAYER_INDEX_[String(name)] = i
        push!(_LAYER_ORDER_, String(name))
    end
end

function metal_to_int(layer::String)
    if !haskey(_LAYER_INDEX_, layer)
        error("layer '$(layer)' not in the tech config Layer.order $(_LAYER_ORDER_) (get_config not called, or a layer the tech does not declare)")
    end
    return _LAYER_INDEX_[layer]
end

# Layer number -> name (inverse of metal_to_int).
function int_to_metal(layer_num::Int)
    if layer_num < 1 || layer_num > length(_LAYER_ORDER_)
        error("layer number $(layer_num) outside the tech config Layer.order $(_LAYER_ORDER_)")
    end
    return _LAYER_ORDER_[layer_num]
end

end # include guard
