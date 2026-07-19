class_name WeaponData
extends Resource
## A weapon = an ordered chain of AttackSteps (docs/ARCHITECTURE.md §3).
## Adding a weapon = authoring a .tres + animations, zero code.
## `id` is stable across sessions so a future unlock pool / random-drop
## system (planned for M5) can reference weapons without scene paths.

@export var id := &"sword"
@export var display_name := "Sword"
@export var steps: Array[AttackStep] = []
