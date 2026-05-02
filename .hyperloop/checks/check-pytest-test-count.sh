#!/usr/bin/env bash
# check-pytest-test-count.sh
#
# Verifies the number of Python test functions (^def test_) across all *.py files
# in extractor/tests/ on the current branch is NOT less than the count on origin/main.
#
# Mirrors check-run-tests-suite-count.sh but for Python pytest rather than GDScript
# _run_suite() registrations.
#
# Observed pattern (task-063, round 3):
#   Branch had 254 pytest tests; origin/main had 264. The 10 missing tests were added
#   to main by task-023 (betweenness centrality) and task-040 (edge weight) after the
#   branch forked at 53b1865. Because the branch was never rebased onto origin/main,
#   those tests were silently absent. check-pytest-passes.sh exited 0 (all 254 remaining
#   tests passed) and check-run-tests-suite-count.sh only covers GDScript suites — the
#   Python regression was invisible to all mechanical checks. The verifier caught it
#   manually by running extractor-lint.sh against both branch and origin/main.
#
# This check fills the gap: a drop in Python test count relative to origin/main is
# always a regression, almost always caused by a missing rebase.
#
# Exit 0 = branch test count >= origin/main count (no tests removed).
# Exit 1 = branch test count < origin/main count (regression — tests removed).
# Exit 0 (SKIP) = no extractor/tests/ directory, or origin/main has 0 test functions.

set -uo pipefail

TESTS_DIR="extractor/tests"

if [[ ! -d "$TESTS_DIR" ]]; then
    echo "SKIP: No $TESTS_DIR/ directory found — Python test count check not applicable."
    exit 0
fi

# Fetch to ensure origin/main is current before comparison.
git fetch origin main:main --quiet 2>/dev/null || true

# Count test functions (^def test_) on origin/main across all .py files in TESTS_DIR.
MAIN_COUNT=0
while IFS= read -r filepath; do
    c=$(git show "origin/main:${filepath}" 2>/dev/null | grep -c "^def test_" || echo "0")
    MAIN_COUNT=$(( MAIN_COUNT + c ))
done < <(git ls-tree -r --name-only origin/main -- "$TESTS_DIR" 2>/dev/null | grep "\.py$" || true)

if [[ "$MAIN_COUNT" -eq 0 ]]; then
    # Count branch tests before deciding to SKIP, to detect suspicious states.
    BRANCH_COUNT_EARLY=0
    while IFS= read -r f; do
        c=$(grep -c "^def test_" "$f" 2>/dev/null || true)
        BRANCH_COUNT_EARLY=$(( BRANCH_COUNT_EARLY + ${c:-0} ))
    done < <(find "$TESTS_DIR" -name "*.py" 2>/dev/null || true)

    if [[ "$BRANCH_COUNT_EARLY" -gt 0 ]]; then
        echo "WARN: origin/main shows 0 test functions but this branch has $BRANCH_COUNT_EARLY."
        echo "  This almost always means the 'git fetch origin main:main' above failed"
        echo "  silently (network/auth issue), so the local origin/main is stale."
        echo ""
        echo "  Verify manually before accepting this SKIP:"
        echo "    git fetch origin main:main"
        echo "    git ls-tree -r --name-only origin/main -- $TESTS_DIR | grep '\\.py\$'"
        echo "    # If files appear, re-run this check — the count will be non-zero."
        echo ""
        echo "  If the fetch truly shows 0 tests on origin/main, this SKIP is correct."
        echo "SKIP: Could not confirm origin/main test count — manual fetch verification required."
    else
        echo "SKIP: origin/main has 0 test functions in $TESTS_DIR/ — nothing to compare."
    fi
    exit 0
fi

# Count test functions in the working tree across all .py files in TESTS_DIR.
BRANCH_COUNT=0
while IFS= read -r f; do
    c=$(grep -c "^def test_" "$f" 2>/dev/null || echo "0")
    BRANCH_COUNT=$(( BRANCH_COUNT + c ))
done < <(find "$TESTS_DIR" -name "*.py" 2>/dev/null || true)

if [[ "$BRANCH_COUNT" -ge "$MAIN_COUNT" ]]; then
    echo "OK: Python test count on branch ($BRANCH_COUNT) >= origin/main ($MAIN_COUNT)."
    exit 0
fi

MISSING=$(( MAIN_COUNT - BRANCH_COUNT ))
echo "FAIL: Branch has fewer Python test functions than origin/main."
echo ""
echo "  origin/main: $MAIN_COUNT test function(s) in $TESTS_DIR/"
echo "  This branch: $BRANCH_COUNT test function(s) in $TESTS_DIR/"
echo "  Missing:     $MISSING test(s)"
echo ""
echo "  Tests absent from this branch were added to origin/main after the branch"
echo "  forked. They are silently absent — check-pytest-passes.sh exits 0 because"
echo "  only the remaining tests run. Root cause: branch not rebased onto main."
echo ""
echo "  Diagnostic — find which tests exist on main but not on branch:"
echo "    diff <(git ls-tree -r --name-only origin/main -- $TESTS_DIR | grep '.py$' \\"
echo "           | xargs -I{} git show origin/main:{} | grep '^def test_') \\"
echo "         <(find $TESTS_DIR -name '*.py' | xargs grep '^def test_')"
echo ""
echo "  Fix: rebase onto origin/main and resolve conflicts keeping main's tests:"
echo "    git fetch origin main:main"
echo "    git rebase origin/main"
echo "    bash .hyperloop/checks/check-pytest-test-count.sh   # must exit 0"
echo "    bash .hyperloop/checks/run-all-checks.sh"
exit 1
