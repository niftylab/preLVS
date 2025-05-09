using BenchmarkTools
using preLVS_sweepline
using YAML

input_path = "benchmark/bench_input.yaml"
input_data = YAML.load_file(input_path)
libname = input_data["libname"]
cellname = input_data["cellname"]


println("Target: $libname - $cellname\n")


# Performance Test

error_log, cgraph, hash_rect = runLVS(input_path)
# println("  - cgraph: $cgraph")
# println("  - hash_rect: $hash_rect")
