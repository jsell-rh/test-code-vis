#!/bin/bash
# Verifies that the Python extractor CLI entry point (main() in __main__.py)
# is exercised by at least one test.
#
# Pattern caught: implementers write `main()` but only test internal extraction
# logic directly, leaving the CLI code path untested.
# Required: a pytest test that calls main([...]) or invokes `python -m extractor`
# via subprocess and asserts exit code 0 and valid JSON output.

set -e
FAIL=0

MAIN_FILE="extractor/__main__.py"
TESTS_DIR="extractor/tests"

if [ ! -f "$MAIN_FILE" ]; then
  echo "SKIP: No extractor/__main__.py found."
  exit 0
fi

if [ ! -d "$TESTS_DIR" ]; then
  echo "SKIP: No extractor/tests/ directory found."
  exit 0
fi

# Check that tests call main() directly or invoke the module via subprocess
if grep -rl "main(" "$TESTS_DIR" 2>/dev/null | grep -q .; then
  echo "OK: A test calls main() from the extractor CLI entry point."
elif grep -rl "python -m extractor\|subprocess.*extractor" "$TESTS_DIR" 2>/dev/null | grep -q .; then
  echo "OK: A test invokes the extractor as a module via subprocess."
else
  echo "FAIL: No test exercises the CLI entry point (main() in extractor/__main__.py)."
  echo "  Required: a pytest test in extractor/tests/ that calls:"
  echo "    from extractor.__main__ import main"
  echo "    rc = main([str(src_path), '--output', str(out)])"
  echo "    assert rc == 0"
  echo "    assert out.exists()"
  echo "  OR a subprocess invocation: subprocess.run(['python', '-m', 'extractor', ...], check=True)"
  echo "  A THEN-clause 'runs as a standalone CLI tool' is PARTIAL until this test exists."
  FAIL=1
fi

exit "$FAIL"
