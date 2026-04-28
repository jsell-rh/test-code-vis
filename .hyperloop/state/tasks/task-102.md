---
id: task-102
title: Schema — cascade depth simulation output format
spec_ref: specs/extraction/scene-graph-schema.spec.md
status: not-started
phase: null
deps: [task-061]
round: 0
branch: null
pr: null
---

Document the cascade depth simulation output format in the schema document. The
failure cascade BFS (task-048) and wave animation (task-049) compute hop-distance
depth at runtime; this task formalises the in-memory data contract between those
components so the format is defined in one place and future implementors understand
what fields each affected node carries during a failure simulation.

Covers `specs/extraction/scene-graph-schema.spec.md` — Requirement: Cascade Depth
in Simulation Output ("When the system computes failure cascade analysis, each
affected node MUST carry a `depth` value indicating its hop distance from the failure
origin. The depth values are available to the visualization for gradient encoding and
wave animation"):

---

**Deliverable: new "Simulation Output" section in `extractor/schema.md`**

Add a section titled `## Simulation Output (Runtime Format)` after the main JSON
serialisation sections. This section documents the data structure that the Godot
cascade BFS engine (task-048) produces at runtime — it is NOT serialised to the
static scene graph JSON file, but it is part of the overall system schema contract.

---

**Cascade depth record** — for each node reached during a failure simulation, the
BFS engine annotates it with the following fields (in-memory Dictionary or equivalent):

```
node_id   (String)  — the id of the affected node; matches an id in the loaded JSON.
depth     (int ≥ 1) — hop distance from the failure origin.
                       depth = 1: directly depends on the failed node
                                  (imports it or calls it).
                       depth = 2: depends on a depth-1 node.
                       depth = N: N hops from the failure origin.
origin_id (String)  — the id of the failure-origin node the human selected.
                       Supports multi-failure: multiple origin_ids may be active
                       simultaneously (task-048).
```

The failure origin node itself is NOT in the output (it is the source, not an
affected node). Nodes not reachable from any origin also do not appear.

---

**BFS derivation rules** (to be reproduced in the schema document):

1. **Graph direction** — traverse the REVERSE dependency graph: from the failed node,
   follow edges in the "depended upon by" direction. An edge `A → B` (A depends on B)
   means A is a consumer of B, so if B fails, A is affected at depth 1 from B.

2. **Depth assignment** — BFS frontier at hop 1 = all nodes that directly import or
   call `origin_id`. The next frontier at hop 2 = all nodes that import or call any
   hop-1 node. Continue until no unvisited nodes remain.

3. **Multi-failure** — when the human selects multiple failed nodes, run independent
   BFS from each `origin_id`. For any node reachable from multiple origins, record
   `depth = min(depth_from_origin_A, depth_from_origin_B, ...)`.

4. **Filtered nodes** — `spec_item` nodes and `spec_to_code` edges are EXCLUDED from
   the BFS traversal (per task-047). They never appear in the cascade output.

---

**Gradient encoding contract** (to be reproduced in the schema document):

The depth value maps to the cascade colour gradient as follows (from task-048):

```
max_depth  = maximum depth value across all affected nodes for the current origin
ratio      = depth / max_depth        (float in [0.0, 1.0])
colour     = Color.lerp(near_color, far_color, ratio)

near_color = Color(1, 0.3, 0)        # depth 1: deep orange-red
far_color  = Color(1, 0.85, 0.7)     # max depth: pale peach
```

When only one depth level is reached (only direct consumers), `max_depth = 1` and
all affected nodes receive `ratio = 1.0` (far_color). This edge case must be handled:
never divide by zero.

---

**Wave animation contract** (to be reproduced in the schema document):

The wave animation (task-049) fires depth groups sequentially:

```
wave_delay_ms  = 300   # ms between consecutive depth rings (named constant)
fade_ms        = 200   # ms for each node's colour interpolation (named constant)

wave N fires after: (N - 1) × wave_delay_ms milliseconds from trigger
```

These timing constants are part of the schema contract so alternative rendering
implementations or test harnesses can reproduce the animation without reading the
Godot script.

---

**No JSON schema changes** — cascade depth output is purely in-memory; the static
scene graph JSON file is not modified during simulation. No new fields are added to
the nodes or edges arrays. No validator updates are required.

**No extractor changes** — the Python extractor does not compute cascade depth; this
is a Godot runtime operation.

**No Godot implementation changes** — task-048 and task-049 already implement the
BFS and animation described above. This task only adds the formal documentation.
