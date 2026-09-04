#!/usr/bin/env bash
# Runs everything that can be checked without opening Studio:
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

echo "== parse"
if [ -x "$COMPILE" ]; then
  fail=0
  while IFS= read -r file; do
    if ! out=$("$COMPILE" --binary "$file" 2>&1 >/dev/null) || [ -n "$out" ]; then
      echo "  $file"; echo "$out"; fail=1
    fi
  done < <(find src -name '*.lua' | sort)
  if [ $fail -eq 0 ]; then echo "  ok ($(find src -name '*.lua' | wc -l) files)"; else status=1; fi
else
  echo "  skipped (luau-compile not found)"
fi

echo
echo "== requires"
python3 tools/check_requires.py || status=1

echo
echo "== config self-test"
if [ -n "$LUAU" ] && [ -x "$LUAU" ]; then
  python3 tools/selftest.py "$LUAU" | tail -3 || status=1
else
  echo "  skipped (luau not found)"
fi

echo
echo "== balance"
if python3 tools/balance.py > /dev/null; then
  python3 tools/balance.py | tail -6
else
  echo "  FAILED"; status=1
fi

echo
if [ $status -eq 0 ]; then echo "All checks passed."; else echo "Some checks FAILED."; fi
exit $status
