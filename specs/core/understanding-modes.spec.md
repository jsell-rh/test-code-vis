# Understanding Modes Specification

## Purpose
Define the three distinct modes of understanding a human needs when evaluating an agent-built system, and the transitions between them.

## Requirements

### Requirement: Conformance Mode
The system MUST allow the human to see whether the as-built system matches the as-specced design.

#### Scenario: Spec-aligned implementation
- GIVEN a spec that defines an auth service separate from user management
- WHEN the human enters conformance mode
- THEN the human can see that the realized system has auth and user management as separate components
- AND the correspondence between spec and realization is visually apparent

#### Scenario: Spec-divergent implementation
- GIVEN a spec that defines payment processing as a separate service
- WHEN the agent has implemented payment logic inline within the order service
- THEN the human can see the divergence between spec and realization
- AND the specific nature of the divergence is clear (merged vs. separate)

### Requirement: Evaluation Mode
The system MUST allow the human to evaluate the architectural quality of the realized system independent of the spec.

#### Scenario: Detecting tight coupling
- GIVEN a system where two services are heavily interdependent
- WHEN the human evaluates the system
- THEN the coupling between those services is apparent
- AND the human can assess whether the coupling is problematic

#### Scenario: Identifying single point of failure
- GIVEN a system where all services depend on one central component
- WHEN the human evaluates the system
- THEN the criticality and centrality of that component is apparent
- AND the risk it represents is clear

#### Scenario: Spec is faithfully implemented but architecturally poor
- GIVEN a spec that was underspecified or specified a poor design
- AND the agent faithfully implemented it
- WHEN the human evaluates the system
- THEN architectural problems are visible even though conformance is perfect

### Requirement: Simulation Mode
The system MUST allow the human to explore the impact of hypothetical changes before committing to them.

#### Scenario: Splitting a service
- GIVEN a monolithic service the human is considering splitting
- WHEN the human simulates the split
- THEN the impact on dependent services is visible
- AND new dependencies or interfaces that would be required are shown

#### Scenario: Failure injection
- GIVEN a running system topology
- WHEN the human simulates a component failure
- THEN the cascade of effects through the system is visible
- AND components that would be affected are clearly identified

### Requirement: Cascade Depth
When simulating failure propagation, the system MUST encode propagation distance — not just which nodes are affected, but how many hops away each affected node is from the failure origin.

#### Scenario: Visualizing blast radius by depth
- GIVEN the human simulates failure of a central component
- WHEN the cascade is computed
- THEN first-order dependents (direct consumers) are visually distinct from second-order, third-order, etc.
- AND depth is encoded as a gradient (e.g. intensity, saturation, or size of the effect marker)
- AND the cascade animates outward in waves — first-order lights up first, then second-order, then third — so the human perceives propagation sequence, not just final state

#### Scenario: Cascade wave animation
- GIVEN the cascade involves nodes at depths 1 through N
- WHEN the simulation plays
- THEN each depth level animates in sequence with a brief staggered delay
- AND the animation is smooth and continuous, not stepped
- AND the human can see where the cascade attenuates (few or no nodes at deeper levels)

### Requirement: Mode Composition
Understanding modes are orthogonal, not mutually exclusive. Multiple modes MAY be active simultaneously, and their visual encodings layer to answer compound questions that no single mode addresses alone.

#### Scenario: Conformance + Evaluation
- GIVEN the human activates both Conformance and Evaluation modes
- WHEN both are active
- THEN the human can see which spec-aligned modules are also single points of failure
- AND which divergent modules have healthy architectural properties
- AND visual encodings layer: one mode controls a primary visual channel (e.g. fill color), the other controls a secondary channel (e.g. border or annotation)

#### Scenario: Evaluation + Simulation
- GIVEN the human activates Evaluation mode and then simulates a failure
- WHEN both are active
- THEN cascade-affected nodes show both their cascade depth and their architectural risk level
- AND the human can prioritize: "which affected nodes are already high-risk?"

#### Scenario: Activating a second mode
- GIVEN one mode is active
- WHEN the human activates a second mode
- THEN the second mode's visual encoding fades in smoothly, layering on top of the first
- AND the first mode's encoding remains visible, adjusting channel if needed to avoid conflict
- AND no visual state snaps or pops — transitions are always animated

#### Scenario: Deactivating a mode
- GIVEN two modes are active
- WHEN the human deactivates one
- THEN that mode's visual encoding fades out smoothly
- AND the remaining mode's encoding expands to use the freed visual channels if appropriate
- AND the transition is animated and continuous
