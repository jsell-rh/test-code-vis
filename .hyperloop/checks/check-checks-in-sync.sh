#!/bin/bash
# check-checks-in-sync.sh
# Fail if any check script present on the main branch is absent from this worktree.
#
# Motivation: check scripts are added to main over time. A worktree branched before
# a check was added will silently skip it when running run-all-checks.sh.
# This script detects that gap so implementers are forced to sync before submitting.
#
# Resolution: git checkout main -- .hyperloop/checks/

set -uo pipefail

CHECKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"

if [ -z "$GIT_ROOT" ]; then
    echo "SKIP: Not inside a git repository"
    exit 0
fi

# Path to checks dir relative to git root (used for git ls-tree)
CHECKS_REL="${CHECKS_DIR#${GIT_ROOT}/}"

# Resolve main ref — try local 'main', then 'origin/main'
MAIN_REF=""
for candidate in main origin/main; do
    if git rev-parse --verify "$candidate" >/dev/null 2>&1; then
        MAIN_REF="$candidate"
        break
    fi
done

if [ -z "$MAIN_REF" ]; then
    echo "SKIP: Could not resolve 'main' or 'origin/main' — skipping sync check"
    exit 0
fi

FAIL=0
CHECKED=0

while IFS= read -r name; do
    [ -z "$name" ] && continue
    [[ "$name" == *.sh ]] || continue
    CHECKED=$((CHECKED + 1))
    if [ ! -f "$CHECKS_DIR/$name" ]; then
        echo "FAIL: '$name' exists on $MAIN_REF but is missing from this worktree."
        echo "      Run: git checkout $MAIN_REF -- $CHECKS_REL/$name"
        echo "      Or sync all checks at once: git checkout $MAIN_REF -- $CHECKS_REL/"
        FAIL=1
    fi
done < <(git ls-tree --name-only "${MAIN_REF}:${CHECKS_REL}" 2>/dev/null || true)

if [ $CHECKED -eq 0 ]; then
    echo "OK: No check scripts found on $MAIN_REF to compare against"
    exit 0
fi

if [ $FAIL -eq 1 ]; then
    exit 1
fi

echo "OK: All check scripts from $MAIN_REF are present in this worktree"
