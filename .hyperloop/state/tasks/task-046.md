---
id: task-046
title: Godot — Evaluation Mode: filter spec nodes and edges from metric computation
spec_ref: specs/core/understanding-modes.spec.md
status: not-started
phase: null
deps: [task-031]
round: 0
branch: null
pr: null
---

Extend Evaluation Mode (task-031) to exclude `spec_item` nodes and `spec_to_code` edges
from all structural metric computations, ensuring that coupling and centrality signals
reflect codebase architecture only — not spec coverage.

Covers `specs/core/understanding-modes.spec.md` — Requirement: Evaluation Mode,
Scenario: Spec is faithfully implemented but architecturally poor ("architectural
problems are visible even though conformance is perfect"):

Without this filtering, a code node that is realised by N spec items carries N phantom
inbound `spec_to_code` edges. Task-031 computes in-degree + out-degree across "all
edges in the scene graph," so those phantom edges inflate the node's centrality score.
A system with perfect conformance (every spec item realised) would therefore show
artificially elevated centrality for every realised code node — potentially triggering
spurious CRITICAL labels and masking the distinction between structurally important
nodes and merely well-specified ones. The scenario requires that evaluation signals
derive from codebase structure alone.

**Filtering rules** — applied once at mode-toggle time, before any metric computation:

- **Node exclusion**: build the working node list by iterating the loaded scene graph
  node list and skipping any node whose `type` field equals `"spec_item"`. All
  subsequent metric computations (degree, betweenness proxy, colour scaling) operate
  only on this filtered node list.

- **Edge exclusion**: build the working edge list by iterating the loaded scene graph
  edge list and skipping any edge whose `type` field equals `"spec_to_code"`. All
  subsequent metric computations (pairwise counts, degree, traversal) operate only on
  this filtered edge list.

**Impact on task-031 metrics:**

- Coupling (pairwise edge counts): computed from filtered edges only. `spec_to_code`
  connections between a spec_item and a code node do not contribute to any pair's
  coupling count.

- Centrality (in-degree + out-degree): computed from filtered nodes and filtered edges
  only. Inbound `spec_to_code` edges do not increase a code node's in-degree.

- CRITICAL label threshold (betweenness proxy — sum of neighbour degrees): neighbours
  are identified from the filtered node and edge sets only.

- Colour normalisation: the minimum and maximum degree values used to scale the
  neutral → warning colour gradient are derived from the filtered set. There is no
  "leakage" from spec node degrees into the scale.

**Backward compatibility** — when no spec data is loaded (extractor run without
`--specs`), the scene graph contains no `spec_item` nodes and no `spec_to_code` edges.
The filtering step is a no-op in that case; task-031 behaviour is unchanged.

**No schema or extractor changes** — this task is a Godot-only change. It adds a
pre-computation filtering step to the Evaluation Mode script that implements task-031.
The JSON scene graph format is unchanged.

- Use only GDScript and Godot 4.6 API. No external libraries.
