#!/usr/bin/env bash
# check-no-vacuous-iteration.sh
#
# Detects vacuous iteration guards in Python test files:
#
#   BAD (vacuous — test passes silently when collection is empty):
#     if ip_entries:
#         for ip in ip_entries:
#             assert "call_name" in ip
#
#   GOOD (test fails correctly when collection is empty):
#     assert ip_entries, "caller → callee must produce at least one entry"
#     for ip in ip_entries:
#         assert "call_name" in ip
#
# When a spec THEN-clause is categorical ("the spine MUST include…"),
# the test must assert the collection is non-empty. An `if collection:`
# guard silently passes with zero entries, giving false coverage confidence.
#
# Observed failure (task-029): test_interprocedural_entries_have_required_keys
# used `if ip_entries:` before iterating. The spec required the spine to
# include a cross-call link, but the test passed vacuously with zero entries.
#
# Exit codes:
#   0 — no vacuous iteration guards found (or no test files exist — SKIP)
#   1 — at least one vacuous guard detected

set -uo pipefail

FAIL=0

# Find all Python test files under extractor/tests
mapfile -t TEST_FILES < <(find extractor/tests -name "test_*.py" 2>/dev/null | sort)

if [ "${#TEST_FILES[@]}" -eq 0 ]; then
    echo "SKIP: no Python test files found under extractor/tests/"
    exit 0
fi

# Use Python to detect the pattern: inside a test function, an `if <var>:`
# line immediately followed (within 5 lines) by `for ... in <var>:`.
python3 - "${TEST_FILES[@]}" << 'PYEOF'
import sys
import re

paths = sys.argv[1:]
violations = []

for path in paths:
    try:
        lines = open(path).read().splitlines()
    except OSError:
        continue

    for i, line in enumerate(lines):
        # Match: whitespace + "if" + identifier + ":"
        m = re.match(r'^(\s+)if\s+([a-z_][a-z_0-9]*)\s*:\s*$', line)
        if not m:
            continue
        varname = m.group(2)

        # Only flag inside a test function (look back up to 30 lines for def test_)
        in_test = any(
            re.match(r'\s*def test_', lines[j])
            for j in range(max(0, i - 30), i)
        )
        if not in_test:
            continue

        # Look ahead up to 5 lines for `for ... in <varname>:`
        for j in range(i + 1, min(i + 6, len(lines))):
            if re.search(rf'\bfor\b.+\bin\s+{re.escape(varname)}\b', lines[j]):
                violations.append(
                    f"  {path}:{i + 1}: `if {varname}:` is a vacuous guard — "
                    f"use `assert {varname}, \"<message>\"` instead"
                )
                break

if violations:
    print("")
    print("FAIL: vacuous iteration guard(s) detected in test files.")
    print("These tests pass silently when the collection is empty,")
    print("giving false coverage for spec THEN-clauses that require non-empty output.")
    print("")
    for v in violations:
        print(v)
    print("")
    print("Fix: replace `if <var>:` with `assert <var>, \"<descriptive message>\"` before the loop.")
    sys.exit(1)
else:
    print("OK: no vacuous iteration guards detected in Python test files.")
    sys.exit(0)
PYEOF
