using BenchmarkTools
using preLVS_vectormerge
using YAML


libname = "scan_generated"
cellname = "scan_chain_17bit"
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
cinfo = runLVS(runset)
