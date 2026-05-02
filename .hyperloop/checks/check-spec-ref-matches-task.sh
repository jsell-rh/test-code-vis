#!/usr/bin/env bash
# check-spec-ref-matches-task.sh
#
# Verifies that the spec file PATH in Spec-Ref commit trailers matches
# the spec file path defined in the task definition
# (.hyperloop/state/tasks/<task-id>.md, field: spec_ref).
#
# Background (task-027): the implementer committed Spec-Ref pointing to
# nfr.spec.md while the task definition referenced visual-primitives.spec.md.
# The implementation was entirely unrelated to the task's assigned spec.
# No mechanical check caught the mismatch before review.
#
# This check validates the PATH component only (not the hash).  A valid
# implementation may commit against a newer hash than the task's pinned
# hash — that is spec-drift handled by check-spec-ref-staleness.sh, not
# a mismatch.  Only the file path must agree.
#
# Exit 0 = all Spec-Ref paths match the task definition, or SKIP conditions met.
# Exit 1 = at least one Spec-Ref path does not match the task definition.

set -uo pipefail

MAIN_BRANCH="main"

# Only meaningful on task branches.
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [[ -z "$CURRENT_BRANCH" || "$CURRENT_BRANCH" == "HEAD" || "$CURRENT_BRANCH" == "main" ]]; then
    echo "SKIP: Not on a task branch."
    exit 0
fi

# Extract Task-Ref from branch commits (first non-process-improvement value found).
TASK_REF=$(
    git log "$MAIN_BRANCH"..HEAD --format="%B" 2>/dev/null \
    | grep -oP '(?<=Task-Ref: )\S+' \
    | grep -v -E '^(process-improvement|intake)$' \
    | head -1 \
    | tr -d '[:space:]' \
    || true
)

if [[ -z "$TASK_REF" ]]; then
    echo "SKIP: No non-process Task-Ref trailer found in branch commits."
    exit 0
fi

TASK_FILE=".hyperloop/state/tasks/${TASK_REF}.md"

if [[ ! -f "$TASK_FILE" ]]; then
    echo "SKIP: Task file '$TASK_FILE' not found — cannot validate spec path."
    exit 0
fi

# Extract spec_ref path from task definition (strip hash suffix and quotes).
TASK_SPEC_RAW=$(
    grep -m1 '^spec_ref:' "$TASK_FILE" \
    | sed 's/spec_ref:[[:space:]]*//' \
    | tr -d '"'"'" \
    | tr -d '[:space:]' \
    || true
)

if [[ -z "$TASK_SPEC_RAW" ]]; then
    echo "SKIP: No spec_ref field found in '$TASK_FILE'."
    exit 0
fi

# Strip hash suffix (@...) to get just the file path.
TASK_SPEC_PATH="${TASK_SPEC_RAW%%@*}"

# Collect all unique Spec-Ref file paths from commits above main that belong to
# the CURRENT task only (Task-Ref == $TASK_REF).
#
# Rationale: long-running branches accumulate commits from sibling tasks, each
# legitimately referencing its own spec.  Checking ALL non-PI commits causes
# false failures for those sibling-task Spec-Refs.  Scoping to the current
# task's Task-Ref isolates only the commits this check was designed to validate.
mapfile -t COMMIT_SPEC_PATHS < <(
    while IFS= read -r commit_hash; do
        body=$(git log -1 --format="%B" "$commit_hash" 2>/dev/null)
        # Only inspect commits whose Task-Ref matches the current task.
        if ! echo "$body" | grep -qE '^Task-Ref:[[:space:]]*'"${TASK_REF}"'[[:space:]]*$'; then
            continue
        fi
        echo "$body" \
            | grep -oP '(?<=Spec-Ref: )\S+' \
            | sed 's/@.*//'
    done < <(git log "$MAIN_BRANCH"..HEAD --format="%H" 2>/dev/null) \
    | sort -u
)

if [[ ${#COMMIT_SPEC_PATHS[@]} -eq 0 ]]; then
    echo "SKIP: No Spec-Ref trailers found in branch implementation commits."
    exit 0
fi

FAIL=0

for commit_path in "${COMMIT_SPEC_PATHS[@]}"; do
    [[ -z "$commit_path" ]] && continue
    if [[ "$commit_path" == "$TASK_SPEC_PATH" ]]; then
        echo "OK: Spec-Ref path '$commit_path' matches task definition spec_ref."
    else
        echo "FAIL: Spec-Ref path mismatch."
        echo "  Committed Spec-Ref path : $commit_path"
        echo "  Task definition spec_ref: $TASK_SPEC_PATH  (from $TASK_FILE)"
        echo ""
        echo "  The implementer committed against a different spec than the task assigned."
        echo "  Either:"
        echo "    (a) Correct the Spec-Ref trailer in your commits to match the task"
        echo "        definition and re-implement against the correct spec, OR"
        echo "    (b) Ask the orchestrator to update the task definition if the spec"
        echo "        assignment was changed intentionally."
        FAIL=1
    fi
done

if [[ $FAIL -ne 0 ]]; then
    exit 1
fi
exit 0
