#!/usr/bin/env bash
# check-sync-divergence-impact.sh
#
# PURPOSE: Assess whether stale check scripts (branch vs. main) produce different
# output for the current working tree.  Run this AFTER check-checks-in-sync.sh
# exits non-zero to determine whether the divergence is substantive.
#
# EXIT 0  — all stale scripts produce identical output (FAST-FIX race condition)
# EXIT 1  — at least one stale script produces different output (substantive FAIL)
#
# Usage: bash .hyperloop/checks/check-sync-divergence-impact.sh

set -euo pipefail

CHECKS_DIR="$(cd "$(dirname "$0")" && pwd)"
TMPDIR_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

# Identify scripts that differ between working tree and main
mapfile -t STALE_SCRIPTS < <(
  git diff --name-only main -- .hyperloop/checks/ 2>/dev/null \
  | grep '\.sh$' \
  | xargs -I{} basename {} 2>/dev/null \
  || true
)

if [[ ${#STALE_SCRIPTS[@]} -eq 0 ]]; then
  echo "OK: No stale check scripts found — check-checks-in-sync.sh should pass."
  echo "    (If check-checks-in-sync.sh still exits non-zero, re-run it.)"
  exit 0
fi

echo "Stale check scripts detected (${#STALE_SCRIPTS[@]} file(s)):"
for s in "${STALE_SCRIPTS[@]}"; do
  echo "  $s"
done
echo ""

DIVERGENT=0

for script in "${STALE_SCRIPTS[@]}"; do
  branch_path="$CHECKS_DIR/$script"
  main_path="$TMPDIR_ROOT/main_$script"

  # Extract main version
  if ! git show "main:.hyperloop/checks/$script" > "$main_path" 2>/dev/null; then
    echo "SKIP: $script — not present on main (new file on branch; not stale)."
    continue
  fi
  chmod +x "$main_path"

  # Run branch (stale) version — capture output, ignore exit code
  branch_out="$TMPDIR_ROOT/branch_out_$script"
  bash "$branch_path" > "$branch_out" 2>&1 || true

  # Run main (current) version — capture output, ignore exit code
  main_out="$TMPDIR_ROOT/main_out_$script"
  bash "$main_path" > "$main_out" 2>&1 || true

  if diff -q "$branch_out" "$main_out" > /dev/null 2>&1; then
    echo "OK (identical output): $script"
    echo "  Branch version and main version produce the same result for this working tree."
  else
    echo "DIVERGENT: $script"
    echo "  Branch (stale) output:"
    sed 's/^/    /' "$branch_out"
    echo "  Main (current) output:"
    sed 's/^/    /' "$main_out"
    DIVERGENT=1
  fi
  echo ""
done

if [[ $DIVERGENT -eq 0 ]]; then
  echo "=== FAST-FIX: All stale scripts produce identical output ==="
  echo "    The check-checks-in-sync.sh failure is a post-sync race condition."
  echo "    No implementation changes are needed.  Fix:"
  echo "      git checkout main -- .hyperloop/checks/"
  echo "      bash .hyperloop/checks/run-all-checks.sh"
  echo "      git add .hyperloop/checks/"
  echo "      git commit -m \"chore(checks): re-sync check scripts from main (race condition)\""
  exit 0
else
  echo "=== SUBSTANTIVE DIVERGENCE: At least one stale script produces different output ==="
  echo "    This is not a simple race condition — the stale check conceals a real finding."
  echo "    The implementer must sync checks AND address the divergent output above."
  exit 1
fi
