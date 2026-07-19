extends Node
## Base class for player states. One script per state, child of StateMachine
## (docs/ARCHITECTURE.md §2 — flat FSM, shared logic lives on the player).
##
## `player` and `machine` are injected by StateMachine._ready(). Both are
## deliberately untyped: player.gd has no class_name per the architecture
## (class_name is reserved for data Resources), and untyped refs keep
## GDScript's duck-typed calls legal without a global type.

var player
var machine
var actor # generic alias for `player` — enemy states use this name


func enter() -> void:
	pass


func exit() -> void:
	pass


func physics_update(_delta: float) -> void:
	pass


func handle_input(_event: InputEvent) -> void:
	pass


## Greybox feedback: tint the placeholder visual per state.
func tint(hex: String) -> void:
	player.visual.color = Color(hex)
