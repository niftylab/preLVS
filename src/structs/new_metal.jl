if !isdefined(@__MODULE__, :_STRUCT_METAL_JL_)
    # 가드 상수를 현재 모듈 스코프에 직접 정의
    # @eval 없이 const를 직접 사용. 모듈의 top-level에서 include될 때 동작합니다.
    const _STRUCT_METAL_JL_ = true

using OrderedCollections
using StaticArrays
include("structure.jl")
include("stack.jl")

@enum MPosition START=1 END=2 UNDEF=3

mutable struct MPoint
    s_coord::Int
    pos::MPosition
    netname::Union{String, Nothing}
end

mutable struct MVector
    layer::Int
    p_coord::Int
    points::SVector{2, MPoint}           # contains only two MPoints (start, end)
    netname::Union{String, Nothing}
end

mutable struct MLayer
    layer::Int
    metals::Dict{Int, Vector{MVector}}   # key: primary coord, value: MVectorList
end

mutable struct MData
    libname::String
    cellname::String
    metals::Dict{Int, MLayer}            # key: metal layer num, value: MLayer
end



###### OrderedMLayer and OrderedMData (최종 결과물) ######

mutable struct MOVector
    layer::Int
    p_coord::Int
    points::SVector{2, MPoint}          # contains only two MPoints (start, end)
    netname::Union{String, Nothing}
    idx::Int                            # unique index for merged metals
    is_visited::Bool
end


mutable struct MOLayer
    layer::Int
    metals::OrderedDict{Int, Vector{MOVector}}   # key: primary coord, value: MVectorList
end


mutable struct MOData
    libname::String
    cellname::String
    metals::OrderedDict{Int, MOLayer}     # key: metal layer num, value: MLayer
end



"""
Convenience constructor for MPoint.
"""
MPoint(s_coord::Int, pos::MPosition; netname::Union{String, Nothing}=nothing) = 
    MPoint(s_coord, pos, netname)

"""
Convenience constructor for MVector.
"""
function MVector(layer::Int, p_coord::Int, p0::MPoint, p1::MPoint; netname::Union{String, Nothing}=nothing)
    return MVector(layer, p_coord, SVector(p0, p1), netname)
end

"""
Convenience constructor for MLayer.
"""
MLayer(layer::Int; metals::Dict{Int, Vector{MVector}}=Dict{Int, Vector{MVector}}()) = 
    MLayer(layer, metals)

"""
Convenience constructor for MData.
"""
MData(libname::String, cellname::String; metals::Dict{Int, MLayer}=Dict{Int, MLayer}()) = 
    MData(libname, cellname, metals)

"""
Convenience constructor for MOVector.
"""
function MOVector(layer::Int, p_coord::Int, p0::MPoint, p1::MPoint; netname::Union{String, Nothing}=nothing, idx::Int=0, is_visited::Bool=false)
    return MOVector(layer, p_coord, SVector(p0, p1), netname, idx, false)
end


"""
Convenience constructor for OrderedMLayer.
"""
function MOLayer(layer::Int; metals::OrderedDict{Int, Vector{MOVector}}=OrderedDict{Int, Vector{MOVector}}())
    return MOLayer(layer, metals)
end

"""
Convenience constructor for OrderedMData.
"""
function MOData(libname::String, cellname::String; metals::OrderedDict{Int, MOLayer}=OrderedDict{Int, MOLayer}())
    return MOData(libname, cellname, metals)
end




import Base: ==

==(a::MVector, b::MVector) = 
    a.layer == b.layer && 
    a.p_coord == b.p_coord && 
    a.points == b.points && 
    a.netname == b.netname

==(a::SVector{2, MPoint}, b::SVector{2, MPoint}) = 
    a[1] == b[1] && 
    a[2] == b[2]

==(a::MPoint, b::MPoint) = 
    a.s_coord == b.s_coord && 
    a.pos == b.pos && 
    a.netname == b.netname


function pop_mvector!(v::Vector{MVector}, x::MVector)
    idx = findfirst(y -> y == x, v)
    for mv in v
        println("MVector: $mv")
        println("x: $x")
        println("mv == x: $(mv == x)")
    end
    if idx === nothing
        error("Element not found in the vector")
    end
    element = v[idx]
    deleteat!(v, idx)
    return element
end

# function get_mvector_at_loc(mdata::MData, layer::Int, p_coord::Int)::MVector


function string_to_mposition(pos::String)::MPosition
    if pos == "START"
        return START
    elseif pos == "END"
        return END
    elseif pos == "UNDEF"
        return UNDEF
    end
    error("Invalid position: $pos")
end

# Needs refactoring
function db_to_MData(libname::String, cellname::String, db_json_data::Dict, orientation_list::Vector{String}, equiv_net_sets::Vector{Tuple{String,Set{String}}})::Tuple{MData, MData}

    # Initialize metals
    # unnamed_metals = metals + pins of primitives
    # named_metals = labels + pins
    unnamed_metals = Dict{Int, MLayer}()
    named_metals = Dict{Int, MLayer}()

    # Initialize unnamed_metals and named_metals
    for i in range(1, stop=length(orientation_list))
        unnamed_metals[i] = MLayer(i, Dict{Int, Vector{MVector}}())
        named_metals[i] = MLayer(i, Dict{Int, Vector{MVector}}())
    end

    db_primitives = db_json_data[libname][cellname]["primitives"]
    db_metals = db_json_data[libname][cellname]["metals"]
    db_labels = db_json_data[libname][cellname]["labels"]
    db_pins = db_json_data[libname][cellname]["pins"]

    # Add pins of primitives
    for _prim in db_primitives
        _pins = _prim["pins"]
        for (pname, p) in _pins
            layer = metal_to_int(p["layer"])
            is_vertical = orientation_list[layer] == "VERTICAL"
            p_coord = p["xy"][1][is_vertical ? 1 : 2]
            extension_orient = is_vertical ? "vextension" : "hextension"
            extension = p[extension_orient]

            min_s = is_vertical ? min(p["xy"][1][2], p["xy"][2][2]) : min(p["xy"][1][1], p["xy"][2][1])
            max_s = is_vertical ? max(p["xy"][1][2], p["xy"][2][2]) : max(p["xy"][1][1], p["xy"][2][1])
            points = SVector{2, MPoint}(MPoint(min_s - extension, UNDEF, nothing),
                                        MPoint(max_s + extension, UNDEF, nothing))

            if !haskey(unnamed_metals[layer].metals, p_coord)
                unnamed_metals[layer].metals[p_coord] = Vector{MVector}()
            end
            push!(unnamed_metals[layer].metals[p_coord], MVector(layer, p_coord, points, nothing))
        end
    end

    # Add metals
    for db_metal in db_metals
        layer = metal_to_int(db_metal["layer"])
        is_vertical = orientation_list[layer] == "VERTICAL"
        p_coord = db_metal["xy"][1][is_vertical ? 1 : 2]
        extension_orient = is_vertical ? "vextension" : "hextension"
        extension = db_metal[extension_orient]

        min_s = is_vertical ? min(db_metal["xy"][1][2], db_metal["xy"][2][2]) : min(db_metal["xy"][1][1], db_metal["xy"][2][1])
        max_s = is_vertical ? max(db_metal["xy"][1][2], db_metal["xy"][2][2]) : max(db_metal["xy"][1][1], db_metal["xy"][2][1])
        points = SVector{2, MPoint}(MPoint(min_s - extension, UNDEF, nothing),
                                    MPoint(max_s + extension, UNDEF, nothing))

        if !haskey(unnamed_metals[layer].metals, p_coord)
            unnamed_metals[layer].metals[p_coord] = Vector{MVector}()
        end
        push!(unnamed_metals[layer].metals[p_coord], MVector(layer, p_coord, points, nothing))
    end

    # Named metals

    # Add labels
    for db_label in db_labels
        layer = metal_to_int(db_label["layer"])
        is_vertical = orientation_list[layer] == "VERTICAL"
        p_coord = db_label["xy"][1][is_vertical ? 1 : 2]
        extension_orient = is_vertical ? "vextension" : "hextension"
        extension = db_label[extension_orient]
        netname = get(db_label, "netname", nothing)
        netname = netname === nothing ? "UNKNOWN" : unify_netname(netname, equiv_net_sets) 

        min_s = is_vertical ? min(db_label["xy"][1][2], db_label["xy"][2][2]) : min(db_label["xy"][1][1], db_label["xy"][2][1])
        max_s = is_vertical ? max(db_label["xy"][1][2], db_label["xy"][2][2]) : max(db_label["xy"][1][1], db_label["xy"][2][1])
        points = SVector{2, MPoint}(MPoint(min_s - extension, UNDEF, netname),
                                    MPoint(max_s + extension, UNDEF, netname))

        if !haskey(named_metals[layer].metals, p_coord)
            named_metals[layer].metals[p_coord] = Vector{MVector}()
        end
        push!(named_metals[layer].metals[p_coord], MVector(layer, p_coord, points, netname))
    end

    # Add pins
    for db_pin in db_pins
        layer = metal_to_int(db_pin["layer"])
        is_vertical = orientation_list[layer] == "VERTICAL"
        p_coord = db_pin["xy"][1][is_vertical ? 1 : 2]
        extension_orient = is_vertical ? "vextension" : "hextension"
        extension = db_pin[extension_orient]
        netname = get(db_pin, "netname", nothing)
        netname = netname === nothing ? "UNKNOWN" : unify_netname(netname, equiv_net_sets)

        min_s = is_vertical ? min(db_pin["xy"][1][2], db_pin["xy"][2][2]) : min(db_pin["xy"][1][1], db_pin["xy"][2][1])
        max_s = is_vertical ? max(db_pin["xy"][1][2], db_pin["xy"][2][2]) : max(db_pin["xy"][1][1], db_pin["xy"][2][1])
        points = SVector{2, MPoint}(MPoint(min_s - extension, UNDEF, netname),
                                    MPoint(max_s + extension, UNDEF, netname))

        if !haskey(named_metals[layer].metals, p_coord)
            named_metals[layer].metals[p_coord] = Vector{MVector}()
        end
        push!(named_metals[layer].metals[p_coord], MVector(layer, p_coord, points, netname))
    end


    return MData(libname, cellname, unnamed_metals), MData(libname, cellname, named_metals)

end


function transform_MData(unnamed_MData::MData, named_MData::MData, Mtransform::Matrix{Int}, net_dict::Dict{String, String}, orientation_list::Vector{String}, source_net_sets::Vector{Tuple{String,Set{String}}})::MData
    
    libname = unnamed_MData.libname
    cellname = unnamed_MData.cellname
    unnamed_metals = unnamed_MData.metals
    named_metals = named_MData.metals

    new_metals = Dict{Int, MLayer}()

    # println("Transforming $libname/$cellname...")
    # println("Mtransform: $Mtransform")
    # println("net_dict: $net_dict")
    
    # For transformation (metals with no netname)
    
    for (layer, mlayer) in unnamed_metals
        new_mlayer = MLayer(layer, Dict{Int, Vector{MVector}}())
        is_vertical = orientation_list[layer] == "VERTICAL"

        for (p_coord, mvector_list) in mlayer.metals
            new_mvector_list = Vector{MVector}()
            new_p_coord = is_vertical ? (Mtransform * [p_coord; 0; 1])[1] : (Mtransform * [0; p_coord; 1])[2]
            for mvector in mvector_list
                new_s1 = is_vertical ? (Mtransform * [0; mvector.points[1].s_coord; 1])[2] : (Mtransform * [mvector.points[1].s_coord; 0; 1])[1]
                new_s2 = is_vertical ? (Mtransform * [0; mvector.points[2].s_coord; 1])[2] : (Mtransform * [mvector.points[2].s_coord; 0; 1])[1]
                
                new_points = SVector{2, MPoint}(MPoint(min(new_s1, new_s2), mvector.points[1].pos, nothing),
                                                MPoint(max(new_s1, new_s2), mvector.points[2].pos, nothing))
                push!(new_mvector_list, MVector(layer, p_coord, new_points, nothing))
            end
            new_mlayer.metals[new_p_coord] = new_mvector_list
        end
        new_metals[layer] = new_mlayer
    end

    # For transformation + netname mapping (metals with netname)

    for (layer, mlayer) in named_metals
        new_mlayer = MLayer(layer, Dict{Int, Vector{MVector}}())
        is_vertical = orientation_list[layer] == "VERTICAL"

        for (p_coord, mvector_list) in mlayer.metals
            new_mvector_list = Vector{MVector}()
            new_p_coord = is_vertical ? (Mtransform * [p_coord; 0; 1])[1] : (Mtransform * [0; p_coord; 1])[2]
            for mvector in mvector_list
                new_s1 = is_vertical ? (Mtransform * [0; mvector.points[1].s_coord; 1])[2] : (Mtransform * [mvector.points[1].s_coord; 0; 1])[1]
                new_s2 = is_vertical ? (Mtransform * [0; mvector.points[2].s_coord; 1])[2] : (Mtransform * [mvector.points[2].s_coord; 0; 1])[1]
                netname = mvector.points[1].netname
                if netname in Set(["UNKNOWN", "OBSTACLE"])
                    netname = "UNKNOWN"
                else
                    # println("Netname: $netname -> $(net_dict[unify_netname(netname, source_net_sets)])")
                    netname = net_dict[unify_netname(mvector.points[1].netname, source_net_sets)]
                end
                
                new_points = SVector{2, MPoint}(MPoint(min(new_s1, new_s2), mvector.points[1].pos, netname),
                                                MPoint(max(new_s1, new_s2), mvector.points[2].pos, netname))
                push!(new_mvector_list, MVector(layer, p_coord, new_points, netname))
            end
            if haskey(new_metals[layer].metals, new_p_coord)
                append!(new_metals[layer].metals[new_p_coord], new_mvector_list)
            else
                new_mlayer.metals[new_p_coord] = new_mvector_list
            end
        end
        if haskey(new_metals, layer)
            for (p_coord, mvector_list) in new_mlayer.metals
                if haskey(new_metals[layer].metals, p_coord)
                    append!(new_metals[layer].metals[p_coord], mvector_list)
                else
                    new_metals[layer].metals[p_coord] = mvector_list
                end
            end
        else
            new_metals[layer] = new_mlayer
        end
    end

    return MData(libname, cellname, new_metals)

end



# Sort and merge MData

function sort_n_merge_MData(mdata::MData)

    new_mdata = MOData(mdata.libname, mdata.cellname, OrderedDict{Int, MOLayer}())
    layer_list = sort(unique(Iterators.flatten(keys(mdata.metals))))

    #named_mvectors = Vector{MVector}()

    # unique index for each metal
    idx = 1

    for layer in layer_list
        new_mdata.metals[layer] = MOLayer(layer, OrderedDict{Int, Vector{MOVector}}())

        # Get all primary coordinates
        p_coords = sort(collect(keys(mdata.metals[layer].metals)))

        for p_coord in p_coords
            new_mdata.metals[layer].metals[p_coord], idx = merge_mvector_list(mdata.metals[layer].metals[p_coord], p_coord, layer, idx)
            # if length(_named_mvectors) > 0
            #     append!(named_mvectors, _named_mvectors)
            # end
        end
    end
    return new_mdata, idx-1#, named_mvectors
end


function merge_mvector_list(mvector_list::Vector{MVector}, p_coord::Int, layer::Int, idx::Int)


    # Assign START/END to each MPoint
    for mvector in mvector_list
        if mvector.points[1].s_coord > mvector.points[2].s_coord
            mvector.points[1].pos = END
            mvector.points[2].pos = START
        else
            mvector.points[1].pos = START
            mvector.points[2].pos = END
        end
    end


    # x.pos로 한 이유는 동일한 s_coord를 가진 MPoint가 여러개일 경우, start_point가 end_point보다 먼저 정렬되도록
    mpoints = sort(
        [mpoint for mvector in mvector_list for mpoint in mvector.points],
        by = x -> (x.s_coord, x.pos)
    )

    merged_metals = Vector{MOVector}()
    # named_metal_list = Vector{MVector}()
    st = Stack{MPoint}()
    netname_set = Set{String}()

    for mpoint in mpoints
        if mpoint.pos == START
            push_stack!(st, mpoint)
        elseif mpoint.pos == END
            if is_empty_stack(st)
                error("No matching START point for END point at s_coord $(mpoint.s_coord)")
                continue
            end
            if mpoint.netname !== nothing && mpoint.netname !== "UNKNOWN"
                push!(netname_set, mpoint.netname)
                if length(netname_set) > 1
                    # error("Multiple netnames found for the same s_coord $(mpoint.s_coord): $(netname_set)")
                    # println("ERROR: Multiple netnames found for the same s_coord $(mpoint.s_coord): $(netname_set)")
                end
            end
                

            start_mpoint = pop_stack!(st)
            if is_empty_stack(st)
                netname = isempty(netname_set) ? nothing : pop!(netname_set)
                push!(merged_metals, MOVector(layer, p_coord, SVector{2, MPoint}(MPoint(start_mpoint.s_coord, START, netname), 
                                                                                    MPoint(mpoint.s_coord, END, netname)), netname, idx, false))
                idx += 1
                # if netname !== nothing
                #     push!(named_metal_list, MVector(layer, p_coord, SVector{2, MPoint}(MPoint(start_mpoint.s_coord, START, netname), 
                #                                                                       MPoint(mpoint.s_coord, END, netname)), netname))
                # end
            end
        end
    end
    return merged_metals, idx #, named_metal_list
end


end #endif