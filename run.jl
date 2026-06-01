if !isdefined(@__MODULE__, :_PRELVS_RUN_JL_)
const _PRELVS_RUN_JL_ = true

# ===========================================================================
# run.jl - Single high-level entry point for the preLVS pipeline.
#
# `run_prelvs` runs the full, verified pipeline in one call:
#   get_tree -> flatten_v2 -> check_grid_consistency -> sort_n_merge_MData
#   -> connect_metals_from_via -> check_and_report_connections_bfs
#   -> (optional) grid netmap
#
# It returns a plain NamedTuple of results; `result_to_dict` turns that into
# the JSON-serializable schema that the migration flow consumes over a
# subprocess boundary (see cli.jl). No file is written and nothing is printed
# to stdout here -- the caller owns I/O.
# ===========================================================================

"""
    run_prelvs(libname, cellname, techname;
               db_dir, config_path, grid_root=".",
               detailed=true, emit_netmap=true) -> NamedTuple

Run the connectivity-verification pipeline for one cell.

Inputs are paths/names only:
- `db_dir`       : directory holding `<libname>_db.json`
- `config_path`  : full path to the tech config YAML
- `grid_root`    : directory holding `grids/<techname>_grid.json`
                   (only used when `emit_netmap`)

Returns a NamedTuple with fields:
`libname, cellname, top_netnames, grid_consistent, grid_errors,
 error_cnt, error_info, added_short, cinfo, netmap`.
`netmap` is a `GridData` (or `nothing` when `emit_netmap=false` or on grid
inconsistency).
"""
function run_prelvs(
    libname::String, cellname::String, techname::String;
    db_dir::String,
    config_path::String,
    grid_root::String = ".",
    detailed::Bool = true,
    emit_netmap::Bool = true,
)
    config_data = get_config(config_path)
    orientation_list = get_orientation_list(config_data)
    equiv = config_data["Equivalent_net_sets"]

    # 1. hierarchy + 2. flatten
    _root, cell_data, db_data, top_netname_list =
        get_tree(libname, cellname, db_dir, equiv)
    mdata, vdata = flatten_v2(
        libname, cellname, cell_data, db_data,
        orientation_list, config_data, equiv, detailed,
    )

    # 3. grid consistency (hard gate -- return a structured failure)
    grid_errors = String[]
    grid_ok = check_grid_consistency(
        libname, cellname, db_data, orientation_list, grid_errors, detailed,
    )
    if !grid_ok
        return (
            libname = libname, cellname = cellname,
            top_netnames = top_netname_list,
            grid_consistent = false, grid_errors = grid_errors,
            error_cnt = Dict("short" => 0, "open" => 0,
                             "floating" => 0, "total" => 0),
            error_info = ErrorInfo[], added_short = Dict{String, Any}[],
            cinfo = ComponentInfo[], netmap = nothing,
        )
    end

    # 4. merge -> 5. via connectivity -> 6. component BFS
    modata, nmetals, short_error_data = sort_n_merge_MData(mdata)
    cgraph = connect_metals_from_via(modata, vdata, nmetals)
    cinfo, error_info, error_cnt =
        check_and_report_connections_bfs(cgraph, equiv)

    # Merge-time SHORT errors (multiple netnames on one merged line) are
    # folded into the count here, mirroring create_error_log_file's logic
    # (so the verdict matches the legacy manifest path).
    added_short = _reconcile_short_errors!(error_cnt, error_info, short_error_data)

    # 7. grid netmap (net / OBSTACLE occupation per grid line)
    netmap = nothing
    if emit_netmap
        grid_json = get_grid(techname, config_data, grid_root)
        empty_grid = create_empty_grid_data(grid_json, cell_data, libname, cellname)
        netmap = get_grid_data(empty_grid, cinfo, top_netname_list, grid_json)
    end

    return (
        libname = libname, cellname = cellname,
        top_netnames = top_netname_list,
        grid_consistent = true, grid_errors = grid_errors,
        error_cnt = error_cnt, error_info = error_info,
        added_short = added_short, cinfo = cinfo, netmap = netmap,
    )
end


# Fold the merge-time SHORT errors (from sort_n_merge_MData) into error_cnt,
# de-duplicating against the SHORT errors already found by the BFS pass.
# Returns the list of newly-added short-error records.
function _reconcile_short_errors!(
    error_cnt::Dict{String, Int},
    error_info::Vector{ErrorInfo},
    short_error_data::Vector{Dict{String, Any}},
)
    seen = Vector{Set{String}}()
    for e in error_info
        if e.type == SHORT
            push!(seen, Set([e.actual_netname, e.expected_netname]))
        end
    end
    added = Vector{Dict{String, Any}}()
    for sd in short_error_data
        if !(sd["netname_set"] in seen)
            error_cnt["short"] += 1
            error_cnt["total"] += 1
            push!(seen, sd["netname_set"])
            push!(added, sd)
        end
    end
    return added
end


# ===========================================================================
# JSON serialization -- the stable subprocess output schema.
# ===========================================================================

"""
    result_to_dict(res) -> Dict

Convert a `run_prelvs` result into the JSON-serializable response consumed
by the migration flow. See README for the schema.
"""
function result_to_dict(res)
    status =
        !res.grid_consistent ? "grid_error" :
        (res.error_cnt["total"] == 0 ? "passed" : "failed")

    out = Dict{String, Any}(
        "target" => "$(res.libname) - $(res.cellname)",
        "status" => status,
        "error_cnt" => res.error_cnt,
        "errors" => _errors_to_list(res.error_info, res.added_short),
        "top_netnames" => res.top_netnames,
        "netmap" => res.netmap === nothing ? nothing : _netmap_to_dict(res.netmap),
    )
    if !res.grid_consistent
        out["grid_errors"] = res.grid_errors
    end
    return out
end


function _errors_to_list(
    error_info::Vector{ErrorInfo},
    added_short::Vector{Dict{String, Any}},
)
    out = Vector{Dict{String, Any}}()
    for e in error_info
        push!(out, Dict{String, Any}(
            "type" => string(e.type),
            "netname" => e.actual_netname,
            "expected" => e.expected_netname,
            "detail" => get_error_string(e),
        ))
    end
    for sd in added_short
        push!(out, Dict{String, Any}(
            "type" => "SHORT",
            "netname_set" => sort(collect(sd["netname_set"])),
            "detail" => sd["message"],
        ))
    end
    # Deterministic order so the output is stable run-to-run.
    sort!(out, by = e -> (
        get(e, "type", ""),
        something(get(e, "netname", nothing), ""),
        something(get(e, "expected", nothing), ""),
        get(e, "detail", ""),
    ))
    return out
end


function _netmap_to_dict(gd::GridData)
    layers = Dict{String, Any}()
    for (layer_num, layer) in gd.layers
        lines = Dict{String, Any}()
        for (xy, gl) in layer.lines
            gl.occupation === nothing && continue
            occ = [
                Dict{String, Any}(
                    "scope" => [lo.scope[1], lo.scope[2]],
                    "netname" => lo.netname,
                )
                for lo in gl.occupation
            ]
            # Deterministic order within a grid line.
            sort!(occ, by = d -> (d["scope"][1], d["scope"][2], d["netname"]))
            lines[string(xy)] = occ
        end
        layers[string(layer_num)] = Dict{String, Any}(
            "orientation" => layer.orientation,
            "lines" => lines,
        )
    end
    return Dict{String, Any}(
        "top_bbox" => [gd.top_bbox[1], gd.top_bbox[2]],
        "layers" => layers,
    )
end

end # include guard
