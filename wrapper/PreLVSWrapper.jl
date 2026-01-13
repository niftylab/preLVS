# ============================================================================
# PreLVSWrapper.jl - Wrapper to integrate preLVS with laygo3-julia
# ============================================================================
#
# This module provides drop-in replacements for:
#   - HierarchicalLoader.build_layout() -> PreLVSWrapper.build_layout()
#   - LVSChecker.check_layout()         -> PreLVSWrapper.run_lvs()
#
# Usage:
#   include("src/preLVS/wrapper/PreLVSWrapper.jl")
#   using .PreLVSWrapper
#   layout = PreLVSWrapper.build_layout(library, cell; tech_spec=tech)
#   lvs_result = PreLVSWrapper.run_lvs(layout)
#
# ============================================================================

module PreLVSWrapper

using JSON
using YAML
using OrderedCollections
using StaticArrays
using Logging

# ============================================================================
# Import laygo3-julia types FIRST (before preLVS includes to avoid name conflicts)
# ============================================================================

using Laygo3Julia.Domain.Geometry: Rectangle, Point
using Laygo3Julia.Domain.LayoutComposite: Layout
using Laygo3Julia.Domain.Grid: TechnologySpec
using Laygo3Julia.Domain.Hierarchy: CellInfo
using Laygo3Julia.UseCases.LVSChecker: LVSResult, LVSError, ConnectivityGraph

# Import with qualified names to avoid conflicts with preLVS types
import Laygo3Julia.Domain.Elements: MergedMetal, RawMetal, MergeMappings, ConnectedComponent
import Laygo3Julia.Domain.Elements: Via as L3ViaType
import Laygo3Julia.Domain.Elements: Pin as L3PinType
import Laygo3Julia.Domain.Elements: Label as L3LabelType

# Create aliases using the imported types
const L3MergedMetal = MergedMetal
const L3Via = L3ViaType
const L3Pin = L3PinType
const L3Label = L3LabelType
const L3ConnectedComponent = ConnectedComponent

# ============================================================================
# Path Setup - Get preLVS root directory
# ============================================================================

const WRAPPER_DIR = @__DIR__
const PRELVS_ROOT = dirname(WRAPPER_DIR)

# ============================================================================
# Include preLVS modules in correct order
# We need to include from preLVS root for relative paths to work
# ============================================================================

# Save current directory and change to preLVS root
const _original_dir = pwd()
cd(PRELVS_ROOT)

try
    # Include utils first (needed by main_functions)
    include(joinpath(PRELVS_ROOT, "utils", "yaml.jl"))

    # Include struct files in dependency order
    include(joinpath(PRELVS_ROOT, "structs", "laygo_origin.jl"))
    include(joinpath(PRELVS_ROOT, "structs", "stack.jl"))
    include(joinpath(PRELVS_ROOT, "structs", "structure.jl"))
    include(joinpath(PRELVS_ROOT, "structs", "new_metal.jl"))
    include(joinpath(PRELVS_ROOT, "structs", "via.jl"))
    include(joinpath(PRELVS_ROOT, "structs", "tree.jl"))
    include(joinpath(PRELVS_ROOT, "structs", "connectivity.jl"))

    # Include main_functions for flatten_v2
    include(joinpath(PRELVS_ROOT, "main_functions.jl"))

finally
    cd(_original_dir)
end

# ============================================================================
# Include wrapper components
# ============================================================================

include(joinpath(WRAPPER_DIR, "config_loader.jl"))
include(joinpath(WRAPPER_DIR, "converters.jl"))

# ============================================================================
# Exports
# ============================================================================

export build_layout, run_lvs, PreLVSConfig, load_prelvs_config

# ============================================================================
# Default paths
# ============================================================================

# Compute workspace root from wrapper location
# WRAPPER_DIR = src/preLVS/wrapper
# PRELVS_ROOT = src/preLVS
# -> go up 2 more levels to get workspace root
const WORKSPACE_ROOT = dirname(dirname(PRELVS_ROOT))

const DEFAULT_DB_DIR = joinpath(WORKSPACE_ROOT, "src", "laygo3-services", "output", "db")
const DEFAULT_CONFIG_PATH = joinpath(PRELVS_ROOT, "config", "config_tsmcN28.yaml")

# ============================================================================
# build_layout - Main Entry Point (replaces HierarchicalLoader.build_layout)
# ============================================================================

"""
    build_layout(library, cell; tech_spec, db_dir, config_path) -> Layout

Build layout using preLVS hierarchy flattening and metal merging.

# Arguments
- `library::String`: Library name
- `cell::String`: Cell name
- `tech_spec::TechnologySpec`: Technology specification (for grid width info)
- `db_dir::String`: Path to database JSON files (default: "src/laygo3-services/output/db")
- `config_path::String`: Path to config YAML (default: "grids/config_tsmcN28.yaml")

# Returns
- `Layout`: laygo3-julia Layout with merged metals, vias, pins, labels
"""
function build_layout(
    library::String,
    cell::String;
    tech_spec::TechnologySpec,
    db_dir::String = DEFAULT_DB_DIR,
    config_path::String = DEFAULT_CONFIG_PATH
)::Layout

    @info "PreLVSWrapper.build_layout starting" library=library cell=cell

    # Load preLVS config
    config = load_prelvs_config(config_path, db_dir)

    # Build orientation_list from tech_spec (not from config)
    max_layer = length(config.config_data["Layer"]["order"])
    orientation_list = build_orientation_list(tech_spec, max_layer)
    @debug "Built orientation_list from tech_spec" max_layer=max_layer

    # Step 1: Build hierarchy tree (preLVS)
    @debug "Building hierarchy tree..."
    root, cell_data, db_data, top_netname_list = get_tree(
        library, cell, db_dir, config.source_net_sets
    )

    # Step 2: Flatten hierarchy (preLVS)
    @debug "Flattening hierarchy..."
    mdata, vdata = flatten_v2(
        library, cell, cell_data, db_data,
        orientation_list, config.config_data,
        config.source_net_sets,
        true  # is_detailed
    )

    # Step 3: Merge metals (preLVS)
    @debug "Merging metals..."
    modata, nmetals, short_errors = sort_n_merge_MData(mdata)

    if !isempty(short_errors)
        @warn "Short errors detected during merge" count=length(short_errors)
        for err in short_errors
            @debug "Short error" message=get(err, "message", "unknown")
        end
    end

    # Step 4: Convert to laygo3-julia types
    @debug "Converting to laygo3-julia types..."

    merged_metals = convert_modata_to_merged_metals(
        modata, orientation_list, tech_spec
    )

    vias = convert_vdata_to_vias(vdata, config.config_data)

    # Extract pins and labels from db_data
    pins = extract_pins(db_data, library, cell, orientation_list)
    labels = extract_labels(db_data, library, cell, orientation_list)

    @info "PreLVSWrapper.build_layout complete" num_metals=length(merged_metals) num_vias=length(vias) num_pins=length(pins) num_labels=length(labels)

    # Create Layout (raw_metals empty, using merged only)
    return Layout(
        library,
        cell,
        tech_spec,
        vias,
        pins,
        labels,
        RawMetal[],              # raw_metals (empty - using merged)
        merged_metals,
        MergeMappings(),         # merge_mappings (empty)
        Dict{Int, CellInfo}()    # cell_registry (empty)
    )
end

# ============================================================================
# run_lvs - LVS Entry Point (replaces LVSChecker.check_layout)
# ============================================================================

"""
    run_lvs(layout; db_dir, config_path) -> Dict

Run LVS using preLVS connectivity analysis.
Re-runs flattening to get MOData/VData for connectivity check.

# Arguments
- `layout::Layout`: Layout to check
- `db_dir::String`: Path to database JSON files
- `config_path::String`: Path to config YAML

# Returns
- `Dict`: Dictionary with keys "success", "passed", "lvs_result", etc.
  (matches RoutingOrchestrator.run_lvs format for compatibility)
"""
function run_lvs(
    layout::Layout;
    db_dir::String = DEFAULT_DB_DIR,
    config_path::String = DEFAULT_CONFIG_PATH
)

    library = layout.library
    cell = layout.cell

    @info "PreLVSWrapper.run_lvs starting" library=library cell=cell

    # Load preLVS config
    config = load_prelvs_config(config_path, db_dir)

    # Build orientation_list from layout's technology
    tech_spec = layout.technology
    max_layer = length(config.config_data["Layer"]["order"])
    orientation_list = build_orientation_list(tech_spec, max_layer)

    # Re-run preLVS pipeline to get MOData/VData
    @debug "Re-running preLVS pipeline for connectivity analysis..."

    root, cell_data, db_data, _ = get_tree(
        library, cell, db_dir, config.source_net_sets
    )

    mdata, vdata = flatten_v2(
        library, cell, cell_data, db_data,
        orientation_list, config.config_data,
        config.source_net_sets,
        true  # is_detailed
    )

    modata, nmetals, short_errors = sort_n_merge_MData(mdata)

    # Assign via indices (continuing from metal indices)
    via_idx = nmetals + 1
    for (vtype, vlist) in vdata.vlists
        for vpoint in vlist.vpoints
            vpoint.idx = via_idx
            via_idx += 1
        end
    end

    # Run preLVS connectivity analysis
    @debug "Running connectivity analysis..."
    cgraph = connect_metals_from_via(modata, vdata, nmetals)

    component_infos, error_infos, error_cnt = check_and_report_connections_bfs(
        cgraph, config.source_net_sets
    )

    @debug "Connectivity analysis complete" num_components=length(component_infos) num_errors=error_cnt

    # Convert to laygo3-julia types
    components = convert_component_infos(component_infos)
    errors = convert_error_infos(error_infos)
    merged_metal_net_map = build_merged_metal_net_map_from_components(component_infos)

    # Build summary
    summary = Dict{String, Any}(
        "total_components" => length(components),
        "total_errors" => error_cnt,
        "shorts" => count(e -> e.type == :short, errors),
        "opens" => count(e -> e.type == :open, errors),
        "floating" => count(e -> e.type == :floating, errors),
        "passed" => error_cnt == 0
    )

    # Create minimal ConnectivityGraph
    graph = create_empty_connectivity_graph()

    @info "PreLVSWrapper.run_lvs complete" passed=summary["passed"] num_components=length(components) num_errors=error_cnt

    lvs_result = LVSResult(
        components,
        errors,
        graph,
        summary,
        error_cnt == 0,
        merged_metal_net_map
    )

    # Return Dict format matching RoutingOrchestrator.run_lvs for compatibility
    error_descriptions = ["$(e.type): $(e.message)" for e in errors]
    return Dict(
        "success" => true,
        "passed" => lvs_result.passed,
        "num_components" => length(components),
        "num_errors" => error_cnt,
        "errors" => error_descriptions,
        "summary" => summary,
        "lvs_result" => lvs_result
    )
end

# ============================================================================
# Convenience function for combined build + LVS
# ============================================================================

"""
    build_layout_with_lvs(library, cell; tech_spec, db_dir, config_path) -> (Layout, LVSResult)

Build layout and run LVS in one call.
"""
function build_layout_with_lvs(
    library::String,
    cell::String;
    tech_spec::TechnologySpec,
    db_dir::String = DEFAULT_DB_DIR,
    config_path::String = DEFAULT_CONFIG_PATH
)
    layout = build_layout(library, cell; tech_spec=tech_spec, db_dir=db_dir, config_path=config_path)
    lvs_result = run_lvs(layout; db_dir=db_dir, config_path=config_path)
    return (layout, lvs_result)
end

end # module PreLVSWrapper
