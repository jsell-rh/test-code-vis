#!/usr/bin/env bash
# check-checks-in-sync.sh
#
# Verifies that every check script in origin/main::.hyperloop/checks/ is also
# present and content-identical in the working tree.
#
# This script fetches origin/main silently before comparing, making it
# self-sufficient: a stale local 'main' no longer produces false-OK results.
#
# Observed pattern (task-001, cycle 11):
#   check-layout-radius-bound.sh was added to main AFTER the task branch was
#   created. The implementer did not run `git checkout main -- .hyperloop/checks/`
#   before submitting, so that check was absent from their run-all-checks.sh
#   output, giving a false impression of a smaller failing set.
#
# Observed pattern (task-075):
#   Implementer ran `git checkout main -- .hyperloop/checks/` without a prior
#   `git fetch origin main:main`. Local main was stale (db76c82, 3 commits behind
#   origin). Both the sync and this script compared against the SAME stale reference,
#   agreeing on 52 checks. Origin/main had 54; the 2 missing scripts included
#   check-rebased-onto-main.sh, making the rebase failure invisible. Fix: this script
#   now fetches origin/main before any comparison.
#
# The verifier overlay documents this risk and references this script.
#
# Exit 0 = working tree is in sync with origin/main (or on main / not a task branch).
# Exit 1 = one or more checks present on origin/main are absent or stale in working tree.

set -uo pipefail

CHECKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF="$(basename "${BASH_SOURCE[0]}")"

# Only meaningful on task branches.
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [[ -z "$CURRENT_BRANCH" || "$CURRENT_BRANCH" == "HEAD" || "$CURRENT_BRANCH" == "main" ]]; then
    echo "SKIP: Not on a task branch."
    exit 0
fi

# Fetch origin/main silently so the comparison is always against the authoritative
# remote state — not a potentially stale local 'main'.
#
# Observed failure (task-075): implementer ran `git checkout main -- .hyperloop/checks/`
# without a prior `git fetch origin main:main`. Local main was at db76c82 (missing 3
# commits). check-checks-in-sync.sh compared against the SAME stale local main, so both
# the sync and the verification agreed on 52 checks — but origin/main had 54. The two
# missing scripts (check-rebased-onto-main.sh, check-run-tests-suite-count.sh) were
# invisible to the implementer's run, concealing the rebase failure.
#
# With this fetch, a stale local main no longer produces false-OK results: the script
# always compares the working tree against what origin/main actually contains.
git fetch origin main:main --quiet 2>/dev/null || true

# List check scripts in origin/main::.hyperloop/checks/ using git ls-tree.
# Using origin/main (not local main) ensures the reference is current even when the
# implementer skipped the fetch step before their git checkout main -- .hyperloop/checks/.
MAIN_CHECKS=$(git ls-tree --name-only "origin/main:.hyperloop/checks/" 2>/dev/null \
    | grep '\.sh$' \
    || true)

# Fall back to local main if origin/main is unavailable (offline / no remote).
if [[ -z "$MAIN_CHECKS" ]]; then
    MAIN_CHECKS=$(git ls-tree --name-only "main:.hyperloop/checks/" 2>/dev/null \
        | grep '\.sh$' \
        || true)
fi

if [[ -z "$MAIN_CHECKS" ]]; then
    echo "SKIP: Cannot list checks on main (git ls-tree failed — possibly no main branch)."
    exit 0
fi

FAIL=0
MISSING=()
STALE=()

while IFS= read -r check_name; do
    [[ -z "$check_name" ]] && continue
    # Skip self to avoid false positives on first run before this script is on main.
    [[ "$check_name" == "$SELF" ]] && continue

    check_path="$CHECKS_DIR/$check_name"
    if [[ ! -f "$check_path" ]]; then
        MISSING+=("$check_name")
        FAIL=1
        continue
    fi

    # Also verify content matches origin/main via git blob SHA.
    # Presence alone is insufficient: a branch may have an older version of a
    # script (e.g., check-not-in-scope.sh before a pre-existing-file filter was
    # added) that passes a presence check but runs stale logic, producing incorrect
    # results that cannot be resolved by the implementer.
    # Use origin/main (consistent with the ls-tree above) so blob hashes reflect
    # the authoritative remote state, not a potentially stale local main.
    main_blob=$(git ls-tree "origin/main:.hyperloop/checks/" -- "$check_name" 2>/dev/null \
        | awk '{print $3}')
    # Fall back to local main if origin/main blob lookup fails.
    if [[ -z "$main_blob" ]]; then
        main_blob=$(git ls-tree "main:.hyperloop/checks/" -- "$check_name" 2>/dev/null \
            | awk '{print $3}')
    fi
    if [[ -n "$main_blob" ]]; then
        local_blob=$(git hash-object "$check_path" 2>/dev/null || true)
        if [[ -n "$local_blob" && "$main_blob" != "$local_blob" ]]; then
            STALE+=("$check_name")
            FAIL=1
        fi
    fi
done <<< "$MAIN_CHECKS"

if [[ $FAIL -eq 0 ]]; then
    echo "OK: All check scripts from main are present and content-identical in working tree ($(echo "$MAIN_CHECKS" | wc -l | tr -d ' ') checked)."
    exit 0
fi

if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo "FAIL: ${#MISSING[@]} check script(s) present on main are missing from this working tree:"
    for name in "${MISSING[@]}"; do
        echo "  $name"
    done
    echo ""
    echo "  These checks were added to main after this branch was created."
    echo "  Without syncing, they cannot fire — their FAILs are invisible to run-all-checks.sh."
    echo ""
fi

if [[ ${#STALE[@]} -gt 0 ]]; then
    echo "FAIL: ${#STALE[@]} check script(s) exist in working tree but have DIFFERENT CONTENT than main:"
    for name in "${STALE[@]}"; do
        echo "  $name"
    done
    echo ""
    echo "  These scripts were updated on main after this branch was created."
    echo "  Running the stale version produces incorrect results (e.g., missing a"
    echo "  pre-existing-file filter that was added to fix a persistent deadlock)."
    echo ""
fi

echo "  Fix: fetch from origin, then sync check scripts from main:"
echo "    git fetch origin main:main"
echo "    git checkout main -- .hyperloop/checks/"
echo "    bash .hyperloop/checks/check-checks-in-sync.sh   # verify exit 0"
echo "    bash .hyperloop/checks/run-all-checks.sh"
echo ""
echo "  This is a process violation (implementer did not sync checks as required"
echo "  by the re-attempt protocol, step 0). Every FAIL produced by missing or"
echo "  stale checks is still blocking regardless of when the change was made."
exit 1
