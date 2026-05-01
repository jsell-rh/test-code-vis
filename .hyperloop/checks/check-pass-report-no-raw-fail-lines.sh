#!/usr/bin/env bash
# check-pass-report-no-raw-fail-lines.sh
#
# VERIFIER GUARD: Prevents embedding raw [EXIT N — FAIL] text in PASS reports.
#
# Background:
#   check-no-zero-commit-reattempt.sh walks commit history looking for prior
#   FAIL reports by grepping for '[EXIT [1-9]' patterns.  A verifier PASS report
#   that quotes transient check failures (e.g., check-report-scope-section.sh
#   failing before the stub was written) embeds these patterns verbatim.  When
#   that PASS report is committed, subsequent cycles treat it as a genuine prior
#   FAIL and require implementation commits that may not be possible.
#
# Observed failure (task-021 / data-flow.spec.md):
#   A verifier PASS report quoted:
#     "check-report-scope-section.sh: [EXIT 1 — FAIL] (NOTE: Expected
#      pre-report failure; file is being written now.)"
#   A subsequent implementer was deadlocked — check-no-zero-commit-reattempt.sh
#   found that committed FAIL-line pattern in history and required implementation
#   commits for a permanently prohibited spec.
#
# What this check does:
#   If the working-tree worker-result.yaml:
#     (A) indicates a PASS verdict — "RESULT: ALL PASS" from run-all-checks.sh,
#         OR a human-written "verdict: pass" line, AND
#     (B) contains '[EXIT [1-9]' patterns from embedded check output,
#   then exit 1.  The PASS + embedded FAIL combination is a contradiction: if
#   all checks actually passed, no check emits an [EXIT N — FAIL] line, so no
#   such pattern should appear in the report.
#
# Correct approach for verifiers:
#   Follow the ordering rule: write the worker-result.yaml stub FIRST (containing
#   at minimum the ## Scope Check Output section), THEN run run-all-checks.sh.
#   With the stub in place, check-report-scope-section.sh finds the scope section
#   and passes — no [EXIT N — FAIL] appears in the run-all-checks.sh output at all.
#   The pre-report artifact problem is eliminated entirely.
#
# If you must describe a transient failure, use plain prose — NOT raw check output:
#   WRONG — triggers deadlock:
#     "check-report-scope-section.sh: [EXIT 1 — FAIL] (NOTE: expected artifact)"
#   RIGHT — safe:
#     "check-report-scope-section.sh was expected to fail before the stub existed.
#      This is a pre-report artifact, not a genuine unresolved failure."
#
# Exit 0: No contradiction detected (file absent, not a PASS, or no FAIL lines).
# Exit 1: PASS report embeds raw [EXIT N — FAIL] lines — must rephrase.

set -uo pipefail

RESULT_FILE=".hyperloop/worker-result.yaml"

# ── File existence / content check ───────────────────────────────────────────
if [[ ! -f "$RESULT_FILE" ]]; then
    echo "SKIP: $RESULT_FILE not found — no report to validate."
    exit 0
fi

CONTENT=$(cat "$RESULT_FILE" 2>/dev/null || true)

if [[ -z "$CONTENT" ]]; then
    echo "SKIP: $RESULT_FILE is empty — no report to validate."
    exit 0
fi

# ── Detect PASS verdict indicators ────────────────────────────────────────────
# Signal A: "RESULT: ALL PASS" — emitted by run-all-checks.sh only when every
#   check exits 0.  Its presence in a report means the embedded run-all-checks.sh
#   output showed all checks passing.
# Signal B: "verdict: pass" — human-written verdict line (case-insensitive).
#   Anchored to start of line with optional leading whitespace to avoid matching
#   prose like "The previous verdict was PASS on the prior round."

PASS_SIGNAL=0

if echo "$CONTENT" | grep -q "RESULT: ALL PASS"; then
    PASS_SIGNAL=1
fi

if echo "$CONTENT" | grep -qiE "^[[:space:]]*verdict:[[:space:]]*pass"; then
    PASS_SIGNAL=1
fi

if [[ "$PASS_SIGNAL" -eq 0 ]]; then
    echo "SKIP: Report does not contain a PASS verdict indicator — check not applicable."
    exit 0
fi

# ── Detect embedded [EXIT N — FAIL] patterns ─────────────────────────────────
# run-all-checks.sh emits "[EXIT N — FAIL]" (where N >= 1) for every check that
# exits non-zero.  These patterns should NEVER appear in a genuine PASS report
# because a genuine PASS requires all checks to exit 0.

if ! echo "$CONTENT" | grep -qE '\[EXIT [1-9][0-9]* — FAIL\]|\[EXIT [1-9]'; then
    echo "OK: PASS report contains no embedded [EXIT N — FAIL] patterns."
    exit 0
fi

# ── Contradiction detected ────────────────────────────────────────────────────
EMBEDDED_LINES=$(echo "$CONTENT" | grep -E '\[EXIT [1-9]' | head -5)

echo "FAIL: PASS report contains embedded [EXIT N — FAIL] lines."
echo ""
echo "  A report indicating a PASS verdict MUST NOT contain raw '[EXIT N — FAIL]'"
echo "  text.  These patterns cause check-no-zero-commit-reattempt.sh to treat"
echo "  this committed report as a 'prior FAIL', deadlocking future implementers"
echo "  on this branch who have made no implementation changes since your commit."
echo ""
echo "  Detected pattern(s) (first 5):"
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    echo "    $line"
done <<< "$EMBEDDED_LINES"
echo ""
echo "  Root cause: run-all-checks.sh was probably run BEFORE writing the"
echo "  worker-result.yaml stub, causing check-report-scope-section.sh to fail"
echo "  (pre-report artifact).  That failure appears in your embedded output."
echo ""
echo "  Resolution (follow the mandatory verifier ordering rule):"
echo "    1. Delete or blank the current worker-result.yaml."
echo "    2. Write a stub with at minimum the '## Scope Check Output' section."
echo "    3. Re-run: bash .hyperloop/checks/run-all-checks.sh"
echo "    4. All checks should now pass — paste the CLEAN output (no FAIL lines)."
echo "    5. Expand the stub into your full PASS report without embedded FAIL text."
echo ""
echo "  If you MUST describe a transient failure, use plain prose:"
echo "    WRONG: 'check-report-scope-section.sh: [EXIT 1 — FAIL] (NOTE: expected)'"
echo "    RIGHT: 'check-report-scope-section.sh was expected to fail before the stub"
echo "            existed. This is a pre-report artifact, not a genuine failure.'"
echo ""
echo "EXIT 1 — Rephrase, or re-run checks with stub written first, before committing."
exit 1
