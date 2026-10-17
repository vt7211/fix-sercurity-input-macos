#!/usr/bin/env bash
# Unit-ish: validate watchdog state JSON against scripts/watchdog-state.schema.json
# Usage:
#   validate-watchdog-state.sh [path/to/last.json]
#   validate-watchdog-state.sh --self-test
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCHEMA="$SCRIPT_DIR/watchdog-state.schema.json"
STATE_DEFAULT="${XDG_STATE_HOME:-$HOME/.local/state}/secure-input-watchdog/last.json"

self_test() {
  local tmp
  tmp=$(mktemp)
  cat > "$tmp" <<'EOF'
{
  "schema_version": 1,
  "pid": "123",
  "comm": "loginwindow",
  "first_seen": 1000,
  "last_notify": 0,
  "last_lock": 0,
  "last_clear": 900,
  "lock_failures": 0,
  "updated": 1100
}
EOF
  if ! validate_file "$tmp"; then
    echo "FAIL self-test: valid fixture rejected" >&2
    rm -f "$tmp"
    exit 1
  fi
  # missing required field
  cat > "$tmp" <<'EOF'
{"schema_version": 1, "pid": "1"}
EOF
  if validate_file "$tmp" 2>/dev/null; then
    echo "FAIL self-test: invalid fixture accepted" >&2
    rm -f "$tmp"
    exit 1
  fi
  rm -f "$tmp"
  echo "OK self-test"
}

validate_file() {
  local file="$1"
  python3 - <<PY
import json, sys
schema = json.load(open("$SCHEMA"))
data = json.load(open("$file"))
required = schema.get("required", [])
props = schema.get("properties", {})
errors = []
for k in required:
    if k not in data:
        errors.append(f"missing required: {k}")
if schema.get("additionalProperties") is False:
    for k in data:
        if k not in props:
            errors.append(f"unknown key: {k}")
for k, rules in props.items():
    if k not in data:
        continue
    v = data[k]
    t = rules.get("type")
    if t == "integer" and not isinstance(v, int):
        errors.append(f"{k}: want int, got {type(v).__name__}")
    if t == "string" and not isinstance(v, str):
        errors.append(f"{k}: want str, got {type(v).__name__}")
    if "const" in rules and v != rules["const"]:
        errors.append(f"{k}: want const {rules['const']!r}, got {v!r}")
    if "minimum" in rules and isinstance(v, int) and v < rules["minimum"]:
        errors.append(f"{k}: below minimum {rules['minimum']}")
    if "pattern" in rules and isinstance(v, str):
        import re
        if not re.fullmatch(rules["pattern"], v):
            errors.append(f"{k}: pattern mismatch {rules['pattern']!r}")
if errors:
    print("INVALID:", file=sys.stderr)
    for e in errors:
        print(" -", e, file=sys.stderr)
    sys.exit(1)
print("OK", "$file")
PY
}

if [[ "${1:-}" == "--self-test" ]]; then
  self_test
  exit 0
fi

TARGET="${1:-$STATE_DEFAULT}"
if [[ ! -f "$TARGET" ]]; then
  echo "No state file yet: $TARGET (OK — watchdog chưa chạy hoặc SI chưa từng on)"
  exit 0
fi
validate_file "$TARGET"
