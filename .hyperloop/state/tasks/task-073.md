---
id: task-073
title: Godot — Mode layering: Conformance + Simulation visual channels
spec_ref: specs/core/understanding-modes.spec.md
status: not-started
phase: null
deps: [task-050, task-030, task-048, task-051, task-052]
round: 0
branch: null
pr: null
---

Define and implement visual channel ownership when Conformance Mode and Simulation Mode
are simultaneously active, completing Mode Composition coverage for all two-mode
combinations: C+E is handled by task-051, E+S by task-052; this task closes the
remaining C+S gap.

Covers `specs/core/understanding-modes.spec.md` — Requirement: Mode Composition
("Multiple modes MAY be active simultaneously, and their visual encodings layer to answer
compound questions that no single mode addresses alone"):

**Channel assignment — Simulation owns fill colour; Conformance owns border ring:**

Simulation Mode (task-048) uses node fill colour to convey the cascade depth gradient
(bright orange-red at depth 1 → pale peach at max depth). When both Conformance and
Simulation are simultaneously active, Simulation retains fill colour ownership and
Conformance Mode MUST present its signals through a secondary channel — the same
border-ring mechanism established by tasks 051 and 052 for Evaluation Mode.

**Conformance secondary channel when Simulation is active:**

For each code node (type != `"spec_item"`), add a border-ring shell (same mechanism
as task-051: a slightly enlarged `MeshInstance3D` copy of the node mesh, rendered with
a solid or wireframe material), where the shell colour encodes spec conformance state:
- `divergence_type: "realized"` → green border ring (spec-aligned implementation).
- `divergence_type: "merged"` → amber border ring (functionality present but merged
  into a broader component rather than isolated as its own).
- Code node with no `spec_to_code` edge targeting it → grey border ring (undocumented:
  exists in the build but has no spec counterpart).

`spec_item` nodes that are `divergence_type: "absent"` (unrealized) retain their base
Conformance red tint on fill — they receive no cascade fill from Simulation (spec items
are excluded from the BFS traversal by task-047/048), so no fill channel conflict arises
for them. `spec_to_code` connecting lines rendered by task-030 remain visible and are
unaffected by this task.

**Compound states the human should be able to read at a glance:**
- Cascade fill (depth 1, bright orange) + green ring → direct dependent that is
  spec-conformant: the cascade hits a properly implemented component.
- Cascade fill (depth 3, pale peach) + grey ring → transitive dependent with no spec
  backing: a structural risk not covered by the spec.
- Non-cascade (dimmed) node + amber ring → a merged/divergent node outside the current
  cascade — a spec concern unaffected by this particular failure, but worth noting.

**Mode re-entry and exit logic:**
- When only Simulation is active (Conformance just deactivated): remove all Conformance
  border rings. Cascade depth gradient, `"✕ FAILED"` markers, and `"⚠ depth N"` labels
  from task-048 are unchanged.
- When only Conformance is active (Simulation just deactivated): remove cascade depth
  fills and depth labels. Restore Conformance fill colour as primary channel (green,
  amber, red, grey fills from task-030 / task-043).
- When both active: apply channel assignment described above.
- When neither active: restore base structural appearance (task-009 default materials).

**Implementation:** add two helper methods to the Conformance Mode script (task-030):

`_apply_conformance_as_secondary_simulation() -> void`
  - Called when both Conformance and Simulation are active.
  - Remove any existing Conformance fill tints from code nodes.
  - Create border-ring shells for all code nodes, coloured by their conformance state
    (`divergence_type` or absence of a `spec_to_code` edge).
  - Keep spec_item node tints (no fill conflict for spec items in this combination).

`_apply_conformance_as_primary() -> void`
  - Called when only Conformance is active (Simulation deactivated).
  - Remove border-ring shells (if any).
  - Reapply fill colour to all code nodes using task-030/task-043 colour logic.

Call these methods from the `mode_changed` signal handler in the Conformance Mode script,
based on whether `"simulation"` is present in the `active_modes` array received from
`ModeController` (task-050).

**Border-ring shell reuse:** the shell geometry is identical to the mechanism in
task-051. If task-051 extracted a shared utility for border-shell creation, reuse it
here. If not, implement independently — the Evaluation border (task-051) and the
Conformance border (this task) may coexist on the same node when all three modes are
active (C+E+S): Evaluation border signals centrality risk; Conformance border signals
spec alignment. No additional handling is required beyond what task-051 and this task
each provide independently.

**No schema or extractor changes.** Godot-only rendering task.

Use only GDScript and Godot 4.6 API. No external libraries.
