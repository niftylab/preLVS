"""
    preLVS

Pre-Layout vs Schematic (preLVS) module for grid-based layout verification.
Provides hierarchy flattening, metal merging, and connectivity checking.

## Main Functions (used by laygo3-julia)
- `get_tree()`: Build hierarchy tree from database
- `flatten_v2()`: Flatten hierarchy to MData/VData
- `sort_n_merge_MData()`: Sort and merge overlapping metals
- `connect_metals_from_via()`: Build connectivity graph from vias
- `check_and_report_connections_bfs()`: BFS to find connected components and errors

## Exported Types
- `MData`, `MOData`: Metal data structures
- `VData`: Via data structure
- `MGraph`: Connectivity graph
- `ComponentInfo`, `ErrorInfo`: LVS result types
"""
module preLVS

using PrecompileTools
using JSON

# ============================================================================
# Includes - Order matters due to dependencies
# ============================================================================

# Get the preLVS root directory (parent of src/)
const PRELVS_ROOT = dirname(@__DIR__)

# Change to preLVS root for relative includes to work
const _original_dir = pwd()
cd(PRELVS_ROOT)

try
    # Core structs (no dependencies)
    include(joinpath(PRELVS_ROOT, "structs", "laygo_origin.jl"))
    include(joinpath(PRELVS_ROOT, "structs", "stack.jl"))
    include(joinpath(PRELVS_ROOT, "structs", "structure.jl"))

    # Metal and Via structs (depend on above)
    include(joinpath(PRELVS_ROOT, "structs", "new_metal.jl"))
    include(joinpath(PRELVS_ROOT, "structs", "via.jl"))

    # Tree struct (depends on structure.jl for affineMat)
    include(joinpath(PRELVS_ROOT, "structs", "tree.jl"))

    # Connectivity (depends on via.jl, new_metal.jl)
    include(joinpath(PRELVS_ROOT, "structs", "connectivity.jl"))

    # Utils
    include(joinpath(PRELVS_ROOT, "utils", "yaml.jl"))

    # Main functions (depends on all above)
    include(joinpath(PRELVS_ROOT, "main_functions.jl"))
finally
    cd(_original_dir)
end

# ============================================================================
# Exports - Functions used by laygo3-julia PreLVSWrapper
# ============================================================================

# Main entry functions
export get_tree, flatten_v2, sort_n_merge_MData
export connect_metals_from_via, check_and_report_connections_bfs

# Data types
export MData, MLayer, MVector, MPoint, MPosition, START, END, UNDEF
export MOData, MOLayer, MOVector
export VData, VList, VPoint
export MGraph, ComponentInfo, ErrorInfo, ErrorType, SHORT, OPEN, FLOATING
export LaygoOrigin

# Helper functions (used by PreLVSWrapper)
export get_config, get_yaml, get_orientation_list
export db_to_MData, db_to_VData, transform_MData, transform_VData
export metal_to_int, affineMat, unify_netname

# ============================================================================
# Precompilation Workload
# ============================================================================

@setup_workload begin
    # Sample data for precompilation - minimal valid structures
    println("Setting up preLVS precompile workload...")

    # Sample config path (use actual config if available)
    sample_config_path = joinpath(PRELVS_ROOT, "config", "config_tsmcN28.yaml")
    sample_db_dir = joinpath(PRELVS_ROOT, "db")

    @compile_workload begin
        println("Running preLVS precompile workload...")

        # Only run workload if sample files exist
        if isfile(sample_config_path) && isdir(sample_db_dir)
            try
                # Load config
                config_data = get_config(sample_config_path)
                orientation_list = get_orientation_list(config_data)
                equiv_net_sets = config_data["Equivalent_net_sets"]

                println("  Precompiled: get_config, get_orientation_list")

                # Try to find a sample cell in db
                db_files = filter(f -> endswith(f, "_db.json"), readdir(sample_db_dir))
                if !isempty(db_files)
                    # Parse library name from first db file
                    sample_db_file = first(db_files)
                    sample_libname = replace(sample_db_file, "_db.json" => "")

                    # Try to get tree (this exercises most of the code)
                    try
                        # Load the JSON to find a cell name
                        db_path = joinpath(sample_db_dir, sample_db_file)
                        db_json = JSON.parse(read(db_path, String))

                        if haskey(db_json, sample_libname)
                            cells = keys(db_json[sample_libname])
                            if !isempty(cells)
                                sample_cellname = first(cells)

                                # Run the main functions
                                root, cell_data, db_data, top_netname_list = get_tree(
                                    sample_libname, sample_cellname, sample_db_dir, equiv_net_sets
                                )
                                println("  Precompiled: get_tree")

                                mdata, vdata = flatten_v2(
                                    sample_libname, sample_cellname, cell_data, db_data,
                                    orientation_list, config_data, equiv_net_sets, true
                                )
                                println("  Precompiled: flatten_v2")

                                modata, nmetals, short_errors = sort_n_merge_MData(mdata)
                                println("  Precompiled: sort_n_merge_MData")

                                cgraph = connect_metals_from_via(modata, vdata, nmetals)
                                println("  Precompiled: connect_metals_from_via")

                                cinfo, error_info, error_cnt = check_and_report_connections_bfs(
                                    cgraph, equiv_net_sets
                                )
                                println("  Precompiled: check_and_report_connections_bfs")
                            end
                        end
                    catch e
                        @debug "Precompile workload skipped cell processing" exception=e
                    end
                end
            catch e
                @debug "Precompile workload skipped" exception=e
            end
        else
            println("  Skipping workload: sample files not found")
        end

        println("Finished preLVS precompile workload.")
    end
end

end # module preLVS
