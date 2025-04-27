if !isdefined(@__MODULE__, :_STRUCT_CONN_JL_)
    # 가드 상수를 현재 모듈 스코프에 직접 정의
    # @eval 없이 const를 직접 사용. 모듈의 top-level에서 include될 때 동작합니다.
    const _STRUCT_CONN_JL_ = true

using DataStructures

include("via.jl")
include("new_metal.jl")

# Create connected sets


# NEW VERSION
# Searches 2 mvectors that are connected by vias
# Creates DisjointSets of MVectors

function connect_metals_from_via(mdata::MData, vdata::VData)
    djs = DisjointSets{MVector}([mv for (layer, mlayer) in mdata.metals for (pcoord, mvlist) in mlayer.metals for mv in mvlist])

    for (vtype, vlist) in vdata.vlists
        for vp in vlist.vpoints
            overlapping_metals = find_overlapping_metals(vp, mdata)
            # original code
            # if length(overlapping_metals) != 2
            #     println("VPoint $vp has $(length(overlapping_metals)) overlapping metals")
            #     continue
            # end
            # mv1, mv2 = overlapping_metals
            # union!(djs, mv1, mv2)
            if length(overlapping_metals) == 2
                mv1, mv2 = overlapping_metals
                union!(djs, mv1, mv2)
            end
        end
    end
    return djs
end


function check_connected_sets(djs::DisjointSets{MVector})
    elements = keys(djs.intmap)                  # 모든 MVector 요소
    groups   = Dict{MVector, Set{MVector}}()     # 대표 원소 → 집합

    for x in elements
        rep = find_root(djs, x)                  # rep: MVector (대표 원소)
        push!( get!(groups, rep, Set{MVector}()), x )
    end

    new_groups = Dict{String, Set{MVector}}()
    for (rep, mvector_set) in groups
        netname = unique([ mv.netname for mv in mvector_set if mv.netname !== nothing ])
        if length(netname) > 1
            # println("Multiple netnames found in the same set: $netname")
        end
        new_groups[string(netname)] = mvector_set
    end


    return new_groups
end




##################################################################################
# OLD VERSION
# Creates connectivity nets by traversing Pin -> MVector -> VPoint -> MVector ... 
##################################################################################


function create_connected_sets(mdata::MData, vdata::VData, named_mvectors::Vector{MVector})

    connected_sets = Dict{String, Set{MVector}}()

    for nmv in named_mvectors
        # Get the netname from the MVector
        netname = nmv.netname

        # println("CUR: $nmv")

        # Check if the netname already exists in the connected_sets dictionary
        if !haskey(connected_sets, netname)
            connected_sets[netname] = Set{MVector}()
        end
        if nmv in connected_sets[netname]
            # println("MVector $nmv already exists in the set for netname $netname")
            continue
        end


        # Perform BFS to find all connected MVectors & VPoints
        q = Queue{Union{MVector, VPoint}}()
        enqueue!(q, nmv)

        while !isempty(q)
            current = dequeue!(q)
            if current in connected_sets[netname]
                # println("Already visited $current")
                continue
            end
            # println("CURRENT node = $current")

            
            if current isa MVector
                # Check for overlapping vias
                overlapping_vias = find_overlapping_vias(current, vdata)

                # println("overlapping vias = $overlapping_vias")
                
                # Enqueue each overlapping via
                foreach(vpoint -> enqueue!(q, vpoint), overlapping_vias)
                
                # 일단 metal만 저장
                push!(connected_sets[netname], current)

            elseif current isa VPoint
                # Check for overlapping metals
                overlapping_metals = find_overlapping_metals(current, mdata)

                # println("overlapping metals = $overlapping_metals")
                
                # Enqueue each overlapping metal
                foreach(mvector -> enqueue!(q, mvector), overlapping_metals)
            end
        end
    end


    return connected_sets, mdata
end



# O(logn)으로 검색 (n = number of vias in the layer&pcoord)
function find_overlapping_vias(mv::MVector, vdata::VData)

    layer = mv.layer
    is_vertical = layer % 2 == 1


    pcoord = mv.p_coord
    srange = (mv.points[1].s_coord, mv.points[2].s_coord) 

    overlapping_vias = Vector{VPoint}()

    search_type = get_search_via_type(layer)

    
    for ty in search_type
        if is_vertical  # pcoord = x
            if haskey(vdata.vxlists, ty) && haskey(vdata.vxlists[ty], pcoord)
                vlist = vdata.vxlists[ty][pcoord]


                low_idx = searchsortedfirst(vlist.vpoints, srange[1], by = x -> (isa(x, VPoint) ? x.xy[2] : x))
                for i in low_idx:length(vlist.vpoints)
                    vpoint = vlist.vpoints[i]
                    if vpoint.xy[2] > srange[2]
                        break
                    end
                    if vpoint.xy[2] >= mv.points[1].s_coord && vpoint.xy[2] <= mv.points[2].s_coord
                        if vpoint.netname !== nothing && vpoint.netname != mv.netname
                            # error("VPoint netname $vpoint.netname is not equal to MVector netname $mv.netname")
                            # println("VPoint netname $vpoint.netname is not equal to MVector netname $mv.netname")
                        end
                        push!(overlapping_vias, vpoint)
                        # update vpoint.netname
                        vpoint.netname = mv.netname
                    end
                end
            else
                continue
            end
        else    # pcoord = y
            if haskey(vdata.vylists, ty) && haskey(vdata.vylists[ty], pcoord)
                vlist = vdata.vylists[ty][pcoord]

                low_idx = searchsortedfirst(vlist.vpoints, srange[1], by = x -> (isa(x, VPoint) ? x.xy[1] : x))
                for i in low_idx:length(vlist.vpoints)
                    vpoint = vlist.vpoints[i]
                    if vpoint.xy[1] > srange[2]
                        break
                    end
                    if vpoint.xy[1] >= mv.points[1].s_coord && vpoint.xy[1] <= mv.points[2].s_coord
                        if vpoint.netname !== nothing && vpoint.netname != mv.netname
                            # error("VPoint netname $vpoint.netname is not equal to MVector netname $mv.netname")
                            # println("VPoint netname $vpoint.netname is not equal to MVector netname $mv.netname")
                        end
                        push!(overlapping_vias, vpoint)
                        # update vpoint.netname
                        # uncomment to update netnames in original VPoints
                        # vpoint.netname = mv.netname
                    end
                end
            else
                continue
            end
        end

    end
    return overlapping_vias
end



# O(logn)으로 검색 (n = number of metals in the layer&pcoord)
function find_overlapping_metals(vpoint::VPoint, mdata::MData)
    
    overlapping_metals = Vector{MVector}()
    
    layers = get_layer_from_via_type(vpoint.type)
    
    for layer in layers
        is_vertical = layer % 2 == 1
        pcoord = is_vertical ? vpoint.xy[1] : vpoint.xy[2]
        scoord = is_vertical ? vpoint.xy[2] : vpoint.xy[1]
        
        
        if haskey(mdata.metals, layer) && haskey(mdata.metals[layer].metals, pcoord)
            mvlist = mdata.metals[layer].metals[pcoord]
        else
            continue
        end
            
        idx = searchsortedfirst(mvlist, scoord, by = x -> (isa(x, MVector) ? x.points[1].s_coord : x)) - 1
        if idx >= 1 && idx <= length(mvlist) && mvlist[idx].points[2].s_coord >= scoord && mvlist[idx].points[1].s_coord <= scoord
            mv = mvlist[idx]
            if mv.netname !== nothing && mv.netname != vpoint.netname
                # error("VPoint netname $vpoint.netname is not equal to MVector netname $mv.netname")
                # println("VPoint netname $vpoint.netname is not equal to MVector netname $mv.netname")
            end
            push!(overlapping_metals, mv)
            # update mv.netname
            # uncomment to update netnames in original MVectors
            # mv.netname = vpoint.netname
            # mv.points[1].netname = vpoint.netname
            # mv.points[2].netname = vpoint.netname
        end
    end
    
    return overlapping_metals
end


# 검색해야 하는 via type을 반환
# ex) layer = 1 -> ["via_M1_M2_0", "via_M1_M2_1"]
# ex) layer = 2 -> ["via_M1_M2_0", "via_M1_M2_1", "via_M2_M3_0", "via_M2_M3_1"]
function get_search_via_type(layer::Int)
    type_list = ["via_M$(layer)_M$(layer+1)_0", "via_M$(layer)_M$(layer+1)_1"]

    if layer > 1
        push!(type_list, "via_M$(layer-1)_M$(layer)_0")
        push!(type_list, "via_M$(layer-1)_M$(layer)_1")
    end
    return type_list
end

function get_layer_from_via_type(via_type::String)
    # Extract the layer numbers from the via type string
    # Example: "via_M1_M2_0" -> (1, 2)
    m = match(r"via_M(\d+)_M(\d+)_\d+", via_type)
    if m !== nothing
        layer1 = parse(Int, m.captures[1])
        layer2 = parse(Int, m.captures[2])
        return (layer1, layer2)
    else
        error("Invalid via type format: $via_type")
    end
end

end #endif


