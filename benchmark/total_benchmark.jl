using BenchmarkTools
using YAML
using CSV
using DataFrames
using Dates
using preLVS_sweepline
using OrderedCollections


function run_benchmarks()
    input_path = "benchmark/total_bench_input.yaml"
    println("Total benchmark config path: $input_path")

    benchmark_input = YAML.load_file(input_path)
    file_paths = benchmark_input["file_paths"]

    n_cells = length(benchmark_input["cells_to_benchmark"])

    all_results = OrderedDict{String, Any}()

    funcs_to_benchmark = [
        ("loadDB", preLVS_sweepline.loadDB),
        ("flatten", preLVS_sweepline.flatten),
        ("alignEvents", preLVS_sweepline.alignEvents),
        ("generate_graph", preLVS_sweepline.generate_graph),
        ("runLVS_wo_log", preLVS_sweepline.runLVS_wo_log),
    ]
            
    for i in 1:n_cells
        target_cell = benchmark_input["cells_to_benchmark"][i]

        # Initialize input parameters
        input_params = Dict{String, Any}()
        input_params["db_dir"] = file_paths["db_dir"]
        input_params["metal_dir"] = file_paths["metal_dir"]
        input_params["via_dir"] = file_paths["via_dir"]
        input_params["visualized_dir"] = file_paths["visualized_dir"]
        input_params["log_dir"] = file_paths["log_dir"]
        input_params["netlog_dir"] = file_paths["netlog_dir"]
        input_params["libname"] = target_cell["libname"]
        input_params["cellname"] = target_cell["cellname"]
        input_params["config_file_path"] = target_cell["config_file_path"]
        input_params["n_samples"] = target_cell["n_samples"]
        input_params["max_benchmark_seconds"] = target_cell["max_benchmark_seconds"]

        cell_key = "$(input_params["libname"]) - $(input_params["cellname"])"
        all_results[cell_key] = OrderedDict{String, Any}()

        println("Processing cell: $cell_key")

        for (func_name, func_to_run) in funcs_to_benchmark
            try
                println("Benchmarking $func_name")
                benchmark_result = @benchmark $func_to_run($input_params) samples=input_params["n_samples"] seconds=(input_params["n_samples"]*input_params["max_benchmark_seconds"])

                # Extract benchmark results
                mean_t_ns = mean(benchmark_result).time
                std_t_ns = std(benchmark_result).time
                median_t_ns = median(benchmark_result).time
                min_t_ns = minimum(benchmark_result).time
                max_t_ns = maximum(benchmark_result).time
                alloc_count = benchmark_result.allocs
                memory_b = benchmark_result.memory
                samples_run = length(benchmark_result.times)

                # Store benchmark results
                all_results[cell_key][func_name] = OrderedDict{String, Any}(
                    "mean_time" => mean_t_ns,
                    "std_time" => std_t_ns,
                    "median_time" => median_t_ns,
                    "min_time" => min_t_ns,
                    "max_time" => max_t_ns,
                    "allocations" => alloc_count,
                    "memory" => memory_b,
                    "samples_run" => samples_run,
                    "error_msg" => "No error"
                )
            catch e
                # Handle errors
                println("Error benchmarking $func_name for cell $cell_key: $e")
                all_results[cell_key][func_name] = OrderedDict{String, Any}(
                    "mean_time" => 0,
                    "std_time" => 0,
                    "median_time" => 0,
                    "min_time" => 0,
                    "max_time" => 0,
                    "allocations" => 0,
                    "memory" => 0,
                    "samples_run" => 0,
                    "error_msg" => "Error: $e"
                )
            end
        end
    end

    return all_results
end




########################################################

# Run Benchmark

########################################################

all_results = run_benchmarks()

println("\n--- Processing results for summary and CSV export ---")




# Save benchmark results to CSV and txt files
result_rows = []
desired_columns = [
    "CellName", "FunctionName", "MeanTime_ns", "StdTime_ns", 
    "MedianTime_ns", "MinTime_ns", "MaxTime_ns", "Allocations", 
    "Memory_bytes", "SamplesRun", "ErrorMsg"
]

for (cell_name, functions_results) in all_results
    if isempty(functions_results)
        println("No results found for cell: $cell_name")
        continue
    end

    for (func_name, result_details) in functions_results
        row_data = OrderedDict{String, Any}(
            "CellName" => cell_name,
            "FunctionName" => func_name,
            "MeanTime_ns" => result_details["mean_time"],
            "StdTime_ns" => result_details["std_time"],
            "MedianTime_ns" => result_details["median_time"],
            "MinTime_ns" => result_details["min_time"],
            "MaxTime_ns" => result_details["max_time"],
            "Allocations" => result_details["allocations"],
            "Memory_bytes" => result_details["memory"],
            "SamplesRun" => result_details["samples_run"],
            "ErrorMsg" => result_details["error_msg"]
        )
        push!(result_rows, row_data)
    end
end

if !isempty(result_rows)

    df_results = DataFrame(result_rows)
    output_dir = "out/benchmark_results"
    if !isdir(output_dir)
        try
            mkpath(output_dir)
            println("Created directory for benchmark results: $output_dir")
        catch e
            println("Error creating directory $output_dir: $e. Saving to current directory instead.")
            global output_dir = "."
        end
    end

    # Create CSV file
    timestamp = Dates.format(now(), "yyyy-mm-dd_HHMMSS")
    output_filename = joinpath(output_dir, "benchmark_summary_$(timestamp).csv")

    try
        CSV.write(output_filename, df_results)
        println("Benchmark results successfully saved to: $output_filename")
    catch e
        println("Error writing CSV file $output_filename: $e")
    end

    # Create txt file
    txt_filename = joinpath(output_dir, "benchmark_summary_$(timestamp).txt")
    open(txt_filename, "w") do io
        for (cell_name, functions_results) in all_results
            println(io, "Cell: $cell_name")
            for (func_name, result_details) in functions_results
                println(io, "  Function: $func_name")
                println(io, "    Mean Time: $(result_details["mean_time"]) ns")
                println(io, "    Std Time: $(result_details["std_time"]) ns")
                println(io, "    Median Time: $(result_details["median_time"]) ns")
                println(io, "    Min Time: $(result_details["min_time"]) ns")
                println(io, "    Max Time: $(result_details["max_time"]) ns")
                println(io, "    Allocations: $(result_details["allocations"])")
                println(io, "    Memory: $(result_details["memory"]) bytes")
                println(io, "    Samples Run: $(result_details["samples_run"])")
            end
        end
    end
    println("Benchmark results successfully saved to: $txt_filename")

else
    println("No results were processed to be saved.")
end

println("\nBenchmark script finished.")