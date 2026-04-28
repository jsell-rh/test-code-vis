#!/bin/bash
# check-spec-ref-valid.sh
# Validates that every Spec-Ref trailer in implementation commits:
#   1. Contains a file-path@commit-hash form  (path@hash)
#   2. The commit hash resolves in this repo   (git cat-file -e)
#   3. The spec file exists at that commit     (git show hash:path)
#
# A Spec-Ref that points to a non-existent commit or file is either
# fabricated or references an un-pushed spec version — both are failures.
#
# Usage: bash .hyperloop/checks/check-spec-ref-valid.sh
# Exit 0 = all Spec-Refs valid (or none found)
# Exit 1 = at least one Spec-Ref is unresolvable

set -uo pipefail

MAIN_BRANCH="main"
FAIL=0
CHECKED=0
MISSING=0

# Collect unique Spec-Ref values from all commits above main
mapfile -t SPEC_REFS < <(
    git log "$MAIN_BRANCH"..HEAD --format="%B" 2>/dev/null \
        | grep -oP '(?<=Spec-Ref: )\S+' \
        | sort -u
)

if [ ${#SPEC_REFS[@]} -eq 0 ]; then
    echo "SKIP: No Spec-Ref trailers found in commits above $MAIN_BRANCH."
    exit 0
fi

for ref in "${SPEC_REFS[@]}"; do
    CHECKED=$((CHECKED + 1))

    # Expected form:  some/path/file.spec.md@<40-hex-char hash>
    if [[ "$ref" =~ ^(.+)@([0-9a-f]{7,40})$ ]]; then
        spec_path="${BASH_REMATCH[1]}"
        commit_hash="${BASH_REMATCH[2]}"
    else
        echo "FAIL: Spec-Ref '$ref' is not in 'path@hash' form."
        FAIL=1
        continue
    fi

    # 1. Verify the commit hash exists in the repo
    if ! git cat-file -e "${commit_hash}^{commit}" 2>/dev/null; then
        echo "FAIL: Spec-Ref commit '$commit_hash' does not exist in this repo."
        echo "      (Spec-Ref: $ref)"
        FAIL=1
        MISSING=$((MISSING + 1))
        continue
    fi

    # 2. Verify the spec file exists at that commit
    if ! git show "${commit_hash}:${spec_path}" >/dev/null 2>&1; then
        echo "FAIL: '$spec_path' does not exist at commit '$commit_hash'."
        echo "      (Spec-Ref: $ref)"
        echo "      The spec file was either never committed at that hash or the path is wrong."
        FAIL=1
        MISSING=$((MISSING + 1))
        continue
    fi

    echo "OK: $ref — commit and file both resolve."
done

echo ""
echo "Checked $CHECKED Spec-Ref(s); $MISSING unresolvable."

if [ $FAIL -ne 0 ]; then
    exit 1
fi
exit 0
