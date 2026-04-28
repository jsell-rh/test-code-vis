#!/usr/bin/env bash
# check-checks-in-sync.sh
#
# Verifies that every check script in main::.hyperloop/checks/ is also
# present in the working tree.
#
# Observed pattern (task-001, cycle 11):
#   check-layout-radius-bound.sh was added to main AFTER the task branch was
#   created. The implementer did not run `git checkout main -- .hyperloop/checks/`
#   before submitting, so that check was absent from their run-all-checks.sh
#   output, giving a false impression of a smaller failing set.
#
# The verifier overlay documents this risk and references this script:
#   "The check-checks-in-sync.sh script in the master runner also detects this gap."
#   "Flag missing check scripts as a process violation in your findings."
#
# This script makes that detection mechanical: if a check script exists on main
# but not in the working tree, the implementer did not sync and their check run
# is incomplete.
#
# Exit 0 = working tree is in sync with main (or on main / not a task branch).
# Exit 1 = one or more checks present on main are absent from the working tree.

set -uo pipefail

CHECKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF="$(basename "${BASH_SOURCE[0]}")"

# Only meaningful on task branches.
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [[ -z "$CURRENT_BRANCH" || "$CURRENT_BRANCH" == "HEAD" || "$CURRENT_BRANCH" == "main" ]]; then
    echo "SKIP: Not on a task branch."
    exit 0
fi

# List check scripts in main::.hyperloop/checks/ using git ls-tree.
MAIN_CHECKS=$(git ls-tree --name-only "main:.hyperloop/checks/" 2>/dev/null \
    | grep '\.sh$' \
    || true)

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

    # Also verify content matches main via git blob SHA.
    # Presence alone is insufficient: a branch may have an older version of a
    # script (e.g., check-not-in-scope.sh before a pre-existing-file filter was
    # added) that passes a presence check but runs stale logic, producing incorrect
    # results that cannot be resolved by the implementer.
    main_blob=$(git ls-tree "main:.hyperloop/checks/" -- "$check_name" 2>/dev/null \
        | awk '{print $3}')
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

echo "  Fix: sync from main before re-running checks:"
echo "    git checkout main -- .hyperloop/checks/"
echo "    bash .hyperloop/checks/run-all-checks.sh"
echo ""
echo "  This is a process violation (implementer did not sync checks as required"
echo "  by the re-attempt protocol, step 0). Every FAIL produced by missing or"
echo "  stale checks is still blocking regardless of when the change was made."
exit 1
