---
task_id: task-027
round: 4
role: verifier
verdict: fail
---
## Scope Check Output

OK: No prohibited (not-in-scope) features detected.

(NOTE: This is the STALE branch version of check-not-in-scope.sh. The main version
produces FAIL — see Sync Divergence section below.)

---

## Full Check Summary Table

| Check | Exit Code |
|-------|-----------|
| check-not-in-scope.sh (branch/stale) | 0 — stale version misses new patterns |
| check-not-in-scope.sh (main/current) | 1 — FAIL |
| check-rebased-onto-main.sh | 1 — FAIL |
| check-sync-divergence-impact.sh | 1 — FAIL (SUBSTANTIVE DIVERGENCE) |
| check-run-tests-suite-count.sh | 0 |
| check-pytest-test-count.sh (branch/stale) | 0 (SKIP — grep-c bug) |
| check-pytest-test-count.sh (main/current) | 0 (OK: 8 >= 8) |
| check-spec-ref-matches-task.sh | 0 |
| check-spec-ref-staleness.sh | 0 |
| check-branch-has-impl-files.sh | 0 |
| All other checks | 0 |

**Overall: FAIL — 2 blocking failures**

---

## Mandatory Individual Check Outputs (verbatim)

### check-rebased-onto-main.sh
```
FAIL: Branch 'hyperloop/task-027' is NOT rebased onto origin/main.

  Fork point (merge-base): 7f08e1d
  origin/main HEAD:        e11ddcf
  Commits on main not in branch: 7

  RISK: Merging this branch as-is would REVERT all 7 commit(s)
  that main added after 7f08e1d. Inspect what would be lost:
    git log 7f08e1d..origin/main --oneline

  Fix:
    git fetch origin main:main
    git rebase origin/main
    bash .hyperloop/checks/check-run-tests-suite-count.sh
    bash .hyperloop/checks/run-all-checks.sh
```

### check-run-tests-suite-count.sh
```
OK: _run_suite() count on branch (20) >= origin/main (20).
```

### check-pytest-test-count.sh (branch/stale version)
```
.hyperloop/checks/check-pytest-test-count.sh: line 42: 0
0: syntax error in expression (error token is "0")
SKIP: origin/main has 0 test functions in extractor/tests/ — nothing to compare.
```

### check-pytest-test-count.sh (main/current version — run via git show | bash)
```
OK: Python test count on branch (8) >= origin/main (8).
```

### check-spec-ref-matches-task.sh
```
OK: Spec-Ref path 'specs/core/visual-primitives.spec.md' matches task definition spec_ref.
```

### check-spec-ref-staleness.sh
```
OK (no drift): specs/core/visual-primitives.spec.md is identical at Spec-Ref
(67df14bc9137e80de5a60d12dad7f77c7d995959) and HEAD.
SUMMARY: No spec drift detected across all Spec-Ref references.
```

### check-sync-divergence-impact.sh
```
Stale check scripts detected (2 file(s)):
  check-not-in-scope.sh
  check-pytest-test-count.sh

DIVERGENT: check-not-in-scope.sh
  Branch (stale) output:
    OK: No prohibited (not-in-scope) features detected.
  Main (current) output:
    FAIL: Prohibited spec-extraction code found in extractor/extractor.py
    FAIL: Prohibited spec-extraction tests found in extractor/tests/

DIVERGENT: check-pytest-test-count.sh
  Branch (stale) output:
    <syntax error in expression — grep-c bug>
    SKIP: origin/main has 0 test functions in extractor/tests/ — nothing to compare.
  Main (current) output:
    OK: Python test count on branch (8) >= origin/main (8).

=== SUBSTANTIVE DIVERGENCE: At least one stale script produces different output ===
    This is not a simple race condition — the stale check conceals a real finding.
    The implementer must sync checks AND address the divergent output above.
```

### check-not-in-scope.sh (main/current version — run via git show | bash)
```
FAIL: Prohibited spec-extraction code found in extractor/extractor.py
FAIL: Prohibited spec-extraction tests found in extractor/tests/
```

### check-branch-has-impl-files.sh
```
OK: Branch 'hyperloop/task-027' has implementation commits (3 non-.hyperloop/ file(s) changed).
```

---

## Missing Commits Analysis

7 commits on origin/main not in branch:

```
e11ddcfd process(task-034): fix grep-c bug, add scope patterns, document intentional regressions
d5e26a20 chore(intake): twenty-sixth review — same five specs, no new tasks (2026-05-02)
eff82370 chore(intake): twenty-fifth review — same five specs, no new tasks (2026-05-02)
fea3e553 chore(intake): twenty-fourth review — same five specs, no new tasks (2026-05-02)
e7283182 chore(intake): twenty-third review — same five specs, no new tasks (2026-05-02)
ec40de41 process: add fix-commit-is-not-a-rebase rule for re-attempt discipline
864830ae process: add wrong-spec-section and feature-supersession guards (task-027)
```

Files touched by ALL 7 missing commits (combined diff against fork point):
- `.hyperloop/agents/process/implementer-overlay.yaml`
- `.hyperloop/agents/process/verifier-overlay.yaml`
- `.hyperloop/checks/check-not-in-scope.sh`
- `.hyperloop/checks/check-pytest-test-count.sh`
- `.hyperloop/state/intake-2026-05-02.md`
- `.hyperloop/state/resolved-specs.json`

No `extractor/` or `godot/` files are among the missing changes. However, the
`.hyperloop/checks/` updates produce SUBSTANTIVE DIVERGENCE per
check-sync-divergence-impact.sh, which prevents REBASE-ONLY FAIL classification.
This is a STANDARD FAIL requiring rebase AND resolution of the scope check finding.

---

## Scope Check Divergence — Detailed Analysis

Commit `e11ddcfd process(task-034)` extended `check-not-in-scope.sh` with new patterns:

**New extractor patterns:** `discover_spec_nodes`, `_position_spec_nodes`
**New test patterns:** `TestSpecNodeDiscovery`, `test_discover_spec_nodes`, `test_position_spec_nodes`

All of these patterns ARE present in the branch working tree:

`extractor/extractor.py`:
- Line 221: docstring references `_position_spec_nodes`
- Line 261: `_position_spec_nodes(spec_nodes, bc_radius)` call
- Line 268: `def discover_spec_nodes(src_path: Path) -> list[Node]:`
- Line 318: `def _position_spec_nodes(spec_nodes: list[Node], code_radius: float) -> None:`
- Line 1697: `spec_nodes = discover_spec_nodes(src_path)` (called from build_scene_graph)

`extractor/tests/test_extractor.py`:
- Line 1012: `class TestSpecNodeDiscovery:`
- Line 1235: `def test_position_spec_nodes_assigns_distinct_x_values`
- Line 1258: `def test_position_spec_nodes_z_offset_beyond_code_radius`
- Line 1275: `def test_position_spec_nodes_no_op_when_empty`

**Context for the orchestrator:** These functions were ALREADY PRESENT at the fork
point (7f08e1d8) — confirmed via `git show 7f08e1d:extractor/extractor.py`. The branch's
two commits (`a237fbb7`, `3333c8f5`) did NOT introduce them. Furthermore, `discover_spec_nodes`
and `_position_spec_nodes` are ALSO PRESENT on current origin/main (e11ddcfd) — confirmed
via `git show origin/main:extractor/extractor.py`. Commit `e11ddcfd` added the scope
check patterns in anticipation of a future removal (likely task-034's implementation work).
When the implementer rebases and syncs checks, they will encounter a failing scope check
for code that was pre-existing at their fork point and has not yet been removed from main.

---

## Commit Trailers

Both commits carry required trailers:

- `a237fbb7` — Spec-Ref: specs/core/visual-primitives.spec.md@67df14bc, Task-Ref: task-027 ✓
- `3333c8f5` — Spec-Ref: specs/core/visual-primitives.spec.md@67df14bc, Task-Ref: task-027 ✓

---

## Requirements Coverage Table

Task-027 spec (visual-primitives.spec.md § Ubiquitous Dependency Detection):

| Requirement | Status | Notes |
|-------------|--------|-------|
| Compute fraction of modules importing each dependency | COVERED | detect_ubiquitous_dependencies() computes fraction per module |
| Flag dependencies imported by >50% (configurable) | COVERED | UBIQUITOUS_THRESHOLD = 0.5 default; function accepts threshold param |
| Edge `ubiquitous: true` annotation for flagged deps | COVERED | detect_ubiquitous_dependencies() sets edge["ubiquitous"] = True |
| Threshold recorded in extraction metadata | COVERED | metadata["ubiquitous_deps"]["threshold_pct"] = 50 |
| Flagged module list in extraction metadata | COVERED | metadata["ubiquitous_deps"]["flagged"] = sorted list |
| UbiquitousDeps TypedDict in schema | COVERED | schema.py adds UbiquitousDeps with threshold_pct and flagged |
| Individual cross_context edges carry weight field | COVERED | raw_edge_count dict accumulator; weight = max(count, 1) |
| Individual internal edges carry weight field | COVERED | Same mechanism |
| Metadata tests (5 new) | COVERED | TestUbiquitousDepsMetadata class |
| Edge weight tests (2 new) | COVERED | test_cross_context_edge_has_weight, test_internal_edge_has_weight |

All spec requirements for task-027 are implemented and tested. The implementation is
substantively correct. The FAIL is driven exclusively by process checks (rebase failure,
scope check divergence), not by implementation gaps.

---

## Minor Code Quality Note

`build_scene_graph()` records `threshold_pct` using `_DEFAULT_UBIQUITY_THRESHOLD` while
`detect_ubiquitous_dependencies()` uses `UBIQUITOUS_THRESHOLD` (separate constants, both
= 0.5). If either constant were changed independently, the recorded threshold would
misrepresent the actual threshold used. Low-risk in the prototype; worth addressing if
threshold configurability is added.

---

## FAIL Reasons

1. **check-rebased-onto-main.sh exits 1**: Branch is 7 commits behind origin/main.
   Merge base: 7f08e1d; origin/main HEAD: e11ddcfd. Rebase is required.

2. **check-sync-divergence-impact.sh exits 1 (SUBSTANTIVE DIVERGENCE)**: The updated
   `check-not-in-scope.sh` on main detects prohibited spec-extraction patterns
   (`discover_spec_nodes`, `_position_spec_nodes`, `TestSpecNodeDiscovery`,
   `test_position_spec_nodes_*`) in the working tree. Branch stale version: OK.
   Main current version: FAIL. The impact assessment explicitly classifies this as
   substantive divergence, not a simple race condition.

---

## Required Fix

```bash
# Step 1: Sync check scripts from current main
git checkout main -- .hyperloop/checks/

# Step 2: Rebase onto current main
git fetch origin main:main
git rebase origin/main

# Step 3: After rebase, run scope check to see what it finds
bash .hyperloop/checks/check-not-in-scope.sh
# Expected: will FAIL on discover_spec_nodes / _position_spec_nodes
# These functions are pre-existing (not introduced by this branch).
# Consult orchestrator for resolution — see ORCHESTRATOR NOTE below.

# Step 4: Run full check suite after scope issue is resolved
bash .hyperloop/checks/run-all-checks.sh
```

**ORCHESTRATOR NOTE:** The spec-extraction functions (`discover_spec_nodes`,
`_position_spec_nodes`) flagged by the updated `check-not-in-scope.sh` are PRE-EXISTING
on main at the branch fork point AND on current origin/main — they were not introduced
by task-027. Commit `e11ddcfd` (process/task-034) added the scope check patterns in
anticipation of removing these functions, which appears to be task-034's implementation
work (not yet merged). Before re-assigning task-027, the orchestrator should clarify
whether: (a) task-027 is expected to also remove the spec-extraction code as part of
its re-attempt, (b) task-034 should complete first so task-027 can rebase onto a clean
main, or (c) the scope check should be relaxed for pre-existing code.