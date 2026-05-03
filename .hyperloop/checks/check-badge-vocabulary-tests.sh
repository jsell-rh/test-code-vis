#!/usr/bin/env bash
# check-badge-vocabulary-tests.sh
#
# Verifies that all 8 required badge vocabulary types have dedicated
# test functions in godot/tests/test_visual_primitives.gd.
#
# The spec (visual-primitives.spec.md) mandates support for exactly
# these badge types: pure, io, async, stateful, error_handling, test,
# entry_point, deprecated.
#
# Each MUST have a dedicated test function named:
#   func test_badge_vocabulary_<type>():
# that asserts the specific "Badge_<type>" child name — not just a
# count or a begins_with("Badge_") check.
#
# Observed gap (task-076): error_handling and entry_point appeared only
# as incidental fixtures in other tests (count assertion, begins_with
# assertion). No dedicated test_badge_vocabulary_error_handling() or
# test_badge_vocabulary_entry_point() function existed. The verifier
# classified both as PARTIAL.
#
# BASELINE COMPARISON (branch attribution):
# If origin/main also fails this check (the gap is pre-existing), this
# script exits 0 with a WARN — the gap is not attributable to the current
# branch. Only exits 1 (FAIL) when the BRANCH introduced the regression
# (i.e., origin/main passes but the working tree fails).
#
# Observed gap (task-001 Round 6): check-badge-vocabulary-tests.sh failed
# on origin/main itself (error_handling + entry_point missing). Every task
# running run-all-checks.sh received a spurious FAIL for a pre-existing
# gap unrelated to their work. Baseline comparison prevents this.
#
# Exit 0 — all 8 vocabulary types have dedicated test functions
# Exit 0 (WARN) — gap is pre-existing on origin/main (not introduced by this branch)
# Exit 1 — branch introduced a regression (origin/main passes, branch fails)
# Exit 0 (SKIP) — test_visual_primitives.gd not found (not applicable)

set -euo pipefail

TEST_FILE="godot/tests/test_visual_primitives.gd"

if [ ! -f "$TEST_FILE" ]; then
    echo "SKIP: $TEST_FILE not found — badge vocabulary tests not yet applicable."
    exit 0
fi

REQUIRED_BADGES=(pure io async stateful error_handling test entry_point deprecated)
MISSING=()

for badge in "${REQUIRED_BADGES[@]}"; do
    if ! grep -q "func test_badge_vocabulary_${badge}()" "$TEST_FILE"; then
        MISSING+=("$badge")
    fi
done

if [ ${#MISSING[@]} -eq 0 ]; then
    echo "OK: All 8 required badge vocabulary types have dedicated test functions."
    echo "  Verified in: $TEST_FILE"
    exit 0
fi

# ---- BASELINE COMPARISON — branch attribution ----
# Check if origin/main also fails for the same missing badges.
# If the gap pre-dates this branch, exit 0 with WARN (not a branch regression).
MISSING_ON_MAIN=()
if git cat-file -e "origin/main:${TEST_FILE}" 2>/dev/null; then
    for badge in "${MISSING[@]}"; do
        if ! git show "origin/main:${TEST_FILE}" | grep -q "func test_badge_vocabulary_${badge}()"; then
            MISSING_ON_MAIN+=("$badge")
        fi
    done
fi

# Compute branch-introduced regressions (missing here but present on main)
BRANCH_REGRESSIONS=()
for badge in "${MISSING[@]}"; do
    pre_existing=false
    for main_badge in "${MISSING_ON_MAIN[@]}"; do
        if [ "$badge" = "$main_badge" ]; then
            pre_existing=true
            break
        fi
    done
    if [ "$pre_existing" = false ]; then
        BRANCH_REGRESSIONS+=("$badge")
    fi
done

if [ ${#BRANCH_REGRESSIONS[@]} -eq 0 ]; then
    echo "WARN: Missing badge vocabulary tests — but gap is pre-existing on origin/main."
    echo "  Missing (same on main): ${MISSING[*]}"
    echo "  This branch did NOT introduce the gap. A separate task must add these tests."
    echo "  Pre-existing gap does NOT count as FAIL for this branch."
    echo ""
    echo "  Required tests to add (separate task):"
    for badge in "${MISSING[@]}"; do
        echo "    func test_badge_vocabulary_${badge}():"
        echo "        # Must assert child.name == \"Badge_${badge}\""
    done
    exit 0
fi

# Branch DID introduce regressions — this is a real FAIL.
echo "FAIL: Branch removed badge vocabulary test functions present on origin/main."
echo "  Regressions introduced by this branch: ${BRANCH_REGRESSIONS[*]}"
echo ""
echo "The spec mandates support for 8 badge types:"
echo "  pure, io, async, stateful, error_handling, test, entry_point, deprecated"
echo ""
echo "Each requires a dedicated function in $TEST_FILE:"
for badge in "${BRANCH_REGRESSIONS[@]}"; do
    echo "  func test_badge_vocabulary_${badge}():"
    echo "      # Must assert the specific child name 'Badge_${badge}'"
    echo "      # Pattern: attach_primitives(node, [\"${badge}\"])"
    echo "      #          assert child.name == \"Badge_${badge}\""
    echo ""
done
echo "A test that uses ${BRANCH_REGRESSIONS[0]} as one of multiple badges in a count assertion"
echo "does NOT satisfy this requirement — the specific Badge_<type> name must"
echo "be asserted directly."
exit 1
