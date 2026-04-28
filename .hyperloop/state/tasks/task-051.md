---
id: task-051
title: Godot — Mode layering: Conformance + Evaluation visual channels
spec_ref: specs/core/understanding-modes.spec.md
status: not-started
phase: null
deps: [task-050, task-030, task-031, task-043, task-044, task-045, task-046]
round: 0
branch: null
pr: null
---

Define and implement visual channel ownership when Conformance Mode and Evaluation Mode
are simultaneously active, so their encodings layer without conflict and the human can
answer compound questions like "which spec-aligned modules are also single points of
failure?"

Covers `specs/core/understanding-modes.spec.md` — Requirement: Mode Composition, Scenario:
Conformance + Evaluation ("one mode controls a primary visual channel (e.g. fill color),
the other controls a secondary channel (e.g. border or annotation)"):

**Channel assignment — Conformance owns fill colour; Evaluation owns outline/annotation:**

Conformance Mode (task-030 / task-043) uses node fill colour to convey spec conformance
state:
- `"realized"` → green tint
- `"merged"` → amber tint
- `"absent"` → red tint
- Undocumented code node → grey tint

Evaluation Mode (task-031 / task-044 / task-045 / task-046) normally uses fill colour to
convey centrality (neutral → warning gradient) and adds CRITICAL labels. When both modes
are simultaneously active, Evaluation Mode MUST surrender fill colour and instead use:

- **Outline / border ring**: add a coloured `MeshInstance3D` shell (a slightly enlarged
  copy of the node mesh, rendered with a wireframe or slightly scaled solid material)
  around each code node, where the shell colour encodes the Evaluation centrality
  gradient (neutral → orange → red). Spec_item nodes do not receive an evaluation shell.
- **CRITICAL label**: keep the floating `"CRITICAL\n← N dependents"` Label3D from
  task-045 unchanged — text annotations do not conflict with fill colour.
- **HIGH COUPLING label**: keep the `"HIGH COUPLING"` edge Label3D from task-044
  unchanged.

**Specific compound states a human should be able to read at a glance:**
- Node is green (conformant) + bright-red border shell → spec-aligned and a SPOF risk.
- Node is amber (merged) + no border or dim border → divergent but architecturally healthy.
- Node is grey (undocumented) + bright-red border + CRITICAL label → an unspecified
  architectural hub — a structural risk with no spec backing.

**Mode re-entry and exit logic:**
- When only Conformance is active (Evaluation just deactivated): restore evaluation fill
  colour, remove evaluation border shells.
- When only Evaluation is active (Conformance just deactivated): restore fill colour
  ownership to Evaluation, remove border shells, return to standard centrality gradient
  on fill.
- When both are active: apply channel assignment above.
- When neither is active: restore all nodes to base structural appearance (task-009's
  default materials).

**Channel assignment is managed by a new helper function in the Evaluation Mode script**
(or a shared utility): `_apply_evaluation_as_secondary()` / `_apply_evaluation_as_primary()`.
These functions are called from the `mode_changed` signal handler in the Evaluation Mode
script, based on whether `"conformance"` is present in the `active_modes` array received
from ModeController (task-050).

**No schema or extractor changes** — this is a Godot-only rendering task.

- Use only GDScript and Godot 4.6 API. No external libraries.
