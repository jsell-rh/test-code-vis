---
task_id: task-063
round: 4
role: spec-reviewer
verdict: fail
---
# Review: task-063 — Scene-Graph Schema Extractor-Level Tests (Round 4)

Branch: hyperloop/task-063
Implementation commits: c2a92036, a64994db (above 5761fff / current origin/main before today's fix)
Spec-Ref: specs/extraction/scene-graph-schema.spec.md
Task-Ref: task-063

---

## Scope Check Output

OK: No prohibited (not-in-scope) features detected.

---

## Blocking FAILs

### 1. Branch Not Rebased onto origin/main (BLOCKING)

`check-rebased-onto-main.sh` exits 1:

```
FAIL: Branch 'hyperloop/task-063' is NOT rebased onto origin/main.

  Fork point (merge-base): 5761fff
  origin/main HEAD:        6db01fe
  Commits on main not in branch: 1
```

The missing commit is a process fix:
```
6db01fe1 fix(process): scope spec-ref check to current task; add commit discipline rule
```

This commit updates three files:
- `.hyperloop/agents/process/spec-reviewer-overlay.yaml`
- `.hyperloop/agents/process/verifier-overlay.yaml`
- `.hyperloop/checks/check-spec-ref-matches-task.sh`

No implementation conflict is expected — the commit only modifies process/check files.

### 2. Stale Check Scripts (BLOCKING)

`check-checks-in-sync.sh` exits 1:

```
FAIL: 1 check script(s) exist in working tree but have DIFFERENT CONTENT than main:
  check-spec-ref-matches-task.sh
```

`check-sync-divergence-impact.sh` also exits 1 because `check-deliverable-component.sh`
produces substantively different output (different tmp path in the SKIP message) — though
this is a cosmetic content difference in the stale file.

Three scripts are stale vs main:
- `check-spec-ref-matches-task.sh` — different content (the scope fix from 6db01fe1)
- `check-deliverable-component.sh` — different content (substantive output difference)
- `check-edge-rerouting-wired.sh` — different content but identical output

Fix:
```
git fetch origin
git rebase origin/main
git checkout origin/main -- .hyperloop/checks/
bash .hyperloop/checks/check-checks-in-sync.sh   # verify exit 0
bash .hyperloop/checks/run-all-checks.sh
```

---

## Non-Blocking (Expected During Review)

`check-report-scope-section.sh` exits 1 because `.hyperloop/worker-result.yaml` was
absent from the working tree; this check validates the report being written now.
The section is present in this report and will satisfy the check in the next round.

---

## Spec Coverage

All spec requirements from `specs/extraction/scene-graph-schema.spec.md` are implemented
and tested. The task-063 implementation itself is correct and complete. The sole blockers
are the missing rebase (1 commit) and stale check scripts.

| Requirement / Scenario | Status | Implementation | Test |
|---|---|---|---|
| Schema Structure: top-level keys `nodes`, `edges`, `metadata`, `clusters` — no others | COVERED | `build_scene_graph()` in extractor.py | `test_build_scene_graph_has_exactly_four_top_level_keys` (test_extractor.py:769); `test_scene_graph_has_no_extra_top_level_fields` (test_schema.py:126) |
| Node: bounded context fields (id, name, type, position, size, parent=null) | COVERED | `discover_bounded_contexts()`, `build_scene_graph()` | `test_bounded_context_node_has_required_keys`, `test_bounded_context_node_parent_is_null` (test_schema.py:164–201) |
| Node: module node fields + parent ref | COVERED | `discover_submodules()` | `test_module_node_has_required_keys`, `test_module_node_parent_references_context` (test_schema.py:203–218) |
| Node: module position relative to parent | COVERED | `compute_layout()` stores local offsets | `test_child_position_is_local_offset` (test_extractor.py:499) — parent at x=5.0 (non-zero), asserts child.x==1.5 (local offset) and child.z==0.0 directly |
| Node: independence_group field | COVERED | `compute_independence_groups()` | `test_independence_group_format` (test_extractor.py:1291); `test_build_scene_graph_assigns_independence_groups` (test_extractor.py:1312) |
| Edge: cross-context source/target/type | COVERED | `build_dependency_edges()` | `test_cross_context_edge_direction_encodes_importer_to_imported` (test_extractor.py:726); `test_cross_context_edge_source/target/type` (test_schema.py:253–263) |
| Edge: internal source/target/type | COVERED | `build_dependency_edges()` | `test_internal_edge_distinguishable_from_cross_context` (test_extractor.py:753); `test_internal_edge_source/target/type` (test_schema.py:270–280) |
| Weighted edge: individual edges carry weight >= 1 | COVERED | `build_dependency_edges()` emits explicit `weight` on all individual edges | `test_individual_cross_context_edges_have_weight` (test_extractor.py:835); `test_individual_internal_edges_have_weight` (test_extractor.py:869) |
| Weighted edge: aggregate edge with weight = import count | COVERED | `build_dependency_edges()` emits `type="aggregate"` edge with `bc_pair_weight` | `test_aggregate_edge_weight_equals_module_import_count` (test_extractor.py:903) — fixture has exactly 2 module imports, asserts weight==2 |
| Metadata: source_path and timestamp | COVERED | `build_scene_graph()` | `test_metadata_has_source_path` (test_extractor.py:652); `test_metadata_has_timestamp` (test_extractor.py:657) |
| Pre-Computed Layout: positions in JSON, coupled nodes closer | COVERED | `compute_layout()` runs layout algorithm; Godot receives pre-computed positions | `test_child_position_is_local_offset` (test_extractor.py:499); `test_coupled_bcs_are_closer_than_uncoupled` (test_extractor.py:542) |
| Cluster: id, members, context, aggregate_metrics | COVERED | `compute_clusters()` | `test_coupled_modules_form_cluster` (test_extractor.py:1331); `test_cluster_aggregate_metrics_keys` (test_extractor.py:1380); `test_cluster_has_required_keys` (test_schema.py:331) |
| Cluster: empty array when no coupling | COVERED | `compute_clusters()` returns `[]` when no pairs exceed threshold | `test_no_clusters_when_no_coupling` (test_extractor.py:1360) |
| Cascade Depth: depth on affected nodes, available to visualization | COVERED | `compute_cascade_depth()` + `annotate_cascade_depth()` | `test_compute_then_annotate_pipeline` (test_extractor.py:1532) — asserts node_a.depth==1, node_b.depth==2; `test_depth_available_in_json` (test_extractor.py:1522) |

---

## Required Fix (Sole Blocker)

Rebase is the only required action. No spec coverage gaps and no implementation defects exist.

```bash
git fetch origin
git rebase origin/main
# No implementation conflicts expected — commit only modifies process/check files
git checkout origin/main -- .hyperloop/checks/
bash .hyperloop/checks/check-checks-in-sync.sh   # verify exit 0
bash .hyperloop/checks/run-all-checks.sh          # all checks must pass
```

After the rebase, the test suite count must remain >= 254.