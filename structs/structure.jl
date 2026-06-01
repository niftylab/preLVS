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

# "M2" / "Metal2" / "m2" -> 2
function metal_to_int(layer::String)
    return parse(Int, replace(lowercase(layer), r"(metal|m)" => "") |> strip)
end

end # include guard
