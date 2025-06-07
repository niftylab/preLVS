if !isdefined(@__MODULE__, :_MAIN_FUNC_JL_)
    # 가드 상수를 현재 모듈 스코프에 직접 정의
    # @eval 없이 const를 직접 사용. 모듈의 top-level에서 include될 때 동작합니다.
    const _MAIN_FUNC_JL_ = true

using JSON
using OrderedCollections
include("structs/tree.jl")
include("structs/new_metal.jl")
include("structs/via.jl")
include("utils/yaml.jl")

############################################################################################


# No Merging for now
# (그러나 cell type별 merge해서 memory에 저장하는 것이 더 효율적일수도 있음. 확인 필요)

# Metals, Primitive Pins, Labels, Pins, Vias를 Flatten하여 MData, VData로 변환

# Consists of 3 parts
# 1-1. Transfrom {Metals}, {Primitive Pins} using node.data.Mtransform
# 1-2. Transform {Labels}, {Pins} using node.data.Mtransform and update netname using node.data.net_extern
# 2.   Transform {Vias} using node.data.Mtransform
function flatten_v2(
    libname::String,
    cellname::String,
    cell_data::Dict,
    db_data::Dict,
    orientation_list::Vector{String},
    config_data::Dict,
    equiv_net_sets::Vector{Tuple{String, Set{String}}}
)::Tuple{MData, VData}

    # Get top cell name
    top_libname = libname
    top_cellname = cellname

    out_metals = Dict{Int, MLayer}()
    out_vias = Dict{String, VList}()

    task_list = Vector{Tuple{String, String}}()

    vidx = 1    # via index

    for (lib, cells) in cell_data
        for (cell, cell_data) in cells
            push!(task_list, (lib, cell))
        end
    end

    for (lib, cell) in task_list

        # println("Creating Cell: $(cell) in Task List")

        # METALS
        # unnamed_metals : metals + pins of primitives
        # named_metals : labels + pins
        unnamed_metals, named_metals = db_to_MData(lib, cell, db_data, orientation_list, equiv_net_sets)
        # println("Named Metals: $(named_metals.metals)")

        # VIAS
        vias = db_to_VData(lib, cell, db_data[lib][cell]["vias"], config_data, false)


        # Transform metals with MTransform & netname_dict
        for (idx, inst) in cell_data[lib][cell]
            Mtransform = inst["Mtransform"]
            net_mapper = inst["net_extern"]

            # For Transform + Netname update metals
            # println("Transforming Metals: $(cell) - $(idx)")
            transformed_MData = transform_MData(unnamed_metals, named_metals, Mtransform, net_mapper, orientation_list, equiv_net_sets)
            for (layer, mlayer) in transformed_MData.metals
                if !haskey(out_metals, layer)
                    out_metals[layer] = mlayer
                else
                    for (pcoord, mvector) in mlayer.metals
                        if haskey(out_metals[layer].metals, pcoord)
                            for mvector in mlayer.metals[pcoord]
                                push!(out_metals[layer].metals[pcoord], mvector)
                            end
                        else
                            out_metals[layer].metals[pcoord] = mlayer.metals[pcoord]
                        end
                    end
                end
            end
            
            # For Transform vias
            # println("Transforming Vias: $(cell) - $(idx)")
            transformed_VData = transform_VData(vias, Mtransform)
            for (vtype, vlist) in transformed_VData.vlists
                if !haskey(out_vias, vtype)
                    out_vias[vtype] = vlist
                else
                    for vpoint in vlist.vpoints
                        push!(out_vias[vtype].vpoints, set_via_idx(vpoint, vidx))
                        vidx += 1
                    end
                end
            end
        end
    end
    return MData(top_libname, top_cellname, out_metals), VData(top_libname, top_cellname, out_vias)
end

end # endif

