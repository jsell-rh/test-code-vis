# Data Flow Specification

## Purpose
Define how data flow through the system is visualized on demand, overlaid on the persistent structural geography.

## Requirements

### Requirement: Flow is On-Demand
The system MUST NOT show data flow by default. Flow visualization SHALL be invoked by the human in response to a specific question.

#### Scenario: Requesting a flow path
- GIVEN the default structural view is displayed
- WHEN the human asks "show me the order submission path"
- THEN the relevant flow path lights up through the structure
- AND irrelevant structural elements are de-emphasized
- AND the flow path is traceable from entry point to terminus

### Requirement: Flow Shows Paths Through Structure
The system MUST render data flow as paths through the existing structural geography, not as a separate view.

#### Scenario: Flow overlaid on structure
- GIVEN a flow has been invoked
- WHEN the human views the flow
- THEN the flow is rendered as a path through the structural space
- AND the structural context remains visible (not replaced)
- AND the human can follow the path spatially through the system

### Requirement: Aggregate Flow Patterns
The system SHOULD support showing aggregate flow patterns (hot paths, bottlenecks) as an overlay on the structure.

#### Scenario: Identifying a bottleneck
- GIVEN aggregate flow data is available
- WHEN the human requests aggregate flow visualization
- THEN high-traffic paths are visually prominent
- AND bottleneck points (where flow constricts) are identifiable
