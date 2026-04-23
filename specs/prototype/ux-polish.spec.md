# UX Polish Specification

## Purpose
Define interaction quality requirements that make the prototype feel intuitive and delightful to use. A prototype that is clunky to navigate cannot effectively test whether spatial representation creates understanding.

## Requirements

### Requirement: Pan with Left Mouse Button
The user MUST be able to pan the view by holding the left mouse button and dragging.

#### Scenario: Panning the view
- GIVEN the top-down camera view
- WHEN the user holds left mouse button and drags
- THEN the camera pans in the direction of the drag
- AND the movement direction matches the drag direction (not inverted)

### Requirement: Non-Inverted Movement
All camera movement directions MUST match the user's intuitive expectation. Dragging left moves the view left. Dragging up moves the view up.

#### Scenario: Drag direction matches view movement
- GIVEN any camera position
- WHEN the user drags in any direction
- THEN the scene moves in the same direction as the drag (i.e. dragging left reveals content to the right, as in Google Maps)

### Requirement: Zoom Toward Mouse Cursor
Scroll-wheel zoom MUST zoom toward the point under the mouse cursor, not toward the center of the screen.

#### Scenario: Zooming into a specific component
- GIVEN the mouse cursor is positioned over a bounded context
- WHEN the user scrolls to zoom in
- THEN the view zooms toward the point under the cursor
- AND the component under the cursor stays under the cursor during the zoom

#### Scenario: Zooming out
- GIVEN a zoomed-in view
- WHEN the user scrolls to zoom out
- THEN the view zooms out from the point under the cursor

### Requirement: Orbit Around Mouse Point
Orbit (right mouse button drag) MUST rotate the camera around the point under the mouse cursor when the orbit began, not around the center of the screen or world origin.

#### Scenario: Orbiting around a component
- GIVEN the mouse cursor is over a specific component
- WHEN the user holds right mouse button and drags
- THEN the camera orbits around the point under the cursor at orbit start
- AND the component remains at the visual center during the orbit

### Requirement: Smooth Camera Movement
All camera transitions MUST be smooth and continuous, with no snapping or jerking.

#### Scenario: Smooth zoom
- GIVEN any camera position
- WHEN the user scrolls to zoom
- THEN the zoom is animated smoothly (interpolated), not instantaneous

#### Scenario: Smooth pan
- GIVEN any camera position
- WHEN the user drags to pan
- THEN the pan movement is smooth and proportional to drag speed
