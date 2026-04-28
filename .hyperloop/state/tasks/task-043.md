---
id: task-043
title: Godot — Conformance Mode: visualize merged vs. absent divergence
spec_ref: specs/core/understanding-modes.spec.md
status: not-started
phase: null
deps: [task-041, task-030]
round: 0
branch: null
pr: null
---

Extend Conformance Mode (task-030) to visually distinguish three spec conformance
states — realized, merged, and absent — using the `divergence_type` field from
task-041. Currently task-030 uses a single "divergence colour" for any spec item that
lacks a `spec_to_code` edge, making it impossible for the human to tell whether a
requirement is simply missing or was absorbed into a broader component.

Covers `specs/core/understanding-modes.spec.md` — Requirement: Conformance Mode,
Scenario: Spec-divergent implementation ("the specific nature of the divergence is
clear (merged vs. separate)"):

- When loading spec_item node metadata during scene load (task-030's load phase), read
  the `divergence_type` field. If the field is absent in the JSON, fall back to the
  task-030 heuristic (presence or absence of a `spec_to_code` edge in the edge list:
  edge present → treat as `"realized"`, no edge → treat as `"absent"`). This ensures
  backwards compatibility with scene graphs produced before task-042.

- Replace task-030's single "divergence colour" with three distinct visual treatments
  applied to `spec_item` MeshInstance3D nodes when Conformance Mode is active:

  - **`"realized"`** — green tint material (same as task-030's "conformant" colour).
    No floating label. The spec item is properly implemented as a separate component.

  - **`"merged"`** — amber/orange tint material. Add a floating `Label3D` reading
    `"MERGED"` directly above the spec_item node (same height offset convention as
    used for the `"CRITICAL"` label in task-031). The spec item's functionality exists
    in the codebase but is not isolated as its own component.

  - **`"absent"`** — red tint material. Add a floating `Label3D` reading `"ABSENT"`
    directly above the spec_item node. The spec item has no implementation anywhere
    in the codebase.

- All other task-030 behaviour is unchanged:
  - The `spec_to_code` connecting lines between spec volumes and code nodes are still
    drawn for spec items that have a `spec_to_code` edge (i.e. `"realized"` and
    `"merged"` items). `"absent"` items have no connecting line.
  - Codebase node colouring (conformant = green tint, undocumented = grey tint) is
    unchanged.
  - Toggling Conformance Mode off removes all tints and floating labels and returns
    all nodes and edges to base structural appearance.
  - The `"No spec data loaded"` warning for missing spec nodes is unchanged.

- Update the Conformance Mode HUD label to include a compact legend:
    `CONFORMANCE MODE   ● Realized  ◐ Merged  ✕ Absent`
  Use coloured inline labels or a small legend panel rather than text alone — the
  three colours (green / amber / red) must be discernible at a glance.

- The `"MERGED"` and `"ABSENT"` Label3D nodes must be removed when Conformance Mode
  is toggled off, using the same cleanup logic that removes other mode-specific nodes.

- Use only GDScript and Godot 4.6 API. No external libraries.
