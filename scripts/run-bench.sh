#!/usr/bin/env bash
#
# run-bench.sh — KitBench runner
#
# Reads every scenario in bench/scenarios/*.json, runs the named hook with
# the scenario's stdin payload + env, and asserts the result matches.
# Pure-determinism eval — no LLM, no network, no shared state between scenarios
# (each runs in a fresh temp dir).
#
# Usage:
#   ./scripts/run-bench.sh                     # run all scenarios
#   ./scripts/run-bench.sh --scenario s01      # run one
#   ./scripts/run-bench.sh --filter protect    # name contains
#   ./scripts/run-bench.sh --verbose           # print stdout/stderr per scenario
#   ./scripts/run-bench.sh --json              # emit machine-readable summary
#
# Exit codes:
#   0  all scenarios passed
#   1  one or more scenarios failed
#   2  runner error (bad scenario file, missing python3, etc.)
#

set -uo pipefail

KIT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCENARIOS_DIR="$KIT_ROOT/bench/scenarios"

if ! command -v python3 >/dev/null 2>&1; then
  echo "run-bench: python3 is required (deterministic JSON handling)" >&2
  exit 2
fi

if [ ! -d "$SCENARIOS_DIR" ]; then
  echo "run-bench: $SCENARIOS_DIR does not exist" >&2
  exit 2
fi

SCENARIO_FILTER=""
NAME_FILTER=""
VERBOSE=0
JSON_OUT=0

while [[ $# -gt 0 ]]; do
  case $1 in
    --scenario|-s) SCENARIO_FILTER="$2"; shift 2 ;;
    --filter|-f) NAME_FILTER="$2"; shift 2 ;;
    --verbose|-v) VERBOSE=1; shift ;;
    --json) JSON_OUT=1; shift ;;
    --help|-h)
      sed -n '1,/^set -uo pipefail/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

KIT_ROOT="$KIT_ROOT" \
SCENARIOS_DIR="$SCENARIOS_DIR" \
SCENARIO_FILTER="$SCENARIO_FILTER" \
NAME_FILTER="$NAME_FILTER" \
VERBOSE="$VERBOSE" \
JSON_OUT="$JSON_OUT" \
exec python3 - <<'PY'
import json, os, sys, subprocess, tempfile, shutil

KIT_ROOT = os.environ["KIT_ROOT"]
SCENARIOS_DIR = os.environ["SCENARIOS_DIR"]
SCENARIO_FILTER = os.environ.get("SCENARIO_FILTER", "") or ""
NAME_FILTER = os.environ.get("NAME_FILTER", "") or ""
VERBOSE = os.environ.get("VERBOSE") == "1"
JSON_OUT = os.environ.get("JSON_OUT") == "1"

def load_scenarios():
    out = []
    for name in sorted(os.listdir(SCENARIOS_DIR)):
        if not name.endswith(".json"):
            continue
        path = os.path.join(SCENARIOS_DIR, name)
        with open(path) as f:
            try:
                data = json.load(f)
            except json.JSONDecodeError as e:
                raise SystemExit(f"run-bench: malformed scenario {name}: {e}")
        # Each scenario file may contain one scenario (dict) or many (list)
        items = data if isinstance(data, list) else [data]
        for s in items:
            if "name" not in s:
                raise SystemExit(f"run-bench: scenario in {name} is missing 'name'")
            out.append((path, s))
    return out

def apply_filter(scenarios):
    if SCENARIO_FILTER:
        scenarios = [(p, s) for p, s in scenarios if s["name"] == SCENARIO_FILTER]
    if NAME_FILTER:
        scenarios = [(p, s) for p, s in scenarios if NAME_FILTER in s["name"]]
    return scenarios

def write_setup_files(workdir, files):
    for relpath, content in (files or {}).items():
        full = os.path.join(workdir, relpath)
        os.makedirs(os.path.dirname(full) or ".", exist_ok=True)
        with open(full, "w") as f:
            f.write(content if content is not None else "")

def substitute(value, workdir):
    if isinstance(value, str):
        return value.replace("{TMPROOT}", workdir).replace("{KIT_ROOT}", KIT_ROOT)
    if isinstance(value, dict):
        return {k: substitute(v, workdir) for k, v in value.items()}
    if isinstance(value, list):
        return [substitute(v, workdir) for v in value]
    return value

def load_state_field(workdir, path, field):
    full = os.path.join(workdir, path)
    if not os.path.isfile(full):
        return None, f"state file missing: {path}"
    try:
        with open(full) as f:
            d = json.load(f)
    except Exception as e:
        return None, f"state file unreadable: {e}"
    cur = d
    for part in field.split("."):
        if not isinstance(cur, dict) or part not in cur:
            return None, f"state field {field!r} not present"
        cur = cur[part]
    return cur, None

def run_scenario(scenario):
    name = scenario["name"]
    hook_rel = scenario["hook"]
    hook_path = os.path.join(KIT_ROOT, hook_rel)
    if not os.path.isfile(hook_path):
        return False, [f"hook not found at {hook_rel}"], "", ""

    workdir = tempfile.mkdtemp(prefix=f"kitbench-{name}-")
    # Provide a "project root" marker so hooks that walk up to find one stop here
    open(os.path.join(workdir, "package.json"), "w").close()

    try:
        write_setup_files(workdir, scenario.get("setup_files"))
        payload = substitute(scenario.get("payload", {}), workdir)

        env = os.environ.copy()
        # Ensure hooks resolve project root to our workdir
        env["CLAUDE_PROJECT_DIR"] = workdir
        # Apply scenario env overrides
        for k, v in (scenario.get("env") or {}).items():
            env[k] = str(v)

        # Run hook with payload as stdin
        proc = subprocess.run(
            ["bash", hook_path],
            input=json.dumps(payload),
            text=True,
            capture_output=True,
            cwd=workdir,
            env=env,
        )

        failures = []

        # exit_code
        if "exit_code" in scenario.get("expect", {}):
            want = scenario["expect"]["exit_code"]
            if proc.returncode != want:
                failures.append(f"exit_code: want {want}, got {proc.returncode}")

        # stderr_contains
        for needle in scenario.get("expect", {}).get("stderr_contains", []):
            if needle not in (proc.stderr or ""):
                failures.append(f"stderr missing substring {needle!r}")

        # stderr_not_contains
        for needle in scenario.get("expect", {}).get("stderr_not_contains", []):
            if needle in (proc.stderr or ""):
                failures.append(f"stderr unexpectedly contains {needle!r}")

        # stdout_contains
        for needle in scenario.get("expect", {}).get("stdout_contains", []):
            if needle not in (proc.stdout or ""):
                failures.append(f"stdout missing substring {needle!r}")

        # stdout_not_contains
        for needle in scenario.get("expect", {}).get("stdout_not_contains", []):
            if needle in (proc.stdout or ""):
                failures.append(f"stdout unexpectedly contains {needle!r}")

        # stdout_empty
        if scenario.get("expect", {}).get("stdout_empty", False):
            if (proc.stdout or "").strip() != "":
                failures.append(f"stdout expected empty, got {len(proc.stdout)} chars")

        # state_assertions (list of {file, field, value})
        for assertion in scenario.get("expect", {}).get("state", []):
            value, err = load_state_field(
                workdir, assertion["file"], assertion["field"]
            )
            if err:
                failures.append(f"state {assertion['file']}.{assertion['field']}: {err}")
                continue
            if "equals" in assertion and value != assertion["equals"]:
                failures.append(
                    f"state {assertion['file']}.{assertion['field']}: want {assertion['equals']!r}, got {value!r}"
                )
            if "gte" in assertion and not (isinstance(value, int) and value >= assertion["gte"]):
                failures.append(
                    f"state {assertion['file']}.{assertion['field']}: want >= {assertion['gte']}, got {value!r}"
                )

        # file_grew (audit log line added)
        for fg in scenario.get("expect", {}).get("file_grew", []):
            full = os.path.join(workdir, fg)
            if not os.path.isfile(full):
                failures.append(f"file expected to exist: {fg}")
                continue
            if os.path.getsize(full) == 0:
                failures.append(f"file expected non-empty: {fg}")

        # file_absent (state cleared / never created)
        for fa in scenario.get("expect", {}).get("file_absent", []):
            full = os.path.join(workdir, fa)
            if os.path.exists(full):
                failures.append(f"file expected absent: {fa}")

        return (not failures), failures, proc.stdout, proc.stderr
    finally:
        shutil.rmtree(workdir, ignore_errors=True)

scenarios = apply_filter(load_scenarios())
if not scenarios:
    msg = "no scenarios matched"
    if SCENARIO_FILTER or NAME_FILTER:
        msg += f" (filter: scenario={SCENARIO_FILTER!r} name={NAME_FILTER!r})"
    print(msg, file=sys.stderr)
    sys.exit(2)

results = []
for path, scenario in scenarios:
    ok, failures, out, err = run_scenario(scenario)
    results.append({
        "name": scenario["name"],
        "ok": ok,
        "failures": failures,
        "stdout": out,
        "stderr": err,
    })

pad = max(len(r["name"]) for r in results) + 2

if JSON_OUT:
    summary = {
        "total": len(results),
        "passed": sum(1 for r in results if r["ok"]),
        "failed": sum(1 for r in results if not r["ok"]),
        "results": [{k: v for k, v in r.items() if k != "stdout" and k != "stderr"} for r in results],
    }
    print(json.dumps(summary, indent=2))
else:
    print("KitBench")
    print("=" * 40)
    for r in results:
        status = "PASS" if r["ok"] else "FAIL"
        print(f"  {r['name']:<{pad}} {status}")
        if not r["ok"]:
            for line in r["failures"]:
                print(f"    - {line}")
            if VERBOSE:
                if r["stdout"]:
                    print("    stdout:", r["stdout"].rstrip())
                if r["stderr"]:
                    print("    stderr:", r["stderr"].rstrip())
        elif VERBOSE and (r["stdout"] or r["stderr"]):
            if r["stdout"]:
                print("    stdout:", r["stdout"].rstrip())
            if r["stderr"]:
                print("    stderr:", r["stderr"].rstrip())
    print("=" * 40)
    passed = sum(1 for r in results if r["ok"])
    failed = sum(1 for r in results if not r["ok"])
    print(f"  {passed}/{len(results)} PASS  {failed} FAIL")

sys.exit(0 if all(r["ok"] for r in results) else 1)
PY
