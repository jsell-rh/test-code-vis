---
task_id: task-063
round: 2
role: spec-reviewer
verdict: fail
---
# Review: task-063 — Scene-Graph Schema Extractor-Level Tests (Round 2)

Branch: hyperloop/task-063
Implementation commit: 6b269173 (test(task-063): add extractor-level coverage for scene-graph schema spec)
Spec-Ref: specs/extraction/scene-graph-schema.spec.md@7b9391479f56416ec06f248e0321b956bdb5f8ed (resolves OK — no drift)
Task-Ref: task-063 (correct on implementation commit)

---

## Scope Check Output

OK: No prohibited (not-in-scope) features detected.

---

## Round 2 vs Round 1 Delta

Previous verdict: FAIL (primary driver: missing test_godot_app_spec.gd suite registration).

Since Round 1:
- Branch has been rebased: check-run-tests-suite-count.sh now EXIT 0 (20 == 20).
- check-branch-forked-from-main.sh: EXIT 0 (parallel-history false positives resolved).
- check-commit-trailer-task-ref.sh: EXIT 0 (resolved).
- check-spec-ref-valid.sh: EXIT 0 (all 9 Spec-Refs resolve cleanly).
- check-checks-in-sync.sh: EXIT 0 (62 checks, content-identical).
- check-nondirectional-movement-assertions.sh: EXIT 0 (no directional tests in scope).

One new check that was introduced to main after Round 1 now fires:
  check-individual-edge-weight.sh: EXIT 1 — Gate 1 FAIL.

This check was added by commit ad7a7d7c ("fix(process): enforce all-variants field
coverage for 'each edge' requirements", 2026-05-02 02:33:06), after the task-063
implementation commit (2026-05-01 22:52:37). Per the process rule established by
commit 6fa72ad2 ("fix(process): require implementers to fix post-rebase check failures
regardless of authorship"), the implementer is required to fix this failure even
though the check did not exist at implementation time.

---

## Failing Checks

### check-individual-edge-weight.sh — EXIT 1

Gate 1 FAIL: `build_dependency_edges()` does not emit `weight` on individual
`cross_context` / `internal` edges.

  Individual edge construction found at extractor/extractor.py:463:
    {"source": src, "target": tgt, "type": etype}
  The `weight` key is absent. No per-pair accumulator exists for non-aggregate edges.

Gate 2: PASSES (by proximity) — but note the actual gate-2 test asserts ABSENCE of
weight, not presence. The check's proximity heuristic fires positively on
`test_individual_cross_context_edges_have_no_weight_field` because it contains both
`"cross_context"` and `"weight"` within 25 lines, but the assertion is
`assert "weight" not in e`. This is a false-positive on Gate 2; the check's Gate 2
intends to find a test that verifies weight IS present.

### Spec vs Check Conflict (informational — check takes precedence)

The spec (§Weighted edge scenario) says:
  "individual module-level edges each have weight: 1 (or weight omitted, defaulting to 1)"

The task-063 tests (`test_individual_cross_context_edges_have_no_weight_field`,
`test_individual_internal_edges_have_no_weight_field`) correctly implement the
"weight omitted" branch of the spec and assert `"weight" not in e`.

The check script enforces the stricter interpretation: individual edges MUST carry an
explicit `weight` field equal to the per-(source,target) import count. The check's
comment cites "each edge carries the import count" as the spec requirement. This is
not literal spec text — the spec allows omission — but the check is now a hard gate
on main and must be satisfied.

### check-report-scope-section.sh — EXIT 0 (after this report is written)

The previous round lacked a `## Scope Check Output` section. This report includes it.

---

## Spec Coverage (spec at 7b9391479f — no drift from HEAD)

| Requirement / Scenario                                | Status   | Notes |
|-------------------------------------------------------|----------|-------|
| Schema Structure: exactly 4 top-level keys            | COVERED  | test_build_scene_graph_has_exactly_four_top_level_keys (set equality) |
| Node: bounded context fields (id, name, type, position, size, parent=null) | COVERED | pre-existing tests |
| Node: module node fields + parent ref + relative position | COVERED | pre-existing tests |
| Node: independence_group field                        | COVERED  | test_independence_group_format + test_build_scene_graph_assigns_independence_groups |
| Edge: cross-context source/target/type                | COVERED  | pre-existing tests |
| Edge: internal source/target/type                     | COVERED  | pre-existing tests |
| Weighted edge: individual weight omitted              | COVERED (spec) / CHECK FAIL | task-063 tests assert absence; implementation omits weight — matches spec but fails check-individual-edge-weight.sh Gate 1 |
| Weighted edge: aggregate weight=N                     | COVERED  | test_aggregate_edge_weight_equals_module_import_count (src_weighted fixture, weight=2) |
| Metadata: source path + timestamp                     | COVERED  | test_metadata_has_source_path + test_metadata_has_timestamp |
| Pre-Computed Layout: positions in JSON                | COVERED  | pre-existing layout tests |
| Cluster: id, members, context, aggregate_metrics      | COVERED  | test_coupled_modules_form_cluster + test_cluster_aggregate_metrics_keys |
| Cluster: empty array when no coupling                 | COVERED  | test_no_clusters_when_no_coupling |
| Cascade Depth: depth=1,2 on affected nodes            | COVERED  | Simulation mode is out of prototype scope per prototype-scope.spec.md; depth field exists as NotRequired in TypedDict |

---

## Required Fix

**check-individual-edge-weight.sh Gate 1** is the sole blocking failure.

The fix has two parts:

### Part 1 — Implementation (extractor/extractor.py, build_dependency_edges)

Replace the `raw_edges` set (which deduplicates but loses import count) with a dict
that accumulates per-(source_id, target_id, etype) import count:

  Before (line 459, approximately):
    raw_edges.add((source_id, target_id, "internal"))
    # and similar for cross_context

  After:
    raw_edge_count: dict[tuple[str, str, str], int] = {}
    # wherever cross_context/internal is detected:
    key = (source_id, target_id, "cross_context")   # or "internal"
    raw_edge_count[key] = raw_edge_count.get(key, 0) + 1

  Then emit weight on each individual edge (lines 462–465):
    edges: list[Edge] = [
        {"source": src, "target": tgt, "type": etype, "weight": count}
        for (src, tgt, etype), count in sorted(raw_edge_count.items())
    ]

### Part 2 — Tests (extractor/tests/test_extractor.py, TestWeightedEdge)

The two tests added by task-063 currently assert that weight is ABSENT from individual
edges — which matched the spec's "weight omitted" branch but now contradicts the check.
Replace them with tests that assert weight IS present and >= 1:

  Replace `test_individual_cross_context_edges_have_no_weight_field`:
    def test_individual_cross_context_edges_have_weight(self, src: Path) -> None:
        ...
        for e in cc_edges:
            assert "weight" in e, f"cross_context edge missing weight: {e}"
            assert e["weight"] >= 1

  Replace `test_individual_internal_edges_have_no_weight_field`:
    def test_individual_internal_edges_have_weight(self, src: Path) -> None:
        ...
        for e in internal_edges:
            assert "weight" in e, f"internal edge missing weight: {e}"
            assert e["weight"] >= 1

No other implementation changes are required. All other spec requirements are
correctly implemented and tested. The test suite count (20 suites) is now correct.