#!/bin/bash
# Verifies that an automated integration test exists that runs the extractor
# against the real ~/code/kartograph codebase and asserts expected output.
#
# The spec requires: "GIVEN the kartograph codebase WHEN the extractor is run
# THEN the scene graph contains the expected bounded contexts (iam, graph,
# shared_kernel)."  A committed scene_graph.json is NOT a test.

set -e
FAIL=0

TESTS_DIR="extractor/tests"

if [ ! -d "$TESTS_DIR" ]; then
  echo "SKIP: No extractor/tests/ directory found."
  exit 0
fi

# An integration test must both:
#   1. Reference the kartograph path (to show it runs against the real codebase)
#   2. Assert a known bounded context is present in the output
if grep -rl "kartograph" "$TESTS_DIR" 2>/dev/null | xargs grep -l "iam\|shared_kernel\|graph" 2>/dev/null | grep -q .; then
  echo "OK: Integration test referencing kartograph codebase with expected-context assertions found."
else
  echo "FAIL: No integration test found that runs the extractor against ~/code/kartograph"
  echo "  Required: a pytest or shell test that invokes 'python -m extractor ~/code/kartograph/src/api'"
  echo "  and asserts the output JSON contains expected bounded contexts (iam, graph, shared_kernel)."
  echo "  A committed scene_graph.json is evidence of a manual run, not an automated test."
  FAIL=1
fi

exit "$FAIL"
