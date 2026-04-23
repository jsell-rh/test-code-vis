---
task_id: task-011
round: 3
role: verifier
verdict: fail
---
## Scope Check Output

```
FAIL: Prohibited file present: godot/scripts/question_panel.gd (moldable views are not in scope)
FAIL: Prohibited file present: godot/scripts/view_spec.gd (moldable views are not in scope)
FAIL: Prohibited file present: godot/scripts/view_spec_renderer.gd (moldable views are not in scope)
FAIL: Prohibited test file present: godot/tests/test_question_panel.gd (covers a not-in-scope feature)
FAIL: Prohibited test file present: godot/tests/test_view_spec.gd (covers a not-in-scope feature)
FAIL: Prohibited test file present: godot/tests/test_view_spec_renderer.gd (covers a not-in-scope feature)
FAIL: main.gd contains references to prohibited moldable-views code
FAIL: Prohibited spec-extraction code found in extractor/extractor.py
FAIL: Prohibited spec-extraction code found in extractor/__main__.py
FAIL: Prohibited spec-extraction tests found in extractor/tests/
```

Exit code: 1

## Verdict

**FAIL.** `check-not-in-scope.sh` exits non-zero with 10 prohibited artifacts detected.
The protocol requires an immediate FAIL when this check fails — no further requirements
are evaluated.

### Required actions for the implementer

Remove all of the following before resubmitting:

**Godot scripts (moldable views — not in scope):**
- `godot/scripts/question_panel.gd`
- `godot/scripts/view_spec.gd`
- `godot/scripts/view_spec_renderer.gd`

**Godot test files (cover not-in-scope features):**
- `godot/tests/test_question_panel.gd`
- `godot/tests/test_view_spec.gd`
- `godot/tests/test_view_spec_renderer.gd`

**Wiring (main.gd):**
- Remove all references to the prohibited moldable-views scripts from `main.gd`.

**Extractor (spec-extraction — not in scope):**
- Remove prohibited spec-extraction code from `extractor/extractor.py`
- Remove prohibited spec-extraction code from `extractor/__main__.py`
- Remove prohibited spec-extraction tests from `extractor/tests/`

Additionally, the existing `worker-result.yaml` states "OK: No prohibited
(not-in-scope) features detected." but the check script clearly fails. The
implementer MUST paste the **verbatim** stdout of `check-not-in-scope.sh` (when it
actually passes) in the `## Scope Check Output` section. A fabricated or stale
"OK" line while prohibited code is present is not acceptable.