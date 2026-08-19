extends Node2D

const WORLD_WIDTH := 8480.0
const FLOOR_Y := 680.0
const START_X := 120.0
const GRAVITY := 1500.0
const RUN_SPEED := 165.0
const NORMAL_JUMP_SPEED := -540.0
const HIGH_JUMP_SPEED := -860.0
const DOUBLE_TAP_WINDOW := 0.5
const START_DELAY := 1.2
const RESPAWN_DELAY := 0.65
const LOTUS_COUNT := 48
const LOTUS_TEXTURE := preload("res://games/jump/assets/lotus.png")
const IDLE_TEXTURE := preload("res://games/jump/assets/player_idle.png")
const WALK_SHEET := preload("res://games/jump/assets/player_walk.png")
const JUMP_SHEET := preload("res://games/jump/assets/player_jump.png")
const COLLISION_MAP_TEXTURE := preload("res://games/jump/assets/collision_map.jpg")
const BACKGROUND_SCALE_X := 0.6873916
const BACKGROUND_SCALE_Y := 0.95629066
const BACKGROUND_LEFT := 3.0
const BACKGROUND_TOP := 249.5

@onready var player: Sprite2D = $Player
@onready var background: Sprite2D = $Background
@onready var lotus_label: Label = $HUD/LotusLabel
@onready var progress_label: Label = $HUD/ProgressLabel
@onready var status_label: Label = $HUD/Status
@onready var collision_overlay: Sprite2D = $CollisionOverlay
@onready var result_overlay: Control = $Overlays/ResultOverlay
@onready var result_title_label: Label = $Overlays/ResultOverlay/ResultPanel/ResultTitleLabel
@onready var result_summary_label: Label = $Overlays/ResultOverlay/ResultPanel/ResultSummaryLabel
@onready var result_score_label: Label = $Overlays/ResultOverlay/ResultPanel/ResultScoreValueLabel
@onready var result_restart_button: Button = $Overlays/ResultOverlay/ResultPanel/RestartButton

var velocity := Vector2.ZERO
var camera_x := 960.0
var collected := 0
var started := true
var finished := false
var coyote_time := 0.0
var jump_buffer := 0.0
var jump_requested := false
var high_jump_requested := false
var last_tap_time := -10.0
var animation_elapsed := 0.0
var elapsed_time := 0.0
var start_delay := START_DELAY
var respawn_delay := 0.0
var last_safe_position := Vector2.ZERO
var lotus_nodes: Array[Sprite2D] = []
var collision_map: Image
var rng := RandomNumberGenerator.new()
var lotuses := [Vector2(470, 570), Vector2(1250, 520), Vector2(1900, 440), Vector2(2570, 590), Vector2(3230, 460), Vector2(3920, 570), Vector2(4660, 500), Vector2(6100, 460)]

func _ready() -> void:
	rng.randomize()
	collision_map = COLLISION_MAP_TEXTURE.get_image()
	$HUD/Restart.pressed.connect(_restart)
	result_restart_button.pressed.connect(_restart)
	_restart()
	queue_redraw()

func _restart() -> void:
	for lotus_node in lotus_nodes:
		if is_instance_valid(lotus_node):
			lotus_node.queue_free()
	lotus_nodes.clear()
	var start_surface := _surface_y_any(START_X)
	if start_surface >= 1000.0:
		start_surface = FLOOR_Y
	player.position = Vector2(START_X, start_surface - 64.0)
	last_safe_position = player.position
	velocity = Vector2.ZERO
	jump_requested = false
	high_jump_requested = false
	last_tap_time = -10.0
	player.scale = Vector2(0.061, 0.061)
	player.offset = Vector2(0, 180)
	player.rotation = 0.0
	player.texture = IDLE_TEXTURE
	player.hframes = 1
	player.vframes = 1
	player.frame = 0
	player.flip_h = false
	result_overlay.visible = false
	camera_x = 960.0
	collected = 0
	elapsed_time = 0.0
	start_delay = START_DELAY
	respawn_delay = 0.0
	started = true
	finished = false
	lotuses = _generate_lotuses()
	_spawn_lotuses()
	_update_hud()
	queue_redraw()

func _spawn_lotuses() -> void:
	for lotus_position in lotuses:
		var lotus := Sprite2D.new()
		lotus.texture = LOTUS_TEXTURE
		lotus.z_index = 6
		lotus.position = lotus_position
		lotus.scale = Vector2(0.58, 0.58)
		lotus_nodes.append(lotus)
		add_child(lotus)

func _generate_lotuses() -> Array[Vector2]:
	var generated: Array[Vector2] = []
	var attempts := 0
	while generated.size() < LOTUS_COUNT and attempts < 3000:
		attempts += 1
		var x := rng.randf_range(80.0, WORLD_WIDTH - 120.0)
		var surface_y := _surface_y_any(x)
		if surface_y >= 1000.0:
			continue
		var candidate := Vector2(x, surface_y - 82.0)
		var too_close := false
		for existing in generated:
			if existing.distance_to(candidate) < 135.0:
				too_close = true
				break
		if not too_close:
			generated.append(candidate)
	return generated

func _physics_process(delta: float) -> void:
	if finished:
		return
	if start_delay > 0.0:
		start_delay = maxf(0.0, start_delay - delta)
		velocity = Vector2.ZERO
		_update_player_animation(delta)
		_update_hud()
		queue_redraw()
		return
	elapsed_time += delta
	if respawn_delay > 0.0:
		respawn_delay = maxf(0.0, respawn_delay - delta)
		velocity = Vector2.ZERO
		_update_player_animation(delta)
		_update_hud()
		queue_redraw()
		return
	velocity.x = move_toward(velocity.x, RUN_SPEED, 1200.0 * delta)
	var jump_pressed := jump_requested
	jump_requested = false
	var high_jump_pressed := high_jump_requested
	high_jump_requested = false
	if jump_pressed:
		jump_buffer = 0.13
	jump_buffer = maxf(0.0, jump_buffer - delta)
	coyote_time = maxf(0.0, coyote_time - delta)
	var was_grounded := _is_grounded()
	if was_grounded:
		coyote_time = 0.12
	if high_jump_pressed:
		velocity.y = HIGH_JUMP_SPEED
		jump_buffer = 0.0
		coyote_time = 0.0
	elif jump_buffer > 0.0 and coyote_time > 0.0:
		velocity.y = NORMAL_JUMP_SPEED
		jump_buffer = 0.0
		coyote_time = 0.0
	velocity.y += GRAVITY * delta
	var old_y := player.position.y
	player.position += velocity * delta
	var landed := false
	var surface_y := _surface_y_between(player.position.x, old_y + 64.0, player.position.y + 64.0)
	if surface_y < 1000.0 and old_y + 64.0 <= surface_y + 40.0 and player.position.y + 64.0 >= surface_y and velocity.y >= 0.0:
		player.position.y = surface_y - 64.0
		velocity.y = 0.0
		landed = true
		if _is_safe_checkpoint_position():
			last_safe_position = player.position
	if not landed and player.position.y > 1050.0:
		_respawn_from_fall()
		return
	var collected_this_frame := false
	for lotus_node in lotus_nodes:
		if lotus_node.visible and player.position.distance_to(lotus_node.position) < 92.0:
			lotus_node.visible = false
			collected += 1
			collected_this_frame = true
	if collected_this_frame:
		_post_audio("flower")
		status_label.text = "莲花入怀｜继续向前"
	if player.position.x >= WORLD_WIDTH - 160.0:
		finished = true
		status_label.text = "抵达彼岸｜心自相忘　（点击重新开始再游一次）"
		result_title_label.text = "逐莲已毕"
		result_score_label.text = str(collected)
		result_summary_label.text = "行至彼岸，莲花满袖\n此心所向，终有所归"
		result_overlay.visible = true
		if OS.has_feature("web"):
			JavaScriptBridge.eval(
				"window.parent.postMessage({type:'godot:lotus-complete', flowers:%d, seconds:%d}, '*')" % [collected, int(elapsed_time)]
			)
	camera_x = lerpf(camera_x, clampf(player.position.x, 960.0, WORLD_WIDTH - 960.0), 7.0 * delta)
	_update_player_animation(delta)
	_update_hud()
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_register_tap()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if event.double_click:
			_request_high_jump()
		else:
			_register_tap()
	elif event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_SPACE or event.keycode == KEY_UP or event.keycode == KEY_ENTER):
		_register_tap()

func _register_tap() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - last_tap_time <= DOUBLE_TAP_WINDOW:
		_request_high_jump()
	else:
		_post_audio("jump")
		jump_requested = true
		last_tap_time = now

func _request_high_jump() -> void:
	_post_audio("jump")
	high_jump_requested = true
	jump_requested = false
	last_tap_time = -10.0

func _respawn_from_fall() -> void:
	_post_audio("fall")
	player.position = last_safe_position
	velocity = Vector2.ZERO
	jump_requested = false
	high_jump_requested = false
	last_tap_time = -10.0
	respawn_delay = RESPAWN_DELAY
	status_label.text = "落水无妨｜从此处再行"
	camera_x = clampf(player.position.x, 960.0, WORLD_WIDTH - 960.0)

func _is_safe_checkpoint_position() -> bool:
	var foot_y := player.position.y + 64.0
	var left_surface := _surface_y_near(player.position.x - 52.0, foot_y)
	var right_surface := _surface_y_near(player.position.x + 70.0, foot_y)
	return (
		left_surface < 1000.0
		and right_surface < 1000.0
		and absf(left_surface - foot_y) < 10.0
		and absf(right_surface - foot_y) < 10.0
	)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		collision_overlay.visible = not collision_overlay.visible


func _post_audio(cue: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.parent.postMessage({type:'godot:audio', cue:'%s'}, '*')" % cue)

func _is_grounded() -> bool:
	var surface_y := _surface_y_near(player.position.x, player.position.y + 64.0)
	return surface_y < 1000.0 and absf(player.position.y + 64.0 - surface_y) < 7.0

func _surface_y_near(world_x: float, expected_world_y: float) -> float:
	return _surface_y_between(world_x, expected_world_y - 45.0, expected_world_y + 45.0)

func _update_player_animation(delta: float) -> void:
	animation_elapsed += delta
	if not _is_grounded():
		if player.texture != JUMP_SHEET:
			player.texture = JUMP_SHEET
			player.scale = Vector2(0.115, 0.115)
			player.offset = Vector2(0, 180)
			player.hframes = 2
			player.vframes = 1
		player.frame = 0 if velocity.y < 0.0 else 1
	else:
		if absf(velocity.x) > 10.0:
			if player.texture != WALK_SHEET:
				player.texture = WALK_SHEET
				player.scale = Vector2(0.115, 0.115)
				player.offset = Vector2(0, 180)
				player.hframes = 4
				player.vframes = 1
			player.frame = int(animation_elapsed * 8.0) % 4
		else:
			if player.texture != IDLE_TEXTURE:
				player.texture = IDLE_TEXTURE
				player.scale = Vector2(0.061, 0.061)
				player.offset = Vector2(0, 180)
				player.hframes = 1
				player.vframes = 1
			player.frame = 0
	if absf(velocity.x) > 10.0:
		player.flip_h = velocity.x < 0.0

func _surface_y_any(world_x: float) -> float:
	if collision_map == null:
		return 1000.0
	var image_x := clampi(int((world_x - BACKGROUND_LEFT) / BACKGROUND_SCALE_X), 0, collision_map.get_width() - 1)
	var surface_pixel_y := collision_map.get_height()
	for x in range(maxi(0, image_x - 4), mini(collision_map.get_width(), image_x + 5)):
		for y in range(collision_map.get_height()):
			var pixel := collision_map.get_pixel(x, y)
			if pixel.r > 0.62 and pixel.r - pixel.g > 0.25 and pixel.r - pixel.b > 0.25:
				surface_pixel_y = mini(surface_pixel_y, y)
				break
	if surface_pixel_y == collision_map.get_height():
		return 1000.0
	return BACKGROUND_TOP + surface_pixel_y * BACKGROUND_SCALE_Y

func _surface_y_between(world_x: float, min_world_y: float, max_world_y: float) -> float:
	if collision_map == null:
		return 1000.0
	var image_x := clampi(int((world_x - BACKGROUND_LEFT) / BACKGROUND_SCALE_X), 0, collision_map.get_width() - 1)
	var min_y := clampi(int((min_world_y - BACKGROUND_TOP) / BACKGROUND_SCALE_Y), 0, collision_map.get_height() - 1)
	var max_y := clampi(int((max_world_y - BACKGROUND_TOP) / BACKGROUND_SCALE_Y) + 1, 0, collision_map.get_height())
	var surface_pixel_y := collision_map.get_height()
	# 只在人物脚下的运动区间内找红线，避免把上方浮台误判成地面。
	for x in range(maxi(0, image_x - 4), mini(collision_map.get_width(), image_x + 5)):
		for y in range(min_y, max_y):
			var pixel := collision_map.get_pixel(x, y)
			if pixel.r > 0.62 and pixel.r - pixel.g > 0.25 and pixel.r - pixel.b > 0.25:
				surface_pixel_y = mini(surface_pixel_y, y)
				break
	if surface_pixel_y == collision_map.get_height():
		return 1000.0
	return BACKGROUND_TOP + surface_pixel_y * BACKGROUND_SCALE_Y

func _update_hud() -> void:
	lotus_label.text = "莲花 %d / %d" % [collected, LOTUS_COUNT]
	progress_label.text = "用时 %s" % _format_time(elapsed_time)

func _format_time(seconds: float) -> String:
	var total_seconds := int(seconds)
	return "%02d:%02d" % [floori(total_seconds / 60.0), total_seconds % 60]

func _process(_delta: float) -> void:
	position.x = 960.0 - camera_x

func _draw() -> void:
	# 纸张底色与卷轴边界
	draw_rect(Rect2(camera_x - 960.0, 188.0, 1920.0, 760.0), Color("f4efdf"))
	draw_line(Vector2(camera_x - 960.0, 188), Vector2(camera_x + 960.0, 188), Color("31566f"), 5.0)
	draw_line(Vector2(camera_x - 960.0, 948), Vector2(camera_x + 960.0, 948), Color("31566f"), 5.0)
	# 莲花收集物
	for lotus in lotuses:
		draw_circle(lotus, 38.0 + sin(Time.get_ticks_msec() * 0.004 + lotus.x) * 4.0, Color(0.9, 0.67, 0.18, 0.18))
