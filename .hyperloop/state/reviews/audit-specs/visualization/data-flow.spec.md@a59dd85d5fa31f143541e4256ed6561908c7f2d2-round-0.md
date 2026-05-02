---
task_id: audit-specs/visualization/data-flow.spec.md@a59dd85d5fa31f143541e4256ed6561908c7f2d2
round: 0
role: auditor
verdict: fail
---
## Data Flow Visualization - Complete Feature Gap

### Summary
The data flow specification requires on-demand visualization of data paths through the system, rendered as overlays on the persistent structural geography. This feature is **completely absent from the codebase**. No mechanisms exist for:
1. Requesting flow visualization
2. Rendering flow paths through the structure
3. De-emphasizing irrelevant structural elements
4. Showing aggregate flow patterns or bottlenecks

### Spec Requirements vs Implementation

#### Requirement 1: Flow is On-Demand
**Status: NOT IMPLEMENTED**

**Spec requirement (line 8-9):**
> "The system MUST NOT show data flow by default. Flow visualization SHALL be invoked by the human in response to a specific question."

**Spec scenario (line 11-16):**
> When human asks "show me the order submission path", the relevant flow path lights up through the structure, irrelevant structural elements are de-emphasized, and flow is traceable from entry point to terminus.

**What the code does:**
- The understanding overlay system in `/home/jsell/code/sandbox/code-vis/worktrees/workers/audit-1bb7105d/godot/scripts/understanding_overlay.gd` (lines 1-294) provides three visualization modes:
  - Alignment overlay (spec_status coloring)
  - Quality overlay (in_degree coloring)
  - Failure impact overlay (cascade depth coloring)
- These are invoked by keyboard (H, J, K keys) in `/home/jsell/code/sandbox/code-vis/worktrees/workers/audit-1bb7105d/godot/scripts/main.gd` (lines 537-550)
- **None of these mechanisms show data flow paths**. They only color nodes based on metrics or status.

**Gap:**
- No mechanism to request a data flow path (e.g., "show order submission path")
- No code traces paths through the structure
- No de-emphasis of irrelevant elements during flow display
- No path endpoint tracking (entry point to terminus)

#### Requirement 2: Flow Shows Paths Through Structure
**Status: NOT IMPLEMENTED**

**Spec requirement (line 18-19):**
> "The system MUST render data flow as paths through the existing structural geography, not as a separate view."

**Spec scenario (line 21-26):**
> When flow is invoked, it renders as a path through structural space, structural context remains visible (not replaced), and human can follow path spatially through system.

**What the code does:**
- The 3D scene graph is built as persistent structural geography (nodes, edges, LOD levels) in `/home/jsell/code/sandbox/code-vis/worktrees/workers/audit-1bb7105d/godot/scripts/main.gd`
- Overlays (understanding_overlay.gd) modify node colors and add annotations but preserve the structure
- No code creates or renders "flow paths" as visual entities

**Gap:**
- No flow path data structure exists
- No rendering of paths through edges/nodes
- No distinction between "flow path" edges and structural edges
- No mechanism to highlight a sequence of edges showing data flow
- The understanding overlays prove the architecture can layer visualizations onto structure, but flow paths specifically are missing

#### Requirement 3: Aggregate Flow Patterns (SHOULD, not MUST)
**Status: NOT IMPLEMENTED**

**Spec requirement (line 28-29):**
> "The system SHOULD support showing aggregate flow patterns (hot paths, bottlenecks) as an overlay on the structure."

**Spec scenario (line 31-35):**
> When human requests aggregate flow visualization, high-traffic paths are visually prominent and bottleneck points (where flow constricts) are identifiable.

**What the code does:**
- The schema includes a "depth" field for failure cascade (extractor/schema.py lines 67-72) but NOT flow metrics
- The schema does NOT include fields for:
  - Flow count per edge
  - Hot path indicators
  - Bottleneck detection
  - Traffic-based edge weights (only exists for aggregate structural edges, not flow)
- No code computes or visualizes hot paths or bottlenecks in a flow context

**Gap:**
- No flow metrics in the scene graph schema
- No hot path detection
- No bottleneck analysis for flow (only structural significance exists)
- No traffic-weighted visualization

### Architecture Review

**Confirmed: The architecture COULD support data flow overlays**

The understanding overlay system demonstrates the visualization pattern needed:
1. `/home/jsell/code/sandbox/code-vis/worktrees/workers/audit-1bb7105d/godot/scripts/understanding_overlay.gd` (lines 48-80) applies overlay colors to nodes
2. `/home/jsell/code/sandbox/code-vis/worktrees/workers/audit-1bb7105d/godot/scripts/main.gd` (lines 537-550) maps keyboard input to overlay activation
3. Overlays preserve structural context while adding visual emphasis

**A data flow overlay would need:**
- Mechanism to request flow paths (similar to H/J/K keys)
- Flow path data structure (sequence of edges + metrics)
- Highlighting function for flow edges (similar to `_apply_node_color`)
- De-emphasis function for non-flow nodes/edges
- Entry point and terminus identification

None of this exists.

### Files Searched

All visualization-related files reviewed:
- `/home/jsell/code/sandbox/code-vis/worktrees/workers/audit-1bb7105d/godot/scripts/main.gd` (lines 1-585) — no flow code
- `/home/jsell/code/sandbox/code-vis/worktrees/workers/audit-1bb7105d/godot/scripts/understanding_overlay.gd` (lines 1-294) — alignment/quality/failure modes only, no flow
- `/home/jsell/code/sandbox/code-vis/worktrees/workers/audit-1bb7105d/godot/scripts/understanding_analyzer.gd` (lines 1-356) — alignment/coupling/criticality/split/failure analysis, no flow
- `/home/jsell/code/sandbox/code-vis/worktrees/workers/audit-1bb7105d/godot/scripts/lod_manager.gd` (lines 1-82) — visibility by distance only
- `/home/jsell/code/sandbox/code-vis/worktrees/workers/audit-1bb7105d/godot/scripts/camera_controller.gd` (lines 1-205) — navigation only
- `/home/jsell/code/sandbox/code-vis/worktrees/workers/audit-1bb7105d/godot/scripts/scene_graph_loader.gd` (lines 1-77) — structure loading only
- `/home/jsell/code/sandbox/code-vis/worktrees/workers/audit-1bb7105d/extractor/schema.py` (lines 1-358) — structural schema only
- `/home/jsell/code/sandbox/code-vis/worktrees/workers/audit-1bb7105d/extractor/extractor.py` (39814 bytes) — code extraction only

### Conclusion

All three requirements of the data flow specification are **unimplemented**. The system shows structural visualization with understanding overlays for alignment/quality/failure, but has **zero implementation of data flow visualization**. This represents a significant feature gap, though the architecture demonstrates it could be added following the established overlay pattern.