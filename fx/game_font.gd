## Shared CJK-capable font for in-game text. Godot's default font has NO
## CJK glyphs (Chinese renders as tofu) — resolve system fonts instead.
## Static, autoload-free (safe in test preload chains).

static var _font: SystemFont


## Apply a Chinese-capable font to a Label (call before/alongside size and
## color overrides).
static func apply(label: Label) -> void:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = ["Microsoft YaHei", "SimHei", "Noto Sans CJK SC", "PingFang SC"]
	label.add_theme_font_override(&"font", _font)
