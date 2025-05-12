if !isdefined(@__MODULE__, :_SWEEPLINE_FLATTEN_JL_)
    # 가드 상수를 현재 모듈 스코프에 직접 정의
    # @eval 없이 const를 직접 사용. 모듈의 top-level에서 include될 때 동작합니다.
    const _SWEEPLINE_FLATTEN_JL_ = true

using JSON
using OrderedCollections
include("../structs/tree.jl")
include("../structs/rect.jl")
include("../utils/yaml.jl")

function flatten_V2(cell_data::Dict, cell_list::Set{Tuple{String, String}}, db_data::Dict, config_data::Dict, source_net_sets::Vector)

    out_metal = Vector{MData}()
    out_via   = Vector{VData}()
    out_label = Vector{LData}()

    memory_metal    = Dict()
    memory_via      = Dict()
    memory_label    = Dict()

    for (lib, cell) in cell_list
        if !haskey(memory_metal, lib)
            memory_metal[lib]   = Dict()
            memory_via[lib]     = Dict()
            memory_label[lib]   = Dict()
        end
        memory_metal[lib][cell]   = db_to_MData(db_data, lib, cell, false)
        memory_via[lib][cell]     = db_to_VData(db_data, lib, cell, config_data)
        memory_label[lib][cell]   = db_to_LData(db_data, lib, cell)

        for (idx, inst) in cell_data[lib][cell]
            Mtransform = inst["Mtransform"]
            net_mapper = inst["net_extern"]

            transformed_metal = get_transformed_MData_V3(memory_metal[lib][cell], Mtransform)
            transformed_via   = get_transformed_VData_V3(memory_via[lib][cell], Mtransform)
            transformed_label = get_transformed_LData_V3(memory_label[lib][cell], inst, source_net_sets)
            
            push!(out_metal, transformed_metal)
            push!(out_via, transformed_via)
            push!(out_label, transformed_label)
        end
    end
    return out_metal, out_via, out_label
end

function get_transformed_MData_V3(originMetal::MData, Mtransform::Matrix{Int})

    # newMData            = deepcopy(originMetal)

    # for (_layerNum, _layer) in newMData.layers
    #     for _metal in _layer.metals
    #         # Determine transformed coordinates
    #         _metal.xy = affine_transform(_metal.xy, Mtransform)
    #     end
    # end
    # return newMData

    newMData = MData(originMetal.libname, originMetal.cellname, OrderedDict{Int, MLayer}())
    for (_layerNum, _layer) in originMetal.layers
        newMData.layers[_layerNum] = MLayer(_layerNum, _layer.prefer_direction, Vector{MRect}())
        for _metal in _layer.metals
            # Determine transformed coordinates
            xy = affine_transform(_metal.xy, Mtransform)
            push!(newMData.layers[_layerNum].metals, MRect(_layerNum, xy))
        end
    end
    return newMData
end

function get_transformed_VData_V3(originVia::VData, Mtransform::Matrix{Int})

    # newVData            = deepcopy(originVia)

    # for (vcellname, vlist) in newVData.vlists
    #     for via in vlist.vias
    #         # Determine transformed coordinates
    #         via.xy = affine_transform(via.xy, Mtransform)
    #     end
    # end
    # return newVData
    newVData = VData(originVia.libname, originVia.cellname, OrderedDict{String, VList}())
    for (vtype, vlist) in originVia.vlists
        newVData.vlists[vtype] = VList(vtype, Vector{VRect}())
        for via in vlist.vias
            # Determine transformed coordinates
            xy = affine_transform(via.xy, Mtransform)
            push!(newVData.vlists[vtype].vias, VRect(via.type, via.layer, xy))
        end
    end
    return newVData
end

function get_transformed_LData_V3(originlabel::LData, inst_data::Dict, equivalent_net_sets::Vector)
    net_mapper          = inst_data["net_extern"]
    instname            = inst_data["instname"]
    Mname               = inst_data["Mname"]
    Mtransform          = inst_data["Mtransform"]

    newLData = LData(originlabel.libname, originlabel.cellname, instname, OrderedDict{Int, LLayer{String}}())
    for (_layerNum, _layer) in originlabel.layers
        newLData.layers[_layerNum] = LLayer(_layerNum, Vector{Label{String}}())
        for _label in _layer.labels
            # Determine transformed coordinates
            xy = affine_transform(_label.xy, Mtransform)

            if _label.netname_origin in Set(["UNKNOWN", "OBSTACLE"])
                _netname = "UNKNOWN"
            else
                _netname = net_mapper[unify_netname(_label.netname_origin, equivalent_net_sets)]
            end

            # _netname        = "UNKNOWN"
            # if haskey(net_mapper, _label.netname_origin)
            #     _netname    = net_mapper[_label.netname_origin]
            # else
            #     for (rep, net_set) in equivalent_net_sets
            #         # if _label.netname_origin in net_set
            #         #     _eqnet = first(intersect(net_set, keys(net_mapper)))
            #         #     _netname    = net_mapper[_eqnet]
            #         #     break
            #         # end
            #         if _label.netname_origin in net_set
            #             common_nets_in_mapper = intersect(net_set, keys(net_mapper))
            #             if !isempty(common_nets_in_mapper)
            #                 _eqnet = first(common_nets_in_mapper)
            #                 _netname = net_mapper[_eqnet]
            #                 break
            #             end
            #         end
            #     end
            # end
            # if _netname == "UNKNOWN"
            #     _netname    = Mname * "__" * _label.netname_origin
                

            #     # DEBUG
            #     if _netname == "dff_2x__CLK"
            #         println("DEBUG: _netname = $(_netname)")
            #         println("_label.netname_origin = $(_label.netname_origin)")
            #         println("net_mapper = $(net_mapper)")
            #     end
            # end
            push!(newLData.layers[_layerNum].labels, Label(_label.netname_origin, _netname, SMatrix{2,2,Int}([xy[1] xy[3]; xy[2] xy[4]]), _label.layer, _label.is_pin))
        end
    end
    return newLData
end



############################################################

function create_rect_table(cell_list::Set{Tuple{String, String}}, db_json_data::Dict, config_data::Dict)
    memory_metal    = Dict()
    memory_via      = Dict()
    memory_label    = Dict()
    for data in cell_list
    #    println("String 1: $(item[1]), String 2: $(item[2])")
        libname = data[1]; cellname = data[2]
        if !haskey(memory_metal, libname)
            memory_metal[libname]   = Dict()
            memory_via[libname]     = Dict()
            memory_label[libname]   = Dict()
        end
        memory_metal[libname][cellname] = db_to_MData(db_json_data, libname, cellname, false)
        memory_via[libname][cellname]   = db_to_VData(db_json_data, libname, cellname, config_data)
        memory_label[libname][cellname] = db_to_LData(db_json_data, libname, cellname)
    end
    return memory_metal, memory_via, memory_label
end

function create_rect_tree(root_cell::TreeNode{CellData}, memory_metal::Dict, memory_label::Dict, memory_via::Dict, config_data::Dict)
    equivalent_net_sets = config_data["equivalent_net_sets"]
    function _traverse_tree!(node_cell::TreeNode{CellData}, node_rect::TreeNode{RectData})
        for child in node_cell.children
            _data       = child.data
            _cellname   = _data.cellname
            _libname    = _data.libname
            newMData    = get_transformed_MData_v2(memory_metal[_libname][_cellname], child.data)
            newLData    = get_transformed_LData_v2(memory_label[_libname][_cellname], child.data, equivalent_net_sets)
            newVData    = get_transformed_VData_v2(memory_via[_libname][_cellname], child.data)
            newRectData = RectData(newMData, newLData, newVData)
            child_rect  = TreeNode(newRectData)
            add_child!(node_rect, child_rect)
            _traverse_tree!(child, child_rect)
        end
    end

    libname_top     = root_cell.data.libname
    cellname_top    = root_cell.data.cellname
    rect_top        = RectData(memory_metal[libname_top][cellname_top], memory_label[libname_top][cellname_top], memory_via[libname_top][cellname_top])
    root_rect       = TreeNode(rect_top)
    _traverse_tree!(root_cell, root_rect)
    return root_rect
end

function get_transformed_MData_v2(originMetal::MData, data::CellData)
    # instname            = data.instname
    # Mname               = data.Mname
    Mtransform          = data.Mtransform

    newMData            = deepcopy(originMetal)
    for (_layerNum, _layer) in newMData.layers
        for _metal in _layer.metals
            # Determine transformed coordinates
            _metal.xy = affine_transform(_metal.xy, Mtransform)
        end
    end
    return newMData
end

function get_transformed_VData_v2(originVia::VData, data::CellData)
    Mtransform          = data.Mtransform
    newVData            = deepcopy(originVia)
    for (vcellname, vlist) in newVData.vlists
        for via in vlist.vias
            # Determine transformed coordinates
            via.xy = affine_transform(via.xy, Mtransform)
        end
    end
    return newVData
end

function get_transformed_LData_v2(originlabel::LData, data::CellData, equivalent_net_sets::Vector)
    net_mapper          = data.net_extern
    instname            = data.instname
    Mname               = data.Mname
    Mtransform          = data.Mtransform

    newLData            = deepcopy(originlabel)
    newLData.instname   = instname
    for (_layerNum, _layer) in newLData.layers
        for _label in _layer.labels
            # Determine transformed coordinates
            _label.xy = affine_transform(_label.xy, Mtransform)
            _netname        = "UNKNOWN"
            if haskey(net_mapper, _label.netname_origin)
                _label.netname    = net_mapper[_label.netname_origin]
                continue
            end
            for net_set in equivalent_net_sets
                if _label.netname_origin in net_set
                    _eqnet = first(intersect(net_set, keys(net_mapper)))
                    _netname    = net_mapper[_eqnet]
                    break
                end
            end
            if _netname == "UNKNOWN"
                _netname    = Mname * "__" * _label.netname_origin
            end
            _label.netname  = _netname
        end
    end
    return newLData
end

end #endif


# -------------- OUTDATED -------------------------

# # 재귀적으로 Tree를 순회하며 각 Cell type 별 merged_metal_dict 생성
# function flatten(rootNode::TreeNode{CellData}, cell_data::Dict, metal_dir::String, via_dir::String, db_json_data::Dict, config_data::Dict)

#     memory_metal    = Dict()
#     memory_metal[rootNode.data.libname]     = Dict()
#     memory_via      = Dict()
#     memory_via[rootNode.data.libname]       = Dict()
#     # db_json_data = JSON.parse(read(db_path, String))
#     # config_data = get_config(config_path)

# function create_metal_dict_sub!(node::TreeNode{CellData}, memory_metal::Dict)
#     cellname = node.data.cellname
#     libname = node.data.libname

#     if !haskey(memory_metal, libname)
#         memory_metal[libname] = Dict()
#     end

#     # CASE 1: 이미 해당 cell이 memory에에 존재하는 경우 return
#     if haskey(memory_metal[libname], cellname)
#         println("FOUND METAL IN MEMORY: memory[$(libname)][$(cellname)]")
#         return

#     # CASE 2: cell이 memory에 없고 & leaf node인 경우
#     elseif node.children == []
#         # db에 있는 해당 cell의 metal을 merge해, memory에 저장
#         memory_metal[libname][cellname] = db_to_MData_test(db_json_data, libname, cellname, true)
#         println("CREATED METAL: memory[$(libname)][$(cellname)]")
    
#     # CASE 3: cell이 memory에 없고 & child node가 있는 경우
#     else
#         child_set = []
#         for child in node.children
#             if !(child.data.cellname in Set([child.data.cellname for child in child_set]))
#                 push!(child_set, child)
#             end
#         end
#         # 모든 child node의 종류가 metals.json이 존재하는지 확인
#         for child in child_set
#             _create_merged_metal_dict(child)
#         end

#         subcell_mdata_list = []

#         # Tree를 순회하며 각 Cell type에 따라 분류
#         nodes_dict = cluster_nodes_by_cellname(node, cell_data)

#         # 각 Cell type에 따라 metal_dict 저장 함수 호출
#         for lib in keys(nodes_dict)
#             for cell in keys(nodes_dict[lib])
#                 # Save metal data of submodules (이미 metals.json이 존재하는 것을 확인했으므로)
#                 push!(subcell_mdata_list, get_transformed_MData(nodes_dict[lib][cell], memory_metal[lib][cell]))
#             end
#         end
#         # Save metal data of top cell
#         top_mdata = get_top_MData(db_json_data[libname][cellname]["metals"], libname, cellname)

#         # metal_data = merge_sort_wo_BTree(metal_data_hor_list, metal_data_ver_list)
#         metal_data = sort_n_merge_MData(top_mdata, subcell_mdata_list...)
        
#         # save to memory
#         memory_metal[libname][cellname] = metal_data

#         # save to json
#         # MData_to_merged_json(metal_data, "$(metal_dir)/$(cellname)_metals.json")
#         println("CREATED METAL: memory[$(libname)][$(cellname)]")
#     end
# end

#     function _create_merged_metal_dict(node::TreeNode{CellData})

#         cellname = node.data.cellname
#         libname = node.data.libname

#         if !haskey(memory_metal, libname)
#             memory_metal[libname] = Dict()
#         end

#         # CASE 1: 이미 해당 cell이 memory에에 존재하는 경우 return
#         if haskey(memory_metal[libname], cellname)
#             println("FOUND METAL IN MEMORY: memory[$(libname)][$(cellname)]")
#             return

#         # CASE 2: cell이 memory에 없고 & leaf node인 경우
#         elseif node.children == []
#             # db에 있는 해당 cell의 metal을 merge해, memory에 저장
#             memory_metal[libname][cellname] = db_to_MData_test(db_json_data, libname, cellname, true)
#             println("CREATED METAL: memory[$(libname)][$(cellname)]")
        
#         # CASE 3: cell이 memory에 없고 & child node가 있는 경우
#         else
#             child_set = []
#             for child in node.children
#                 if !(child.data.cellname in Set([child.data.cellname for child in child_set]))
#                     push!(child_set, child)
#                 end
#             end
#             # 모든 child node의 종류가 metals.json이 존재하는지 확인
#             for child in child_set
#                 _create_merged_metal_dict(child)
#             end

#             subcell_mdata_list = []

#             # Tree를 순회하며 각 Cell type에 따라 분류
#             nodes_dict = cluster_nodes_by_cellname(node, cell_data)
    
#             # 각 Cell type에 따라 metal_dict 저장 함수 호출
#             for lib in keys(nodes_dict)
#                 for cell in keys(nodes_dict[lib])
#                     # Save metal data of submodules (이미 metals.json이 존재하는 것을 확인했으므로)
#                     push!(subcell_mdata_list, get_transformed_MData(nodes_dict[lib][cell], memory_metal[lib][cell]))
#                 end
#             end
#             # Save metal data of top cell
#             top_mdata = get_top_MData(db_json_data[libname][cellname]["metals"], libname, cellname)

#             # metal_data = merge_sort_wo_BTree(metal_data_hor_list, metal_data_ver_list)
#             metal_data = sort_n_merge_MData(top_mdata, subcell_mdata_list...)
            
#             # save to memory
#             memory_metal[libname][cellname] = metal_data

#             # save to json
#             # MData_to_merged_json(metal_data, "$(metal_dir)/$(cellname)_metals.json")
#             println("CREATED METAL: memory[$(libname)][$(cellname)]")
#         end
#     end


#     function _create_via_dict(node::TreeNode{CellData})

#         cellname = node.data.cellname
#         libname = node.data.libname

#         if !haskey(memory_via, libname)
#             memory_via[libname] = Dict()
#         end

#         # CASE 1: 이미 해당 cell이 memory에에 존재하는 경우 return
#         if haskey(memory_via[libname], cellname)
#             println("FOUND VIA IN MEMORY: memory[$(libname)][$(cellname)]")
#             return

#         # CASE 2: cell이 memory에 없고 & leaf node인 경우
#         elseif node.children == []
#             # db에 있는 해당 cell의 via로 VData 생성
#             memory_via[libname][cellname] = db_to_VData(libname, cellname, db_json_data[libname][cellname]["vias"], config_data, true)
#             println("CREATED VIA: memory[$(libname)][$(cellname)]")
        
#         # CASE 3: merged_metal_dict.json이 없고 & child node가 있는 경우
#         else
#             child_set = []
#             for child in node.children
#                 if !(child.data.cellname in Set([child.data.cellname for child in child_set]))
#                     push!(child_set, child)
#                 end
#             end
#             # 모든 child node의 종류가 merged_metal_dict가 존재하는지 확인
#             for child in child_set
#                 _create_via_dict(child)
#             end

#             subcell_vdata_list = []

#             # Tree를 순회하며 각 Cell type에 따라 분류
#             nodes_dict = cluster_nodes_by_cellname(node, cell_data)

#             # println("nodes_dict = ", nodes_dict)
#             # println("memory_via = ", memory_via)
    
#             # 각 Cell type에 따라 metal_dict 저장 함수 호출
#             for lib in keys(nodes_dict)
#                 for cell in keys(nodes_dict[lib])
#                     # Save metal data of submodules (이미 merged_metal_dict가 존재하는 것을 확인했으므로)
#                     push!(subcell_vdata_list, get_transformed_VData(nodes_dict[lib][cell], memory_via[lib][cell]))
#                 end
#             end
#             # Save metal data of top cell
#             top_vdata = get_top_VData(db_json_data[libname][cellname]["vias"], libname, cellname, config_data)

#             # metal_data = merge_sort_wo_BTree(metal_data_hor_list, metal_data_ver_list)
#             via_data = sort_VData(top_vdata, subcell_vdata_list...)
            
#             # save to memory
#             memory_via[libname][cellname] = via_data

#             # save to json
#             # VData_to_json(via_data, "$(via_dir)/$(cellname)_vias.json")
#             println("CREATED VIA: memory[$(libname)][$(cellname)]")
#         end
#     end

#     println("\nCreating metal_dict (merged)")
#     _create_merged_metal_dict(rootNode)

#     # MData_to_merged_json(memory_metal[rootNode.data.libname][rootNode.data.cellname], "$(metal_dir)/$(rootNode.data.cellname)_metals.json")
#     # println("JSON file created: $(metal_dir)/$(rootNode.data.cellname)_metals.json")

#     println("\nCreating via_dict")
#     _create_via_dict(rootNode)

#     # VData_to_json(memory_via[rootNode.data.libname][rootNode.data.cellname], "$(via_dir)/$(rootNode.data.cellname)_vias.json")
#     # println("JSON file created: $(via_dir)/$(rootNode.data.cellname)_vias.json")
#     return memory_metal, memory_via
# end

# 같은 cell들의 Metals Transform 후 MData로 변환
# function get_transformed_MData(nodes_list::Vector{Dict{String, Any}}, memory_metal_data::MData)

#     out_mdata = MData(memory_metal_data.libname, memory_metal_data.cellname, OrderedDict{Int, MLayer}())

#     for node in nodes_list
#         Mtransform = node["Mtransform"]

#         for (layer, metal_layer) in memory_metal_data.metals
#             # Determine if the metal layer is horizontal or vertical
#             is_horizontal = layer % 2 == 0

#             # Ensure the layer key exists
#             if !haskey(out_mdata.metals, layer)
#                 out_mdata.metals[layer] = MLayer(layer, OrderedDict{Int, MVectorList}())
#             end

#             for (main_coord, metal_vector_list) in metal_layer.metals
#                 for metal_vector in metal_vector_list.sub_coords
#                     # Determine transformed coordinates
#                     if is_horizontal  # Horizontal: main_coord = y, sub_coords = x
#                         x1, y1 = metal_vector.points[1].coord, main_coord
#                         x2, y2 = metal_vector.points[2].coord, main_coord
#                     else  # Vertical: main_coord = x, sub_coords = y
#                         x1, y1 = main_coord, metal_vector.points[1].coord
#                         x2, y2 = main_coord, metal_vector.points[2].coord
#                     end

#                     xy = get_metal_xy([[x1, y1], [x2, y2]], Mtransform)

#                     # Extract sorted coordinates
#                     m_coord, s_coord_1, s_coord_2 = is_horizontal ?
#                         (xy[1][2], min(xy[1][1], xy[2][1]), max(xy[1][1], xy[2][1])) :
#                         (xy[1][1], min(xy[1][2], xy[2][2]), max(xy[1][2], xy[2][2]))

#                     # Find existing MVectorList or create a new one
#                     if haskey(out_mdata.metals[layer].metals, m_coord)
#                         push!(out_mdata.metals[layer].metals[m_coord].sub_coords, MVector([MPoint(s_coord_1, START), MPoint(s_coord_2, END)]))
#                     else
#                         out_mdata.metals[layer].metals[m_coord] = MVectorList(m_coord, [MVector([MPoint(s_coord_1, START), MPoint(s_coord_2, END)])])
#                     end
#                 end
#             end
#         end
#     end
#     return out_mdata
# end

# function get_transformed_VData(nodes_list::Vector{Dict{String, Any}}, memory_via_data::VData)
    
#     out_vdata = VData(memory_via_data.libname, memory_via_data.cellname, OrderedDict{String, VList}())

#     for node in nodes_list
#         Mtransform = node["Mtransform"]

#         for (vtype, vlist) in memory_via_data.vlists
#             vpoints = Vector{VPoint}()
#             for vpoint in vlist.vpoints
#                 xy = get_via_xy(vpoint.xy, Mtransform)
#                 push!(vpoints, VPoint(xy, vpoint.extension, vpoint.layer, vpoint.type))
#             end
#             out_vdata.vlists[vtype] = VList(vtype, vpoints)
#         end
#     end
#     return out_vdata
# end

# function get_transformed_LData(originlabel::LData, data::CellData)
#     net_mapper          = data.net_extern
#     instname            = data.instname
#     Mname               = data.Mname
#     Mtransform          = data.Mtransform

#     newLData            = deepcopy(originlabel)
#     newLData.instname   = instname
#     for _label in newLData.labels
#         is_horizontal   = _label.layer % 2 == 0
#         main_coord      = _label.m_coord
#         # Determine transformed coordinates
#         if is_horizontal  # Horizontal: main_coord = y, sub_coords = x
#             x1, y1 = _label.xy[1], main_coord
#             x2, y2 = _label.xy[2], main_coord
#         else  # Vertical: main_coord = x, sub_coords = y
#             x1, y1 = main_coord, _label.xy[1]
#             x2, y2 = main_coord, _label.xy[2]
#         end

#         xy = get_metal_xy([[x1, y1], [x2, y2]], Mtransform)

#         # Extract sorted coordinates
#         m_coord, s_coord_1, s_coord_2 = is_horizontal ?
#             (xy[1][2], min(xy[1][1], xy[2][1]), max(xy[1][1], xy[2][1])) :
#             (xy[1][1], min(xy[1][2], xy[2][2]), max(xy[1][2], xy[2][2]))
#         _label.m_coord  = m_coord
#         _label.xy       = SVector{2, Int}(s_coord_1, s_coord_2)
#         _netname        = "UNKNOWN"
#         if haskey(net_mapper, _label.netname_origin)
#             _netname    = net_mapper[_label.netname_origin]
#         else
#             _netname    = Mname * "__" * _label.netname_origin
#         end
#         _label.netname  = _netname
#     end
#     return newLData
# end

# BTree의 top cell에 MData 추가
# function get_top_MData(db_metals::Vector{Any}, libname::String, cellname::String)

#     top_mdata = MData(libname, cellname, OrderedDict{Int, MLayer}())

#     for metal in db_metals
#         layer = metal_to_int(metal["layer"])
#         is_horizontal = layer % 2 == 0

#         # Ensure the layer key exists
#         if !haskey(top_mdata.metals, layer)
#             top_mdata.metals[layer] = MLayer(layer, OrderedDict{Int, MVectorList}())
#         end

#         # Extract coordinates and extensions
#         m_coord = metal["xy"][1][1 + is_horizontal]  # y for horizontal, x for vertical
#         extension_key = is_horizontal ? "hextension" : "vextension"
#         extension = get(metal, extension_key, 35)

#         s_coord_1, s_coord_2 = metal["xy"][1][2 - is_horizontal], metal["xy"][2][2 - is_horizontal]
#         s_coord_1, s_coord_2 = (min(s_coord_1, s_coord_2) - extension, max(s_coord_1, s_coord_2) + extension)

#         if haskey(top_mdata.metals[layer].metals, m_coord)
#             push!(top_mdata.metals[layer].metals[m_coord].sub_coords, MVector([MPoint(s_coord_1, START), MPoint(s_coord_2, END)]))
#         else
#             top_mdata.metals[layer].metals[m_coord] = MVectorList(m_coord, [MVector([MPoint(s_coord_1, START), MPoint(s_coord_2, END)])])
#         end
#     end
#     return top_mdata
# end

# function get_top_VData(db_vias::Vector{Any}, libname::String, cellname::String, config_data::Dict)
#     return db_to_VData(libname, cellname, db_vias, config_data, false)
# end
