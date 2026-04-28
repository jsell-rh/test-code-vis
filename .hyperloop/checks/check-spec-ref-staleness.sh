#!/bin/bash
# check-spec-ref-staleness.sh
# Compares each spec file referenced by Spec-Ref trailers in implementation commits
# against the same file at HEAD. Any difference is surfaced as a SPEC-DRIFT WARNING
# so verifiers know to apply the Spec-Drift Detection protocol before scoring.
#
# This check is INFORMATIONAL — it exits 0 regardless of drift so it never
# blocks submission. Its output MUST be quoted verbatim in verifier reports.
#
# Usage: bash .hyperloop/checks/check-spec-ref-staleness.sh
# Exit 0 always (warnings emitted to stdout).

set -uo pipefail

MAIN_BRANCH="main"
DRIFT_FOUND=0

# Collect unique Spec-Ref values from commits above main
mapfile -t SPEC_REFS < <(
    git log "$MAIN_BRANCH"..HEAD --format="%B" 2>/dev/null \
        | grep -oP '(?<=Spec-Ref: )\S+' \
        | sort -u
)

# Also accept bare directory references (e.g. ".hyperloop/agents/process")
# by filtering to only file-like refs (containing a dot in the basename)
FILE_REFS=()
for ref in "${SPEC_REFS[@]}"; do
    if [[ "$ref" =~ ^(.+)@([0-9a-f]{7,40})$ ]]; then
        FILE_REFS+=("$ref")
    fi
done

if [ ${#FILE_REFS[@]} -eq 0 ]; then
    echo "SKIP: No file-form Spec-Ref trailers found (path@hash) in commits above $MAIN_BRANCH."
    exit 0
fi

for ref in "${FILE_REFS[@]}"; do
    spec_path="${ref%@*}"
    commit_hash="${ref##*@}"

    # Silently skip if the commit or file don't resolve — check-spec-ref-valid.sh covers that
    if ! git cat-file -e "${commit_hash}^{commit}" 2>/dev/null; then
        continue
    fi
    if ! git show "${commit_hash}:${spec_path}" >/dev/null 2>&1; then
        continue
    fi

    # Compare spec at Spec-Ref hash vs. spec at HEAD
    spec_at_ref=$(git show "${commit_hash}:${spec_path}" 2>/dev/null)
    spec_at_head=$(git show "HEAD:${spec_path}" 2>/dev/null) || {
        echo "WARNING: $spec_path no longer exists at HEAD (deleted or renamed)."
        echo "         Spec-Ref hash: $commit_hash"
        DRIFT_FOUND=1
        continue
    }

    if [ "$spec_at_ref" = "$spec_at_head" ]; then
        echo "OK (no drift): $spec_path is identical at Spec-Ref ($commit_hash) and HEAD."
    else
        DRIFT_FOUND=1
        echo "SPEC-DRIFT DETECTED: $spec_path differs between Spec-Ref ($commit_hash) and HEAD."
        echo ""
        echo "  --- spec at Spec-Ref ($commit_hash) vs HEAD ---"
        diff <(echo "$spec_at_ref") <(echo "$spec_at_head") \
            | head -60 \
            | sed 's/^/  /'
        echo ""
        echo "  ACTION REQUIRED (verifier): Apply the Spec-Drift Detection protocol."
        echo "    1. Requirements present in your assignment but absent from the committed"
        echo "       spec (Spec-Ref version above) are SPEC-DRIFT, not MISSING."
        echo "    2. Score only against the committed spec. SPEC-DRIFT items are NOT FAIL drivers."
        echo "    3. If all failures are SPEC-DRIFT, your verdict MUST be PASS."
        echo ""
    fi
done

if [ $DRIFT_FOUND -eq 1 ]; then
    echo "SUMMARY: Spec drift detected. Read the Spec-Drift Detection section of your"
    echo "         guidelines before scoring any requirement. This check exits 0 (informational)."
else
    echo "SUMMARY: No spec drift detected across all Spec-Ref references."
fi

exit 0
