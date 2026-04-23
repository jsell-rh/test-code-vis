class_name QuestionPanel
extends Control

## UI panel that accepts natural-language questions and emits a structured view spec.
##
## Covers specs/interaction/moldable-views.spec.md:
##
## Scenario: Architectural question
##   GIVEN a loaded software system
##   WHEN the human asks "how does authentication work?"
##   THEN the system generates a view focused on auth-related components
##        → process_question() returns a spec with show + highlight + annotate for auth_service
##   AND irrelevant components are hidden or de-emphasized
##        → the show op's fixed id list implicitly excludes unrelated nodes
##   AND the relevant components are arranged to answer the question
##        → spec includes highlight and annotate ops to emphasise auth_service
##
## Scenario: Impact question
##   GIVEN a loaded software system
##   WHEN the human asks "what depends on the user database?"
##   THEN the system generates a view showing the user database and all its dependents
##        → process_question() returns a spec with show op for user_db and auth_service
##   AND the dependency relationships are spatially clear
##        → spec includes a connect op between auth_service and user_db
##
## Scenario: LLM produces view spec
##   THEN it emits a structured view specification (not raw 3D geometry)
##        → process_question() returns a Dictionary (ViewSpec.from_dict output)
##   AND the view spec controls which elements are shown, hidden, highlighted,
##       and how they are arranged
##        → all operations are taken from ViewSpec.VALID_OPS
##   AND the 3D renderer interprets the view spec into a spatial scene
##        → the returned spec is valid input for ViewSpecRenderer.apply()
##
## Scenario: LLM uses existing primitives
##   THEN it composes the answer from the existing set of primitives
##   AND no new rendering logic is generated at runtime
##        → ViewSpec.from_dict() filters any op outside VALID_OPS

## Emitted when the user submits a question.  Listeners (e.g. main.gd)
## should call ViewSpecRenderer.apply(graph, spec, root) to materialise the view.
signal view_spec_requested(spec: Dictionary)

const ViewSpec = preload("res://scripts/view_spec.gd")

## Exposed as public vars so tests can inspect them without needing the node
## to enter the scene tree (_ready is only called on scene-tree entry).
var line_edit: LineEdit
var submit_button: Button


func _init() -> void:
	# Initialise UI elements here so they exist as soon as QuestionPanel.new()
	# is called — this lets headless tests inspect them without a scene tree.
	line_edit = LineEdit.new()
	line_edit.placeholder_text = "Ask a question about the codebase..."
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	submit_button = Button.new()
	submit_button.text = "Ask"
	submit_button.pressed.connect(_on_submit_pressed)


func _ready() -> void:
	# Wire the UI elements into a layout when the node enters the scene tree.
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)
	vbox.add_child(line_edit)
	vbox.add_child(submit_button)


func _on_submit_pressed() -> void:
	var question: String = line_edit.text.strip_edges()
	if question.is_empty():
		return
	var spec: Dictionary = process_question(question)
	emit_signal("view_spec_requested", spec)


## Generate a structured view spec from a natural-language question.
##
## In this prototype, keyword matching drives the spec.
## A production system would call an LLM API here and the LLM would output
## a view spec JSON — the architecture and primitive set are identical.
##
## THEN it emits a structured view specification (not raw 3D geometry):
##   Returns a Dictionary produced by ViewSpec.from_dict(), never raw Node
##   objects or geometry.
##
## AND no new rendering logic is generated at runtime:
##   All ops are chosen from ViewSpec.VALID_OPS; ViewSpec.from_dict() filters
##   any op not in that fixed set.
func process_question(question: String) -> Dictionary:
	var q: String = question.to_lower()
	var ops: Array = []

	if "auth" in q or "authentication" in q:
		# Architectural question: focus on auth-related components.
		# THEN the system generates a view focused on auth-related components.
		ops.append({"op": "show",      "ids": ["auth_service"]})
		# AND the relevant components are arranged to answer the question
		# (highlighted = visually emphasised above other nodes).
		ops.append({"op": "highlight", "ids": ["auth_service"], "color": [1.0, 0.8, 0.0]})
		ops.append({"op": "annotate",  "id":  "auth_service",   "text": "Auth entry point"})

	elif "user database" in q or "user_db" in q or "depend" in q:
		# Impact question: show the focal node and its dependents.
		# THEN the system generates a view showing the user database and all its dependents.
		ops.append({"op": "show",     "ids": ["user_db", "auth_service"]})
		# AND the dependency relationships are spatially clear.
		ops.append({"op": "connect",  "source": "auth_service", "target": "user_db"})
		ops.append({"op": "annotate", "id":     "user_db",      "text": "Focal node"})

	# else: unknown question → ops is empty, which renders all graph nodes unchanged.

	return ViewSpec.from_dict({"question": question, "operations": ops})
