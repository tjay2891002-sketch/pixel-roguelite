extends SceneTree
## Headless generator validation — M3's done-when:
##   20 seeds: first is START with a P spawn, boss present + reachable via the
##   parent chain, no bounds overlaps, main path complete + role order,
##   >= 15 of 20 layouts meaningfully distinct.
##   500 seeds: zero generation failures.
## Run: godot --headless --path <project> --script res://tools/generator_test.gd

const Generator := preload("res://level/generator/stage_generator.gd")
const GreyboxBiome := preload("res://data/biomes/greybox.tres")

var _failures: Array[String] = []


func _initialize() -> void:
	var signatures := {}
	for seed in range(1, 21):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed * 7919
		var layout := Generator.generate(GreyboxBiome, rng)
		if layout.is_empty():
			_check(false, "seed %d: non-empty layout" % seed, "")
			continue
		_check_layout(layout, seed)
		signatures[_signature(layout)] = true
		Generator.free_after_review(layout)
	_check(signatures.size() >= 15, "diversity: >= 15/20 distinct layouts", "got %d" % signatures.size())

	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var failed := 0
	for i in 500:
		var layout := Generator.generate(GreyboxBiome, rng)
		if layout.is_empty():
			failed += 1
		Generator.free_after_review(layout)
	_check(failed == 0, "500 seeds: zero generation failures", "%d failed" % failed)
	_finish()


func _check_layout(layout: Array, seed: int) -> void:
	var first: Dictionary = layout[0]
	_check(first.role == 0, "seed %d: first is START" % seed, "role=%d" % first.role)
	_check(not first.chunk.spawn_points(&"P").is_empty(), "seed %d: start has P spawn" % seed, "")

	# main path complete + role order (TREASURE may have rolled into SHOP)
	var main_count := 0
	for pl in layout:
		if pl.role != 5:
			main_count += 1
	_check(main_count == GreyboxBiome.path_roles.size(), "seed %d: main path complete" % seed, "got %d/%d" % [main_count, GreyboxBiome.path_roles.size()])
	var order_ok := true
	for i in GreyboxBiome.path_roles.size():
		var want: int = GreyboxBiome.path_roles[i]
		var got: int = layout[i].role
		if want == 3:
			order_ok = order_ok and got in [2, 3]
		else:
			order_ok = order_ok and got == want
	_check(order_ok, "seed %d: main-path role order" % seed, "")

	# boss present + reachable via parent chain
	var boss_idx := -1
	for i in layout.size():
		if layout[i].role == 4:
			boss_idx = i
	_check(boss_idx >= 0, "seed %d: boss present" % seed, "")
	if boss_idx >= 0:
		var cursor := boss_idx
		var guard := 0
		while cursor > 0 and guard < 100:
			cursor = layout[cursor].parent
			guard += 1
		_check(cursor == 0, "seed %d: boss reachable from start" % seed, "")

	# no bounds overlaps
	var overlap := false
	for i in layout.size():
		var a := Rect2(layout[i].pos, layout[i].chunk.bounds().size)
		for j in range(i + 1, layout.size()):
			var b := Rect2(layout[j].pos, layout[j].chunk.bounds().size)
			if a.intersects(b) and a.intersection(b).get_area() > 1.0:
				overlap = true
	_check(not overlap, "seed %d: no bounds overlaps" % seed, "")


func _signature(layout: Array) -> String:
	var parts := []
	for pl in layout:
		parts.append("%d@%d,%d" % [pl.role, int(pl.pos.x), int(pl.pos.y)])
	return "|".join(parts)


func _check(condition: bool, what: String, detail := "") -> void:
	if condition:
		print("PASS: %s" % what)
	else:
		var message := "FAIL: %s (%s)" % [what, detail]
		_failures.append(message)
		printerr(message)


func _finish() -> void:
	if _failures.is_empty():
		print("GENERATOR TEST: all checks passed")
	else:
		printerr("GENERATOR TEST: %d check(s) failed" % _failures.size())
	quit(0 if _failures.is_empty() else 1)
