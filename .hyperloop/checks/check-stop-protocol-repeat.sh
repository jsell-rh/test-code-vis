#!/usr/bin/env bash
# check-stop-protocol-repeat.sh
#
# Detects when a task has triggered STOP PROTOCOL ("feature already on main")
# in a prior cycle. Called by check-cycle-gate.sh (Step 2c) for each finding
# task ID, and auto-runs from run-all-checks.sh on task branches.
#
# A STOP PROTOCOL finding means the task's assigned deliverable already exists
# on origin/main — re-assigning the same task with the same title/spec_ref
# produces the same STOP PROTOCOL result deterministically. Round 4 of task-078
# is the canonical observed failure: the feature (extract_symbols) was confirmed
# on main in Rounds 1-3; the orchestrator did not retire the task; Round 4
# produced the identical finding.
#
# This check fetches the task's remote branch and scans worker-result.yaml
# history for commits containing "STOP PROTOCOL" text. If any exist, exit 1.
#
# Usage:
#   bash check-stop-protocol-repeat.sh             # auto-detect from branch name
#   bash check-stop-protocol-repeat.sh <task-id>   # explicit task ID
#
# Exit 0 = no prior STOP PROTOCOL rounds found, or SKIP (branch absent / clean).
# Exit 1 = prior STOP PROTOCOL round(s) confirmed — task must NOT be re-assigned.

set -uo pipefail

RESULT_FILE=".hyperloop/worker-result.yaml"

# ── Resolve task ID ──────────────────────────────────────────────────────────
TASK_ID="${1:-}"

if [ -z "$TASK_ID" ]; then
    # Auto-detect from current branch name (run-all-checks.sh context)
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    if [[ -z "$CURRENT_BRANCH" || "$CURRENT_BRANCH" == "HEAD" || "$CURRENT_BRANCH" == "main" ]]; then
        echo "SKIP: Not on a task branch — cannot auto-detect task ID."
        exit 0
    fi
    TASK_ID=$(echo "$CURRENT_BRANCH" | grep -oP '(?<=hyperloop/)task-\d+' || true)
    if [ -z "$TASK_ID" ]; then
        TASK_ID=$(echo "$CURRENT_BRANCH" | grep -oP '^task-\d+' || true)
    fi
    if [ -z "$TASK_ID" ]; then
        echo "SKIP: Cannot extract task ID from branch name '${CURRENT_BRANCH}'."
        exit 0
    fi
fi

# ── Fetch the task's remote branch silently ──────────────────────────────────
# Use an explicit refspec to populate a proper remote tracking ref so we can
# run git log against it. Suppress all output; a missing branch is not an error.
git fetch origin \
    "refs/heads/hyperloop/${TASK_ID}:refs/remotes/origin/hyperloop/${TASK_ID}" \
    --quiet 2>/dev/null || true

REMOTE_BRANCH="origin/hyperloop/${TASK_ID}"

# ── Check that the remote branch exists ──────────────────────────────────────
if ! git rev-parse --verify "${REMOTE_BRANCH}" &>/dev/null; then
    echo "SKIP: Remote branch ${REMOTE_BRANCH} not found — no prior STOP PROTOCOL history."
    exit 0
fi

# ── Check for commits above origin/main ──────────────────────────────────────
COMMITS_ABOVE=$(git log "origin/main..${REMOTE_BRANCH}" --format="%H" \
    2>/dev/null | wc -l | tr -d ' ')

if [ "$COMMITS_ABOVE" -eq 0 ]; then
    echo "SKIP: ${REMOTE_BRANCH} has no commits above origin/main — nothing to scan."
    exit 0
fi

# ── Scan worker-result.yaml commits for STOP PROTOCOL text ──────────────────
STOP_COUNT=0
STOP_COMMITS=()

while IFS= read -r sha; do
    [[ -z "$sha" ]] && continue
    content=$(git show "${sha}:${RESULT_FILE}" 2>/dev/null || true)
    [[ -z "$content" ]] && continue
    if echo "$content" | grep -q "STOP PROTOCOL"; then
        STOP_COUNT=$((STOP_COUNT + 1))
        SHORT="${sha:0:7}"
        ROUND_TAG=$(echo "$content" | grep -oP 'Round \d+' | head -1 || true)
        STOP_COMMITS+=("${SHORT}${ROUND_TAG:+ (${ROUND_TAG})}")
    fi
done < <(git log "origin/main..${REMOTE_BRANCH}" --format="%H" \
    -- "${RESULT_FILE}" 2>/dev/null)

if [ "$STOP_COUNT" -eq 0 ]; then
    echo "OK: No prior STOP PROTOCOL findings in ${TASK_ID} remote branch history."
    exit 0
fi

# ── FAIL: prior STOP PROTOCOL rounds detected ────────────────────────────────
NEXT_ROUND=$((STOP_COUNT + 1))

echo "FAIL: ${TASK_ID} has ${STOP_COUNT} prior STOP PROTOCOL finding(s) in remote branch history."
echo ""
echo "  Re-assigning this task will produce Round ${NEXT_ROUND} STOP PROTOCOL."
echo "  The assigned deliverable already exists on origin/main and cannot be removed"
echo "  by any implementer action."
echo ""
echo "  Prior STOP PROTOCOL commits on ${REMOTE_BRANCH}:"
for commit_info in "${STOP_COMMITS[@]}"; do
    echo "    ${commit_info}"
done
echo ""
echo "  REQUIRED ORCHESTRATOR ACTION — exactly ONE of:"
echo ""
echo "  Option A — RETIRE (feature was delivered by a parallel task):"
echo "    Verify the feature is fully on origin/main, then close on BOTH branches:"
echo ""
echo "    # On main:"
echo "    sed -i 's/^status:.*/status: closed/' .hyperloop/state/tasks/${TASK_ID}.md"
echo "    git add .hyperloop/state/tasks/${TASK_ID}.md"
echo "    git commit -m 'chore(tasks): retire superseded ${TASK_ID} — deliverable on main'"
echo "    git push origin main"
echo ""
echo "    # On hyperloop/state:"
echo "    git checkout hyperloop/state"
echo "    sed -i 's/^status:.*/status: closed/' .hyperloop/state/tasks/${TASK_ID}.md"
echo "    git add .hyperloop/state/tasks/${TASK_ID}.md"
echo "    git commit -m 'chore(tasks): retire superseded ${TASK_ID} — deliverable on main'"
echo "    git push origin hyperloop/state"
echo "    git checkout main"
echo ""
echo "  Option B — REDESIGN (a different spec section is genuinely unimplemented):"
echo "    Update task definition: change spec_ref hash, title, pr_description."
echo "    Confirm the new primary function is NOT on origin/main before re-assigning:"
echo "      git grep -n 'def <new_primary_function>' origin/main -- extractor/ godot/"
echo "    Only re-assign after that grep returns nothing."
echo ""
echo "  DO NOT re-assign ${TASK_ID} unchanged. DO NOT create a new task number"
echo "  for the same already-implemented feature."
echo "  check-cycle-gate.sh Step 2c calls this check on every cycle — it will exit 1"
echo "  again until one of the above actions is completed."
exit 1
