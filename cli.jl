# ===========================================================================
# cli.jl - Subprocess entry point for the layout-migration flow.
#
# Usage (from the migration flow):
#   julia --project=<preLVS_root> cli.jl <input.json> <output.json>
#   julia --project=<preLVS_root> cli.jl <input.json>   # result on stdout
#   julia --project=<preLVS_root> cli.jl                # input on stdin
#
# The migration flow always passes <output.json> (file contract,
# 2026-08-12): stdout as a data channel is vulnerable to external
# pollution — juliaup's periodic version-DB update wrote to stdout and
# broke JSON parsing on the compute server (measured incident).
#
# Input JSON:
#   {
#     "libname":     "logic_generated",
#     "cellname":    "inv_2x",
#     "techname":    "tsmcN28",
#     "db_dir":      "<dir holding <libname>_db.json>",
#     "config_path": "<path to tech config yaml>",
#     "grid_root":   "<dir holding grids/<techname>_grid.json>",  // default "."
#     "options": { "detailed": true, "emit_netmap": true }        // optional
#   }
#
# Output: a single JSON object on STDOUT (see run.jl result_to_dict / README).
# Everything else (progress, warnings, logs) goes to STDERR so STDOUT stays
# clean and parseable by the calling process.
# ===========================================================================

using preLVS
using JSON

function main()
    raw = isempty(ARGS) ? read(stdin, String) : read(ARGS[1], String)
    inp = JSON.parse(raw)

    opts = get(inp, "options", Dict{String, Any}())

    # Run the whole pipeline with stdout redirected to stderr, so the only
    # thing written to the real stdout is the final JSON below.
    result = redirect_stdout(stderr) do
        run_prelvs(
            String(inp["libname"]),
            String(inp["cellname"]),
            String(inp["techname"]);
            db_dir      = String(inp["db_dir"]),
            config_path = String(inp["config_path"]),
            grid_root   = String(get(inp, "grid_root", ".")),
            detailed    = Bool(get(opts, "detailed", true)),
            emit_netmap = Bool(get(opts, "emit_netmap", true)),
        )
    end

    if length(ARGS) >= 2
        open(ARGS[2], "w") do io
            JSON.print(io, result_to_dict(result))
        end
    else
        JSON.print(stdout, result_to_dict(result))
        println(stdout)
    end
    return 0
end

main()
