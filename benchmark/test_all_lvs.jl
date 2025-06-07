using BenchmarkTools
using YAML
using CSV
using DataFrames
using Dates
using preLVS_vectormerge
using OrderedCollections


function run_LVS_all()
    input_path = "benchmark/test_all_lvs.yaml"
    println("Total benchmark config path: $input_path")

    benchmark_input = YAML.load_file(input_path)
    file_paths = benchmark_input["file_paths"]

    n_cells = length(benchmark_input["cells_to_benchmark"])

    all_results = OrderedDict{String, Any}()

    funcs_to_benchmark = [
        ("loadDB", preLVS_vectormerge.loadDB),
        ("flatten", preLVS_vectormerge.flatten),
        ("mergeVector", preLVS_vectormerge.mergeVector),
        ("generate_graph", preLVS_vectormerge.generate_graph),
        ("runLVS_wo_log", preLVS_vectormerge.runLVS_wo_log),
        ("runLVS", preLVS_vectormerge.runLVS)
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

        cinfo, error_info, error_cnt = runLVS(input_params)
    end

    return
end




########################################################

# Run LVS

########################################################

run_LVS_all()
