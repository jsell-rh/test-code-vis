---
id: task-065
title: Extractor — layout: spatial separation of independence groups
spec_ref: specs/visualization/orthogonal-independence.spec.md
status: not-started
phase: null
deps: [task-062, task-005]
round: 0
branch: null
pr: null
---

Extend the layout algorithm (task-005) to enforce a visible spatial gap between
independence groups within each bounded context, so structural independence is
perceivable from node positions alone.

Covers `specs/visualization/orthogonal-independence.spec.md` — Requirement: Spatial
Separation of Independent Groups, Scenario: Visual gap between independent groups:

**Gap constraint** — within each bounded context, modules in different independence
groups MUST be separated by a gap larger than the maximum within-group inter-module
distance.

**Post-pass algorithm** (applied after task-005's base layout):
1. For each independence group within a context, compute the group centroid.
2. Sort groups by centroid (e.g. along the x-axis) to assign spatial regions.
3. Translate all module positions in each group so that the bounding-box gap between
   adjacent groups equals at least `GROUP_GAP`:
   - `GROUP_GAP = 1.5 × mean within-group inter-module distance`
   - Minimum `GROUP_GAP = 5.0` units (applies when a group has a single module).
4. After translation, if any module falls outside the parent context's spatial extents,
   scale the context extents outward to accommodate.

**Within-group layout** — coupling-aware positioning from task-005 applies within each
group unchanged.  This pass only adjusts inter-group distances.

**Degenerate cases**:
- All modules in one group (fully connected context): no separation applied.
- Every module a singleton group: arrange groups in a regular grid within the context
  with uniform `GROUP_GAP` spacing.

**Output**: updated node list with `position` fields reflecting group-separated layout.
The `independence_group` field (set by task-062) is the grouping key.

Use only Python standard library / numpy.
