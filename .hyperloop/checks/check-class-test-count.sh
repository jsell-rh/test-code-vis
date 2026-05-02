#!/usr/bin/env bash
# check-class-test-count.sh
#
# Counts ALL Python test functions (any "def test_" regardless of indentation)
# across extractor/tests/*.py and compares the branch count to origin/main.
#
# This is the class-method-inclusive COMPLEMENT to check-pytest-test-count.sh,
# which counts only TOP-LEVEL ^def test_ functions. That top-level check passes
# silently when class-method tests are dropped (because adding even one top-level
# test can compensate for dozens of removed class-method tests).
#
# Observed failure (task-034):
#   16 class-method tests in TestSpecNodeDiscovery were removed (prohibited
#   feature). A new integration test file added 2 top-level test functions.
#   check-pytest-test-count.sh saw branch=10 vs main=8 → OK.
#   Total all-test count went 256 → 244 (net: -12). That class-method regression
#   was completely invisible to the top-level-only check.
#
# Exception — intentional scope-correct removal:
#   When branch commits remove tests because the tested functions are prohibited
#   by prototype-scope.spec.md, the verifier overlay requires the commit message
#   to contain:
#     (3) the exact number of tests removed
#     (4) the phrase "intentional and scope-correct — not a rebase regression"
#
#   When element (4) is detected in any branch commit message, this check exits 0
#   with a NOTE rather than FAIL. The verifier MUST still manually validate
#   element (3) (the claimed count) and elements (1) and (2) (function names and
#   prohibition citation) per the verifier overlay.
#
# Exit 0       = branch all-test count >= origin/main count
# Exit 0 (NOTE)= branch count < main, but removal is documented as scope-correct
# Exit 0 (SKIP)= no extractor/tests/ directory, or origin/main has 0 all-tests
# Exit 1       = branch count < main with no scope-correct documentation

set -uo pipefail

TESTS_DIR="extractor/tests"
SCOPE_CORRECT_PHRASE="intentional and scope-correct"

if [[ ! -d "$TESTS_DIR" ]]; then
    echo "SKIP: No $TESTS_DIR/ directory found — class test count check not applicable."
    exit 0
fi

# Fetch to ensure origin/main is current before comparison.
git fetch origin main:main --quiet 2>/dev/null || true

# Count ALL "def test_" (any indentation) on origin/main across all .py files.
# Uses grep without ^ anchor so class methods are included.
MAIN_COUNT=0
while IFS= read -r filepath; do
    c=$(git show "origin/main:${filepath}" 2>/dev/null | grep -c "def test_" || true)
    MAIN_COUNT=$(( MAIN_COUNT + ${c:-0} ))
done < <(git ls-tree -r --name-only origin/main -- "$TESTS_DIR" 2>/dev/null | grep "\.py$" || true)

if [[ "$MAIN_COUNT" -eq 0 ]]; then
    BRANCH_COUNT_EARLY=0
    while IFS= read -r f; do
        c=$(grep -c "def test_" "$f" 2>/dev/null || true)
        BRANCH_COUNT_EARLY=$(( BRANCH_COUNT_EARLY + ${c:-0} ))
    done < <(find "$TESTS_DIR" -name "*.py" 2>/dev/null || true)

    if [[ "$BRANCH_COUNT_EARLY" -gt 0 ]]; then
        echo "WARN: origin/main shows 0 all-test functions but this branch has $BRANCH_COUNT_EARLY."
        echo "  This almost always means 'git fetch origin main:main' failed silently."
        echo "  Verify manually: git fetch origin main:main && re-run this check."
        echo "SKIP: Could not confirm origin/main all-test count — manual fetch required."
    else
        echo "SKIP: origin/main has 0 'def test_' lines in $TESTS_DIR/ — nothing to compare."
    fi
    exit 0
fi

# Count ALL "def test_" in the working tree.
BRANCH_COUNT=0
while IFS= read -r f; do
    c=$(grep -c "def test_" "$f" 2>/dev/null || true)
    BRANCH_COUNT=$(( BRANCH_COUNT + ${c:-0} ))
done < <(find "$TESTS_DIR" -name "*.py" 2>/dev/null || true)

if [[ "$BRANCH_COUNT" -ge "$MAIN_COUNT" ]]; then
    echo "OK: All-test count (class-method-inclusive) on branch ($BRANCH_COUNT) >= origin/main ($MAIN_COUNT)."
    exit 0
fi

DELTA=$(( MAIN_COUNT - BRANCH_COUNT ))

# Check whether any branch commit documents the removal as intentional and scope-correct.
DOCUMENTED=false
if git log "origin/main..HEAD" --format="%B" 2>/dev/null | grep -q "$SCOPE_CORRECT_PHRASE"; then
    DOCUMENTED=true
fi

if $DOCUMENTED; then
    echo "NOTE: All-test count on branch ($BRANCH_COUNT) < origin/main ($MAIN_COUNT) — delta: -$DELTA."
    echo ""
    echo "  A branch commit message contains '$SCOPE_CORRECT_PHRASE',"
    echo "  indicating this reduction was intentional (prohibited feature removal)."
    echo ""
    echo "  VERIFIER: Manually validate that the removal commit also contains:"
    echo "    (1) the specific function name(s) removed"
    echo "    (2) the prototype-scope.spec.md prohibition by name"
    echo "    (3) the exact number of tests removed (claimed vs actual delta: $DELTA)"
    echo "    (4) the phrase 'intentional and scope-correct — not a rebase regression'"
    echo "  If any element is missing, treat as a standard regression and issue FAIL."
    echo ""
    echo "  IMPLEMENTER: This check exits 0 — no action needed unless the verifier"
    echo "  finds your commit message is missing a required element."
    exit 0
fi

echo "FAIL: Branch has fewer all-test functions (class-method-inclusive) than origin/main."
echo ""
echo "  origin/main: $MAIN_COUNT 'def test_' occurrence(s) in $TESTS_DIR/"
echo "  This branch: $BRANCH_COUNT 'def test_' occurrence(s) in $TESTS_DIR/"
echo "  Missing:     $DELTA test(s)"
echo ""
echo "  Unlike check-pytest-test-count.sh (which counts only top-level ^def test_),"
echo "  this check counts ALL test definitions including class methods."
echo "  A class-method test drop is invisible to the top-level-only check."
echo ""
echo "  Two possible causes:"
echo ""
echo "  A) REBASE REGRESSION: tests from other tasks were dropped during conflict"
echo "     resolution. Fix: rebase onto origin/main, keeping all of main's tests."
echo "       git fetch origin main:main"
echo "       git rebase origin/main"
echo "       bash .hyperloop/checks/check-class-test-count.sh   # must exit 0"
echo ""
echo "  B) INTENTIONAL SCOPE-CORRECT REMOVAL: you removed tests for a prohibited"
echo "     feature. This is allowed but MUST be documented in the commit message:"
echo "       (1) Name the specific functions removed."
echo "       (2) Cite the prototype-scope.spec.md prohibition by name."
echo "       (3) State the exact number of tests removed: 'Removes $DELTA tests'"
echo "       (4) Add the phrase: 'intentional and scope-correct — not a rebase regression'"
echo "     Once documented, this check exits 0 with a NOTE."
echo ""
echo "  Diagnostic — find where the delta comes from:"
echo "    diff <(git ls-tree -r --name-only origin/main -- $TESTS_DIR | grep '.py\$' \\"
echo "           | xargs -I{} sh -c 'git show origin/main:{} | grep -n \"def test_\"') \\"
echo "         <(find $TESTS_DIR -name '*.py' | xargs grep -n 'def test_')"
exit 1
