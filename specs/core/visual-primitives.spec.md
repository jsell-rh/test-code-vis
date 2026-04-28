# Visual Primitives Specification

## Purpose
Define the fixed, finite set of visual primitives that the system uses to represent software structure. These primitives are the vocabulary of the system: the extractor emits structural data, the LLM selects and composes primitives from this set, and the Godot renderer draws them. No primitive is invented at runtime. Every view the system produces is a composition of elements from this set.

The primitive system has two layers:
- **Extraction Layer** — structural data mechanically derived from source code. Fixed pipeline, deterministic, cheap. This is what the extractor produces.
- **Composition Layer** — visual elements the LLM maps extracted data onto. The LLM's job is selecting which composition primitives to instantiate, at what granularity, for a given question.

## Design Principles

Three constraints govern this primitive set, derived from cross-disciplinary analysis (see [Primitive Research](primitive-research.spec.md)):

1. **Principled information loss** (cartography): The LLM's primary job is deciding what to HIDE, not what to show. Every view is a deliberate distortion. The system must make the distortion explicit.
2. **Purpose-first comprehension** (cognitive science): Experts build understanding in layers — purpose, then mechanism, then detail. The extraction pipeline must emit data at all three levels. The LLM must compose top-down views, not bottom-up line-reading views.
3. **Iconic over symbolic** (semiotics): Maximize signs that resemble or point to what they represent. Minimize arbitrary conventions requiring a legend. The system should teach itself through use.

---

## Extraction Layer

The extraction layer defines what structural data the extractor mechanically derives from source code. These are not visual — they are data structures that feed the composition layer. They are ordered from cheapest to most expensive to compute.

### Requirement: Scope Nesting Extraction
The extractor MUST produce the full containment hierarchy of the codebase: project contains packages, packages contain modules, modules contain classes, classes contain methods.

#### Scenario: Containment tree
- GIVEN a Python codebase with packages, modules, and classes
- WHEN the extractor runs scope nesting analysis
- THEN every code entity has a parent reference forming a tree
- AND the tree root is the project itself
- AND every leaf is an atomic declaration (function, method, constant)
- AND the tree is available for the composition layer to map onto nested containers at any depth

#### Scenario: Extraction cost
- GIVEN any codebase of any size
- WHEN scope nesting extraction runs
- THEN it completes in time proportional to the number of files
- AND it requires only single-file AST parsing (no cross-file resolution)

### Requirement: Module Graph Extraction
The extractor MUST produce the directed graph of import-based dependencies between modules.

#### Scenario: Import-based edges
- GIVEN module A contains `import B` and `from C import foo`
- WHEN the extractor analyzes imports
- THEN edges A->B and A->C are emitted
- AND each edge carries the import count (number of individual import statements between the pair)

#### Scenario: Distinction from scope nesting
- GIVEN module A is inside package P, and module B is inside package Q
- WHEN the module graph is extracted
- THEN the A->B edge represents a dependency relationship
- AND the A-inside-P relationship is a containment relationship from scope nesting
- AND these two relationship types are distinct in the scene graph

### Requirement: Symbol Table Extraction
The extractor MUST produce the named entities in each scope — functions, types, constants, variables — with their signatures and visibility.

#### Scenario: Public vs. private symbols
- GIVEN a Python module with functions `def process_order()` and `def _validate_input()`
- WHEN the extractor runs symbol table analysis
- THEN both functions are emitted as symbols
- AND `process_order` is marked as public visibility
- AND `_validate_input` is marked as private visibility
- AND each symbol carries its signature (parameter names, type hints if present, return type hint if present)

#### Scenario: Symbol as labeling layer
- GIVEN a call graph edge from function A to function B
- WHEN the composition layer renders the edge
- THEN the symbol table provides the human-readable names and signatures for A and B
- AND without the symbol table, the edge would connect anonymous nodes

### Requirement: Type Topology Extraction
The extractor MUST produce the graph of type relationships: inheritance, implementation, and composition (has-a).

#### Scenario: Inheritance chain
- GIVEN class `PaymentProcessor` extends `BaseProcessor`
- WHEN the extractor analyzes type topology
- THEN an inheritance edge is emitted from `PaymentProcessor` to `BaseProcessor`
- AND the edge type is `inherits`

#### Scenario: Composition relationship
- GIVEN class `Order` has a field of type `PaymentInfo`
- WHEN the extractor analyzes type topology
- THEN a composition edge is emitted from `Order` to `PaymentInfo`
- AND the edge type is `has_a`

#### Scenario: Extraction cost
- GIVEN any codebase
- WHEN type topology extraction runs
- THEN it requires only AST parsing of class declarations, field types, and base classes
- AND it does not require type inference or flow analysis

### Requirement: Call Graph Extraction
The extractor MUST produce the directed graph of function-to-function invocations.

#### Scenario: Direct calls
- GIVEN function `handle_request` contains the expression `validate_input(data)`
- WHEN the extractor analyzes the call graph
- THEN an edge is emitted from `handle_request` to `validate_input`
- AND the edge type is `direct_call`

#### Scenario: Indirect calls
- GIVEN function `dispatch` contains `handler(request)` where `handler` is a parameter
- WHEN the extractor analyzes the call graph
- THEN the call site is emitted as a `dynamic_call` with no resolved target
- AND the call site carries the parameter name and any type hints
- AND the extractor does NOT attempt to resolve all possible targets (this is the LLM's job when composing views)

#### Scenario: Call frequency annotation
- GIVEN function A calls function B in three separate locations within A's body
- WHEN the extractor produces the call graph
- THEN the edge A->B carries a weight of 3

### Requirement: Data Flow Spine Extraction
The extractor MUST produce intraprocedural data flow chains showing how values produced in one place are consumed in another, scoped to function parameters and return values.

#### Scenario: Parameter to return value
- GIVEN function `transform(input: Data) -> Result` that passes `input` through three internal operations before returning
- WHEN the extractor traces data flow spines
- THEN the spine from parameter `input` through each operation to the return value is emitted
- AND each step in the spine references the intermediate function or expression

#### Scenario: One-call-deep interprocedural flow
- GIVEN function A calls function B with argument `x`, and B returns a value that A assigns to `y`
- WHEN the extractor traces data flow spines
- THEN the spine includes: A's `x` -> B's parameter -> B's return -> A's `y`
- AND the extractor does NOT trace deeper than one call level

#### Scenario: Extraction cost boundary
- GIVEN a codebase with 10,000 functions
- WHEN data flow spine extraction runs
- THEN it completes by analyzing each function body independently (intraprocedural)
- AND interprocedural analysis is limited to one call depth
- AND whole-program fixed-point analysis is NOT performed

### Requirement: Structural Significance Extraction
The extractor MUST compute graph-theoretic significance measures for each node in the module graph and call graph.

#### Scenario: Hub detection
- GIVEN a module that is imported by 40 other modules
- WHEN structural significance is computed
- THEN the module is annotated with high in-degree
- AND it is flagged as a hub

#### Scenario: Bridge detection
- GIVEN a module with high betweenness centrality (sits on many shortest paths between other modules)
- WHEN structural significance is computed
- THEN the module is annotated with its betweenness centrality score
- AND it is flagged as a bridge

#### Scenario: Peripheral detection
- GIVEN a module with in-degree 0 and out-degree 1 (a leaf utility)
- WHEN structural significance is computed
- THEN the module is annotated as peripheral
- AND it is a candidate for de-emphasis at overview zoom levels

#### Scenario: Community detection
- GIVEN a module graph with natural clustering
- WHEN the extractor runs community detection (e.g. Louvain/Leiden)
- THEN each module is annotated with its detected community identifier
- AND the detected communities are compared to the declared package structure
- AND modules whose detected community differs from their declared package are flagged as `community_drift`

### Requirement: Ubiquitous Dependency Detection
The extractor MUST identify dependencies that are imported by a large fraction of modules and flag them as ubiquitous.

#### Scenario: Standard library suppression
- GIVEN that 85% of modules import `logging`
- WHEN ubiquitous dependency detection runs
- THEN `logging` is flagged as ubiquitous
- AND its edges are present in the scene graph but marked as `ubiquitous: true`
- AND the composition layer defaults to suppressing ubiquitous edges (power rail principle)

#### Scenario: Threshold
- GIVEN a configurable threshold (default: imported by >50% of modules)
- WHEN a dependency exceeds the threshold
- THEN it is flagged as ubiquitous
- AND the threshold is recorded in extraction metadata

---

## Composition Layer

The composition layer defines the visual primitives that the LLM maps extracted data onto. These are the building blocks of every view the system renders. The LLM selects which primitives to instantiate and how to parameterize them. The renderer knows how to draw each one.

### Requirement: Container Primitive
The system MUST support a Container primitive: a bounded region with a semi-permeable membrane representing scope, encapsulation, or logical grouping.

#### Scenario: Module as container
- GIVEN a module with 5 public functions and 3 private functions
- WHEN the LLM maps it to a Container
- THEN the Container has a boundary (membrane) whose visual density reflects encapsulation strength
- AND the 5 public functions are represented as Ports on the membrane
- AND the 3 private functions are contained inside, visible only at close zoom

#### Scenario: Nested containers
- GIVEN a package containing 3 modules, each containing classes
- WHEN the LLM maps the hierarchy to Containers
- THEN the package is an outer Container
- AND each module is a Container nested inside
- AND each class is a Container nested inside its module
- AND the nesting depth is apparent from the visual structure

#### Scenario: Container membrane permeability
- GIVEN a module with 2 public symbols and 30 private symbols
- WHEN the Container is rendered
- THEN the membrane appears thick/opaque (strong encapsulation — few openings relative to interior)
- AND a module with 25 public symbols and 5 private symbols has a thin/porous membrane
- AND permeability is a continuous visual property, not a binary toggle

### Requirement: Node Primitive
The system MUST support a Node primitive: an entity with identity, carrying zero or more Badges. Nodes do not have baked-in types — their visual identity comes entirely from their Badges.

#### Scenario: Function node
- GIVEN a function `validate_order` with no side effects
- WHEN the LLM maps it to a Node
- THEN the Node exists with its name
- AND it carries a "pure" Badge
- AND no special shape distinguishes it from a class node — only the Badges differ

#### Scenario: Node without badges
- GIVEN an entity with no notable aspects yet analyzed
- WHEN it is rendered
- THEN it appears as a plain Node with its name
- AND Badges are added as analysis layers are applied

### Requirement: Badge Primitive
The system MUST support a Badge primitive: a small glyph docked to a Node indicating an aspect or cross-cutting property.

#### Scenario: Side-effect badge
- GIVEN a function that performs I/O operations
- WHEN the LLM attaches a Badge
- THEN the Node displays a small glyph indicating "performs I/O"
- AND the Badge is positioned consistently (e.g. top-right corner) across all Nodes

#### Scenario: Multiple badges
- GIVEN a function that performs I/O, is async, and has error handling
- WHEN multiple Badges are attached
- THEN all Badges are visible, arranged in a consistent order
- AND the human can read the function's cross-cutting properties at a glance

#### Scenario: Badge vocabulary
- GIVEN the fixed set of Badge types
- THEN the system supports at minimum: `pure`, `io`, `async`, `stateful`, `error_handling`, `test`, `entry_point`, `deprecated`
- AND new Badge types can be added to the vocabulary by extending the extractor, not by LLM invention at runtime

### Requirement: Edge Primitive
The system MUST support an Edge primitive: a directed visual connection between two Nodes or Ports, with weight encoding coupling intensity.

#### Scenario: Weighted edge
- GIVEN module A imports 12 symbols from module B
- WHEN the Edge is rendered
- THEN its visual thickness is proportional to the weight (12)
- AND a single-import Edge is visibly thinner than a 12-import Edge

#### Scenario: Edge type distinction
- GIVEN edges representing calls, imports, and inheritance
- WHEN they are rendered
- THEN edge type is encoded by line style (solid for calls, dashed for imports, dotted for inheritance)
- AND at most 3-4 line styles are used (more becomes unreadable)

#### Scenario: Suppressed ubiquitous edges
- GIVEN an Edge to a module flagged as ubiquitous
- WHEN the default view is rendered
- THEN the Edge is NOT drawn
- AND a small indicator on the Node acknowledges the dependency exists (power rail notation)
- AND the human can toggle ubiquitous edges on if needed

### Requirement: Port Primitive
The system MUST support a Port primitive: a small visual element anchored to a Container's membrane, representing an interface point (public function, API endpoint, event emitter).

#### Scenario: Port placement
- GIVEN a module with 4 public functions
- WHEN the Container is rendered
- THEN 4 Ports appear on its membrane
- AND each Port is labeled with the function name
- AND Edges connect to Ports, not directly to the Container body

#### Scenario: Port direction
- GIVEN a function that accepts parameters and returns a value
- WHEN it is rendered as a Port
- THEN input Ports (parameters/dependencies) are visually distinct from output Ports (return values/emitted events)

#### Scenario: Port visibility at zoom levels
- GIVEN a Container viewed from far away
- WHEN the zoom level is far
- THEN Ports are hidden (the Container appears as a solid region)
- AND as the human zooms in, Ports fade in on the membrane
- AND this follows the LOD Shell behavior

### Requirement: Route Primitive
The system MUST support a Route primitive: a named, highlighted path through the graph representing a unit of work (request lifecycle, data pipeline, error propagation chain).

#### Scenario: Request path
- GIVEN the human asks "show me the order submission path"
- WHEN the LLM traces the path through the call graph and data flow spines
- THEN a Route is rendered as a highlighted, labeled path through the structural geography
- AND the Route has a name ("Order Submission")
- AND each segment of the Route is a sequence of Edges
- AND non-Route elements are de-emphasized

#### Scenario: Route classification
- GIVEN multiple Routes are visible simultaneously
- WHEN the Routes represent different concerns (happy path, error path, fallback)
- THEN each Route has a distinct visual treatment (color, dash pattern)
- AND the system supports at most 4 simultaneous Routes before visual overload

#### Scenario: Route direction
- GIVEN a Route from HTTP handler through service layer to database
- WHEN it is rendered
- THEN the direction of flow is apparent (animated particles, gradient, or arrow heads)
- AND the entry point and terminus of the Route are visually distinct (landmark-style)

### Requirement: Landmark Primitive
The system MUST support a Landmark primitive: a structurally significant Node that persists across all zoom levels and serves as an orientation anchor.

#### Scenario: Hub as landmark
- GIVEN a module with the highest in-degree in the codebase (most depended upon)
- WHEN it is identified as a Landmark
- THEN it is visible at every zoom level, even when surrounding Nodes are hidden by LOD
- AND it has a distinctive visual treatment (larger, brighter, or marked with a glyph)

#### Scenario: Entry point as landmark
- GIVEN the main HTTP entry point of a web application
- WHEN it is identified as a Landmark
- THEN it persists at all zoom levels
- AND it serves as a spatial reference ("the API gateway is to the north")

#### Scenario: Bridge as landmark
- GIVEN a module with high betweenness centrality connecting two major subsystems
- WHEN it is identified as a Landmark
- THEN it persists at all zoom levels
- AND it is positioned between the two subsystems it connects

#### Scenario: Landmark sources
- GIVEN the extraction layer has computed structural significance
- THEN Landmarks are derived from: hubs (high in-degree), bridges (high betweenness centrality), entry points (no in-edges from application code), and human-designated Landmarks
- AND the LLM MAY designate additional Landmarks per query context

### Requirement: Tint Primitive
The system MUST support a Tint primitive: a background color on a Container encoding one categorical dimension.

#### Scenario: Domain tinting
- GIVEN bounded contexts representing auth, billing, and shipping
- WHEN the LLM assigns Tints
- THEN each context has a distinct desaturated fill color
- AND the palette is limited to 4-6 categorical colors (preattentive discrimination limit)

#### Scenario: One tint dimension per view
- GIVEN the Tint channel is in use for "domain" categorization
- WHEN the human asks a question about test coverage
- THEN the LLM MAY reassign Tints to encode coverage levels instead
- AND the previous Tint assignment is replaced, not layered
- AND only ONE categorical dimension is encoded via Tint at a time

#### Scenario: Tint is the only symbolic primitive
- GIVEN all other primitives are iconic or indexical (they resemble or point to what they represent)
- WHEN Tint is used
- THEN it is the one primitive that requires a legend
- AND the legend is always visible when Tint is active
- AND this is acknowledged as a design tradeoff: Tint is the highest-bandwidth preattentive variable, worth the legend cost for one dimension

### Requirement: LOD Shell Primitive
The system MUST support a LOD Shell primitive: precomputed summaries at multiple zoom tiers, enabling the LLM to compose views at any scale without re-analyzing the codebase.

#### Scenario: Three-tier LOD
- GIVEN a bounded context with 15 internal modules, each containing multiple classes
- WHEN LOD Shells are precomputed
- THEN tier 0 (far): the context is a single Container with aggregate metrics (total LOC, total in-degree, total out-degree) and its Landmarks
- AND tier 1 (medium): the context expands to show its 15 module-level Containers with inter-module Edges
- AND tier 2 (near): modules expand to show classes, functions, and all Edges

#### Scenario: LLM tier selection
- GIVEN the human asks a broad question ("what are the main parts of this system?")
- WHEN the LLM composes a view
- THEN it selects tier 0 LOD Shells for the entire codebase
- AND the view answers the question without overwhelming detail

#### Scenario: Mixed tiers
- GIVEN the human asks "how does auth interact with billing?"
- WHEN the LLM composes a view
- THEN it selects tier 1 or tier 2 for auth and billing contexts
- AND tier 0 for all other contexts (de-emphasized background)
- AND the zoom level varies by relevance, not by uniform distance

### Requirement: Power Rail Notation
The system MUST support Power Rail notation: a visual acknowledgment that a ubiquitous dependency exists without drawing its edges.

#### Scenario: Standard library power rail
- GIVEN `logging` is imported by 85% of modules and flagged as ubiquitous
- WHEN the default view is rendered
- THEN no edges to `logging` are drawn
- AND each Node that imports `logging` has a small, consistent indicator (e.g. a tiny rail glyph at its base)
- AND the `logging` module itself is not shown in the structural view unless explicitly requested

#### Scenario: Power rail toggle
- GIVEN the human wants to see all dependencies including ubiquitous ones
- WHEN the human toggles power rails to visible
- THEN all suppressed ubiquitous edges fade in
- AND the visual immediately demonstrates WHY they were suppressed (the screen becomes cluttered)
- AND the toggle is reversible

#### Scenario: Multiple power rails
- GIVEN `logging`, `typing`, and `os.path` are all flagged as ubiquitous
- WHEN the default view is rendered
- THEN each has its own power rail indicator
- AND the indicators are visually consistent (same glyph, same position)
- AND at most 5-7 power rails are active (above that, the indicators themselves become noise)

---

## Composition Principles

### Requirement: Overlay/Facet Composition
The system MUST support projecting different lenses over the same structural geography without changing the underlying topology.

#### Scenario: Switching from dependency view to failure view
- GIVEN the human is viewing the structural geography with dependency Edges
- WHEN the human asks "where is this system fragile?"
- THEN the LLM composes a failure-mode overlay
- AND Edge weights shift to encode blast radius instead of import count
- AND Tints shift to encode resilience (presence/absence of error handling)
- AND Landmarks shift to highlight single points of failure
- AND the underlying topology (Container nesting, Node positions) does NOT change

#### Scenario: Switching from structure view to ownership view
- GIVEN the human asks "what does team X own?"
- WHEN the LLM composes an ownership overlay
- THEN Tints encode team ownership
- AND Containers are grouped by ownership rather than by package (if ownership boundaries differ from package boundaries)
- AND the structural geography provides continuity — the human recognizes the same space with different coloring

#### Scenario: Facet as the LLM's primary compositional act
- GIVEN a fixed structural geography
- WHEN the LLM receives a question
- THEN the LLM's primary job is selecting which facet to project: which Edges to show, which Tints to assign, which Landmarks to emphasize, which Routes to trace, and which LOD tier to select for each region
- AND the LLM does NOT rearrange the spatial layout (that is computed by the extractor)

### Requirement: Distortion Legend
Every composed view MUST include a legend that makes the current distortion explicit.

#### Scenario: Legend contents
- GIVEN the LLM has composed a view
- WHEN the view is rendered
- THEN the legend shows: what Tint encodes, what Edge weight encodes, what is suppressed (power rails, LOD-hidden elements), and what Landmarks are active
- AND the legend updates when the facet changes

#### Scenario: What's hidden is as important as what's shown
- GIVEN the LLM composed a view showing only auth-related components
- WHEN the legend is rendered
- THEN it explicitly states how many Nodes and Edges are hidden
- AND the human can see "showing 12 of 147 modules" or equivalent
- AND this prevents the human from mistaking a filtered view for the complete system

### Requirement: Purpose-Level Annotation
The system MUST support attaching purpose-level annotations to structural elements, bridging the gap between mechanism (what the code does) and meaning (what the code is for).

#### Scenario: LLM-generated purpose annotation
- GIVEN a cluster of modules handling payment validation, fraud detection, and PCI compliance
- WHEN the LLM analyzes the cluster
- THEN it attaches a purpose annotation: "Payment Safety Gate — ensures all transactions meet compliance requirements before processing"
- AND the annotation is visible at the cluster's Container level
- AND it is distinct from the module names (which describe mechanism, not purpose)

#### Scenario: Beacon recognition
- GIVEN a function body that matches a well-known pattern (retry loop, accumulator, observer dispatch)
- WHEN the LLM analyzes the function
- THEN it MAY attach a beacon annotation naming the recognized pattern
- AND the beacon is visible as a small indicator on the Node
- AND beacons help the human form hypotheses about purpose without reading code

#### Scenario: Invariant annotation
- GIVEN a set of validation functions that collectively enforce a business rule
- WHEN the LLM identifies the pattern
- THEN it MAY annotate the invariant: "Order cannot ship if payment is pending"
- AND the invariant is attached to the Aggregate or Container that the validations protect
- AND the invariant is surfaced in conformance mode as a spec-vs-implementation checkpoint

---

## Primitive Interactions

### Requirement: Primitives Compose, Not Interfere
Visual encodings of different primitives MUST use distinct perceptual channels so that simultaneous primitives are independently readable.

#### Scenario: Channel allocation
- GIVEN the primitive set
- THEN Containers use spatial containment (position channel)
- AND Edges use connection (line channel)
- AND Tint uses color fill (hue channel)
- AND Badges use shape/icon (glyph channel)
- AND Edge weight uses line thickness (size channel)
- AND Landmarks use brightness/scale (luminance channel)
- AND no two primitives compete for the same perceptual channel

#### Scenario: Maximum simultaneous primitives
- GIVEN a rendered view
- WHEN all applicable primitives are active
- THEN a human can independently read: what contains what (Containers), what connects to what (Edges), what category things belong to (Tint), what aspects things have (Badges), how strong connections are (Edge weight), and what the important nodes are (Landmarks)
- AND this is possible because each primitive occupies a distinct perceptual channel

### Requirement: Primitive Set is Closed
No primitive is invented at runtime. The LLM selects from this set; it does not extend it.

#### Scenario: Novel question, existing primitives
- GIVEN the human asks a question no one has asked before
- WHEN the LLM composes a view
- THEN it uses only primitives defined in this specification
- AND if no composition of existing primitives can answer the question, the LLM says so explicitly rather than inventing a new primitive
- AND suggestions for new primitives are recorded for future spec iteration
