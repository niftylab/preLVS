using OrderedCollections
using StaticArrays
include("structure.jl")
include("stack.jl")


# Metal structures

# old version
# @enum MPosition START END

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

@enum MPosition START END

struct MPoint
    s_coord::Int
    pos::MPosition
    netname::Union{String, Nothing}
end

mutable struct MVector
    p_coord::Int
    points::SVector{2, MPoint}                  # contains only two MPoints (start, end)
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

# TODO: defining Matal_dat format and migrate into MData_ver2 with proper struct name
"""
mutable struct Metal_dat
    m_coord::Int
    s_coords::SVector{2, Int}
end

mutable struct MLayer_ver2
    layer::Int
    metals::Vector{Metal_dat}   # key: main coord, value: MVectorList
end

mutable struct MData_ver2
    libname::String
    cellname::String
    metals::OrderedDict{Int, MLayer_ver2}        # key: metal layer num, value: MLayer
end
"""

function string_to_mposition(pos::String)::MPosition
    if pos == "START"
        return START
    elseif pos == "END"
        return END
    else
        error("Invalid position: $pos")
    end
end



################## MData functions ##################
#=
    json -> MData:      merged_to_MData
    db -> MData:        db_to_MData
    MData -> json:      MData_to_merged_json
=#
#####################################################


# merged_metal_dict.json -> MData format    ( JSON -> MData )
function merged_to_MData(libname::String, cellname::String, merged_path::String)
    if !isfile(merged_path)
        error("File not found at $merged_path")
        exit(1)
    end

    merged_data = JSON.parse(read(merged_path, String))

    _mdata = MData(libname, cellname, OrderedDict{Int, MLayer}())
    
    # "Metal1" : { "180" : [ [ { "coord" : "-35", "pos" : "START" }, { "coord" : "440", "pos" : "END" } ] ] }

    layer_list = sort([metal_to_int(layer) for layer in keys(merged_data)])

    for layer in layer_list
        _layer_data = merged_data["Metal" * string(layer)]

        _mlayer = MLayer(layer, OrderedDict{Int, MVectorList}())

        _m_coord_list = sort([parse(Int, m_coord) for m_coord in keys(_layer_data)])

        for _m_coord in _m_coord_list
            _mvlist = _layer_data[string(_m_coord)]
            _metal_vector_list = Vector{MVector}()
            for m in _mvlist
                _start = MPoint(m[1]["coord"], string_to_mposition(m[1]["pos"]))
                _end = MPoint(m[2]["coord"], string_to_mposition(m[2]["pos"]))
                push!(_metal_vector_list, MVector([_start, _end]))
            end
            _mlayer.metals[_m_coord] = MVectorList(_m_coord, _metal_vector_list)
        end
        _mdata.metals[layer] = _mlayer
    end

    return _mdata
end


# db -> MData format    (outputs unmerged MData)    ( JSON -> MData )
function db_to_MData(libname::String, cellname::String, db_metals::Vector, perform_sort::Bool=false)

    _unmerged_mdata = MData(libname, cellname, OrderedDict{Int, MLayer}())

    for metal in db_metals
        layer = metal_to_int(metal["layer"])
        is_horizontal = layer % 2 == 0
        if !haskey(_unmerged_mdata.metals, layer)
            _unmerged_mdata.metals[layer] = MLayer(layer, OrderedDict{Int, MVectorList}())
        end

        m_coord = metal["xy"][1][is_horizontal ? 2 : 1]
        extension_key = is_horizontal ? "hextension" : "vextension"
        extension = haskey(metal, extension_key) ? metal[extension_key] : 35

        s_coord_1, s_coord_2 = metal["xy"][1][2 - is_horizontal], metal["xy"][2][2 - is_horizontal]
        s_coord_1, s_coord_2 = (min(s_coord_1, s_coord_2) - extension, max(s_coord_1, s_coord_2) + extension)

        if haskey(_unmerged_mdata.metals[layer].metals, m_coord)
            push!(_unmerged_mdata.metals[layer].metals[m_coord].sub_coords, MVector([MPoint(s_coord_1, START), MPoint(s_coord_2, END)]))
        else
            _unmerged_mdata.metals[layer].metals[m_coord] = MVectorList(m_coord, [MVector([MPoint(s_coord_1, START), MPoint(s_coord_2, END)])])
        end

    end
    if perform_sort
        return sort_n_merge_MData(_unmerged_mdata)
    end
    return _unmerged_mdata
end

# db -> MData format    (outputs unmerged MData)    ( JSON -> MData )
# modified version of db_to_MData
# TODO: skip merge operation and make appliable into modified MData structure (see MData_ver2 definition)
function db_to_MData_test(db_json_data::Dict, libname::String, cellname::String, perform_sort::Bool=false)
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
        if !haskey(_unmerged_mdata.metals, layer)
            _unmerged_mdata.metals[layer] = MLayer(layer, OrderedDict{Int, MVectorList}())
        end

        m_coord = metal["xy"][1][is_horizontal ? 2 : 1]
        extension_key = is_horizontal ? "hextension" : "vextension"
        extension = haskey(metal, extension_key) ? metal[extension_key] : 35

        s_coord_1, s_coord_2 = metal["xy"][1][2 - is_horizontal], metal["xy"][2][2 - is_horizontal]
        s_coord_1, s_coord_2 = (min(s_coord_1, s_coord_2) - extension, max(s_coord_1, s_coord_2) + extension)

        if haskey(_unmerged_mdata.metals[layer].metals, m_coord)
            push!(_unmerged_mdata.metals[layer].metals[m_coord].sub_coords, MVector([MPoint(s_coord_1, START), MPoint(s_coord_2, END)]))
        else
            _unmerged_mdata.metals[layer].metals[m_coord] = MVectorList(m_coord, [MVector([MPoint(s_coord_1, START), MPoint(s_coord_2, END)])])
        end

    end
    if perform_sort
        return sort_n_merge_MData(_unmerged_mdata)
    end
    return _unmerged_mdata
end

# MData -> merged_metal_dict.json format    ( MData -> JSON )
# INPUT MData MUST BE SORTED & MERGED PRIOR TO THIS FUNCTION
function MData_to_merged_json(mdata::MData, merged_path::String)
    merged_data = OrderedDict()
    for (layer, metal_layer) in mdata.metals
        layer = "Metal" * string(layer)
        merged_data[layer] = OrderedDict()
        for (_main_coord, _mvlist) in metal_layer.metals
            merged_data[layer][_main_coord] = []
            for m_vector in _mvlist.sub_coords
                push!(merged_data[layer][_main_coord], [Dict("coord" => m.coord, "pos" => string(m.pos)) for m in m_vector.points])
            end
        end
    end

    open(merged_path, "w") do f
        JSON.print(f, merged_data, 2)
    end
end


################## MData Sorting & Merging functions ##################


function sort_n_merge_MData(mdatas::MData...)
    new_mdata = MData(mdatas[1].libname, mdatas[1].cellname, OrderedDict{Int, MLayer}())
    layer_list = sort(unique(Iterators.flatten(keys(mdata.metals) for mdata in mdatas)))
    for layer in layer_list
        new_mdata.metals[layer] = MLayer(layer, OrderedDict{Int, MVectorList}())

        main_coords = sort(unique(Iterators.flatten(
            keys(mdata.metals[layer].metals) for mdata in mdatas if haskey(mdata.metals, layer)
        )))

        for main_coord in main_coords
            mvector_list = Vector{MVector}()
            for mdata in mdatas
                if haskey(mdata.metals, layer) && haskey(mdata.metals[layer].metals, main_coord)
                    push!(mvector_list, mdata.metals[layer].metals[main_coord].sub_coords...)
                end
            end
            new_mdata.metals[layer].metals[main_coord] = merge_MVList(MVectorList(main_coord, mvector_list))
        end
    end
    return new_mdata
end


function sort_n_merge_MData(mdata::MData)
    new_mdata = MData(mdata.libname, mdata.cellname, OrderedDict{Int, MLayer}())
    layer_list = sort(collect(keys(mdata.metals)))
    for layer in layer_list
        new_mdata.metals[layer] = MLayer(layer, OrderedDict{Int, MVectorList}())
        mlayer = mdata.metals[layer]
        main_coords = sort(collect(keys(mlayer.metals)))
        for main_coord in main_coords
            new_mdata.metals[layer].metals[main_coord] = merge_MVList(mlayer.metals[main_coord])
        end
    end
    return new_mdata
end

function merge_MVList(mvlist::MVectorList)
    mpoints = sort(
        [mpoint for mvector in mvlist.sub_coords for mpoint in mvector.points],
        by = x -> x.coord
    )
    
    metals = []
    s1 = Stack{MPoint}()

    for mpoint in mpoints
        if mpoint.pos == START
            push_stack!(s1, mpoint)
        elseif mpoint.pos == END
            if is_empty_stack(s1)
                error("No matching start mpoint found for end mpoint at $(mpoint.coord)")
                continue
            end
            start_mpoint = pop_stack!(s1)
            if is_empty_stack(s1)
                push!(metals, MVector([start_mpoint, mpoint]))
            end
        end
    end
    return MVectorList(mvlist.main_coord, metals)
end

