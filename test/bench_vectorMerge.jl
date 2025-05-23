using BenchmarkTools
using preLVS_vectormerge

loadDB_benchmark = @benchmark loadDB("test/test_input.yaml")
flatten_benchmark = @benchmark flatten("test/test_input.yaml")
mergeVector_benchmark = @benchmark mergeVector("test/test_input.yaml")
total_benchmark = @benchmark runLVS("test/test_input.yaml")
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
println("Target: runLVS")
display(total_benchmark)
println("-"^20)
