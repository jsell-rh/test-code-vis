# Primitive Research — Cross-Disciplinary Analysis

## Purpose
Document the research basis for the visual primitive set defined in [Visual Primitives](visual-primitives.spec.md). Twenty disciplines were surveyed to answer: what are the right primitives for a system where structural data is mechanically extracted from code, an LLM composes visual representations from those primitives, and the goal is systematic human understanding?

This document is the rationale record. It is not a spec — it prescribes nothing. It explains why the primitives are what they are, what was considered and rejected, and what each discipline contributed.

---

## The Twenty Perspectives

### 1. Program Analysis
**Question asked:** What structures can be mechanically extracted from code with high fidelity?

**Proposed primitives:** Module Graph, Symbol Table, Call Graph, Type Topology, Data Flow Spines, Scope Nesting.

**Key contribution:** Established the extraction cost ordering. Scope nesting, module graph, symbol table, and type topology are essentially free (single-file AST parse). Call graph is cheap for direct calls. Data flow spines are the only primitive requiring real analysis, and scoping to one-call-deep keeps it tractable.

**What was rejected:** Control flow graphs (too granular — they visualize single function bodies, which developers already read as source code). Pointer/escape/taint analysis (require whole-program analysis with expensive fixed-point computation, and results are hard to visualize without a specific query). Dynamic traces (not mechanically extractable from source; require execution).

**What was adopted:** All six proposed primitives became the Extraction Layer.

---

### 2. Cognitive Science of Programming
**Question asked:** What mental models do programmers actually build when they understand code?

**Proposed primitives:** Beacon, Plan, Focal Structure, Causal Chain, Role, Boundary, Dependency Gradient.

**Key contribution:** The layered comprehension insight — experts build purpose first, then mechanism, then detail. This became Composition Principle #2 (purpose-first comprehension). The Beacon concept became the beacon recognition feature in Purpose-Level Annotation. The Boundary concept reinforced the Container primitive's membrane property.

**Research basis:** Brooks' top-down model, Pennington's cross-referencing model (program model vs. domain model), Soloway & Ehrlich's programming plans, Sajaniemi's variable roles, Letovsky's knowledge structures, Storey's cognitive design elements, Détienne's coupling/cohesion as central to expert reasoning.

**The critical insight:** Experts don't read code linearly. They form hypotheses about purpose and then seek confirming evidence. The visual system must support hypothesis formation, not line-by-line reading. This fundamentally shapes how the LLM should compose views — purpose annotations and beacons first, mechanism detail on demand.

---

### 3. Category Theory
**Question asked:** What are the minimal algebraic primitives needed to faithfully represent software structure?

**Proposed primitives:** Node (Object), Arrow (Morphism), Boundary (Functor), Bridge (Natural Transformation), Diamond (Pullback), Shade (Monad/Effect Boundary).

**Key contribution:** The mathematical argument that six constructs are sufficient: objects and morphisms give the graph, functors give hierarchy and encapsulation, natural transformations give mappings between views, pullbacks give shared structure (coupling), monads give effect boundaries. The Boundary-as-Functor framing — that a module boundary is a structure-preserving mapping from internals to interface — deepened the Container membrane concept.

**What was adopted:** Node, Arrow, and Boundary mapped directly to the composition layer's Node, Edge, and Container. The Shade concept informed the Badge primitive's `io`, `async`, and `stateful` aspects. The Diamond concept (shared dependency as coupling indicator) informed how Edge weight is computed.

**What was rejected as too abstract for direct visual use:** Natural transformations and pullbacks. These are powerful for formal reasoning but don't have intuitive visual forms that pass the semiotics test (Principle #3: iconic over symbolic).

---

### 4. Visual Language Theory
**Question asked:** What properties must primitives have to be composable, discriminable, learnable, and semantically transparent?

**Proposed primitives:** Container, Port, Flow, Stack, Badge, Tint.

**Key contribution:** Moody's Physics of Notations provided the upper bound on primitive count (~6 discriminable symbol types without hierarchical grouping). Shimojima's "free rides" justified containment as the primary structural encoding (spatial inclusion directly represents logical scope — the reader infers membership without decoding). Healey & Enns' preattentive processing research justified Tint as the highest-bandwidth categorical channel, limited to 4-6 hues.

**What was adopted:** Container, Port, Badge, and Tint became composition layer primitives directly. The 6-primitive cognitive limit informed the overall primitive count.

**What was adopted as a constraint:** The composability contract — every visual sentence is Containers connected by Edges through Ports, with Badges and Tints as property encodings. The LLM selects mappings; the primitives are stable.

---

### 5. Architecture Description Languages
**Question asked:** What primitives do ADLs converge on after decades of practice?

**Proposed primitives:** Component, Port, Connector, Configuration, Role/Binding Point, Flow.

**Key contribution:** The convergence evidence. Every serious ADL (ACME, Wright, Rapide, Darwin, AADL, C4) independently arrives at: Component, Port, Connector, Configuration (composition boundary), and Flow. This is the strongest empirical validation for the Container + Port + Edge core.

**What survived decades of ADL research:** Component, Port, Connector, Configuration, Flow. Everything that died was either metadata on these or behavioral formalism that practitioners rejected (Wright's CSP protocols, Rapide's posets).

**Critical finding:** C4 drops Ports — and that is exactly where C4 loses precision. This validated Port as a required primitive, not an optional refinement.

**What was adopted:** The Component-Port-Connector-Configuration core mapped directly to Container-Port-Edge-Container(nested).

---

### 6. Knowledge Representation
**Question asked:** What are the right ontological primitives for representing software systems as knowledge?

**Proposed primitives:** Concept, Role, Boundary, Flow, Invariant, Facet, Stratum.

**Key contribution:** The distinction between code model (what is written) and knowledge model (what is meant). Syntax-level constructs (functions, classes, files) are *instances* in this ontology, never primitives. The primitives capture the meaning those constructs serve. This deepened the purpose-level annotation requirement.

**Critical concepts adopted:**
- **Invariant** — a property that holds across the system but exists nowhere in the code. Became the Invariant Annotation feature.
- **Facet** — a cross-cutting concern that colors multiple elements. Became the Overlay/Facet composition principle.
- **Stratum** — a layering relationship expressing dependency direction and abstraction level. Informed the LOD Shell design.

---

### 7. Diagramming Practice (Empirical)
**Question asked:** What visual elements do practitioners actually use when they diagram code?

**Proposed primitives:** Box, Arrow, Nesting, Label, Lifeline/Sequence, Boundary/Zone.

**Key contribution:** Empirical reduction. Across UML (14 diagram types), C4, ERD, whiteboard sketches — practitioners converge on six elements. Everything else (stereotypes, lollipop interfaces, diamond composition markers, swimlanes) is either skipped or approximated with labels.

**Critical finding:** Labels do more work than visual encoding. People write "REST/JSON" on an arrow rather than inventing an arrow style. This validated the Badge primitive approach — structured labels, not more arrow types.

**Pattern:** Boxes, arrows, nesting, labels, ordering, and boundaries. Six primitives. Everything else is a label on one of these six.

---

### 8. Information Visualization
**Question asked:** What visual encodings map best to which data types in code?

**Proposed primitives:** Region, Node, Edge, Weight, Temperature, Port, Layer.

**Key contribution:** Bertin's retinal variable mapping — each primitive must use a distinct perceptual channel. This became the Primitive Interactions requirement (Primitives Compose, Not Interfere). Shneiderman's visual information seeking mantra (overview first, zoom and filter, details on demand) became the LOD Shell design principle.

**Channel allocation derived from this analysis:**
- Position → containment (Container)
- Connection → relationships (Edge)
- Hue → categories (Tint)
- Shape → aspects (Badge)
- Size → magnitude (Edge weight, Container mass)
- Luminance → significance (Landmark)

**Critical constraint:** When two primitives compete for the same perceptual channel, one becomes unreadable. This is why Tint encodes only ONE dimension at a time.

---

### 9. Semiotics
**Question asked:** What types of signs should the primitives be — iconic, indexical, or symbolic?

**Proposed primitives:** Container (icon), Channel (index), Membrane (icon), Flow (index), Mass (icon), Colour Band (symbol), Fracture (index).

**Key contribution:** Peirce's hierarchy — icons are easiest to learn, indices next, symbols hardest. This became Composition Principle #3 (iconic over symbolic). Five of seven proposed primitives are iconic or indexical, meaning interpretable on first encounter. Only Tint (colour) requires a legend.

**Design consequence:** The system should teach itself through use. A new user seeing nested boxes (containment), directed lines (flow), thick vs. thin lines (weight), and large vs. small nodes (significance) should understand the basics without a tutorial. Only color coding requires explanation.

**The Fracture concept** — a visible crack where structural integrity is violated (circular deps, layer violations) — was not adopted as a standalone primitive but informed how the LLM should highlight violations in evaluation mode.

---

### 10. Domain-Driven Design
**Question asked:** Which DDD concepts can be mechanically inferred from code?

**Proposed primitives:** Aggregate Cluster, Bounded Context Boundary, Context Bridge, Domain Event Channel, Repository Gateway, Invariant Nexus.

**Key contribution:** The extraction difficulty gradient. Aggregate clusters, event channels, and repository gateways are largely mechanical (static analysis). Bounded context boundaries and context bridges need an LLM to judge semantic similarity. Invariant identification is almost entirely LLM-dependent. This gradient validated the two-layer architecture: static analysis proposes candidates, the LLM confirms and names them.

**What was adopted:** The bounded context as the primary Container at the highest zoom level (already present in existing specs). The Invariant Nexus became the Invariant Annotation feature. The Context Bridge concept informed the Bridge/Landmark detection.

---

### 11. Type Theory
**Question asked:** What visual primitives emerge from taking types seriously?

**Proposed primitives:** Cell (Product), Fork (Sum), Arrow (Function), Lens (Polymorphism), Shadow (Subtype), Membrane (Effect), Bridge (Isomorphism).

**Key contribution:** The effect boundary concept — code inside an effect membrane (IO, Async, Error) operates under different rules. Crossing the membrane should be visually explicit. This reinforced the Badge primitive for `io`, `async`, and `error_handling` aspects.

**The Lens concept** (parametric polymorphism as a shape with a hollow interior) was elegant but too fine-grained for the target zoom levels. It would be useful in a near-zoom code-level view but not at the module/package level where most views operate.

**The Shadow concept** (subtype as offset overlay) was interesting but creates visual clutter with deep hierarchies. Subtyping is better represented as a type topology Edge with an `inherits` type.

---

### 12. Network Science
**Question asked:** What graph-theoretic properties of code-as-graph does a human need to see?

**Proposed primitives:** Community Cluster, Bridge Node, Hub, Structural Hole, Fanout Star, Peripheral Isolate, Coupling Edge Weight.

**Key contribution:** The structural significance measures that became the Landmark primitive's detection algorithm. Hubs (high in-degree), bridges (high betweenness centrality), and peripherals (low degree) are the three significance classes. Community detection (Louvain/Leiden) became the community drift detection in the extraction layer.

**Critical insight:** The gap between detected communities and declared package structure is itself a signal. It shows where the architecture has drifted from intent. This is a first-class feature, not a side effect.

**What was adopted:** Hub detection, bridge detection, peripheral detection, and community detection all became extraction layer requirements. Edge weight as coupling intensity became a core Edge property. The Structural Hole concept (node whose removal disconnects the graph) became a simulation mode feature.

---

### 13. Spatial/Embodied Cognition
**Question asked:** What spatial metaphors map naturally to code concepts?

**Proposed primitives:** Basin (container), Conduit (path), Pillar (verticality/abstraction), Membrane (boundary), Anchor (center-periphery), Bridge (link across gap), Sediment (layers).

**Key contribution:** Grounding in Johnson's image schemas — pre-conceptual structures humans acquire in infancy through bodily experience. Container, path, link, center-periphery, part-whole, up-down. These are the spatial reasoning primitives that require ZERO learning.

**Design consequence:** The Container primitive works because spatial containment IS logical scoping to the human spatial reasoning system. Edges work because directed paths IS causal flow. Landmarks work because center-periphery IS importance. These are not arbitrary mappings — they exploit innate spatial cognition.

**What was adopted:** Basin → Container, Conduit → Edge, Membrane → Container membrane, Anchor → Landmark. The Pillar/Sediment (verticality = abstraction level) concept informed the LOD Shell's tier ordering but was not adopted as a separate primitive.

---

### 14. Cartography
**Question asked:** What can code visualization learn from map-making?

**Proposed primitives:** Contour Lines, Watersheds, Choropleth Shading, Generalization Level, Named Routes, Landmarks, Legend/Marginalia.

**Key contribution:** The deepest meta-insight of all twenty perspectives: **the LLM's primary job is deciding what to HIDE, not what to show.** Cartography's central problem is principled information loss — choosing what to suppress so what remains is legible. This became Composition Principle #1.

**What was directly adopted:**
- **Generalization Level** → LOD Shell primitive
- **Named Routes** → Route primitive
- **Landmarks** → Landmark primitive
- **Legend/Marginalia** → Distortion Legend requirement
- **Choropleth Shading** → Tint primitive

**The Watershed concept** (partitioning by dependency flow rather than directory structure) was powerful but complex to compute and visualize. It informed the community detection approach but was not adopted as a standalone primitive.

**The Contour Lines concept** (abstraction depth as topographic elevation) was elegant but requires a true 3D representation to work intuitively. It may be revisited when the 3D rendering capabilities mature.

---

### 15. Circuit Design / Electronics Schematics
**Question asked:** Why do schematics work so well, and what transfers?

**Proposed primitives:** Component Block, Net, Bus, Power Rail/Ground Rail, Reference Designator, Sheet/Hierarchical Block, Test Point.

**Key contribution:** Two critical insights:

1. **Separation of topology from geometry.** A schematic is not a picture of the physical circuit; it is a picture of the logical relationships. Code visualization needs the same: show how things connect, not where they sit in the filesystem. This validated the extractor computing layout based on coupling, not directory structure.

2. **Power Rail suppression.** VCC and GND are implicit connections present everywhere but drawn only once. Drawing every wire to power would make every schematic unreadable. This directly became the Power Rail notation primitive — ubiquitous dependencies (stdlib, logging, ORM) are acknowledged once and suppressed.

**The Bus concept** (grouped signals as a thick line) informed how aggregate edges work at far zoom levels.

**The Test Point concept** (explicitly marked observable locations) was not adopted as a primitive but could inform future debugging/observability overlays.

**The Reference Designator concept** (stable identifier independent of name or position) validated the scene graph's node ID strategy.

---

### 16. Biological Pathway Diagrams (SBGN)
**Question asked:** What did biology get right that software diagrams got wrong?

**Proposed primitives:** Compartment, Species Pool, Process Node, Catalysis Arc, Regulatory Arc, Submap.

**Key contribution:** Three insights UML missed:

1. **Make the verb a visible node.** SBGN's Process Node — the transformation is a first-class entity, not just an arrow. Functions should be visible nodes, not hidden inside class boxes. This reinforced the Node primitive's type-agnostic design (Nodes are Nodes — classes and functions differ only in Badges).

2. **Separate material flow from regulatory flow.** Data flow (what gets transformed) is visually distinct from control flow (what gates execution). Middleware, decorators, auth checks, rate limiters — these are regulatory arcs, not data arcs. This informed Edge type distinction (different line styles for calls vs. imports vs. inheritance).

3. **Boundaries are meaningful topology, not cosmetic grouping.** A SBGN Compartment's membrane carries meaning (permeability, interface surface). This directly shaped the Container membrane concept — thick border = strong encapsulation, porous = leaky abstraction.

**The Submap concept** (collapsing an entire pathway into a single glyph with defined terminals) is exactly the cluster collapsing feature already specified.

---

### 17. Systems Dynamics
**Question asked:** What primitives help a human understand how code BEHAVES as a system?

**Proposed primitives:** Stock, Flow, Feedback Loop (Balancing), Feedback Loop (Reinforcing), Delay, Constraint/Bottleneck, Leverage Point.

**Key contribution:** The insight that matters most for understanding is not static structure but dynamic behavior patterns. Stocks (queues, caches, pools) without balancing feedback loops (rate limiters, circuit breakers) are uncontrolled accumulations — memory leaks, unbounded queues, tables that grow forever.

**What this means for the system:** The LLM should be able to identify stocks and feedback loops in the extracted data and flag unbalanced stocks as architectural risks. This is not a visual primitive per se — it's a compositional pattern the LLM should detect and annotate.

**Concepts adopted as LLM-level analysis, not as rendering primitives:**
- **Stock** → Nodes flagged as stateful (Badge: `stateful`)
- **Feedback Loop** → Cycle detection in the call graph, annotated by the LLM
- **Leverage Point** → Landmark candidate (high structural significance + high change impact)
- **Constraint/Bottleneck** → Simulation mode: nodes with lowest throughput capacity on critical paths

---

### 18. Game Engine Architecture
**Question asked:** What does ECS and scene graph architecture contribute?

**Proposed primitives:** Entity, Component Badge, Scene Node, Port, Wire, LOD Shell, Behavior Layer.

**Key contribution:** Two insights:

1. **Don't bake identity into the node type.** ECS's core principle: a function node and a class node are the same Entity — they differ only in which Component Badges they carry. This makes the system extensible without inventing new node types. This directly shaped the Node primitive's design — Nodes have no inherent visual type; Badges provide all differentiation.

2. **LOD as precomputed tiers.** Game engines precompute simplified meshes at multiple detail levels. The camera distance selects the tier. This became the LOD Shell primitive — the extractor precomputes summaries at each tier so the LLM can compose views at any zoom level without re-analyzing.

**The Behavior Layer concept** (a toggleable overlay showing control flow paths, separate from structural view) reinforced the Overlay/Facet composition principle.

---

### 19. Music Notation
**Question asked:** How does music notation handle temporal + parallel + hierarchical?

**Proposed primitives:** Staff, Voicing, Rehearsal Mark, Repeat Signs/Coda, Dynamics Hairpin, Unison/Divisi.

**Key contribution:** Music notation is optimized for a human to track multiple parallel flows, spot structural repetition, and navigate non-linearly. The score shows the decisions the composer made, not every vibration.

**Concepts that influenced design:**
- **Rehearsal Marks** (named structural landmarks for navigation) → reinforced Landmark primitive
- **Dynamics Hairpin** (intensity change over a region) → informed how Edge weight could vary along a Route
- **Unison/Divisi** (shared behavior vs. specialization without visual duplication) → influenced how the LLM should annotate structural duplication. When two modules implement the same interface identically, the annotation says so rather than duplicating the visual.

**What was not adopted:** The temporal axis (staff as left-to-right time). Code visualization is primarily spatial, not temporal. Temporal views (sequence diagrams, execution traces) are a separate concern handled by Routes and simulation mode.

---

### 20. Failure Analysis / Incident Investigation
**Question asked:** What primitives help someone see where a system can break?

**Proposed primitives:** Fault Gate, Error Boundary, Blast Radius, Single Point of Failure, Recovery Path, Unsafe Control Action, Propagation Channel, Degradation Boundary.

**Key contribution:** Understanding WHERE and HOW things can go wrong IS understanding the system. These primitives compose naturally: a fault tree terminates at a single point of failure, whose blast radius is bounded by error boundaries, with recovery paths on the other side. Propagation channels explain correlated failures.

**What was adopted:**
- **Error Boundary** → Container with `error_handling` Badge, reinforced by membrane concept
- **Blast Radius** → Simulation mode's cascade depth feature (already specified)
- **Single Point of Failure** → Landmark + structural significance (hub with no redundancy)
- **Recovery Path** → Route primitive applied to error/fallback flows

**What was adopted as LLM-level analysis:**
- **Unsafe Control Action** (function that issues commands without feedback) → LLM can detect and annotate
- **Propagation Channel** (shared mutable state coupling otherwise independent components) → LLM can identify via data flow spine analysis and community detection

---

## Convergence Map

The following table shows which composition layer primitives were independently proposed by which perspectives (marked with an X):

| Primitive | ProgAn | CogSci | CatTh | VisLang | ADL | KR | UML | Infovis | Semiotics | DDD | TypeTh | NetSci | Spatial | Carto | Circuit | Bio | SysDyn | GameEng | Music | Failure |
|-----------|--------|--------|-------|---------|-----|-----|-----|---------|-----------|-----|--------|--------|---------|-------|---------|-----|--------|---------|-------|---------|
| Container | X | X | X | X | X | X | X | X | X | X | | | X | | X | X | | X | | X |
| Node | X | | X | | X | | X | X | | | X | | | | X | X | | X | | |
| Edge | X | X | X | X | X | X | X | X | X | X | X | X | X | X | X | X | X | X | | X |
| Port | | | | X | X | | | X | | | | | | | X | | | X | | |
| Badge | | X | | X | | | | | | | | | | | | | | X | | |
| Route | | X | | | | X | | | | | | | | X | | | | | | X |
| Landmark | | X | | | | | | | | | | X | X | X | | | | | X | X |
| Tint | | | | X | | | | X | X | | | | | X | | | | | | |
| LOD Shell | X | | | | | | | | | | | | | X | X | X | | X | | |
| Power Rail | | | | | | | | | | | | | | | X | | | | | |

**Primitives with broadest convergence:**
1. Edge (19/20 perspectives)
2. Container (16/20)
3. Node (11/20)
4. LOD Shell (7/20)
5. Landmark (7/20)
6. Route (5/20)
7. Port (5/20)
8. Tint (5/20)

**Primitives with narrowest convergence but highest novelty:**
1. Power Rail (1/20 — circuits only, but solves a problem every other perspective ignores)
2. Badge (3/20 — but validated by the ECS extensibility argument)

---

## What Was Universally Rejected

Across all twenty perspectives, no one proposed:
- **Animation as a primitive** — animation is a property of transitions between views, not a primitive itself
- **3D-specific primitives** — depth, rotation, or volumetric forms. All twenty perspectives produced 2D-native primitives that happen to work in 3D via containment and layering. This suggests the 3D space is a navigation medium, not a semantic encoding.
- **Text-heavy primitives** — long labels, inline documentation, tooltip-dependent elements. Every perspective favored visual encoding over textual.

---

## Open Questions

1. **Process Node vs. Class Node:** SBGN argues that functions (verbs) should be first-class visible nodes distinct from types (nouns). The current design treats both as Nodes with Badges. Should the verb/noun distinction be a Badge, a shape difference, or a separate primitive?

2. **Temporal axis:** Music notation and sequence diagrams both use a temporal axis. The current design handles temporality through Routes and simulation mode. Is this sufficient, or does flow animation along Routes need its own primitive?

3. **Feedback loop detection:** Systems dynamics argues that feedback loops are the most important structural feature for understanding system behavior. How much of this can the extractor detect mechanically vs. requiring LLM analysis?

4. **Regulatory vs. material flow:** SBGN's distinction between catalysis arcs and substrate arcs. Should the Edge primitive have a first-class `regulatory` type (middleware, decorators, auth checks) distinct from data flow edges?

5. **Community drift visualization:** Network science proposes that the gap between detected and declared module boundaries is a first-class signal. What visual form should this take — a Container with a dashed boundary? A ghost Container showing where the community "should" be?
