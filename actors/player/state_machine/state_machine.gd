extends Node
## Flat state machine. States are child nodes (one script each); transitions
## happen by name via change_state(). Delegates physics + input to the
## current state. Not a true HSM by design — see docs/ARCHITECTURE.md §2.

@export var initial_state := &"Idle"

## Untyped on purpose (see state.gd header comment).
var player
var current

var _states := {}


func _ready() -> void:
	player = get_parent()
	for child in get_children():
		_states[StringName(child.name)] = child
		child.set(&"player", player)
		child.set(&"machine", self)
		child.set(&"actor", player) # generic alias — enemy states use this
	# Deferred: children are ready before their parent, so the player's
	# @onready refs don't exist yet at this point. The deferred call runs
	# after the player's _ready(), before the first physics frame.
	change_state.call_deferred(initial_state)


func change_state(state_name: StringName) -> void:
	var next = _states.get(state_name)
	if next == null or next == current:
		return
	if current:
		current.exit()
	current = next
	current.enter()
	player.emit_state(state_name)


## Re-enter the CURRENT state (exit + enter). Needed by parameterized states
## like Attack: chaining to the next step is a re-entry with different data,
## and change_state() deliberately no-ops same-name transitions.
func restart() -> void:
	if current:
		current.exit()
		current.enter()
		player.emit_state(current.name)


func physics_update(delta: float) -> void:
	if current:
		current.physics_update(delta)


func has_state(state_name: StringName) -> bool:
	return _states.has(state_name)


func handle_input(event: InputEvent) -> void:
	if current:
		current.handle_input(event)
