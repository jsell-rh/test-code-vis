#!/usr/bin/env bash
# check-prescribed-fixes-applied.sh
#
# When a prior FAIL report cites specific source files in "Offending lines:"
# sections, verifies that at least one implementation commit exists for each
# cited file since that report.
#
# Observed pattern (task-014 cycle 2):
#   Three checks (check-layout-radius-bound.sh, check-circular-position-y-axis.sh,
#   check-relative-position-tests.sh) all cited extractor/extractor.py with exact
#   line numbers and prescribed fixes.  The implementer made zero commits to any
#   source file between the prior FAIL report (cda15d5) and the re-attempt.
#   check-no-zero-commit-reattempt.sh catches the zero-commit case globally;
#   this check catches the complementary case where commits exist but do NOT
#   touch any of the specifically cited files — i.e., the implementer committed
#   unrelated work without applying the prescribed fixes.
#
# Algorithm:
#   1. Find the most recent prior FAIL report in branch or main history.
#   2. Extract file paths from "Offending lines:" sections in that report.
#      Format: "  <file>:<line>:<content>"
#   3. For each unique cited file, verify at least one non-.hyperloop commit
#      exists on the branch after the prior FAIL report commit.
#   4. Exit 1 if any cited file has no such commit.
#
# Exit 0 = no prior FAIL found, no "Offending lines:" citations, or all cited
#          files have been touched since the prior FAIL report.
# Exit 1 = at least one cited file has zero commits since the prior FAIL.

set -uo pipefail

RESULT_FILE=".hyperloop/worker-result.yaml"

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [[ -z "$CURRENT_BRANCH" || "$CURRENT_BRANCH" == "HEAD" || "$CURRENT_BRANCH" == "main" ]]; then
    echo "SKIP: Not on a task branch."
    exit 0
fi

COMMIT_COUNT=$(git log main..HEAD --oneline 2>/dev/null | wc -l | tr -d ' ')
if [[ "$COMMIT_COUNT" -le 1 ]]; then
    echo "SKIP: Branch has only ${COMMIT_COUNT} commit(s) above main — first attempt."
    exit 0
fi

# ── Find prior FAIL report (mirrors check-no-zero-commit-reattempt.sh) ────────
PRIOR_SHA=""
PRIOR_CONTENT=""

while IFS= read -r sha; do
    [[ -z "$sha" ]] && continue
    content=$(git show "${sha}:${RESULT_FILE}" 2>/dev/null || true)
    [[ -z "$content" ]] && continue
    fail_count=$(echo "$content" | grep -c '\[EXIT [1-9]' 2>/dev/null || true)
    if [[ "$fail_count" -gt 0 ]]; then
        PRIOR_SHA="$sha"
        PRIOR_CONTENT="$content"
        break
    fi
done < <(git log main..HEAD --format="%H" -- "$RESULT_FILE" 2>/dev/null)

# Fallback: walk main's history (post-reset branches)
if [[ -z "$PRIOR_SHA" ]]; then
    while IFS= read -r sha; do
        [[ -z "$sha" ]] && continue
        content=$(git show "${sha}:${RESULT_FILE}" 2>/dev/null || true)
        [[ -z "$content" ]] && continue
        fail_count=$(echo "$content" | grep -c '\[EXIT [1-9]' 2>/dev/null || true)
        if [[ "$fail_count" -gt 0 ]]; then
            PRIOR_SHA="$sha"
            PRIOR_CONTENT="$content"
            break
        fi
    done < <(git log main --format="%H" -- "$RESULT_FILE" 2>/dev/null | head -10)
fi

if [[ -z "$PRIOR_SHA" ]]; then
    echo "SKIP: No prior FAIL report found — nothing to verify."
    exit 0
fi

PRIOR_SHORT="${PRIOR_SHA:0:7}"

# ── Extract file paths cited in "Offending lines:" sections ───────────────────
# Lines in the report after "Offending lines:" have the form:
#   "  extractor/extractor.py:206:    bc_radius = max(..."
# We extract the file path (first colon-delimited token) from each such line.
CITED_FILES=$(echo "$PRIOR_CONTENT" \
    | awk '
        /Offending lines:/ { in_offending=1; next }
        in_offending && /^  [a-zA-Z\/][^[:space:]]+:[0-9]+:/ {
            line = $0
            sub(/^[[:space:]]+/, "", line)
            n = split(line, parts, ":")
            if (n >= 2) print parts[1]
            next
        }
        in_offending && /^\s*$/ { next }
        in_offending { in_offending=0 }
    ' \
    | grep -v '^$' \
    | sort -u)

if [[ -z "$CITED_FILES" ]]; then
    echo "SKIP: Prior FAIL report contains no 'Offending lines:' file citations."
    exit 0
fi

echo "Checking files cited in prior FAIL report (${PRIOR_SHORT}) 'Offending lines:' sections..."
echo ""

FAIL=0
MISSING_FILES=()

while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    # Count commits after the prior FAIL report that touch this file
    COMMITS_SINCE=$(git log "${PRIOR_SHA}..HEAD" --oneline -- "$file" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$COMMITS_SINCE" -eq 0 ]]; then
        echo "FAIL: $file"
        echo "      Cited in prior FAIL report 'Offending lines:' — but NO commits"
        echo "      since ${PRIOR_SHORT} touch this file. The prescribed fix was"
        echo "      not applied and committed."
        MISSING_FILES+=("$file")
        FAIL=1
    else
        echo "OK:   $file (${COMMITS_SINCE} commit(s) since ${PRIOR_SHORT})"
    fi
done <<< "$CITED_FILES"

echo ""

if [[ $FAIL -gt 0 ]]; then
    echo "FAIL: ${#MISSING_FILES[@]} cited file(s) from prior FAIL report have no commits"
    echo "  since ${PRIOR_SHORT}. The prescribed fixes at the 'Offending lines:'"
    echo "  locations were not applied."
    echo ""
    echo "  For each uncorrected file:"
    echo "    1. Read the prior report: git show ${PRIOR_SHORT}:.hyperloop/worker-result.yaml"
    echo "    2. Find the 'Offending lines:' entry for the file."
    echo "    3. Open the file at the cited line number."
    echo "    4. Apply the fix exactly as prescribed."
    echo "    5. Run the specific failing check to confirm exit 0."
    echo "    6. Commit: git commit -m 'fix: <description>'"
    exit 1
fi

echo "OK: All files cited in prior FAIL 'Offending lines:' have commits since ${PRIOR_SHORT}."
exit 0
