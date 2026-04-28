---
id: task-082
title: Extractor — structural significance (hub, bridge, peripheral, community)
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-074, task-063]
round: 0
branch: null
pr: null
---

Implement structural significance analysis in the Python extractor: compute hub,
bridge, and peripheral classification for each module node in the module graph,
run community detection to find natural clusters, detect community drift, and
annotate each module node with its `significance` object and `landmark` flag as
defined in task-074.

Covers `specs/core/visual-primitives.spec.md` — Requirement: Structural Significance
Extraction (hub detection, bridge detection, peripheral detection, community detection):

**Input** — the module graph: module-level nodes and the full edge list (import edges
from task-003, weighted/aggregate edges from task-063). Use ONLY `module` and
`bounded_context` nodes for graph analysis (not yet-to-be-added class/function nodes).

**Hub detection:**
1. Compute in-degree for each module node: count of edges where the node is `target`
   (exclude `dynamic_call` edges with null target; exclude `aggregate` edges to avoid
   double-counting).
2. A node is a **hub** if its in-degree is in the top 10% of all module in-degrees,
   OR if its absolute in-degree ≥ 5 (whichever produces the more selective set for
   this codebase — use the criterion that flags fewer nodes).
3. Set `significance.hub = true` and `significance.in_degree = <count>`.

**Bridge detection:**
4. Compute betweenness centrality approximation (BFS-based, NOT full Floyd-Warshall):
   - For a random sample of up to 50 source nodes, run BFS and count how many
     shortest paths pass through each intermediate node.
   - Normalise to [0.0, 1.0] relative to the maximum observed betweenness in the
     sample.
5. A node is a **bridge** if normalised betweenness ≥ 0.5.
6. Set `significance.bridge = true` and `significance.betweenness = <float>`.

**Peripheral detection:**
7. A node is **peripheral** if `in_degree == 0` AND `out_degree ≤ 1` (a leaf utility
   with no dependents and at most one dependency).
8. Set `significance.peripheral = true`.

**Community detection (Louvain-inspired simple greedy approach):**
9. Build undirected adjacency using all non-aggregate edges.
10. Run a simple connected-components pass first; if the graph is disconnected, each
    component is its own community.
11. Within each connected component, run a greedy modularity optimisation (simplified):
    - Assign each node to its own community.
    - For each node (in random order), evaluate whether moving it to any neighbour's
      community increases the modularity Q.
    - Repeat until no improvement (or max 10 iterations).
    - Assign deterministic community identifiers: `"<bounded_context_id>:c<index>"`
      sorted by component size descending.
12. Set `significance.community_id = <community_id>` on each module node.

**Community drift detection:**
13. For each module node, compare `significance.community_id` to the node's declared
    package boundary (its `parent` field, i.e. its bounded context).
14. If the node's detected community contains members from MULTIPLE bounded contexts,
    set `significance.community_drift = true` for all members of that cross-boundary
    community. Otherwise `community_drift = false`.

**Landmark derivation:**
15. Set `landmark = true` on a node if ANY of the following:
    - `significance.hub == true`
    - `significance.bridge == true`
    - `significance.in_degree == 0` AND `significance.peripheral == false`
      (a true entry point: no one imports it, but it has outgoing dependencies)
16. Set `landmark = false` on all other nodes.

**Output**: the same node list with `significance` objects and `landmark` flags
populated on every module node.

Use only Python standard library. No external graph libraries (no networkx, no scipy).
Implement BFS and greedy modularity from scratch.
