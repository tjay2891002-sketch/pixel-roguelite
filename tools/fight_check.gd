extends Node2D
var frames := 0
var _stage
var _rc
var _fly

func _ready() -> void:
	_stage = load("res://level/playground.tscn").instantiate()
	add_child(_stage)
	_rc = load("res://actors/enemies/redcap_boss.tscn").instantiate()
	add_child(_rc)
	_rc.global_position = Vector2(240, 139)
	_fly = load("res://actors/enemies/flyer.tscn").instantiate()
	add_child(_fly)
	_fly.global_position = Vector2(340, 110)
	_stage.player.global_position = Vector2(268, 139)

func _process(_delta: float) -> void:
	frames += 1
	if frames == 55:
		get_viewport().get_texture().get_image().save_png("C:/Users/admin/.claude/jobs/56ee7cdf/tmp/fight1.png")
	if frames == 110:
		get_viewport().get_texture().get_image().save_png("C:/Users/admin/.claude/jobs/56ee7cdf/tmp/fight2.png")
		get_tree().quit()
