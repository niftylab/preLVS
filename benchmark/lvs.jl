using BenchmarkTools
using preLVS_sweepline
using YAML

libname = "serializer_generated"
cellname = "ser_8to1_2x"
config_file_path = "config/config_tsmcN28.yaml"
db_dir = "db"
metal_dir = "out/metal"
via_dir = "out/via"
visualized_dir = "out/visualized"
log_dir = "out/log"
netlog_dir = "out/label"

runset = Dict{String, Any}(
    "libname" => libname,
    "cellname" => cellname,
    "config_file_path" => config_file_path,
    "db_dir" => db_dir,
    "metal_dir" => metal_dir,
    "via_dir" => via_dir,
    "visualized_dir" => visualized_dir,
    "log_dir" => log_dir,
    "netlog_dir" => netlog_dir
)


println("Target: $libname - $cellname\n")


# Performance Test

root, inst_flatten, cell_list, db_data = loadDB(runset)


error_log, cgraph, hash_rect = runLVS(runset)
