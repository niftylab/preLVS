using BenchmarkTools
using preLVS_vectormerge

println("Benchmarking preLVS_vectorMerge")

println("Functions:")
println("1. loadDB ")
println("2. flatten")
println("3. mergeVector")
println("4. generate_graph")
println("5. runLVS_wo_print")


# Performance Test
loadDB_benchmark = @benchmark loadDB("benchmark/bench_input.yaml")                    samples=100 seconds=100    
flatten_benchmark = @benchmark flatten("benchmark/bench_input.yaml")                  samples=100 seconds=100
mergeVector_benchmark = @benchmark mergeVector("benchmark/bench_input.yaml")          samples=100 seconds=100
generate_graph_benchmark = @benchmark generate_graph("benchmark/bench_input.yaml")    samples=100 seconds=100
total_benchmark = @benchmark runLVS_wo_print("benchmark/bench_input.yaml")            samples=100 seconds=100


# Display Results
println("Target: loadDB")
display(loadDB_benchmark)
println("-"^20)
println()
println("Target: flatten")
display(flatten_benchmark)
println("-"^20)
println()
println("Target: mergeVector")
display(mergeVector_benchmark)
println("-"^20)
println()
println("Target: generate_graph")
display(generate_graph_benchmark)
println("-"^20)
println()
println("Target: runLVS_wo_print")
display(total_benchmark)
println("-"^20)
