extends SceneTree
## Measure solid foot row (alpha>0.5, center 50%) for set-1 player sheets.

const SHEETS := {
	"idle": ["res://assets/enemies/player/Idle.png", 48, 48],
	"walk": ["res://assets/enemies/player/Walk.png", 48, 48],
	"attack": ["res://assets/enemies/player/Attack.png", 48, 48],
	"death": ["res://assets/enemies/player/Death.png", 48, 48],
}

const ALPHA := 0.5
const THRESH := 0.10


func _initialize() -> void:
	for name in SHEETS:
		var path: String = SHEETS[name][0]
		var fh: int = SHEETS[name][1]
		var fw: int = SHEETS[name][2]
		var img: Image = load(path).get_image()
		var foot := _foot_row(img, 0, fw, fh)
		print("%-8s foot_row=%d  offset_y(body22)=%d" % [name, foot, 11 - (foot - fh / 2)])
	quit()


func _foot_row(img: Image, frame_index: int, fw: int, fh: int) -> int:
	var x0 := frame_index * fw
	var cx0 := x0 + int(fw * 0.25)
	var cx1 := x0 + int(fw * 0.75)
	var cw := cx1 - cx0
	for y in range(fh - 1, -1, -1):
		var opaque := 0
		for x in range(cx0, cx1):
			if img.get_pixel(x, y).a > ALPHA:
				opaque += 1
		if float(opaque) / cw >= THRESH:
			return y
	return 0
