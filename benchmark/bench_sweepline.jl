using BenchmarkTools
using preLVS_sweepline
using YAML

# Set sampling parameters
n_samples = 100             # Number of samples to run
max_benchmark_seconds = 3   # Maximum number of seconds to run each sample

input_path = "benchmark/bench_input.yaml"
input_data = YAML.load_file(input_path)
libname = input_data["libname"]
cellname = input_data["cellname"]



println("\nBenchmarking preLVS_sweepline\n")

println("Target: $libname - $cellname\n")

println("Functions:")
println("1. loadDB ")
println("2. flatten")
println("3. alignEvents")
println("4. generate_graph")
println()


# Performance Test
println("Starting benchmark: loadDB")
loadDB_benchmark = @benchmark loadDB(input_path)                    samples=n_samples seconds=(n_samples*max_benchmark_seconds)

println("Starting benchmark: flatten")
flatten_benchmark = @benchmark flatten(input_path)                  samples=n_samples seconds=(n_samples*max_benchmark_seconds)

println("Starting benchmark: alignEvents")
alignEvents_benchmark = @benchmark alignEvents(input_path)          samples=n_samples seconds=(n_samples*max_benchmark_seconds)

println("Starting benchmark: generate_graph")
generate_graph_benchmark = @benchmark generate_graph(input_path)    samples=n_samples seconds=(n_samples*max_benchmark_seconds)


# Display Results
println("Target: loadDB")
display(loadDB_benchmark)
println("-"^20)
println()
println("Target: flatten")
display(flatten_benchmark)
println("-"^20)
println()
println("Target: alignEvents")
display(alignEvents_benchmark)
println("-"^20)
println()
println("Target: generate_graph")
display(generate_graph_benchmark)
println("-"^20)
println()


