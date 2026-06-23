class_name FloatingText
extends Node2D
## 一次性上浮文字（如产品成本扣除 "-12 成本"）：约 0.9 秒内上浮并淡出后自毁。
## 由生成方放到世界坐标位置；仅当玩家正监控该房间时可见。

const LIFETIME := 0.9
const RISE := 42.0  # 总上浮像素
const FONT_SIZE := 22

var _text: String = ""
var _color := Color(0.95, 0.45, 0.35)
var _t: float = 0.0
var _font: Font = null


func _ready() -> void:
	z_index = 220  # 画在火花 / 设备 / 产品之上
	_font = ThemeDB.fallback_font


## 设置文字与颜色（生成后立即调）。
func setup(text: String, color: Color = Color(0.95, 0.45, 0.35)) -> void:
	_text = text
	_color = color
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFETIME:
		queue_free()
		return
	position.y -= RISE * delta / LIFETIME
	queue_redraw()


func _draw() -> void:
	if _font == null or _text.is_empty():
		return
	var f := clampf(_t / LIFETIME, 0.0, 1.0)
	var alpha := 1.0 - f * f  # 后段加速淡出
	var color := Color(_color.r, _color.g, _color.b, alpha)
	var width := _font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	draw_string(
		_font, Vector2(-width * 0.5, 0.0), _text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color
	)
