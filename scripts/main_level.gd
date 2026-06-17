extends Node2D

const SCREEN_SIZE := Vector2(960.0, 540.0)
const BOOTH_RECT := Rect2(Vector2(90.0, 280.0), Vector2(180.0, 140.0))
const BOOTH_DOOR_POSITION := Vector2(282.0, 350.0)
const BOOTH_INSIDE_POSITION := Vector2(180.0, 350.0)
const BOOTH_OUTSIDE_POSITION := Vector2(318.0, 350.0)
const INTERACT_RADIUS := 48.0
const SMOKE_DURATION := 12.0
const PLAYER_CONTROLLER_SCRIPT := preload("res://scripts/player_controller.gd")

var player
var blindness_overlay: Node2D
var hint_label: Label
var status_label: Label
var smoke_bar: ProgressBar
var smoke_seconds: float = 0.0


func _ready() -> void:
	_ensure_input_actions()
	_build_world()
	_spawn_player()
	_build_hud()
	_update_hud()


func _process(delta: float) -> void:
	if player == null:
		return

	_sync_booth_state()

	if player.inside_booth:
		smoke_seconds = minf(SMOKE_DURATION, smoke_seconds + delta)

	if Input.is_action_just_pressed("interact"):
		if player.inside_booth:
			_exit_booth()
		elif player.global_position.distance_to(BOOTH_DOOR_POSITION) <= INTERACT_RADIUS:
			_enter_booth()

	_update_hud()


func _ensure_input_actions() -> void:
	_add_key_action("move_up", [KEY_W, KEY_UP])
	_add_key_action("move_down", [KEY_S, KEY_DOWN])
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("interact", [KEY_E, KEY_SPACE])


func _add_key_action(action_name: StringName, keys: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for key in keys:
		var already_bound := false
		for event in InputMap.action_get_events(action_name):
			if event is InputEventKey and event.keycode == key:
				already_bound = true
				break
		if already_bound:
			continue

		var key_event := InputEventKey.new()
		key_event.keycode = key
		InputMap.action_add_event(action_name, key_event)


func _build_world() -> void:
	_add_rect("YardFloor", SCREEN_SIZE * 0.5, Vector2(900.0, 500.0), Color(0.12, 0.15, 0.14), -100)
	_add_rect("ConcretePath", Vector2(470.0, 350.0), Vector2(350.0, 54.0), Color(0.22, 0.24, 0.23), -90)
	_add_rect("WorkZone", Vector2(660.0, 285.0), Vector2(280.0, 240.0), Color(0.10, 0.13, 0.15), -95)

	_add_static_rect("NorthWall", Vector2(480.0, 30.0), Vector2(900.0, 24.0), Color(0.34, 0.36, 0.36), -40)
	_add_static_rect("SouthWall", Vector2(480.0, 510.0), Vector2(900.0, 24.0), Color(0.34, 0.36, 0.36), -40)
	_add_static_rect("WestWall", Vector2(30.0, 270.0), Vector2(24.0, 500.0), Color(0.34, 0.36, 0.36), -40)
	_add_static_rect("EastWall", Vector2(930.0, 270.0), Vector2(24.0, 500.0), Color(0.34, 0.36, 0.36), -40)

	_build_guard_booth()
	_build_devices()
	_build_blindness_overlay()

	var camera := Camera2D.new()
	camera.name = "OverviewCamera"
	camera.position = SCREEN_SIZE * 0.5
	camera.enabled = true
	add_child(camera)


func _build_guard_booth() -> void:
	_add_rect("GuardBoothFloor", BOOTH_RECT.get_center(), BOOTH_RECT.size, Color(0.19, 0.23, 0.27), -20)
	_add_static_rect("GuardBoothTopWall", Vector2(180.0, 280.0), Vector2(190.0, 14.0), Color(0.42, 0.44, 0.42), 5)
	_add_static_rect("GuardBoothBottomWall", Vector2(180.0, 420.0), Vector2(190.0, 14.0), Color(0.42, 0.44, 0.42), 5)
	_add_static_rect("GuardBoothLeftWall", Vector2(90.0, 350.0), Vector2(14.0, 140.0), Color(0.42, 0.44, 0.42), 5)
	_add_static_rect("GuardBoothRightWallTop", Vector2(270.0, 307.0), Vector2(14.0, 54.0), Color(0.42, 0.44, 0.42), 5)
	_add_static_rect("GuardBoothRightWallBottom", Vector2(270.0, 393.0), Vector2(14.0, 54.0), Color(0.42, 0.44, 0.42), 5)

	_add_rect("BoothDesk", Vector2(158.0, 327.0), Vector2(78.0, 24.0), Color(0.38, 0.26, 0.16), 0)
	_add_rect("BoothAshtray", Vector2(190.0, 327.0), Vector2(18.0, 10.0), Color(0.62, 0.66, 0.68), 2)
	_add_rect("BoothDoorMarker", BOOTH_DOOR_POSITION, Vector2(12.0, 56.0), Color(0.95, 0.78, 0.28), 15)
	_add_world_label("保安亭", Vector2(180.0, 453.0), Vector2(120.0, 24.0), 17, Color(0.86, 0.90, 0.88))
	_add_world_label("门 / E", Vector2(312.0, 317.0), Vector2(74.0, 22.0), 14, Color(0.98, 0.86, 0.42))


func _build_devices() -> void:
	_add_static_rect("Generator", Vector2(650.0, 255.0), Vector2(118.0, 76.0), Color(0.18, 0.44, 0.42), 0)
	_add_rect("GeneratorPanel", Vector2(650.0, 240.0), Vector2(82.0, 16.0), Color(0.08, 0.13, 0.13), 2)
	_add_circle("GeneratorLightA", Vector2(622.0, 240.0), 5.0, Color(0.30, 0.95, 0.45), 3)
	_add_circle("GeneratorLightB", Vector2(650.0, 240.0), 5.0, Color(0.95, 0.78, 0.24), 3)
	_add_circle("GeneratorLightC", Vector2(678.0, 240.0), 5.0, Color(0.95, 0.30, 0.24), 3)
	_add_world_label("发电机", Vector2(650.0, 308.0), Vector2(120.0, 22.0), 15, Color(0.78, 0.94, 0.90))

	_add_static_rect("ControlCabinet", Vector2(764.0, 372.0), Vector2(80.0, 100.0), Color(0.25, 0.30, 0.36), 0)
	_add_rect("ControlScreen", Vector2(764.0, 348.0), Vector2(52.0, 24.0), Color(0.15, 0.80, 0.72), 2)
	_add_rect("ControlSwitches", Vector2(764.0, 386.0), Vector2(52.0, 12.0), Color(0.10, 0.12, 0.14), 2)
	_add_world_label("控制台", Vector2(764.0, 436.0), Vector2(110.0, 22.0), 15, Color(0.78, 0.88, 0.98))

	_add_static_rect("ForbiddenKeyBase", Vector2(535.0, 380.0), Vector2(74.0, 54.0), Color(0.36, 0.33, 0.28), 0)
	_add_circle("ForbiddenKey", Vector2(535.0, 372.0), 18.0, Color(0.86, 0.10, 0.08), 3)
	_add_world_label("不要按", Vector2(535.0, 424.0), Vector2(96.0, 22.0), 15, Color(1.0, 0.78, 0.58))

	_add_static_rect("ToolRack", Vector2(825.0, 190.0), Vector2(92.0, 30.0), Color(0.40, 0.32, 0.22), 0)
	_add_world_label("维修手册", Vector2(825.0, 218.0), Vector2(96.0, 20.0), 13, Color(0.92, 0.86, 0.70))
	_add_world_label("设备区", Vector2(660.0, 158.0), Vector2(170.0, 24.0), 18, Color(0.74, 0.82, 0.88))


func _build_blindness_overlay() -> void:
	blindness_overlay = Node2D.new()
	blindness_overlay.name = "BlindnessOverlay"
	blindness_overlay.z_index = 60
	blindness_overlay.visible = false
	add_child(blindness_overlay)

	var shade := Color(0.01, 0.015, 0.018, 0.88)
	_add_rect("BlindTop", Vector2(SCREEN_SIZE.x * 0.5, BOOTH_RECT.position.y * 0.5), Vector2(SCREEN_SIZE.x, BOOTH_RECT.position.y), shade, 0, blindness_overlay)
	_add_rect("BlindBottom", Vector2(SCREEN_SIZE.x * 0.5, (BOOTH_RECT.end.y + SCREEN_SIZE.y) * 0.5), Vector2(SCREEN_SIZE.x, SCREEN_SIZE.y - BOOTH_RECT.end.y), shade, 0, blindness_overlay)
	_add_rect("BlindLeft", Vector2(BOOTH_RECT.position.x * 0.5, BOOTH_RECT.get_center().y), Vector2(BOOTH_RECT.position.x, BOOTH_RECT.size.y), shade, 0, blindness_overlay)
	_add_rect("BlindRight", Vector2((BOOTH_RECT.end.x + SCREEN_SIZE.x) * 0.5, BOOTH_RECT.get_center().y), Vector2(SCREEN_SIZE.x - BOOTH_RECT.end.x, BOOTH_RECT.size.y), shade, 0, blindness_overlay)
	_add_world_label("外面只能靠声音判断", Vector2(520.0, 70.0), Vector2(240.0, 28.0), 16, Color(0.80, 0.84, 0.86), blindness_overlay)


func _spawn_player() -> void:
	player = PLAYER_CONTROLLER_SCRIPT.new()
	player.name = "SecurityGuard"
	player.global_position = BOOTH_OUTSIDE_POSITION
	player.z_index = 90
	add_child(player)


func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "HUD"
	add_child(canvas)

	var box := VBoxContainer.new()
	box.position = Vector2(16.0, 14.0)
	box.custom_minimum_size = Vector2(430.0, 0.0)
	canvas.add_child(box)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 16)
	box.add_child(status_label)

	hint_label = Label.new()
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.add_theme_font_size_override("font_size", 14)
	hint_label.modulate = Color(0.86, 0.90, 0.86)
	box.add_child(hint_label)

	smoke_bar = ProgressBar.new()
	smoke_bar.min_value = 0.0
	smoke_bar.max_value = SMOKE_DURATION
	smoke_bar.value = 0.0
	smoke_bar.show_percentage = false
	smoke_bar.custom_minimum_size = Vector2(360.0, 16.0)
	box.add_child(smoke_bar)


func _enter_booth() -> void:
	player.global_position = BOOTH_INSIDE_POSITION
	player.set_inside_booth(true)
	blindness_overlay.visible = true


func _exit_booth() -> void:
	player.global_position = BOOTH_OUTSIDE_POSITION
	player.set_inside_booth(false)
	blindness_overlay.visible = false


func _sync_booth_state() -> void:
	var is_in_booth := BOOTH_RECT.grow(-4.0).has_point(player.global_position)
	if is_in_booth == player.inside_booth:
		return

	player.set_inside_booth(is_in_booth)
	blindness_overlay.visible = is_in_booth


func _update_hud() -> void:
	if player == null or status_label == null:
		return

	smoke_bar.value = smoke_seconds

	if smoke_seconds >= SMOKE_DURATION:
		status_label.text = "香烟抽完：本关通关条件已满足。"
	else:
		status_label.text = "原型目标：进保安亭抽完一根烟，同时留意设备区。"

	if player.inside_booth:
		hint_label.text = "保安亭内看不到外面。按 E 出门，抽烟进度会暂停但保留。"
	elif player.global_position.distance_to(BOOTH_DOOR_POSITION) <= INTERACT_RADIUS:
		hint_label.text = "按 E 进入保安亭。"
	else:
		hint_label.text = "WASD / 方向键移动。设备区足够小，出门后可以一眼看完。"


func _add_static_rect(node_name: String, center: Vector2, size: Vector2, color: Color, z: int) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = node_name
	body.position = center
	body.z_index = z
	add_child(body)

	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

	var polygon := Polygon2D.new()
	polygon.name = "Visual"
	polygon.polygon = _rect_points(size)
	polygon.color = color
	body.add_child(polygon)

	return body


func _add_rect(node_name: String, center: Vector2, size: Vector2, color: Color, z: int, parent: Node = null) -> Polygon2D:
	var polygon := Polygon2D.new()
	polygon.name = node_name
	polygon.position = center
	polygon.polygon = _rect_points(size)
	polygon.color = color
	polygon.z_index = z
	if parent == null:
		add_child(polygon)
	else:
		parent.add_child(polygon)
	return polygon


func _add_circle(node_name: String, center: Vector2, radius: float, color: Color, z: int, parent: Node = null) -> Polygon2D:
	var polygon := Polygon2D.new()
	polygon.name = node_name
	polygon.position = center
	polygon.polygon = _circle_points(radius, 24)
	polygon.color = color
	polygon.z_index = z
	if parent == null:
		add_child(polygon)
	else:
		parent.add_child(polygon)
	return polygon


func _add_world_label(text: String, center: Vector2, size: Vector2, font_size: int, color: Color, parent: Node = null) -> Label:
	var label := Label.new()
	label.text = text
	label.position = center - size * 0.5
	label.size = size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = color
	label.z_index = 80
	if parent == null:
		add_child(label)
	else:
		parent.add_child(label)
	return label


func _rect_points(size: Vector2) -> PackedVector2Array:
	var half := size * 0.5
	return PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y)
	])


func _circle_points(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
