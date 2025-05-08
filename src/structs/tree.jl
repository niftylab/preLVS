if !isdefined(@__MODULE__, :_STRUCT_TREE_JL_)
    # 가드 상수를 현재 모듈 스코프에 직접 정의
    # @eval 없이 const를 직접 사용. 모듈의 top-level에서 include될 때 동작합니다.
    const _STRUCT_TREE_JL_ = true

using DataStructures

# cell들간의 hierarchy를 나타내기 위한 tree 구조
# NodeData: cell의 정보를 담는 struct
# TreeNode: tree의 node를 나타내는 struct
# Tree의 기본적인 구조는 다음과 같다.
# Top_cell
# ├── Sub_cell1
# │   ├── Sub_sub_cell1
# │   └── Sub_sub_cell2
# └── Sub_cell2
#     ├── Sub_sub_cell3
#     └── Sub_sub_cell4

struct NodeData
    libname::String
    cellname::String
    instname::String
    Mname::String
    Mtransform::Matrix{Int}
    net_extern::Dict{String, String}
    width::Int
    height::Int
    idx::Int
end

function NodeData(
    ; libname::String,
      cellname::String,
      instname::String,
      Mname::String,
      Mtransform::Matrix{Int},
      net_extern::Dict{String, String},
      width::Int,
      height::Int,
      idx::Int
)
    return NodeData(libname, cellname, instname, Mname, Mtransform, net_extern, width, height, idx)
end

struct TreeNode{T}
    data::T
    children::Vector{TreeNode{T}}
end

function TreeNode(data::T) where T
    TreeNode(data, TreeNode{T}[])
end

function add_child!(parent::TreeNode, child::TreeNode)
    push!(parent.children, child)
end

# TreeNode를 iterate하기 위한 Base.iterate 구현
function Base.iterate(tree::TreeNode{T}) where T
    stack = [tree]  # Initialize stack with the root node
    _iterate(stack) # Begin iteration with the stack
end

function Base.iterate(::TreeNode{T}, stack) where T
    _iterate(stack) # Continue iteration with the current stack
end

# Helper function to manage stack traversal
function _iterate(stack)
    isempty(stack) && return nothing  # Stop iteration if stack is empty
    node = pop!(stack)               # Pop the top node from the stack
    append!(stack, reverse(node.children))  # Push children in reverse order for left-to-right traversal
    return node, stack               # Return current node and updated stack
end



function print_tree(node::TreeNode; prefix::String="", is_last_child::Bool=true)
    """
    Prints out the tree in a hierarchical style, using prefixes like `|- ` and so on.
    """
    # Decide which branch symbol to use
    branch_symbol = is_last_child ? "└─ " : "├─ "

    # Print this node
    println(prefix * branch_symbol * node_to_str(node))

    # The prefix for children depends on whether this node is the last child.
    # If it's the last child, use spaces; otherwise, use a vertical bar.
    child_prefix = prefix * (is_last_child ? "   " : "│  ")

    # Recursively print children
    n = length(node.children)
    for (i, child) in enumerate(node.children)
        print_tree(child;
            prefix=child_prefix,
            is_last_child=i == n  # This child is last if we are at the last in the list
        )
    end
end

function node_to_str(node::TreeNode)
    # Helper function to convert node's data to a string
    return "$(node.data.cellname) $(node.data.idx) $(node.data.Mtransform) $(node.data.net_extern)"
end

function print_tree_root(node::TreeNode)
    println("Tree for $(node.data.cellname):")
    print_tree(node)
    println()
end


function unify_netname(netname::String, equivalent_net_sets::Vector{Tuple{String, Set{String}}})
    for (rep, net_set) in equivalent_net_sets
        if netname in net_set
            return rep
        end
    end

    return netname
end


##############################################################################
# Functions for creating the tree structure
#############################################################################


# db_dir에서 libname과 cellname에 해당하는 cell의 정보를 가져오는 함수
function get_lib_cell_db(libname::String, cellname::String, db_dir::String, memory_db::Dict)

    if haskey(memory_db, libname) && haskey(memory_db[libname], cellname)
        return
    end

    db_json_path = "$(db_dir)/$(libname)_db.json"
    if !isfile(db_json_path)
        error("Database file '$(libname)_db.json' not found in $(db_dir)")
        exit(1)
    end
    db_json_data = JSON.parse(read(db_json_path, String))
    if !haskey(db_json_data, libname)
        error("Library name '$libname' not found in database at $db_json_path")
        exit(1)
    elseif !haskey(db_json_data[libname], cellname)
        error("Cell name '$cellname' not found in library '$libname' at $db_json_path")
        exit(1)
    end

    # Save the loaded data to memory_db for future use
    memory_db[libname] = db_json_data[libname]
    return
end



function get_tree_sub!(node::TreeNode{NodeData}, cell_data::Dict, db_dir::String, db_data::Dict, source_net_sets::Vector{Tuple{String, Set{String}}}, idx::Int)
    libname = node.data.libname
    cellname = node.data.cellname

    get_lib_cell_db(libname, cellname, db_dir, db_data)
    inst = db_data[libname][cellname]

    if haskey(inst, "subblocks")
        sub_blocks = inst["subblocks"]
        for block in sub_blocks
            libname = node.data.libname
            cellname = node.data.cellname

            _libname     = block["libname"]
            _cellname    = block["cellname"]

            # Get the cell data from the database JSON
            if haskey(db_data, _libname)
                if !haskey(db_data[_libname], _cellname)
                    error("Cell name '$_cellname' not found in library '$_libname' at $db_dir")
                end
            else
                get_lib_cell_db(_libname, _cellname, db_dir, db_data)
            end

            _name        = block["name"]
            # println("Subblock: $_libname - $_cellname - $_name")
            _w = db_data[_libname][_cellname]["bbox"][2][1] - db_data[_libname][_cellname]["bbox"][1][1]
            _h = db_data[_libname][_cellname]["bbox"][2][2] - db_data[_libname][_cellname]["bbox"][1][2]

            # affine transformation
            _trans      = block["transform"]
            _move       = Int.(block["xy"])
            affine      = affineMat(_trans, _move)
            # println("For $cellname - $idx: $affine")
            # println("node.data.Mtransform: $(node.data.Mtransform)")
            transform   = node.data.Mtransform * affine
            # println("Transform: $transform")

            # Primitives are added in primitives field
            if occursin("_microtemplates_", _libname)
                continue
            end
            
            net_block = Dict{String, String}()
            if haskey(block, "pins")
                pins = block["pins"]
                net_block = Dict{String, String}()
                for pin in pins
                    _pin = pin.second
                    _netname = get(_pin, "netname", nothing)
                    _netname = _netname === nothing ? "UNKNOWN" : unify_netname(_netname, source_net_sets)     # "netname": null인 경우 해결
                    _termname = unify_netname(_pin["termname"], source_net_sets)
                    
                    if haskey(node.data.net_extern, _netname)
                        net_block[_termname] = node.data.net_extern[_netname]
                    else
                        net_block[_termname] = node.data.Mname * "__" * _name * "__" * _netname
                        node.data.net_extern[_netname] = node.data.Mname * "__" * _name * "__" * _netname
                    end
                end
            end
            if haskey(db_data[_libname][_cellname], "labels")
                labels = db_data[_libname][_cellname]["labels"]
                for label in labels
                    _netname = get(label, "netname", nothing)
                    _netname = _netname === nothing ? "UNKNOWN" : unify_netname(_netname, source_net_sets)     # "netname": null인 경우 해결
                    if !haskey(net_block, _netname)
                        if haskey(node.data.net_extern, _netname)
                            net_block[_netname] = node.data.net_extern[_netname]
                        else
                            net_block[_netname] = node.data.Mname * "__" * _name * "__" * _netname
                            node.data.net_extern[node.data.Mname * "__" * _name * "__" * _netname] = node.data.Mname * "__" * _name * "__" * _netname
                        end
                    end
                end
            end

            child = TreeNode(
                NodeData(
                    libname     = _libname,
                    cellname    = _cellname,
                    instname    = _name,
                    Mname       = node.data.Mname * "__" * _name,
                    Mtransform  = transform,
                    net_extern  = net_block,
                    width       = _w,
                    height      = _h,
                    idx         = idx
                    )
            )

            # cell_data에 libname, cellname이 없으면 추가
            if haskey(cell_data, _libname)
                if !haskey(cell_data[_libname], _cellname)
                    cell_data[_libname][_cellname] = Dict{Int, Dict{String, Any}}()
                end
            else
                cell_data[_libname] = Dict()
                cell_data[_libname][_cellname] = Dict{Int, Dict{String, Any}}()
            end

            cell_data[_libname][_cellname][idx] = Dict{String, Any}(
                "libname"           => _libname,
                "cellname"          => _cellname,
                "instname"          => _name,
                "Mname"             => node.data.Mname * "__" * _name,
                "width"             => _w,
                "height"            => _h,
                "Mtransform"        => transform,
                "net_extern"        => net_block
            )
            idx += 1

            # println("ADDING CHILD: ", child.data.cellname, " ", child.data.idx)

            add_child!(node, child)
            idx = get_tree_sub!(child, cell_data, db_dir, db_data, source_net_sets, idx)
        end
    end
    return idx
end

function get_tree(libname::String, cellname::String, db_dir::String, source_net_sets::Vector{Tuple{String,Set{String}}})

    # Unique index for each node
    idx = 1

    # Initialize cell data with top cell node
    cell_data = Dict()
    cell_data[libname]              = Dict()
    cell_data[libname][cellname]    = Dict{Int, Dict{String, Any}}()

    db_data = Dict()
    get_lib_cell_db(libname, cellname, db_dir, db_data)
    inst_top = db_data[libname][cellname]

    # Top Cell의 net_extern에는 internal net들까지 포함하여 저장
    net_extern_top = Dict{String, String}()
    if haskey(inst_top, "pins")
        pins = inst_top["pins"]
        for _pin in pins
            _netname = get(_pin, "netname", nothing)
            _netname = _netname === nothing ? "UNKNOWN" : unify_netname(_netname, source_net_sets)     # "netname": null인 경우 해결
            net_extern_top[_netname] = _netname
        end
    end
    if haskey(inst_top, "labels")
        labels = inst_top["labels"]
        for label in labels
            _netname = get(label, "netname", nothing)
            _netname = _netname === nothing ? "UNKNOWN" : unify_netname(_netname, source_net_sets)     # "netname": null인 경우 해결
            net_extern_top[_netname] = _netname
        end
    end

    # Initialize top cell node
    rootNode = TreeNode(
        NodeData(
            libname     = libname,
            cellname    = cellname,
            instname    = cellname, # top instance name -> cellname (temporal decision)
            Mname       = cellname, 
            Mtransform  = [1 0 0; 0 1 0; 0 0 1],
            net_extern  = net_extern_top,
            width       = db_data[libname][cellname]["bbox"][2][1] - db_data[libname][cellname]["bbox"][1][1],
            height      = db_data[libname][cellname]["bbox"][2][2] - db_data[libname][cellname]["bbox"][1][2],
            idx         = idx
        )
    )
    cell_data[libname][cellname][idx] = Dict{String, Any}(
        "libname"           => libname,
        "cellname"          => cellname,
        "instname"          => cellname,
        "Mname"             => cellname,
        "width"             => db_data[libname][cellname]["bbox"][2][1] - db_data[libname][cellname]["bbox"][1][1],
        "height"            => db_data[libname][cellname]["bbox"][2][2] - db_data[libname][cellname]["bbox"][1][2],
        "Mtransform"        => [1 0 0; 0 1 0; 0 0 1],
        "net_extern"        => net_extern_top
    )
    idx += 1

    
    # Process top level subblocks separately
    if haskey(inst_top, "subblocks")
        sub_blocks_top = inst_top["subblocks"]
        for block in sub_blocks_top
            _libname    = block["libname"]
            _cellname   = block["cellname"]

            # Get the cell data from the database JSON
            if haskey(db_data, _libname)
                if !haskey(db_data[_libname], _cellname)
                    error("Cell name '$_cellname' not found in library '$_libname")
                end
            else
                get_lib_cell_db(_libname, _cellname, db_dir, db_data)
            end

            _name       = block["name"]
            _w = db_data[_libname][_cellname]["bbox"][2][1] - db_data[_libname][_cellname]["bbox"][1][1]
            _h = db_data[_libname][_cellname]["bbox"][2][2] - db_data[_libname][_cellname]["bbox"][1][2]

            # affine transformation
            _trans      = block["transform"]
            _move       = Int.(block["xy"])
            affine      = affineMat(_trans, _move)
            transform   = rootNode.data.Mtransform * affine
            # println("For $_cellname - $_name - $idx : w = $_w, h = $_h")
            # println("Trans: $transform, _move: $_move")
            # println("affine: $affine")
            # println("node.data.Mtransform: $(rootNode.data.Mtransform)")
            # println("Transform: $transform")


            net_block_top = Dict{String, String}() 
            if haskey(block, "pins")
                pins = block["pins"]
                for pin in pins
                    _pin = pin.second
                    _netname = get(_pin, "netname", nothing)
                    _netname = _netname === nothing ? "UNKNOWN" : unify_netname(_netname, source_net_sets)     # "netname": null인 경우 해결
                    _termname = unify_netname(_pin["termname"], source_net_sets)

                    if haskey(net_extern_top, _netname)
                        net_block_top[_termname] = net_extern_top[_netname]
                    else
                        net_block_top[_termname] = rootNode.data.Mname * "__" * _netname
                        rootNode.data.net_extern[_netname] = rootNode.data.Mname * "__" * _netname
                        cell_data[rootNode.data.libname][rootNode.data.cellname][rootNode.data.idx]["net_extern"][rootNode.data.Mname * "__" * _netname] = rootNode.data.Mname * "__" * _netname
                    end
                end
            end

            if haskey(db_data[_libname][_cellname], "labels")
                labels = db_data[_libname][_cellname]["labels"]
                for label in labels
                    _netname = get(label, "netname", nothing)
                    _netname = _netname === nothing ? "UNKNOWN" : unify_netname(_netname, source_net_sets)     # "netname": null인 경우 해결
                    if !haskey(net_block_top, _netname)
                        net_block_top[_netname] = rootNode.data.Mname * "__" * _name * "__" * _netname
                        rootNode.data.net_extern[rootNode.data.Mname * "__" * _name * "__" * _netname] = rootNode.data.Mname * "__" * _name * "__" * _netname
                        cell_data[rootNode.data.libname][rootNode.data.cellname][rootNode.data.idx]["net_extern"][rootNode.data.Mname * "__" * _name * "__" * _netname] = rootNode.data.Mname * "__" * _name * "__" * _netname
                    end
                end
            end
            
            
            # Create child node
            child_top = TreeNode(
                NodeData(
                    libname     = _libname,
                    cellname    = _cellname,
                    instname    = _name,
                    Mname       = rootNode.data.Mname * "__" * _name,
                    Mtransform  = transform,
                    net_extern  = net_block_top,
                    width       = _w,
                    height      = _h,
                    idx         = idx
                    )
            )

            # cell_data에 libname, cellname이 없으면 추가
            if haskey(cell_data, _libname)
                if !haskey(cell_data[_libname], _cellname)
                    cell_data[_libname][_cellname] = Dict{Int, Dict{String, Any}}()
                end
            else
                cell_data[_libname] = Dict()
                cell_data[_libname][_cellname] = Dict{Int, Dict{String, Any}}()
            end
                    
            # Add child node info to cell_data
            cell_data[_libname][_cellname][idx] = Dict{String, Any}(
                "libname"           => _libname,
                "cellname"          => _cellname,
                "instname"          => _name,
                "Mname"             => rootNode.data.Mname * "__" * _name,
                "width"             => _w,
                "height"            => _h,
                "Mtransform"        => transform,
                "net_extern"        => net_block_top
            )
            idx += 1
            
            add_child!(rootNode, child_top)
            idx = get_tree_sub!(child_top, cell_data, db_dir, db_data, source_net_sets, idx) # Start recursive tree generation from the children of the top node
        end
    end

    for lib in keys(cell_data)
        for cell in keys(cell_data[lib])
            if isempty(cell_data[lib][cell])
                delete!(cell_data[lib], cell)
            end
        end
    end

    return rootNode, cell_data, db_data
end


function build_task_list(
    node::TreeNode{NodeData},
    tasks::Vector{Tuple{String,String}} = Vector{Tuple{String,String}}(),
    visited::Set{Tuple{String,String}} = Set{Tuple{String,String}}()
)
    # Key to check if we've built this cell already:
    key = (node.data.libname, node.data.cellname)

    # If this node’s cell has already been added/built, skip it
    if key in visited
        return tasks
    end

    # Otherwise, process children first (post-order)
    for child in node.children
        build_task_list(child, tasks, visited)
    end

    # Then push the current node’s data
    push!(tasks, (node.data.libname, node.data.cellname))

    # Mark it as visited
    push!(visited, key)

    return tasks
end

end # endif

# function cluster_nodes_by_cellname(node::TreeNode, cell_data::Dict)
#     libname = node.data.libname
#     cellname = node.data.cellname

#     clusters = Dict{String, Any}()

#     if !haskey(cell_data, libname) || !haskey(cell_data[libname], cellname)
#         error("libname: $libname, cellname: $cellname not found in cell_data")
#     end

#     for (bottom_left_xy, block) in cell_data[libname][cellname]
#         if !haskey(clusters, block["libname"])
#             clusters[block["libname"]] = Dict{String, Vector{Dict{String, Any}}}()
#         end
#         if !haskey(clusters[block["libname"]], block["cellname"])
#             clusters[block["libname"]][block["cellname"]] = Vector{Dict{String, Any}}()
#         end
#         push!(clusters[block["libname"]][block["cellname"]], block)
#     end

#     return clusters
# end
