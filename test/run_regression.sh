#!/usr/bin/env bash
# Regression check: run cli.jl on each test input and diff its (canonicalized)
# JSON output against the saved golden. Exit non-zero on any mismatch.
#
# Usage:  bash test/run_regression.sh
# Env:    JULIA  (default: ~/.local/julia/bin/julia)
set -u
cd "$(dirname "$0")/.."                       # preLVS root
JULIA="${JULIA:-$HOME/.local/julia/bin/julia}"

fail=0
for inp in test/inputs/*.json; do
    name="$(basename "$inp" .json)"
    gold="test/golden/${name}.json"
    out="$(mktemp)"
    "$JULIA" --project=. cli.jl "$inp" 1>"$out" 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "FAIL  $name : cli.jl exited non-zero"; fail=1; continue
    fi
    # canonicalize both sides (sorted keys) and diff
    if python3 -c "
import json,sys
a=json.load(open('$out')); b=json.load(open('$gold'))
sys.exit(0 if json.dumps(a,sort_keys=True)==json.dumps(b,sort_keys=True) else 1)
"; then
        echo "PASS  $name"
    else
        echo "FAIL  $name : output differs from golden"
        python3 -c "
import json
a=json.load(open('$out')); b=json.load(open('$gold'))
print('  got status =',a.get('status'),'error_cnt=',a.get('error_cnt'))
print('  exp status =',b.get('status'),'error_cnt=',b.get('error_cnt'))"
        fail=1
    fi
    rm -f "$out"
done
exit $fail
