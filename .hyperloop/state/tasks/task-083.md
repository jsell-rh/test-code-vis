---
id: task-083
title: Extractor — ubiquitous dependency detection
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-076, task-063]
round: 0
branch: null
pr: null
---

Implement ubiquitous dependency detection in the Python extractor: identify dependencies
imported by more than a configurable threshold fraction of all modules, flag them as
ubiquitous, and mark their edges with `ubiquitous: true` so the Godot renderer can
apply power rail notation.

Covers `specs/core/visual-primitives.spec.md` — Requirement: Ubiquitous Dependency
Detection ("The extractor MUST identify dependencies that are imported by a large
fraction of modules and flag them as ubiquitous"):

**Input** — the full edge list produced by tasks 003 and 063, and the module node list
from task-002.

**Algorithm:**

1. Collect the set of all module nodes (type `"module"`). Let `M` = count of these
   module nodes.

2. For each unique `target` node id appearing in `cross_context` edges:
   - Count how many distinct source MODULE nodes import this target:
     `import_count = len(set(e["source"] for e in edges
                             if e["target"] == target_id
                             and e["type"] in ("cross_context", "internal")))`
   - Compute the fraction: `fraction = import_count / M`.

3. If `fraction > UBIQUITOUS_THRESHOLD` (default: `0.50`), mark the target node as
   ubiquitous:
   - Set `ubiquitous: true` on ALL edges whose `target` is this node id.
   - Record the node id in an `ubiquitous_deps` list in the extraction metadata.

4. Record the threshold used in the `metadata` object:
   `"ubiquitous_threshold": 0.50` (or whatever value was used).

**Threshold configuration** — the threshold MUST be exposed as a CLI parameter
(e.g. `--ubiquitous-threshold 0.5`) so it can be tuned per-project. The default
is 0.50 (50% of modules import this target).

**Metadata update** — extend the `metadata` object in the JSON output with:

```json
"ubiquitous_threshold": 0.50,
"ubiquitous_deps": ["shared_kernel.logging", "shared_kernel.utils"]
```

**Validator update** (extend from task-076):
- `metadata.ubiquitous_threshold`: optional float, recorded when detection runs.
- `metadata.ubiquitous_deps`: optional array of node id strings.

**Scenarios from spec:**
- `logging` imported by 85% of modules (> 50% threshold) → all edges targeting
  `logging` get `ubiquitous: true`; `logging` appears in `ubiquitous_deps`.
- A shared utility imported by 30% of modules → NOT flagged (below threshold).

**Edge cases:**
- Module graph with only 1 module: threshold logic still applies; if that 1 module
  imports a target, fraction = 1.0 > threshold → flagged.
- Target node not in the known node set (already excluded as stdlib/third-party by
  task-003): nothing to flag (only known application nodes are in the edge list).
- `dynamic_call` edges with `target: null`: excluded from this analysis.

Use only Python standard library. No external dependencies.

**Output**: the edge list with `ubiquitous: true` added to qualifying edges, plus
updated metadata fields.
