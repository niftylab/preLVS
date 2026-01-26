if !isdefined(@__MODULE__, :_PRELVS_NEW_METAL_JL_)
const _PRELVS_NEW_METAL_JL_ = true

using OrderedCollections
using StaticArrays
include("structure.jl")
include("stack.jl")
include("laygo_origin.jl")

@enum MPosition START=1 END=2 UNDEF=3

mutable struct MPoint
    s_coord::Int
    pos::MPosition
    netname::Union{String, Nothing}
    laygo_origin::Union{LaygoOrigin, Nothing}
end

mutable struct MVector
    layer::Int
    p_coord::Int
    width::Int                            # width in primary coord direction
    points::SVector{2, MPoint}           # contains only two MPoints (start, end)
    netname::Union{String, Nothing}
    laygo_origin::Union{LaygoOrigin, Nothing}
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
    width::Int                           # width in primary coord direction
    points::SVector{2, MPoint}          # contains only two MPoints (start, end)
    netname::Union{String, Nothing}
    laygo_origin_set::Union{Set{LaygoOrigin}, Nothing}
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
MPoint(s_coord::Int, pos::MPosition; netname::Union{String, Nothing}=nothing, laygo_origin::Union{LaygoOrigin, Nothing}=nothing) = 
    MPoint(s_coord, pos, netname, laygo_origin)

"""
Convenience constructor for MVector.
"""
function MVector(layer::Int, p_coord::Int, width::Int, p0::MPoint, p1::MPoint; netname::Union{String, Nothing}=nothing, laygo_origin::Union{LaygoOrigin, Nothing}=nothing)
    return MVector(layer, p_coord, width, SVector(p0, p1), netname, laygo_origin)
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



# OrderedMLayer and OrderedMData



"""
Convenience constructor for MOVector.
"""
function MOVector(layer::Int, p_coord::Int, width::Int, p0::MPoint, p1::MPoint; netname::Union{String, Nothing}=nothing, laygo_origin_set::Union{Set{LaygoOrigin}, Nothing}=nothing, idx::Int=0, is_visited::Bool=false)
    return MOVector(layer, p_coord, width, SVector(p0, p1), netname, laygo_origin_set, idx, is_visited)
end

function MOVector(layer::Int, p_coord::Int, width::Int, points::SVector{2, MPoint}; netname::Union{String, Nothing}=nothing, laygo_origin_set::Union{Set{LaygoOrigin}, Nothing}=nothing, idx::Int=0, is_visited::Bool=false)
    return MOVector(layer, p_coord, width, points, netname, laygo_origin_set, idx, is_visited)
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


# Grid에 따라 만들어지지 않은 metal 확인.
function check_grid_consistency(
    libname::String, cellname::String, 
    db_json_data::Dict, 
    orientation_list::Vector{String}, 
    grid_error_log::Vector{String},
    is_detailed::Bool=false,
    is_topcell::Bool=false
    )::Bool

    db_primitives = db_json_data[libname][cellname]["primitives"]
    db_metals = db_json_data[libname][cellname]["metals"]
    db_labels = db_json_data[libname][cellname]["labels"]
    db_pins = db_json_data[libname][cellname]["pins"]

    is_grid_consistent = true

    push!(grid_error_log, "Checking grid consistency for $libname/$cellname...")

    for _prim in db_primitives
        _pins = _prim["pins"]
        for (pname, p) in _pins
            layer = metal_to_int(p["layer"])
            is_vertical = orientation_list[layer] == "VERTICAL"
            p_coord_1 = p["xy"][1][is_vertical ? 1 : 2]
            p_coord_2 = p["xy"][2][is_vertical ? 1 : 2]
            if p_coord_1 !== p_coord_2
                push!(grid_error_log, "Primitive $pname occupies more than one grid: p_coords: $p_coord_1, $p_coord_2 / PinName: $pname")
                is_grid_consistent = false
            end
        end
    end

    for db_metal in db_metals
        _metal = is_detailed ? last(db_metal) : db_metal
        _name = is_detailed ? first(db_metal) : nothing
        layer = metal_to_int(_metal["layer"])
        is_vertical = orientation_list[layer] == "VERTICAL"
        p_coord_1 = _metal["xy"][1][is_vertical ? 1 : 2]
        p_coord_2 = _metal["xy"][2][is_vertical ? 1 : 2]
        if p_coord_1 !== p_coord_2
            push!(grid_error_log, "Metal occupies more than one grid: p_coords: $p_coord_1, $p_coord_2 / MetalName: $_name")
            is_grid_consistent = false
        end
    end

    for db_label in db_labels
        layer = metal_to_int(db_label["layer"])
        is_vertical = orientation_list[layer] == "VERTICAL"
        p_coord_1 = db_label["xy"][1][is_vertical ? 1 : 2]
        p_coord_2 = db_label["xy"][2][is_vertical ? 1 : 2]
        if p_coord_1 !== p_coord_2
            push!(grid_error_log, "Label occupies more than one grid: p_coords: $p_coord_1, $p_coord_2 / LabelName: $(db_label["netname"])")
            is_grid_consistent = false
        end
    end

    for db_pin in db_pins
        layer = metal_to_int(db_pin["layer"])
        is_vertical = orientation_list[layer] == "VERTICAL"
        p_coord_1 = db_pin["xy"][1][is_vertical ? 1 : 2]
        p_coord_2 = db_pin["xy"][2][is_vertical ? 1 : 2]
        if p_coord_1 !== p_coord_2
            push!(grid_error_log, "Pin occupies more than one grid: p_coords: $p_coord_1, $p_coord_2 / PinName: $(db_pin["name"])")
            is_grid_consistent = false
        end
    end
    
    return is_grid_consistent
end



# Needs refactoring
function db_to_MData(
    libname::String, cellname::String, 
    db_json_data::Dict, 
    orientation_list::Vector{String}, 
    source_net_sets::Vector{Tuple{String,Set{String}}},
    is_detailed::Bool=false,
    is_topcell::Bool=false
    )::Tuple{MData, MData}

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
            # Width-direction extension (perpendicular to span)
            width_extension = is_vertical ? p["hextension"] : p["vextension"]
            width = width_extension * 2

            min_s = is_vertical ? min(p["xy"][1][2], p["xy"][2][2]) : min(p["xy"][1][1], p["xy"][2][1])
            max_s = is_vertical ? max(p["xy"][1][2], p["xy"][2][2]) : max(p["xy"][1][1], p["xy"][2][1])
            points = SVector{2, MPoint}(MPoint(min_s - extension, UNDEF, netname=nothing, laygo_origin=nothing),
                                        MPoint(max_s + extension, UNDEF, netname=nothing, laygo_origin=nothing))

            if !haskey(unnamed_metals[layer].metals, p_coord)
                unnamed_metals[layer].metals[p_coord] = Vector{MVector}()
            end
            push!(unnamed_metals[layer].metals[p_coord], MVector(layer, p_coord, width, points, nothing, nothing))
        end
    end

    # Add metals
    for db_metal in db_metals

        # detailed (key: name, value: metal_data)
        # non-detailed (key: metal_data)
        # detailed인 경우 메탈의 이름을 따로 저장.

        # println("db_metal: $db_metal")
        # println("is_detailed: $is_detailed")
        metal_data = is_detailed ? last(db_metal) : db_metal
        current_name = is_detailed ? first(db_metal) : nothing

        if is_topcell
            laygo_origin = LaygoOrigin(current_name)
        else
            laygo_origin = LaygoOrigin("OBSTACLE")
        end

        # println("current_name: $current_name")
        # println("metal_data: $metal_data")

        layer = metal_to_int(metal_data["layer"])
        is_vertical = orientation_list[layer] == "VERTICAL"
        p_coord = metal_data["xy"][1][is_vertical ? 1 : 2]
        extension_orient = is_vertical ? "vextension" : "hextension"
        extension = metal_data[extension_orient]
        # Width-direction extension (perpendicular to span)
        width_extension = is_vertical ? metal_data["hextension"] : metal_data["vextension"]
        width = width_extension * 2

        min_s = is_vertical ? min(metal_data["xy"][1][2], metal_data["xy"][2][2]) : min(metal_data["xy"][1][1], metal_data["xy"][2][1])
        max_s = is_vertical ? max(metal_data["xy"][1][2], metal_data["xy"][2][2]) : max(metal_data["xy"][1][1], metal_data["xy"][2][1])
        points = SVector{2, MPoint}(MPoint(min_s - extension, UNDEF, netname=nothing, laygo_origin=laygo_origin),
                                    MPoint(max_s + extension, UNDEF, netname=nothing, laygo_origin=laygo_origin))

        if !haskey(unnamed_metals[layer].metals, p_coord)
            unnamed_metals[layer].metals[p_coord] = Vector{MVector}()
        end
        push!(unnamed_metals[layer].metals[p_coord], MVector(layer, p_coord, width, points, nothing, laygo_origin))
    end

    # Named metals

    # Add labels
    for db_label in db_labels

        if is_topcell
            if db_label["netname"] === nothing
                laygo_origin = LaygoOrigin("UNKNOWN_LABEL")
            else
                laygo_origin = LaygoOrigin(db_label["netname"])
            end
        else
            laygo_origin = LaygoOrigin("OBSTACLE")
        end

        layer = metal_to_int(db_label["layer"])
        is_vertical = orientation_list[layer] == "VERTICAL"
        p_coord = db_label["xy"][1][is_vertical ? 1 : 2]
        extension_orient = is_vertical ? "vextension" : "hextension"
        extension = db_label[extension_orient]
        # Width-direction extension (perpendicular to span)
        width_extension = is_vertical ? db_label["hextension"] : db_label["vextension"]
        width = width_extension * 2
        netname = get(db_label, "netname", nothing)
        netname = netname === nothing ? "UNKNOWN" : unify_netname(netname, source_net_sets)

        min_s = is_vertical ? min(db_label["xy"][1][2], db_label["xy"][2][2]) : min(db_label["xy"][1][1], db_label["xy"][2][1])
        max_s = is_vertical ? max(db_label["xy"][1][2], db_label["xy"][2][2]) : max(db_label["xy"][1][1], db_label["xy"][2][1])
        points = SVector{2, MPoint}(MPoint(min_s - extension, UNDEF, netname=netname, laygo_origin=laygo_origin),
                                    MPoint(max_s + extension, UNDEF, netname=netname, laygo_origin=laygo_origin))

        if !haskey(named_metals[layer].metals, p_coord)
            named_metals[layer].metals[p_coord] = Vector{MVector}()
        end
        push!(named_metals[layer].metals[p_coord], MVector(layer, p_coord, width, points, netname, laygo_origin))
    end

    # Add pins
    for db_pin in db_pins

        if is_topcell
            if db_pin["netname"] === nothing
                laygo_origin = LaygoOrigin("UNKNOWN_PIN")
            else
                laygo_origin = LaygoOrigin(db_pin["netname"])
            end
        else
            laygo_origin = LaygoOrigin("OBSTACLE")
        end

        layer = metal_to_int(db_pin["layer"])
        is_vertical = orientation_list[layer] == "VERTICAL"
        p_coord = db_pin["xy"][1][is_vertical ? 1 : 2]
        extension_orient = is_vertical ? "vextension" : "hextension"
        extension = db_pin[extension_orient]
        # Width-direction extension (perpendicular to span)
        width_extension = is_vertical ? db_pin["hextension"] : db_pin["vextension"]
        width = width_extension * 2
        netname = get(db_pin, "netname", nothing)
        netname = netname === nothing ? "UNKNOWN" : unify_netname(netname, source_net_sets)

        min_s = is_vertical ? min(db_pin["xy"][1][2], db_pin["xy"][2][2]) : min(db_pin["xy"][1][1], db_pin["xy"][2][1])
        max_s = is_vertical ? max(db_pin["xy"][1][2], db_pin["xy"][2][2]) : max(db_pin["xy"][1][1], db_pin["xy"][2][1])
        points = SVector{2, MPoint}(MPoint(min_s - extension, UNDEF, netname=netname, laygo_origin=laygo_origin),
                                    MPoint(max_s + extension, UNDEF, netname=netname, laygo_origin=laygo_origin))

        if !haskey(named_metals[layer].metals, p_coord)
            named_metals[layer].metals[p_coord] = Vector{MVector}()
        end
        push!(named_metals[layer].metals[p_coord], MVector(layer, p_coord, width, points, netname, laygo_origin))
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
                
                new_points = SVector{2, MPoint}(MPoint(min(new_s1, new_s2), mvector.points[1].pos, netname=mvector.netname, laygo_origin=mvector.laygo_origin),
                                                MPoint(max(new_s1, new_s2), mvector.points[2].pos, netname=mvector.netname, laygo_origin=mvector.laygo_origin))
                push!(new_mvector_list, MVector(layer, p_coord, mvector.width, new_points, mvector.netname, mvector.laygo_origin))
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

                new_points = SVector{2, MPoint}(MPoint(min(new_s1, new_s2), mvector.points[1].pos, netname=netname, laygo_origin=mvector.laygo_origin),
                                                MPoint(max(new_s1, new_s2), mvector.points[2].pos, netname=netname, laygo_origin=mvector.laygo_origin))
                push!(new_mvector_list, MVector(layer, p_coord, mvector.width, new_points, netname, mvector.laygo_origin))
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
    short_error_data = Vector{Dict{String, Any}}()

    #named_mvectors = Vector{MVector}()

    # unique index for each metal
    idx = 1

    for layer in layer_list
        new_mdata.metals[layer] = MOLayer(layer, OrderedDict{Int, Vector{MOVector}}())

        # Get all primary coordinates
        p_coords = sort(collect(keys(mdata.metals[layer].metals)))

        for p_coord in p_coords
            new_mdata.metals[layer].metals[p_coord], idx = merge_mvector_list(mdata.metals[layer].metals[p_coord], p_coord, layer, idx, short_error_data)
            # if length(_named_mvectors) > 0
            #     append!(named_mvectors, _named_mvectors)
            # end
        end
    end
    return new_mdata, idx-1, short_error_data #, named_mvectors
end


function merge_mvector_list(mvector_list::Vector{MVector}, p_coord::Int, layer::Int, idx::Int, short_error_data::Vector{Dict{String, Any}})

    # Build a map from MPoint to its source MVector (for width lookup)
    mpoint_to_mvector = Dict{MPoint, MVector}()
    for mvector in mvector_list
        for mpoint in mvector.points
            mpoint_to_mvector[mpoint] = mvector
        end
    end

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
    st = CustomStack{MPoint}()
    netname_set = Set{String}()
    laygo_origin_set = Set{LaygoOrigin}()
    width_set = Set{Int}()  # Track widths of metals being merged

    for mpoint in mpoints

        if mpoint.pos == START
            push_stack!(st, mpoint)
            # Track width of this metal
            if haskey(mpoint_to_mvector, mpoint)
                push!(width_set, mpoint_to_mvector[mpoint].width)
            end

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
                    current_error_data = Dict{String, Any}()
                    current_error_data["message"] = "SHORT_ERROR: Multiple netnames found for the same s_coord $(mpoint.s_coord): $(netname_set)"
                    current_error_data["netname_set"] = copy(netname_set)
                    push!(short_error_data, current_error_data)
                end
            end
            if mpoint.laygo_origin !== nothing
                if !(mpoint.laygo_origin.traceback in Set([laygo_origin.traceback for laygo_origin in laygo_origin_set]))
                    push!(laygo_origin_set, mpoint.laygo_origin)
                end
            end

            start_mpoint = pop_stack!(st)
            # empty stack = metal 끝
            if is_empty_stack(st)
                netname = isempty(netname_set) ? nothing : pop!(netname_set)
                # Use maximum width from merged metals (or 0 if no widths tracked)
                merged_width = isempty(width_set) ? 0 : maximum(width_set)
                push!(merged_metals, MOVector(layer, p_coord, merged_width, SVector{2, MPoint}(MPoint(start_mpoint.s_coord, START, netname=netname, laygo_origin=start_mpoint.laygo_origin),
                                                                                  MPoint(mpoint.s_coord, END, netname=netname, laygo_origin=mpoint.laygo_origin)), netname, copy(laygo_origin_set), idx, false))
                idx += 1

                # 이름 저장한 set들 초기화
                empty!(laygo_origin_set)
                empty!(netname_set)
                empty!(width_set)
                # if netname !== nothing
                #     push!(named_metal_list, MVector(layer, p_coord, SVector{2, MPoint}(MPoint(start_mpoint.s_coord, START, netname),
                #                                                                       MPoint(mpoint.s_coord, END, netname)), netname))
                # end
            end

            # println("laygo_origin_set: $laygo_origin_set")
            # if isempty(laygo_origin_set)
            #     println("laygo_origin_set is empty")
            #     println("mpoint: $mpoint")
            # end
        end
    end
    return merged_metals, idx #, named_metal_list
end

end # include guard
