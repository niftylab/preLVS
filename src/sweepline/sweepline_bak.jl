if !isdefined(@__MODULE__, :_SWEEPLINE_SWEEPLINE_JL_)
    # 가드 상수를 현재 모듈 스코프에 직접 정의
    # @eval 없이 const를 직접 사용. 모듈의 top-level에서 include될 때 동작합니다.
    const _SWEEPLINE_SWEEPLINE_JL_ = true

using DataStructures
using IntervalTrees
include("../structs/tree.jl")
include("../structs/rect.jl")
include("../structs/event.jl")
include("../utils/yaml.jl")


function traverse_rect_tree!(events::Vector{Event}, hash_rect::Vector{Rect}, node_cell::TreeNode{CellData}, node_rect::TreeNode{RectData}, config_data::Dict)
    events_metal    = get_events!(hash_rect, node_cell, node_rect.data.metal_data)
    events_label    = get_events!(hash_rect, node_cell, node_rect.data.label_data)
    events_via      = get_events!(hash_rect, node_cell, node_rect.data.via_data, config_data)
    append!(events, events_metal); append!(events, events_label); append!(events, events_via);
    if length(node_cell.children) != length(node_rect.children)
        len1 = length(node_cell.children); len2 = length(node_rect.children)
        println("Error! Cell and Rect Node have different number of children: $len1, $len2")
        exit(-1)
    end
    for (child_cell, child_rect) in zip(node_cell.children, node_rect.children)
        traverse_rect_tree!(events, hash_rect, child_cell, child_rect, config_data)
    end     
end

function create_events(root_cell::TreeNode{CellData}, root_rect::TreeNode{RectData}, config_data::Dict)
    events      = Vector{Event}()
    hash_rect   = Vector{Rect}()
#    elapsed_time_initializing = @belapsed begin
    traverse_rect_tree!(events, hash_rect, root_cell, root_rect, config_data)
#    end
    # println("-"^20)
    # println("elapsed time for initializing: ",elapsed_time_initializing)
    # println("-"^20)
#    elapsed_time_sorting = @belapsed begin
    events_sorted = deepcopy(events)
    sort!(events_sorted, by=event_sort_priority)
#    end
    # println("-"^20)
    # println("elapsed time for sorting: ",elapsed_time_sorting)
    # println("-"^20)
    return events, events_sorted, hash_rect
end

function get_events!(hash_rect::Vector{Rect}, cnode::TreeNode{CellData}, mdata::MData)
    events = Vector{Event}()
    for (layerNum, layer) in mdata.layers
        for metal in layer.metals
            _idx     = length(hash_rect) + 1
            xy_start = SVector{2, Int}(minimum(metal.xy[:,1]), minimum(metal.xy[:,2]))
            xy_end   = SVector{2, Int}(maximum(metal.xy[:,1]), maximum(metal.xy[:,2]))
            _range   = SVector{2, Int}(xy_start[2], xy_end[2])
            _start   = Event(METAL, START, layerNum, xy_start, _range, _idx, cnode)
            _end     = Event(METAL, END, layerNum, xy_end, _range, _idx, cnode)
            push!(events, _start); push!(events, _end)
            push!(hash_rect, metal)
        end
    end
    return events
end

function get_events!(hash_rect::Vector{Rect}, cnode::TreeNode{CellData}, ldata::LData)
    events = Vector{Event}()
    for (layerNum, layer) in ldata.layers
        for label in layer.labels
            _idx     = length(hash_rect) + 1
            xy_start = SVector{2, Int}(minimum(label.xy[:,1]), minimum(label.xy[:,2]))
            xy_end   = SVector{2, Int}(maximum(label.xy[:,1]), maximum(label.xy[:,2]))
            _range   = SVector{2, Int}(xy_start[2], xy_end[2])
            _start   = Event(LABEL, START, layerNum, xy_start, _range, _idx, cnode)
            _end     = Event(LABEL, END, layerNum, xy_end, _range, _idx, cnode)
            push!(events, _start); push!(events, _end)
            push!(hash_rect, label)
        end
    end
    return events
end

function get_events!(hash_rect::Vector{Rect}, cnode::TreeNode{CellData}, vdata::VData, config_data::Dict)
    events = Vector{Event}()
    for (vcellname, vlist) in vdata.vlists
        hextension   = config_data["Via"][vcellname]["extension"][1]
        vextension   = config_data["Via"][vcellname]["extension"][2]
        for via in vlist.vias
            _idx     = length(hash_rect) + 1
            layerNum = via.layer[1]
            xy_start = SVector{2, Int}(via.xy[1] - hextension, via.xy[2] - vextension)
            xy_end   = SVector{2, Int}(via.xy[1] + hextension, via.xy[2] + vextension)
            _range   = SVector{2, Int}(xy_start[2], xy_end[2])
            _start   = Event(VIA, START, layerNum, xy_start, _range, _idx, cnode)
            _end     = Event(VIA, END, layerNum, xy_end, _range, _idx, cnode)
            push!(events, _start); push!(events, _end)
            push!(hash_rect, via)
        end
    end
    return events
end

function collect_sets(s::IntDisjointSets{T}) where T<:Integer
    # 루트를 키로, 멤버 리스트를 값으로 가지는 딕셔너리 생성
    groups = Dict{T, Vector{T}}()
    
    # 모든 원소에 대해 반복 (1부터 length(s)까지)
    for i in Base.OneTo(T(length(s)))
        # 각 원소의 루트를 찾음 (경로 압축이 일어날 수 있음)
        root = find_root!(s, i)
        
        # 해당 루트가 딕셔너리에 키로 존재하지 않으면 새로운 리스트 생성
        if !haskey(groups, root)
            groups[root] = Vector{T}()
        end
        
        # 해당 루트의 리스트에 현재 원소를 추가
        push!(groups[root], i)
    end
    
    return groups
end

function process_events(sorted_events::Vector{Event}, rect_hash::Vector{Rect})
    # K=Int, Val=String, B=64
    layerNum  = 5
    itrees    = Dict{Int, IntervalTree{Int, Interval{Int}}}() # 트리는 간격 자체를 저장
    imaps     = Dict{Int, Dict{Tuple{Int, Int}, Set{Int}}}()
    djs       = IntDisjointSets(length(rect_hash))
    djs_temp  = IntDisjointSets(length(rect_hash))
    via_link  = Dict{Int, Tuple{Int, Int}}()
    error_log = Vector{ErrorEvent}()
    for i in 1:layerNum # Rect Layer
        imaps[i] = Dict{Tuple{Int, Int}, Set{Int}}()
    end
    for i in 1:(layerNum-1) # VIA Layer
        imaps[layerNum+i] = Dict{Tuple{Int, Int}, Set{Int}}()
    end
    for i in 1:layerNum # Rect Layer
        itrees[i] = IntervalTree{Int, Interval{Int}}()
    end
    for i in 1:(layerNum-1) # VIA Layer
        itrees[layerNum+i] = IntervalTree{Int, Interval{Int}}()
    end
    
    for event_data in sorted_events
        range_interval  = (event_data.range[1], event_data.range[2])
        event_idx       = event_data.idx
        if event_data.etype == VIA
            layer1 = event_data.layer; layer2 = event_data.layer+1; vialayer = layerNum + layer1
            overlap_idx1 = -1; overlap_idx2 = -1
            if event_data.position == START
                # check intersecting metals
                overlap_idx1 = -1; overlap_idx1 = -1;

                # layer1에서 겹치는 metal이 있는지 확인
                if haskey(imaps[layer1], range_interval) # matched interval exist in layer1 tree
                    # get index of one of activated rect
                    for _idx in imaps[layer1][range_interval]
                        if typeof(rect_hash[_idx]) == MRect
                            overlap_idx1 = _idx
                            break
                        end
                    end
                    # overlap_idx1 = first(imaps[layer1][range_interval])
                else # check overlap in intervalTree[layer1]
                    overlap_iter = intersect(itrees[layer1], range_interval)
                    for _iter in overlap_iter
                        _range = (_iter.first, _iter.last)
                        for _idx in imaps[layer1][_range]
                            if typeof(rect_hash[_idx]) == MRect
                                overlap_idx1 = _idx
                                break
                            end
                        end
                        if overlap_idx1 !== -1
                            break
                        end
                    end
                    # if !isempty(overlap_iter)# overlap exist
                    #     first_overlap   = iterate(overlap_iter)
                    #     range_overlap   = (first_overlap[1].first, first_overlap[1].last)
                    #     # get index of one of activated rect
                    #     overlap_idx1    = first(imaps[layer1][range_overlap])
                    # end
                end

                # layer2에서 겹치는 metal이 있는지 확인
                if haskey(imaps[layer2], range_interval) # matched interval exist in tree
                    # get index of one of activated rect
                    # overlap_idx2 = first(imaps[layer2][range_interval])
                    for _idx in imaps[layer2][range_interval]
                        if typeof(rect_hash[_idx]) == MRect
                            overlap_idx2 = _idx
                            break
                        end
                    end                    
                else # check overlap in intervalTree
                    overlap_iter = intersect(itrees[layer2], range_interval)
                    for _iter in overlap_iter
                        _range = (_iter.first, _iter.last)
                        for _idx in imaps[layer2][_range]
                            if typeof(rect_hash[_idx]) == MRect
                                overlap_idx2 = _idx
                                break
                            end
                        end
                        if overlap_idx2 !== -1
                            break
                        end
                    end
                    # first_overlap = iterate(overlap_iter)
                    # if first_overlap !== nothing # overlap exist
                    #     range_overlap   = (first_overlap[1].first, first_overlap[1].last)
                    #     # get index of one of activated rect
                    #     overlap_idx2    = first(imaps[layer2][range_overlap])
                    # end
                end
                if overlap_idx1 == -1 && overlap_idx2 == -1
                    _xy = hash_rect[event_data.idx].xy
                    push!(error_log,ErrorEvent(VIA, event_idx, -1)) # complete floating VIA
                #    println("Error: Floating VIA at (M$(layer1) M$(layer2)) -> (M$(layer1) M$(layer2)) ($(_xy))")
                elseif overlap_idx1 == -1
                    _xy = hash_rect[event_data.idx].xy
                    push!(error_log,ErrorEvent(VIA, event_idx, overlap_idx2)) # floating VIA overlapped on rect_hash[overlap_idx2]
                #    println("Error: Floating VIA at (M$(layer1) M$(layer2)) -> (M$(layer1)) ($(_xy))")
                elseif overlap_idx2 == -1
                    _xy = hash_rect[event_data.idx].xy
                    push!(error_log,ErrorEvent(VIA, event_idx, overlap_idx1)) # floating VIA overlapped on rect_hash[overlap_idx1]
                #    println("Error: Floating VIA at (M$(layer1) M$(layer2)) -> (M$(layer2)) ($(_xy))")
                else # normal case -> mapping two intersecting metals through VIA
                    via_link[event_idx] = (overlap_idx1, overlap_idx2)
                    # djs_temp(cross-layer union for DEBUG)
                    union!(djs_temp, overlap_idx1, overlap_idx2)
                    _root = find_root!(djs_temp, overlap_idx1)
                    union!(djs_temp, _root, event_idx)
                end
                # push VIA into interval tree
                if haskey(imaps[vialayer], range_interval) # case1: same range VIA Found
                    # just put event_idx into the set that has the active via
                    idx_active_via = first(imaps[vialayer][range_interval])
                    union!(djs, idx_active_via, event_idx)
                    union!(djs_temp, idx_active_via, event_idx) # (cross-layer union for DEBUG)
                    push!(imaps[vialayer][range_interval], event_idx)
                elseif !isempty(intersect(itrees[vialayer], range_interval)) # case2: intersecting VIA Found
                    overlap_iter_via = intersect(itrees[vialayer], range_interval)
                    first_overlap = iterate(overlap_iter_via)
                    _range = (first_overlap[1].first, first_overlap[1].last)
                    _idx = first(imaps[vialayer][_range])
                    union!(djs, _idx, event_idx)
                    union!(djs_temp, _idx, event_idx) # (cross-layer union for DEBUG)
                    # push node to tree and record in the map
                    push!(itrees[vialayer], Interval{Int}(range_interval[1], range_interval[2]))
                    imaps[vialayer][range_interval] = Set{Int}(event_idx)
                else # case3: no intersecting VIA -> No grouping, Simple push into intervalTree
                    # push node to tree and record in the map
                    push!(itrees[vialayer], Interval{Int}(range_interval[1], range_interval[2]))
                    imaps[vialayer][range_interval] = Set{Int}(event_idx)
                    # check if it intersects two metals and 
                end
            else # Pop VIA 
                if haskey(imaps[vialayer], range_interval)
                    pop!(imaps[vialayer][range_interval], event_idx)
                    if isempty(imaps[vialayer][range_interval]) # no other rect with the identical range -> delete node
                        delete!(imaps[vialayer], range_interval)
                        IntervalTrees.deletefirst!(itrees[vialayer], range_interval)
                    end
                else # no matched one -> error!
                    println("Error! no matched VIA (idx:$(event_idx))")
                end
            end
        else # event_data.etype == METAL and LABEL
            # METAL and LABEL의 경우.

            layer = event_data.layer
            # 1. START 인 경우
            if event_data.position == START
                    # overlap check layer1
                if haskey(imaps[layer], range_interval) # case1: same range Rect Found
                    # just put event_idx into the set that has the active via
                    idx_active = first(imaps[layer][range_interval])
                    union!(djs, idx_active, event_idx)
                    union!(djs_temp, idx_active, event_idx) # (cross-layer union for DEBUG)
                    push!(imaps[layer][range_interval], event_idx)
                else # case2: searching Interval TREE
                    overlap_iter    = intersect(itrees[layer], range_interval)
                    first_overlap   = iterate(overlap_iter) 
                    # Note: iterate(overlap iterator) returns Tuple{Interval, value(nothing)}
                    if first_overlap !== nothing # overlap FOUND -> union
                        _range = (first_overlap[1].first, first_overlap[1].last)
                        _idx = first(imaps[layer][_range])
                        union!(djs, _idx, event_idx)
                        union!(djs_temp, _idx, event_idx) # (cross-layer union for DEBUG)
                    end
                    # push node to tree and record in the map
            #        println("[DEBUG]: range_interval of Rect idx $(event_idx) is $(range_interval)")
                    push!(itrees[layer], Interval{Int}(range_interval[1], range_interval[2]))
                    imaps[layer][range_interval] = Set{Int}(event_idx)
                end
            else # position == END
                if haskey(imaps[layer], range_interval)
                    pop!(imaps[layer][range_interval], event_idx)
                    if isempty(imaps[layer][range_interval])
                        delete!(imaps[layer], range_interval)
                        IntervalTrees.deletefirst!(itrees[layer], range_interval)
                    end
                else
                    println("Error! no matched RECT (idx:$(event_idx))")
                end
            end
        end
    end 
    overlaps = collect_sets(djs)
    nets     = collect_sets(djs_temp)
    return djs, overlaps, via_link, error_log, nets
end

end #endif