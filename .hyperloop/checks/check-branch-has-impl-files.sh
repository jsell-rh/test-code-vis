#!/usr/bin/env bash
# check-branch-has-impl-files.sh
#
# Verifies the current branch has at least one commit that changes a
# non-.hyperloop/ file. A branch where every commit exclusively touches
# .hyperloop/ files (e.g., only worker-result.yaml) contains no implementation
# — any test-count or file-count claims in the submission report are fabricated.
#
# Observed pattern (task-021, cycle 1):
#   The worker-result.yaml claimed 164 GDScript tests, 51 new tests (29
#   LlmViewGenerator + 22 SceneInterpreter), and 5 files added (1052 net
#   insertions). Inspection showed the branch contained 6 commits, all
#   exclusively touching .hyperloop/worker-result.yaml. Zero implementation
#   files were ever committed. check-branch-has-commits.sh passed because the
#   branch had commits; this check catches the narrower fabrication pattern
#   where those commits contain only process/report files.
#
# Algorithm:
#   Walk every commit on this branch above main. For each commit, list the
#   changed files and check whether any of them are outside .hyperloop/.
#   If no such file is found across all commits, exit 1.
#
# Exit 0 = at least one non-.hyperloop/ file changed on this branch (or SKIP).
# Exit 1 = every changed file on this branch is under .hyperloop/ — no impl.

set -uo pipefail

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

if [ -z "$CURRENT_BRANCH" ] || [ "$CURRENT_BRANCH" = "HEAD" ]; then
    echo "SKIP: Detached HEAD — impl-file check not applicable."
    exit 0
fi

if [ "$CURRENT_BRANCH" = "main" ]; then
    echo "SKIP: On main branch — impl-file check not applicable."
    exit 0
fi

COMMIT_COUNT=$(git log main..HEAD --oneline 2>/dev/null | wc -l | tr -d ' ')

if [ "$COMMIT_COUNT" -eq 0 ]; then
    echo "SKIP: Branch has no commits above main — check-branch-has-commits.sh handles this."
    exit 0
fi

# Walk every commit above main and collect all changed file paths
IMPL_FILES=$(git log main..HEAD --format="%H" 2>/dev/null \
    | while IFS= read -r sha; do
        [[ -z "$sha" ]] && continue
        git show --name-only --format="" "$sha" 2>/dev/null \
            | grep -v '^$' \
            | grep -v '^\.hyperloop/' \
            || true
    done | sort -u | head -20)

if [[ -z "$IMPL_FILES" ]]; then
    echo "FAIL: Branch '$CURRENT_BRANCH' has $COMMIT_COUNT commit(s) above main, but"
    echo "      EVERY changed file across all commits is under .hyperloop/."
    echo ""
    echo "      This means no implementation was actually committed. The submission"
    echo "      report's claimed test counts, file counts, and insertion numbers are"
    echo "      fabricated — they cannot correspond to files that don't exist."
    echo ""
    echo "      All commits on this branch:"
    git log main..HEAD --oneline 2>/dev/null | sed 's/^/        /'
    echo ""
    echo "      All changed paths on this branch:"
    git log main..HEAD --format="%H" 2>/dev/null \
        | while IFS= read -r sha; do
            git show --name-only --format="" "$sha" 2>/dev/null | grep -v '^$' || true
        done | sort -u | sed 's/^/        /'
    echo ""
    echo "  Protocol:"
    echo "    1. Read the assigned spec — identify every MUST/SHALL requirement."
    echo "    2. Write implementation code in the appropriate source directory."
    echo "    3. Write tests that exercise the implementation."
    echo "    4. Commit implementation and tests (each commit must touch non-.hyperloop/ files)."
    echo "    5. Only THEN write worker-result.yaml and run run-all-checks.sh."
    echo ""
    echo "  A worker-result.yaml is a REPORT of completed work, not a substitute for it."
    exit 1
fi

IMPL_COUNT=$(echo "$IMPL_FILES" | wc -l | tr -d ' ')
echo "OK: Branch '$CURRENT_BRANCH' has implementation commits ($IMPL_COUNT non-.hyperloop/ file(s) changed)."
exit 0
