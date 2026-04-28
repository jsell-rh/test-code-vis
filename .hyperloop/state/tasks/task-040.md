---
id: task-040
title: Godot — code node detail panel (click to inspect)
spec_ref: specs/core/system-purpose.spec.md
status: not-started
phase: null
deps: [task-009, task-013]
round: 0
branch: null
pr: null
---

Display a side panel of factual data when the human clicks any non-spec codebase node,
enabling them to correctly answer architectural questions about the system without reading
source code.

Covers `specs/core/system-purpose.spec.md` — Requirement: Understanding Without Writing
Code, Scenario: Architect evaluates unfamiliar system ("the human can correctly answer
architectural questions about the system"):

- **Trigger**: clicking any `MeshInstance3D` whose node metadata marks it as a code node
  (i.e. `node_type != "spec_item"`) opens the detail panel for that node.
  - Clicking a `spec_item` node is handled separately by task-037 (Conformance Mode
    only); this task handles all other node types in all modes.
  - Clicking the same node again, pressing `Escape`, or clicking anywhere else in the
    scene (outside the panel) closes the panel.

- **Panel layout** — a `CanvasLayer` containing a `PanelContainer` anchored to the
  right side of the viewport, the same side as the spec inspection panel (task-037).
  The two panels are mutually exclusive: opening a code node panel closes the spec panel
  and vice versa. The panel contains the following rows:
  - **Name** (bold header): the node's `name` field.
  - **Type**: the node's `type` value (e.g. `bounded_context`, `module`, `file`).
  - **Parent**: the `name` of the parent node, or `"(top-level)"` if `parent` is null.
  - **Lines of code**: the integer value of `metrics.loc`; display as `"LOC: <n>"`.
    If the field is absent, display `"LOC: —"`.
  - **Outgoing dependencies**: the count of edges in the loaded scene graph where this
    node's `id` appears as `source`. Display as `"Out: <n>"`.
  - **Incoming dependencies**: the count of edges where this node's `id` appears as
    `target`. Display as `"In: <n>"`.

- **Selection highlight**: while the panel is open, apply a brighter emissive tint to
  the selected node's `MeshInstance3D` so the human can see which node they are
  inspecting. Closing the panel removes the tint.

- **Input isolation**: the panel must not intercept camera navigation inputs (pan, zoom,
  orbit from tasks 015–017). Use `mouse_filter = MOUSE_FILTER_STOP` only on interactive
  panel controls; the background viewport must continue to receive camera events.

- **Mode compatibility**: the panel opens in any mode (no-mode, Conformance, Evaluation,
  Simulation). It does not alter the active mode's visual state; conformance colouring,
  evaluation overlays, and simulation markers remain visible alongside the open panel.

- **Dependency counts** are computed on demand from the already-loaded edge list at
  click time; no re-parsing or file I/O after initial scene load.

- Use only GDScript and Godot 4.6 API. No external libraries.
