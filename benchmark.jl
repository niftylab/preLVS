# Uncomment to Download necessary packages
# using Pkg
# Pkg.add("JSON")
# Pkg.add("JSON3")
# Pkg.add("YAML")
# Pkg.add("StaticArrays")
# Pkg.add("DataStructures")
# Pkg.add("OrderedCollections")
# Pkg.add("BenchmarkTools")

using BenchmarkTools
using JSON
include("utils/visualize.jl")
include("main_functions_test.jl") # main functions ver2
include("structs/connectivity.jl")
include("utils/log.jl")

# REPL 테스트 용으로 ARGS 없이 직접 변수를 넣어줌

# 0. Fetch input ARG
input_arg   = get_yaml("test_input.yaml")

# 1. Prepare JSON files and directories
libname     = input_arg["libname"]#"scan_generated"   # 라이브러리 이름
cellname    = input_arg["cellname"]#"scan_cell"  # cell 이름

db_dir = input_arg["db_dir"] #"db"
metal_dir = input_arg["metal_dir"] #"out/metal"
via_dir = input_arg["via_dir"] #"out/via"
visualized_dir = input_arg["visualized_dir"] #"out/visualized"
log_dir = input_arg["log_dir"] #"out/log"

config_file_path = input_arg["config_file_path"] #"config/config.yaml"

    # Check if database/config file exists
if !isfile("$(db_dir)/$(libname)_db.json")
    error("Database file '$(libname)_db.json' not found in $(db_dir)")
end
if !isfile(config_file_path)
    error("Config file not found at $config_file_path")
end

# Load db_json_data
# db_json_path   = "$(db_dir)/$(libname)_db.json"
# db_json_data   = JSON.parse(read(db_json_path, String))
config_data    = get_config(config_file_path)
orientation_list = get_orientation_list(config_data)

# # libname, cellname이 db_json_data에 있는지 확인
# if !haskey(db_json_data, libname)
#     error("Library name '$libname' not found in database at $db_json_path")
# elseif !haskey(db_json_data[libname], cellname)
#     error("Cell name '$cellname' not found in library '$libname' at $db_json_path")
# end

# =============================================
# 2. 각 단계별로 @benchmark
# =============================================

# 2.1. Tree 생성 함수 측정
println("-"^20)
println("Benchmark for creating tree:")
# equivalent_net_sets는 이후 flatten에서도 사용하기 위해 전역 변수로 유지
equivalent_net_sets = [("VDD", Set(["VDD", "vdd", "VDD:"])),
                         ("VSS", Set(["VSS", "VSS:", "vss"]))]
# get_tree 함수의 실행시간을 측정 및 반환 결과를 root와 cell_data에 저장

tree_benchmark = @benchmark get_tree($libname, $cellname, $db_dir, $equivalent_net_sets)
display(tree_benchmark)
println("-"^20)

root, cell_data, db_data = get_tree(libname, cellname, db_dir, equivalent_net_sets)


# 2.2. Flatten 함수 측정
println("-"^20)
println("Benchmark for flattening:")
# flatten_v2의 실행 시간 측정을 통해 mdata와 vdata를 받음
flatten_benchmark = @benchmark flatten_v2($libname, $cellname, $cell_data, $db_data, $config_data, $orientation_list, $equivalent_net_sets)
display(flatten_benchmark)
println("-"^20)

mdata, vdata = flatten_v2(libname, cellname, cell_data, db_data, config_data, orientation_list, equivalent_net_sets)

# 2.3. Merge (sort_n_merge_MData) 함수 측정
println("-"^20)
println("Benchmark for merging:")
merge_benchmark = @benchmark sort_n_merge_MData($mdata)
display(merge_benchmark)
println("-"^20)

merged_mdata, nmetals = sort_n_merge_MData(mdata)


# 2.4. Via와 연결되어 있는 MVector 탐색 후 connectivity graph 생성
println("-"^20)
println("Benchmark for connecting via -> metals:")
connect_via_benchmark = @benchmark connect_metals_from_via($merged_mdata, $vdata, $nmetals)
display(connect_via_benchmark)
println("-"^20)

cgraph = connect_metals_from_via(merged_mdata, vdata, nmetals)

# # 2.5. Connected sets 생성 함수 측정
# println("-"^20)
# println("Benchmark for checking connected sets:")
# check_connected_sets_benchmark = @benchmark check_connected_sets($djs)
# display(check_connected_sets_benchmark)
# println("-"^20)

# groups = check_connected_sets(djs)



function connectivity_benchmark(mdata::MData, vdata::VData)
    # Merge metals and vias
    merged_mdata, nmetals = sort_n_merge_MData(mdata)

    # Create connectivity sets
    cgraph = connect_metals_from_via(merged_mdata, vdata, nmetals)


    return nothing
end

println("-"^20)
println("Benchmark for connectivity:")
connectivity_benchmark_benchmark = @benchmark connectivity_benchmark($mdata, $vdata)
display(connectivity_benchmark_benchmark)
println("-"^20)




# OLD VERSION

# # 2.4. Vias 정렬 (sort_VData) 함수 측정
# println("-"^20)
# println("Benchmark for sorting vias:")
# sort_via_benchmark = @benchmark sort_VData($vdata)
# display(sort_via_benchmark)
# println("-"^20)

# sorted_vdata = sort_VData(vdata)


# # 2.5. Connected sets 생성 함수 측정
# println("-"^20)
# println("Benchmark for connecting nets:")
# connect_nets_benchmark = @benchmark create_connected_sets($merged_mdata, $sorted_vdata, $named_mvectors)
# display(connect_nets_benchmark)
# println("-"^20)


# connected_sets, merged_mdata = create_connected_sets(merged_mdata, sorted_vdata, named_mvectors)


# function merge_n_connect(mdata::MData, vdata::VData, named_mvectors::Vector{MVector})
#     # Merge metals and vias
#     merged_mdata, named_mvectors = sort_n_merge_MData(mdata)
#     vdata = sort_VData(vdata)

#     # Create connected sets
#     connected_sets, merged_mdata = create_connected_sets(merged_mdata, vdata, named_mvectors)

#     return merged_mdata, connected_sets
# end


# println("-"^20)
# println("Benchmark for merging and connecting:")
# merge_connect_benchmark = @benchmark merge_n_connect($mdata, $vdata, $named_mvectors)
# display(merge_connect_benchmark)
# println("-"^20)




# =============================================
# 이후 필요한 추가 코드 및 시각화 작업을 수행
# visualize_metals_by_layer(merged_mdata.metals, orientation_list, "$(visualized_dir)/test_$(cellname)")
# visualize_metals(merged_mdata.metals, orientation_list, "$(visualized_dir)/test_$(cellname).png")
