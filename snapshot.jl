using JSON
using Dates


# target lib/cell/directory is configured via python

# ex) python input
# libname = "logic_generated"
# cellname = "inv"
# workdir = "D:/dev/dev_nifty/laygo_mcp"
# lvsdir = "D:/dev/dev_nifty/laygo_mcp/preLVS"
# config_path = "D:/dev/dev_nifty/laygo_mcp/preLVS/config/config_tsmcN28.yaml"

# variables
# db_dir = "D:/dev/dev_nifty/laygo_mcp/output/db/{libname}_generated_db.json"
# log_dir = "D:/dev/dev_nifty/laygo_mcp/output/out/log"
# outlogFilePath = "D:/dev/dev_nifty/laygo_mcp/output/out/log/$(libname)_$(cellname).txt"



# temp example
# libname = "logic_generated"
# cellname = "inv"
# workdir = "D:\\dev\\dev_nifty\\laygo_mcp"
# lvsdir = "D:\\dev\\dev_nifty\\laygo_mcp\\preLVS"
# config_file_path = "D:\\dev\\dev_nifty\\laygo_mcp\\preLVS\\config\\config_tsmcN28.yaml"



# Set variables
log_dir = joinpath(workdir, "output", "out", "log")
outlogFilePath = joinpath(log_dir, "$(libname)_$(cellname).txt")

# Check if directory exists
if !isdir(lvsdir)
    error("LVS directory $lvsdir does not exist")
end
if !isdir(log_dir)
    error("Log directory $log_dir does not exist")
end

# Include files
include(joinpath(lvsdir, "main_functions.jl")) # main functions ver2
include(joinpath(lvsdir, "structs", "connectivity.jl"))
include(joinpath(lvsdir, "utils", "log.jl"))
# include(joinpath(lvsdir, "utils", "visualize.jl"))
include(joinpath(lvsdir, "eval", "SliceMap.jl"))


# Load config data
config_data = get_config(config_file_path)
is_detailed = true
orientation_list = get_orientation_list(config_data)
equiv_net_sets = config_data["Equivalent_net_sets"]


# 2. Create tree structure from db
root, cell_data, db_data, top_netname_list = get_tree(libname, cellname, db_dir, equiv_net_sets)

# 3. Flatten target cell
mdata, vdata = flatten_v2(libname, cellname, cell_data, db_data, orientation_list, config_data, equiv_net_sets, is_detailed)

# 3-1. Check grid consistency
grid_error_log = Vector{String}()
is_grid_consistent = check_grid_consistency(libname, cellname, db_data, orientation_list, grid_error_log, is_detailed)

if !is_grid_consistent
    for error in grid_error_log
        println(error) 
    end

    txt_path = "$(log_dir)/$(libname)_$(cellname)_grid_error_log.txt"
    open(txt_path, "w") do f
        for error in grid_error_log
            write(f, error * "\n")
        end
    end
    error("Grid consistency check failed.\n Error : $(grid_error_log)")
end

# 4. Sort & Merge metals (vector merge)
merged_mdata, nmetals, short_error_data = sort_n_merge_MData(mdata)

# 5. Connect metals from via
cgraph = connect_metals_from_via(merged_mdata, vdata, nmetals)

# 6. Check & Report connections
cinfo, error_info, error_cnt = check_and_report_connections_bfs(cgraph, equiv_net_sets)

# 7. 각 struct를 Dict로 변환하는 도우미 함수들을 정의합니다.
function get_svector(v::SVector{2, MPoint})
    p1 = v[1].s_coord
    p2 = v[2].s_coord
    return [min(p1), max(p2)]
end
to_dict(o::LaygoOrigin) = Dict("name" => o.traceback)
# to_dict(p::MPoint) = Dict(
#     "s_coord" => p.s_coord,
#     "pos" => string(p.pos)
#     # "netname" => p.netname,
#     # "laygo_origin" => p.laygo_origin === nothing ? nothing : to_dict(p.laygo_origin)
# )
to_dict(v::MOVector) = Dict(
    "layer" => "M"*string(v.layer),
    "p_coord" => v.p_coord,
    # SVector를 일반 Vector{Dict}로 변환
    "s_vector" => get_svector(v.points),
    "netname" => v.netname,
    # Set을 일반 Vector{Dict}로 변환
    "laygo_origin_set" => v.laygo_origin_set === nothing ? nothing : [to_dict(o) for o in v.laygo_origin_set],
    "idx" => v.idx,
    # "is_visited" => v.is_visited
)
# VPoint struct의 정의를 알 수 없어, 필드가 xy와 layer라고 가정합니다.
# 실제 필드에 맞게 이 부분을 수정해야 할 수 있습니다.
to_dict(v::VPoint) = Dict("xy" => v.xy, "layer" => v.layer)

to_dict(ci::ComponentInfo) = Dict(
    "number" => ci.number,
    "nodes" => [to_dict(n) for n in ci.nodes], # Set -> Vector
    "vias" => [to_dict(v) for v in ci.vias],   # Set -> Vector
    "netname" => ci.netname,
    "laygo_origin_set" => [to_dict(o) for o in ci.laygo_origin_set], # Set -> Vector
    "is_consistent" => ci.is_consistent
)

# 8. ComponentInfo 리스트(cinfo)를 Dict의 리스트로 변환합니다.
output_data = map(to_dict, cinfo)

# 9. 최종적으로 변환된 Dict 리스트를 JSON 문자열로 변환하여 반환합니다.
#    이 문자열이 juliacall을 통해 파이썬으로 전달됩니다.
JSON.json(output_data)
