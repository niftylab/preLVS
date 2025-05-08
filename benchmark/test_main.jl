using BenchmarkTools
using preLVS_vectormerge
using YAML


input_path = "benchmark/bench_input.yaml"
input_data = YAML.load_file(input_path)
libname = input_data["libname"]
cellname = input_data["cellname"]


cinfo = runLVS(input_path)
