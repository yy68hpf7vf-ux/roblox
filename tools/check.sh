#!/usr/bin/env bash
# Runs everything that can be checked without opening Studio, for both games:
#
#   1. every source file parses as Luau
#   2. every require() resolves, and there are no cycles
#   3. the shared config layer passes its self-test
#   4. the economy simulation still runs
#
# Usage:  tools/check.sh [path/to/luau]
#
# The luau interpreter (https://github.com/luau-lang/luau/releases) is optional;
# steps 1 and 3 are skipped without it, and the script says so.
set -uo pipefail
cd "$(dirname "$0")/.."

LUAU="${1:-$(command -v luau || true)}"
COMPILE="${LUAU%luau}luau-compile"
status=0

# name:project-dir:balance-script
GAMES=(
  "Rift Miner:.:tools/balance.py"
  "Monster Motel:games/monster-motel:games/monster-motel/tools/balance.py"
)

for entry in "${GAMES[@]}"; do
  IFS=: read -r name dir balance <<< "$entry"
  echo "############ $name"

  echo "== parse"
  if [ -x "$COMPILE" ]; then
    fail=0
    while IFS= read -r file; do
      if ! out=$("$COMPILE" --binary "$file" 2>&1 >/dev/null) || [ -n "$out" ]; then
        echo "  $file"; echo "$out"; fail=1
      fi
    done < <(find "$dir/src" -name '*.lua' | sort)
    count=$(find "$dir/src" -name '*.lua' | wc -l)
    if [ $fail -eq 0 ]; then echo "  ok ($count files)"; else status=1; fi
  else
    echo "  skipped (luau-compile not found)"
  fi

  echo "== requires"
  python3 tools/check_requires.py "$dir" || status=1

  echo "== config self-test"
  if [ -n "$LUAU" ] && [ -x "$LUAU" ]; then
    python3 tools/selftest.py "$LUAU" "$dir" | tail -2 || status=1
  else
    echo "  skipped (luau not found)"
  fi

  echo "== balance"
  if python3 "$balance" > /dev/null; then
    echo "  ok"
  else
    echo "  FAILED"; status=1
  fi
  echo
done

if [ $status -eq 0 ]; then echo "All checks passed."; else echo "Some checks FAILED."; fi
exit $status
