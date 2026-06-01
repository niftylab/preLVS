# preLVS

Connectivity-verification + grid-netmap engine for grid-based (LAYGO) layouts,
used as a **subprocess** by the layout-migration flow.

Given a LAYGO `*_db.json` and the target-tech config, preLVS flattens the cell
hierarchy, merges metals, walks via connectivity, and reports:

1. **LVS verdict** — per-net connectivity errors (`SHORT` / `OPEN` / `FLOATING`).
2. **netmap** — which net (or `OBSTACLE`) occupies each routing-grid line.
   The migration solver uses this to fill device-internal obstacle
   `terminal_role`s and to gate on a clean LVS.

All coordinates are layer-oriented: each metal is a 1-D segment on a grid line
(`p_coord` = the line, `scope` = its extent along the line).

---

## Pipeline

```
<libname>_db.json + config + grid
        │  get_tree            hierarchy tree (+ cumulative affine, net mapping)
        │  flatten_v2          → MData (metals) + VData (vias), top-coords
        │  check_grid_consistency
        │  sort_n_merge_MData  → merged metals (1-D interval union per grid line)
        │  connect_metals_from_via      → MGraph (metals linked through vias)
        │  check_and_report_connections_bfs   → components + SHORT/OPEN/FLOATING
        │  get_grid_data        → netmap (net / OBSTACLE per grid line)
        ▼
   result JSON  (status, error_cnt, errors, top_netnames, netmap)
```

`run_prelvs` (in `run.jl`) runs all of the above in one call; `cli.jl` is the
subprocess wrapper around it.

---

## Input / Output contract

### Input — `cli.jl` reads one JSON (from a file arg or stdin)

```jsonc
{
  "libname":     "logic_generated",
  "cellname":    "inv_2x",
  "techname":    "tsmcN28",
  "db_dir":      "db",                          // dir holding <libname>_db.json
  "config_path": "config/config_tsmcN28.yaml",
  "grid_root":   ".",                            // dir holding grids/<tech>_grid.json
  "options": { "detailed": true, "emit_netmap": true }   // optional
}
```

### Output — a single JSON object on **stdout**

All logs/progress go to **stderr**, so stdout is always clean, parseable JSON.

```jsonc
{
  "target": "logic_generated - inv_2x",
  "status": "passed",                            // passed | failed | grid_error
  "error_cnt": { "short": 0, "open": 0, "floating": 0, "total": 0 },
  "errors": [                                    // empty when passed
    { "type": "FLOATING", "netname": null, "expected": null,
      "detail": "FLOATING: No netname found metals. Start node = ..." }
  ],
  "top_netnames": ["I", "VSS:", "VDD:", "O"],
  "netmap": {
    "top_bbox": [520, 1200],
    "layers": {
      "2": {                                     // layer number (M2/M3/M4)
        "orientation": "horizontal",
        "lines": {                               // keyed by grid-line coord (p_coord)
          "0": [ { "scope": [-75, 595], "netname": "VSS:" } ]
        }
      },
      "3": { "orientation": "vertical",   "lines": { "130": [ { "scope": [455, 745], "netname": "I" } ] } },
      "4": { "orientation": "horizontal", "lines": {} }
    }
  }
}
```

- `netname` is a top-level net, or the literal `"OBSTACLE"` for sub-cell
  (device-internal) geometry.
- Output is **deterministic** (stable run-to-run) — component order, error
  order, and netmap line order are all sorted.

---

## Running it

### From the migration flow (Python subprocess)

```python
import json, subprocess
from pathlib import Path

def run_prelvs(payload: dict, prelvs_root: Path) -> dict:
    proc = subprocess.run(
        ["julia", f"--project={prelvs_root}", str(prelvs_root / "cli.jl")],
        input=json.dumps(payload), capture_output=True, text=True,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"preLVS failed:\n{proc.stderr}")
    return json.loads(proc.stdout)   # {status, error_cnt, errors, top_netnames, netmap}
```

### Directly

```bash
julia --project=. cli.jl test/inputs/inv_2x.json     # input file
echo '{...}' | julia --project=. cli.jl              # input on stdin
```

---

## Setup

```bash
# Julia (>= 1.9) must be available. One contained way:
#   curl -fsSL .../julia-<ver>-linux-x86_64.tar.gz | tar -xz -C ~/.local/julia --strip-components=1
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

---

## Tests

`test/run_regression.sh` runs `cli.jl` on every `test/inputs/*.json` and diffs
the (canonicalized) output against `test/golden/*.json`:

```bash
bash test/run_regression.sh
```

---

## Layout

```
cli.jl              subprocess entry point (input JSON -> result JSON on stdout)
run.jl              run_prelvs() orchestration + result_to_dict() serialization
main_functions.jl   flatten_v2() (hierarchy flattening)
src/preLVS.jl       module: include order + exports + precompile workload
structs/            core data + algorithms
  tree.jl             hierarchy tree (get_tree)
  new_metal.jl        MData/MOData, db_to_MData, sort_n_merge_MData, grid check
  via.jl              VData, db_to_VData, transform_VData
  connectivity.jl     MGraph, connect_metals_from_via, BFS LVS check
  grid.jl             netmap (GridData, get_grid_data)
  structure.jl        affine transforms + metal-name parsing
  stack.jl, laygo_origin.jl
utils/yaml.jl       config loader (get_config, get_orientation_list)
config/             <tech>.yaml        (layer orientation, via extension, net equivalences)
grids/              <tech>_grid.json   (routing grid: scope/elements/extension/width)
db/                 sample <libname>_db.json inputs
test/               inputs/ + golden/ + run_regression.sh
examples/generators/  LAYGO generators that produce db.json (reference)
experimental/       out-of-scope code kept for reference (routing/, eval/, viz)
```

## Module API

```julia
using preLVS

# One-call pipeline (what cli.jl uses):
res = run_prelvs("logic_generated", "inv_2x", "tsmcN28";
                 db_dir="db", config_path="config/config_tsmcN28.yaml", grid_root=".")
dict = result_to_dict(res)          # JSON-serializable

# Lower-level stage functions are also exported (get_tree, flatten_v2,
# sort_n_merge_MData, connect_metals_from_via, check_and_report_connections_bfs,
# get_grid, create_empty_grid_data, get_grid_data).
```
