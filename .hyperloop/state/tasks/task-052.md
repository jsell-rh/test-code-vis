---
id: task-052
title: Godot — Mode layering: Evaluation + Simulation visual channels
spec_ref: specs/core/understanding-modes.spec.md
status: not-started
phase: null
deps: [task-050, task-031, task-044, task-045, task-046, task-048]
round: 0
branch: null
pr: null
---

Define and implement visual channel ownership when Evaluation Mode and Simulation Mode
are simultaneously active, so cascade-depth markers and architectural-risk signals layer
without conflict and the human can immediately identify "which cascade-affected nodes
are already high architectural risk."

Covers `specs/core/understanding-modes.spec.md` — Requirement: Mode Composition, Scenario:
Evaluation + Simulation ("cascade-affected nodes show both their cascade depth AND their
architectural risk level AND the human can prioritize: 'which affected nodes are
already high-risk?'"):

**Channel assignment — Simulation owns fill colour; Evaluation owns outline/annotation:**

Simulation Mode (task-048) uses node fill colour to convey cascade depth gradient
(bright orange-red at depth 1 → pale peach at max depth). When both Evaluation and
Simulation are simultaneously active, Simulation retains fill colour ownership and
Evaluation Mode MUST present its signals through secondary channels:

**Evaluation secondary channels in Simulation context:**
- **CRITICAL annotation**: retain the floating `"CRITICAL\n← N dependents"` Label3D from
  task-045. Text annotations do not conflict with fill colour; a cascade-affected node
  that is also architecturally critical will show both its depth-gradient fill AND the
  CRITICAL label above it.
- **Outline border ring** (same mechanism as task-051): add a coloured shell around
  nodes whose evaluation centrality is non-trivial. The shell colour encodes the
  centrality level:
  - High centrality (would be full warning colour in Evaluation-only mode): bright
    orange-red border.
  - Medium centrality: amber border.
  - Low centrality: no border (do not add a shell to every node — only those that
    would be visually distinct in Evaluation-only mode).
- **HIGH COUPLING edge label** (task-044): retain unchanged — edge annotations do not
  conflict with node fill colour.
- Nodes **not reached by the cascade** (dimmed nodes in Simulation entry state) still
  show their evaluation border shell so the human can read architectural risk across
  the entire graph, not just the affected subset. This answers the question: "of the
  nodes that DIDN'T fail, which ones are at risk of cascading if they were to fail next?"

**Compound states the human should be able to read:**
- Node has deep-cascade fill (pale peach, depth 4) + bright-red border + CRITICAL label
  → a transitive dependent that is itself a critical architectural hub.
- Node has cascade fill (bright orange, depth 1) + no border → a direct dependent with
  no architectural significance.
- Non-cascade node (dimmed) + amber border → an architectural risk zone outside the
  current cascade.

**Mode re-entry and exit logic:**
- When only Simulation is active (Evaluation deactivated): remove evaluation border shells.
  Cascade depth gradient and `"✕ FAILED"` / `"⚠ depth N"` labels are unchanged.
- When only Evaluation is active (Simulation deactivated): restore fill colour to
  centrality gradient, remove cascade depth fills and labels. Border shells are no longer
  needed — Evaluation takes fill colour as primary channel.
- When both active: apply channel assignment above.
- When neither active: restore base structural appearance.

**Implementation:** add `_apply_evaluation_as_secondary_simulation()` /
`_apply_evaluation_as_primary()` helpers to the Evaluation Mode script. These are called
from the `mode_changed` signal handler based on whether `"simulation"` is present in the
`active_modes` array from ModeController (task-050).

**Simulation mode activation mid-evaluation:** if Evaluation Mode is already active and
the human activates Simulation Mode, the centrality fill is replaced by the dimmed
Simulation entry state immediately. Evaluation border shells appear on all nodes. When
the human then clicks a node to inject failure, cascade depth fills replace the dimmed
state on affected nodes — evaluation borders persist.

**No schema or extractor changes.** No new scene graph fields. Godot-only rendering task.

- Use only GDScript and Godot 4.6 API. No external libraries.
