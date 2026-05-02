---
task_id: task-078
round: 0
role: verifier
verdict: fail
---
## Scope Check Output

```
NOTE: Pre-existing prohibited spec-extraction code in extractor/extractor.py (NOT introduced by this branch).
  Informational only — does NOT count as FAIL. Another task is responsible for removal.
NOTE: Pre-existing prohibited spec-extraction tests in extractor/tests/ (NOT introduced by this branch).
  Informational only — does NOT count as FAIL. Another task is responsible for removal.
OK: No prohibited (not-in-scope) features detected.
```

(After re-syncing checks from main — see Check Sync section below.)

---

## Check Sync

Initial sync `git checkout main -- .hyperloop/checks/` ran before check-not-in-scope.sh.
`check-checks-in-sync.sh` exited 0 (69 scripts).

During the review, main advanced by one process-only commit:
`9a83afdb process(task-027): add branch-attribution to scope check section 2 and Case C guidance`
Files touched: `.hyperloop/agents/process/implementer-overlay.yaml`, `.hyperloop/agents/process/orchestrator-overlay.yaml`, `.hyperloop/checks/check-not-in-scope.sh`. No implementation files.

A second sync was performed; `check-checks-in-sync.sh` again exited 0 (69 scripts).

`check-sync-divergence-impact.sh` exited 0 — no divergent output.

---

## run-all-checks.sh Output (final run, after second sync)

All 69 checks pass except one:

```
--- check-rebased-onto-main.sh ---
FAIL: Branch 'hyperloop/task-078' is NOT rebased onto origin/main.
  Fork point (merge-base): 639dc44
  origin/main HEAD:        9a83afd
  Commits on main not in branch: 1
[EXIT 1 — FAIL]
```

All other checks: EXIT 0.

---

## Rebase Failure Classification

The single missing commit is:
```
9a83afdb process(task-027): add branch-attribution to scope check section 2 and Case C guidance
```
Files: `.hyperloop/agents/process/implementer-overlay.yaml`, `.hyperloop/agents/process/orchestrator-overlay.yaml`, `.hyperloop/checks/check-not-in-scope.sh` — no extractor/, no godot/, no implementation files.

Per REBASE-ONLY FAIL classification: this is a process-only race condition. Main advanced during the review window; the implementer cannot prevent this.

**However, the verdict is still FAIL due to a substantive WRONG-FEATURE finding (see below). The rebase is required, but the WRONG-FEATURE issue also needs resolution.**

Fix:
```
git fetch origin main:main
git rebase origin/main
bash .hyperloop/checks/run-all-checks.sh
```

---

## Spec-Ref Staleness Check

`check-spec-ref-staleness.sh` output:
```
OK (no drift): specs/core/visual-primitives.spec.md is identical at Spec-Ref
(67df14bc9137e80de5a60d12dad7f77c7d995959) and HEAD.
SUMMARY: No spec drift detected.
```

No spec drift. The spec the implementer worked against is identical to HEAD.

Note: The task definition (`hyperloop/state:.hyperloop/state/tasks/task-078.md`) uses spec_ref
`82d048ecde6d3209435ad2561c1384da93ba2cdd` while the implementation commits use
`67df14bc9137e80de5a60d12dad7f77c7d995959`. Both refer to commits whose spec file content
is identical (verified by `check-spec-ref-staleness.sh`). No scoring impact.

---

## check-spec-ref-matches-task.sh

```
SKIP: Task file '.hyperloop/state/tasks/task-078.md' not found — cannot validate spec path.
```

Task file exists on `hyperloop/state` branch but is not present in the working tree.
Retrieved manually from `git show hyperloop/state:.hyperloop/state/tasks/task-078.md`.

---

## SPEC SECTION vs TASK TITLE AUDIT — WRONG-FEATURE FAIL

**Task-078 definition (from hyperloop/state):**
```yaml
id: task-078
title: Extractor — symbol table extraction
spec_ref: specs/core/visual-primitives.spec.md@82d048ecde6d3209435ad2561c1384da93ba2cdd
deps: [task-075, task-002]
```

**Branch commits (above main):**
| Commit | Subject |
|--------|---------|
| 84d56212 | feat(godot): render Port primitives on Container membrane (task-078) |
| d9667b93 | feat(extractor): implement data flow spine extraction for function symbols |
| 64fd5e89 | fix(godot): add billboard and pixel_size assertions to port label tests |
| 6de0f670 | fix(extractor): remove unused _trace_param_to_return import from tests |
| 293c69a5 | chore(intake): twenty-fifth review (process-only) |
| 639dc446 | feat(visualization): cluster collapse/expand supernode animation (task-068, already on main) |

**Section implemented vs section assigned:**

The task title names **"Symbol Table Extraction"** — spec section at line 57 of the committed
spec:
```
### Requirement: Symbol Table Extraction
The extractor MUST produce the named entities in each scope — functions, types, constants,
variables — with their signatures and visibility.
```

The branch implements:
1. **Data Flow Spine Extraction** — spec section `### Requirement: Data Flow Spine Extraction` (line 116)
2. **Port Primitive rendering** — spec section `### Requirement: Port Primitive` (line 271, Composition Layer)

**Is the ASSIGNED feature (Symbol Table Extraction) implemented on this branch?** No. The
branch adds zero code to `extract_symbols()` and zero new tests for `TestSymbolTableExtraction`.

**Is the ASSIGNED feature implemented at all?** Yes — by task-023 in PR #234 (commit `20461a84`,
`Task-Ref: task-023`). `extract_symbols()` at line 952 of origin/main fully covers the
Symbol Table Extraction requirement.

**VERDICT: FAIL — WRONG-FEATURE.** The branch implements Data Flow Spine Extraction and Port
Primitive rendering. The task assigned Symbol Table Extraction. Symbol table extraction is
complete on origin/main and was NOT this task's contribution.

**Orchestrator note:** Task-078 was assigned a feature already implemented on main by
task-023. The orchestrator should:
1. Determine the intended deliverable for task-078.
2. If the deliverable was Data Flow Spine Extraction — create a new task for it, close
   task-078 or retitle it, and re-review the branch under the correct task.
3. If the deliverable was Port Primitive rendering — note that task-038 is also
   implementing Port Primitive (PR #240, phase: spec-review). Evaluate whether task-078's
   port work overlaps with or supersedes task-038. Only one should proceed.
4. The data flow spine work (d9667b93) and the port primitive work (84d56212) are both
   legitimate new features not yet on main — they need correct task assignments before
   they can be accepted.

---

## Port Primitive — THEN-Clause Coverage (implemented feature)

Even setting aside the wrong-feature issue, the Port Primitive implementation is PARTIAL.

**Scenario: Port placement:**
| THEN-clause | Status | Test |
|-------------|--------|------|
| 4 Ports appear on its membrane | COVERED | `test_port_nodes_created_for_public_functions` |
| each Port is labeled with the function name | COVERED | `test_port_labels_match_function_names` |
| Edges connect to Ports, not directly to the Container body | MISSING | No test; edge rendering still routes to Container centroid |

**Scenario: Port direction:**
| THEN-clause | Status | Test |
|-------------|--------|------|
| input Ports (parameters/dependencies) visually distinct from output Ports (return values/emitted events) | MISSING | No implementation; all ports are uniform cyan spheres; no distinction by direction |

**Scenario: Port visibility at zoom levels:**
| THEN-clause | Status | Test |
|-------------|--------|------|
| Ports are hidden (the Container appears as a solid region) at far | COVERED | `test_ports_hidden_at_far_lod` |
| as the human zooms in, Ports fade in on the membrane | COVERED (PASS-WITH-NOTE) | `test_ports_visible_at_near_lod` asserts `visible==true`; lod_manager uses `Tween.tween_property(node, "modulate:a", ...)` which is architecturally correct but untestable in headless CI |
| this follows the LOD Shell behavior | COVERED | ports registered as `node_type="port"` in `_lod_node_entries` |

**Summary:** Port placement (count + labels) and LOD visibility are COVERED.
Port direction (input vs output) is MISSING — no implementation and no test.
Edge routing to Ports is MISSING — no implementation and no test.

**Actionable fixes:**
1. Implement port direction: distinguish input (parameter) ports from output (return value)
   ports visually — e.g., different color or position (left-half vs right-half of membrane).
2. Add `test_port_direction_input_output_distinct()`: fixture with a function having
   parameters AND a return type; assert input-side ports and output-side ports are
   positioned differently.
3. Implement edge routing to Ports: when building edges, look up the Port position for the
   target node and route the edge endpoint there instead of the Container centroid.
4. Add `test_edges_connect_to_ports()`: fixture with one node having ports and an edge
   targeting it; assert edge endpoint position matches a Port position, not the Container
   centroid.

---

## Data Flow Spine Extraction — THEN-Clause Coverage (implemented feature)

This section reviews the data flow spine work (d9667b93) for completeness even though it is
the wrong feature for this task.

**Scenario: Parameter to return value:**
| THEN-clause | Status | Test |
|-------------|--------|------|
| spine from parameter `input` through each operation to the return value is emitted | COVERED | `test_parameter_to_return_emits_spine` |
| each step in the spine references the intermediate function or expression | COVERED | `test_intermediate_call_sites_recorded` |

**Scenario: One-call-deep interprocedural flow:**
| THEN-clause | Status | Test |
|-------------|--------|------|
| spine includes A's x -> B's parameter -> B's return -> A's y | COVERED | `test_one_call_deep_interprocedural_flow` |
| extractor does NOT trace deeper than one call level | COVERED by architecture | Single-pass analysis of each function body; no fixed-point recursion present |

**Scenario: Extraction cost boundary:**
| THEN-clause | Status | Test |
|-------------|--------|------|
| completes by analyzing each function body independently (intraprocedural) | COVERED by design | Each function analyzed independently |
| interprocedural analysis limited to one call depth | COVERED | `test_one_call_deep_interprocedural_flow` |
| whole-program fixed-point analysis is NOT performed | COVERED by design | No fixed-point code exists |

Additional tests: `test_spine_starts_with_parameter_step`, `test_spine_ends_with_return_value_step`,
`test_type_hint_recorded_on_parameter_step`, `test_unannotated_parameter_has_no_type_hint`,
`test_parameter_not_reaching_return_omitted`, `test_self_excluded_from_spines`, `test_no_params_returns_empty`.
Two integration tests in `TestFlowSpinesIntegratedIntoSymbols` verify `flow_spines` appears
on function symbol dicts in the scene graph output.

All Data Flow Spine THEN-clauses: **COVERED**.

---

## Symbol Table Extraction — ASSIGNED Section (not implemented by this branch)

**Scenario: Public vs. private symbols:**
| THEN-clause | Status | Test |
|-------------|--------|------|
| both functions emitted as symbols | COVERED on main | `extract_symbols()`, `TestSymbolTableExtraction` (pre-existing, task-023) |
| `process_order` marked public; `_validate_input` marked private | COVERED on main | same |
| each symbol carries its signature | COVERED on main | same |

**Scenario: Symbol as labeling layer:**
| THEN-clause | Status | Test |
|-------------|--------|------|
| symbol table provides human-readable names/signatures for call graph edges | COVERED on main | `extract_symbols()` populates `symbols` array; pre-existing |

This task's ASSIGNED section is fully covered by pre-existing origin/main code (task-023). This
branch contributes zero new implementation or tests for symbol table extraction.

---

## Mechanical Checks Summary

| Check | Result | Notes |
|-------|--------|-------|
| check-not-in-scope.sh | PASS (NOTE) | Pre-existing spec-extraction patterns; not introduced by this branch |
| check-rebased-onto-main.sh | FAIL | Process-only race: 1 commit (`.hyperloop/` only) added to main during review |
| check-branch-forked-from-main.sh | PASS | (Resolved after main re-sync) |
| check-commit-trailer-task-ref.sh | PASS | (Resolved after main re-sync) |
| check-spec-ref-valid.sh | PASS | (Resolved after main re-sync; 639dc446 moved to main) |
| check-spec-ref-matches-task.sh | SKIP | task-078.md not in working tree |
| check-spec-ref-staleness.sh | PASS | No spec drift |
| check-branch-has-impl-files.sh | PASS | 6 non-.hyperloop files |
| check-no-gdscript-duplicate-functions.sh | PASS | |
| godot-compile.sh | PASS | |
| godot-tests.sh | PASS | 244 passed, 0 failed (includes 5 new port tests) |
| extractor-lint.sh | PASS | ruff + 268 pytest tests pass |
| check-run-tests-suite-count.sh | PASS | 20 suites on branch >= 20 on origin/main |
| check-pytest-test-count.sh | PASS | 8 top-level test functions >= 8 on origin/main |
| check-typeddict-fields-extractor-tested.sh | PASS | |
| check-compute-functions-called-from-entry-point.sh | PASS | |
| All other checks | PASS | |

---

## Verdict Explanation

**FAIL** for two reasons:

1. **REBASE-ONLY FAIL**: `check-rebased-onto-main.sh` fails because main advanced by one
   process-only commit during the review window. No implementation changes are needed for
   this — a rebase is sufficient.

2. **WRONG-FEATURE (substantive)**: The task assigned "Extractor — symbol table extraction"
   (already on main via task-023). This branch implements Data Flow Spine Extraction and
   Port Primitive rendering — different spec sections. Before re-attempting, the orchestrator
   must clarify the correct task assignment for these features.

**What the implementer must NOT do:** Do not simply rebase and resubmit. The wrong-feature
issue requires orchestrator decision about task ownership before any re-attempt.

**What the implementer must do (once orchestrator has clarified task assignment):**
1. `git fetch origin main:main && git rebase origin/main`
2. Address the two MISSING Port Primitive THEN-clauses (port direction + edge routing)
3. Confirm task ID is correct before resubmitting