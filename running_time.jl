# Uncomment to Download necessary packages
# using Pkg
# Pkg.add("JSON")
# Pkg.add("JSON3")
# Pkg.add("YAML")
# Pkg.add("StaticArrays")
# Pkg.add("DataStructures")
# Pkg.add("OrderedCollections")
# Pkg.add("BenchmarkTools")

using BenchmarkTools  # @btime 사용을 위해 추가
using JSON
include("utils/visualize.jl")
include("main_functions_test.jl") # main functions ver2
include("structs/connectivity.jl")
include("utils/log.jl")

# REPL 테스트 용으로 ARGS 없이 직접 변수를 넣어줌

# 1. Prepare JSON files and directories
libname = "test_generated"   # 라이브러리 이름
cellname = "scan_cell"       # cell 이름

db_dir          = "db"
metal_dir       = "out/metal"
via_dir         = "out/via"
visualized_dir  = "out/visualized"

config_file_path = "config/config.yaml"

# Check if database/config file exists
if !isfile("$(db_dir)/$(libname)_db.json")
    error("Database file '$(libname)_db.json' not found in $(db_dir)")
end
if !isfile(config_file_path)
    error("Config file not found at $config_file_path")
end

# Load db_json_data
db_json_path   = "$(db_dir)/$(libname)_db.json"
db_json_data   = JSON.parse(read(db_json_path, String))
config_data    = get_config(config_file_path)
orientation_list = get_orientation_list(config_data)

# libname, cellname이 db_json_data에 있는지 확인
if !haskey(db_json_data, libname)
    error("Library name '$libname' not found in database at $db_json_path")
elseif !haskey(db_json_data[libname], cellname)
    error("Cell name '$cellname' not found in library '$libname' at $db_json_path")
end

# =============================================
# 2. 각 단계별로 @btime을 이용한 실행시간 측정
# =============================================

# 2.1. Tree 생성 함수 측정
println("-"^20)
println("Benchmark for creating tree:")
# equivalent_net_sets는 이후 flatten에서도 사용하기 위해 전역 변수로 유지
equivalent_net_sets = [("VDD", Set(["VDD", "vdd", "VDD:"])),
                         ("VSS", Set(["VSS", "VSS:", "vss"]))]
# get_tree 함수의 실행시간을 측정 및 반환 결과를 root와 cell_data에 저장
root, cell_data = @btime get_tree($libname, $cellname, $db_json_data, equivalent_net_sets)
println("-"^20)

# 2.2. Task 리스트 생성 함수 측정
println("Benchmark for creating task list:")
task_list = @btime build_task_list($root)
println("-"^20)

# 2.3. Flatten 함수 측정
println("Benchmark for flattening:")
# flatten_v2의 실행 시간 측정을 통해 mdata와 vdata를 받음
mdata, vdata = @btime flatten_v2($cell_data, $task_list, $metal_dir, $via_dir, $db_json_data, $orientation_list, equivalent_net_sets)
println("-"^20)


function merge_n_connect(mdata::MData, vdata::VData)
    # Merge metals and vias
    merged_mdata, named_mvectors = sort_n_merge_MData(mdata)
    vdata = sort_VData(vdata)

    # Create connected sets
    connected_sets, merged_mdata = create_connected_sets(merged_mdata, vdata, named_mvectors)

    return merged_mdata, connected_sets
end

println("Benchmark for merging and connecting:")
merged_mdata, connected_sets = @btime merge_n_connect($mdata, $vdata)
println("-"^20)



# # 2.4. Merge (sort_n_merge_MData) 함수 측정
# println("Benchmark for merging:")
# merged_mdata, named_mvectors = @btime sort_n_merge_MData($mdata)
# println("-"^20)

# # 2.5. Vias 정렬 (sort_VData) 함수 측정
# println("Benchmark for sorting vias:")
# vdata = @btime sort_VData($vdata)
# println("-"^20)

# # 2.6. Connected sets 생성 함수 측정
# println("Benchmark for connecting nets:")
# connected_sets, merged_mdata = @btime create_connected_sets($merged_mdata, $vdata, $named_mvectors)
# println("-"^20)

# =============================================
# 이후 필요한 추가 코드 및 시각화 작업을 수행
# visualize_metals_by_layer(merged_mdata.metals, orientation_list, "$(visualized_dir)/test_$(cellname)")
# visualize_metals(merged_mdata.metals, orientation_list, "$(visualized_dir)/test_$(cellname).png")
