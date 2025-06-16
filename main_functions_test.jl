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
    # rootNode::TreeNode{NodeData},
    libname::String,
    cellname::String,
    cell_data::Dict,
    db_data::Dict,
    config_data::Dict,
    orientation_list::Vector{String},
    source_net_sets::Vector{Tuple{String,Set{String}}}
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
        unnamed_metals, named_metals = db_to_MData(lib, cell, db_data, orientation_list, source_net_sets)
        # println("Named Metals: $(named_metals.metals)")

        # VIAS
        vias = db_to_VData(lib, cell, db_data[lib][cell]["vias"], config_data, false)


        # Transform metals with MTransform & netname_dict
        for (idx, inst) in cell_data[lib][cell]
            Mtransform = inst["Mtransform"]
            net_mapper = inst["net_extern"]

            # For Transform + Netname update metals
            # println("Transforming Metals: $(cell) - $(idx)")
            transformed_MData = transform_MData(unnamed_metals, named_metals, Mtransform, net_mapper, orientation_list, source_net_sets)
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






# # 재귀적으로 Tree를 순회하며 각 Cell type 별 merged_metal_dict 생성
# function flatten(rootNode::TreeNode{NodeData}, cell_data::Dict, metal_dir::String, via_dir::String, db_json_data::Dict, config_data::Dict)

#     memory_metal    = Dict()
#     memory_metal[rootNode.data.libname]     = Dict()
#     memory_via      = Dict()
#     memory_via[rootNode.data.libname]       = Dict()
#     # db_json_data = JSON.parse(read(db_path, String))
#     # config_data = get_config(config_path)

#     function _create_merged_metal_dict(node::TreeNode{NodeData})

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
#             println("nodes_dict = ", nodes_dict)
    
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


#     function _create_via_dict(node::TreeNode{NodeData})

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
#     # return memory_metal, memory_via
#     return memory_metal[rootNode.data.libname][rootNode.data.cellname], memory_via[rootNode.data.libname][rootNode.data.cellname]
# end

# # Requires Top label Data Node initialized -> see test_main.jl
# # TODO: top node declaration part in main_test.jl needed to be integrated into wrapper function
# function create_label_tree!(treeNode::TreeNode{NodeData}, current_node::TreeNode{LData{String}}, memory_label::Dict, db_json_data::Dict, config_data::Dict)
#     # # 아직 label fetch를 안한 경우 -> fetch
#     # if !haskey(memory_label[libname], cellname)
#     #     # db에 있는 해당 cell의 label로 LData 생성(initialize)
#     #     memory_label[libname][cellname] = db_to_LData(db_json_data,libname,cellname)
#     #     println("FETCH LABEL: memory[$(libname)][$(cellname)]")
#     # end

#     # newLData            = get_transformed_LData(memory_label[libname][cellname], treeNode.data)
#     # current_node.data   = newLData
#     # Children Instances
#     for child in treeNode.children
#         _data       = child.data
#         _cellname   = _data.cellname
#         _libname    = _data.libname
#         if !haskey(memory_label, _libname)
#             memory_label[_libname] = Dict()
#         end
#         if !haskey(memory_label[_libname], _cellname)
#             memory_label[_libname][_cellname] = db_to_LData(db_json_data,_libname,_cellname)
#             println("FETCH LABEL: memory[$(_libname)][$(_cellname)]")
#         end
#         # newLData    = get_transformed_LData(memory_label[libname][cellname], child.data)
#         newLData    = get_transformed_LData(memory_label[_libname][_cellname], child.data)
#         child_label = TreeNode(newLData)
#         add_child!(current_node, child_label)
#         create_label_tree!(child, child_label, memory_label, db_json_data, config_data)
#     end
# end










# # 같은 cell들의 Metals Transform 후 MData로 변환
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

# # TODO: debugging coordinate transformation
# function get_transformed_LData(originlabel::LData, data::NodeData)
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

# function get_top_VData(db_vias::Vector{Any}, libname::String, cellname::String, config_data::Dict)
#     return db_to_VData(libname, cellname, db_vias, config_data, false)
# end