extends Node2D
## Run windowed to capture the actual in-game frame (headless can't render).
var frames := 0


func _ready() -> void:
	var stage = load("res://level/stage.tscn").instantiate()
	add_child(stage)


func _process(_delta: float) -> void:
	frames += 1
	if frames == 200:
		var img := get_viewport().get_texture().get_image()
		img.save_png("C:/Users/admin/.claude/jobs/0afce185/tmp/ingame.png")
		get_tree().quit()
