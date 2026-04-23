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
