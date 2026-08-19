extends Node2D

signal exit_requested

const ROUND_DURATION := 60
const PLAYER_SPEED := 420.0
const COW_WANDER_SPEED := 170.0
const COW_FLEE_SPEED := 260.0
const COW_FLEE_RADIUS := 260.0
const CATCH_DISTANCE := 92.0
const STATUS_FLASH_SECONDS := 0.9
const COW_ANIMATION_FPS := 8.0
const PERSON_ANIMATION_FPS := 8.0
const SEEKER_BASE_SCALE := 0.12
const COW_BASE_SCALE := 0.28

@onready var playfield_background: Sprite2D = $BackgroundLayer/PlayfieldBackground
@onready var seeker: Sprite2D = $Actors/Seeker
@onready var cow_area: Area2D = $Actors/Cow
@onready var cow_sprite: Sprite2D = $Actors/Cow/CowSprite
@onready var game_timer: Timer = $GameTimer

@onready var score_value_label: Label = $HUD/ScorePanel/ScoreValueLabel
@onready var score_unit_label: Label = $HUD/ScorePanel/ScoreUnitLabel
@onready var timer_value_label: Label = $HUD/TimerValueLabel
@onready var timer_unit_label: Label = $HUD/TimerUnitLabel
@onready var goal_body_label: Label = $HUD/GoalBodyLabel
@onready var status_label: Label = $HUD/StatusLabel
@onready var result_overlay: Control = $Overlays/ResultOverlay
@onready var result_title_label: Label = $Overlays/ResultOverlay/ResultPanel/ResultTitleLabel
@onready var result_summary_label: Label = $Overlays/ResultOverlay/ResultPanel/ResultSummaryLabel
@onready var result_score_label: Label = $Overlays/ResultOverlay/ResultPanel/ResultScoreValueLabel
@onready var result_score_unit_label: Label = $Overlays/ResultOverlay/ResultPanel/ResultScoreUnitLabel
@onready var result_restart_button: Button = $Overlays/ResultOverlay/ResultPanel/RestartButton
@onready var result_continue_button: Button = $Overlays/ResultOverlay/ResultPanel/ContinueButton
@onready var back_button: Button = $HUD/BackButton

var score := 0
var time_left := ROUND_DURATION
var is_round_active := true
var player_direction := Vector2.ZERO
var cow_target := Vector2.ZERO
var cow_velocity := Vector2.ZERO
var cow_step_time := 0.0
var status_flash_left := 0.0
var cow_animation_time := 0.0
var seeker_animation_time := 0.0

var play_rect := Rect2()
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	play_rect = _build_play_rect()

	game_timer.wait_time = 1.0
	game_timer.timeout.connect(_on_game_timer_timeout)
	result_restart_button.pressed.connect(_on_restart_button_pressed)
	result_continue_button.pressed.connect(_on_continue_button_pressed)
	cow_area.input_event.connect(_on_cow_input_event)
	back_button.pressed.connect(_on_back_button_pressed)

	goal_body_label.text = "点击草地改变牧人的方向，\n在 60 秒内尽可能多地抓住逃跑的牛。"
	result_overlay.visible = false
	status_label.text = "点击草地开始追牛"
	status_label.modulate.a = 1.0
	score_unit_label.text = "分"
	timer_unit_label.text = "s"
	result_score_unit_label.text = "分"

	_reset_round()


func _process(delta: float) -> void:
	if not is_round_active:
		_update_status_flash(delta)
		return

	_update_seeker(delta)
	_update_seeker_animation(delta)
	_update_cow(delta)
	_update_cow_animation(delta)
	_check_catch()
	_update_status_flash(delta)


func _input(event: InputEvent) -> void:
	if not is_round_active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var click_position: Vector2 = event.position
		if play_rect.has_point(click_position):
			player_direction = (click_position - seeker.position).normalized()
			_flash_status("牧人调转方向，继续追！")


func _build_play_rect() -> Rect2:
	var texture_size := playfield_background.texture.get_size() * playfield_background.scale
	var top_left := playfield_background.position - texture_size * 0.5
	return Rect2(top_left + Vector2(80, 60), texture_size - Vector2(160, 120))


func _reset_round() -> void:
	score = 0
	_post_seek_event("godot:seek-score")
	time_left = ROUND_DURATION
	is_round_active = true
	score_value_label.text = str(score)
	timer_value_label.text = str(time_left)
	result_overlay.visible = false
	seeker.position = Vector2(play_rect.position.x + 420.0, play_rect.position.y + play_rect.size.y * 0.7)
	player_direction = Vector2.RIGHT
	seeker_animation_time = 0.0
	seeker.frame = 0
	seeker.rotation = 0.0
	seeker.scale = Vector2(SEEKER_BASE_SCALE, SEEKER_BASE_SCALE)
	cow_velocity = Vector2.ZERO
	cow_step_time = 0.0
	cow_sprite.position.y = 0.0
	cow_sprite.rotation = 0.0
	cow_sprite.scale = Vector2(COW_BASE_SCALE, COW_BASE_SCALE)
	_respawn_cow(true)
	game_timer.start()


func _update_seeker(delta: float) -> void:
	if player_direction == Vector2.ZERO:
		return
	var next_position := seeker.position + player_direction * PLAYER_SPEED * delta
	var clamped_position := _clamp_to_play_rect(next_position)
	if clamped_position.is_equal_approx(seeker.position):
		player_direction = Vector2.ZERO
		return
	seeker.position = clamped_position


func _update_seeker_animation(delta: float) -> void:
	if player_direction == Vector2.ZERO:
		seeker.frame = 0
		seeker.rotation = 0.0
		seeker.scale = Vector2(SEEKER_BASE_SCALE, SEEKER_BASE_SCALE)
		return
	seeker_animation_time += delta
	seeker.frame = int(seeker_animation_time * PERSON_ANIMATION_FPS) % 4
	seeker.flip_h = player_direction.x < 0.0
	var step_phase := sin(seeker_animation_time * PERSON_ANIMATION_FPS * TAU)
	seeker.rotation = step_phase * 0.035
	seeker.scale = Vector2(
		SEEKER_BASE_SCALE * (1.0 + step_phase * 0.025),
		SEEKER_BASE_SCALE * (1.0 - step_phase * 0.025)
	)


func _update_cow(delta: float) -> void:
	var cow_position := cow_area.position
	var to_player := seeker.position - cow_position
	var speed := COW_WANDER_SPEED
	cow_velocity = Vector2.ZERO

	if to_player.length() < COW_FLEE_RADIUS:
		var flee_direction := (cow_position - seeker.position).normalized()
		if flee_direction == Vector2.ZERO:
			flee_direction = Vector2.RIGHT
		cow_target = _clamp_to_play_rect(cow_position + flee_direction * 240.0)
		speed = COW_FLEE_SPEED
	elif cow_position.distance_to(cow_target) < 18.0:
		cow_target = _random_play_position()

	var move := cow_target - cow_position
	if move.length() > 1.0:
		cow_velocity = move.normalized() * speed
		var step := minf(cow_velocity.length() * delta, move.length())
		cow_area.position += cow_velocity.normalized() * step

	cow_area.position = _clamp_to_play_rect(cow_area.position)
	if absf(cow_velocity.x) > 0.01:
		cow_sprite.flip_h = cow_velocity.x < 0.0


func _update_cow_animation(delta: float) -> void:
	if cow_velocity.length_squared() < 0.0001:
		cow_step_time = 0.0
		cow_sprite.frame = 0
		cow_sprite.position.y = 0.0
		cow_sprite.rotation = 0.0
		cow_sprite.scale = Vector2(COW_BASE_SCALE, COW_BASE_SCALE)
		return
	cow_step_time += delta
	cow_sprite.frame = int(cow_step_time * COW_ANIMATION_FPS) % 4
	var step_phase := sin(cow_step_time * COW_ANIMATION_FPS * TAU)
	cow_sprite.position.y = step_phase * 4.0
	cow_sprite.rotation = step_phase * 0.035
	cow_sprite.scale = Vector2(
		COW_BASE_SCALE * (1.0 + absf(step_phase) * 0.035),
		COW_BASE_SCALE * (1.0 - absf(step_phase) * 0.035)
	)


func _check_catch() -> void:
	if seeker.position.distance_to(cow_area.position) > CATCH_DISTANCE:
		return

	score += 1
	_post_audio("catch")
	score_value_label.text = str(score)
	_post_seek_event("godot:seek-score")
	_flash_status("抓到一头牛！")
	_respawn_cow(false)


func _respawn_cow(is_round_start: bool) -> void:
	var candidate := _random_play_position()
	var attempts := 0
	while candidate.distance_to(seeker.position) < 240.0 and attempts < 16:
		candidate = _random_play_position()
		attempts += 1

	cow_area.position = candidate
	cow_target = _random_play_position()

	if is_round_start:
		status_label.text = "点击草地开始追牛"


func _random_play_position() -> Vector2:
	return Vector2(
		rng.randf_range(play_rect.position.x, play_rect.end.x),
		rng.randf_range(play_rect.position.y, play_rect.end.y)
	)


func _clamp_to_play_rect(point: Vector2) -> Vector2:
	return Vector2(
		clampf(point.x, play_rect.position.x, play_rect.end.x),
		clampf(point.y, play_rect.position.y, play_rect.end.y)
	)


func _on_game_timer_timeout() -> void:
	if not is_round_active:
		return

	time_left -= 1
	timer_value_label.text = str(max(time_left, 0))

	if time_left > 0:
		return

	is_round_active = false
	player_direction = Vector2.ZERO
	game_timer.stop()
	result_overlay.visible = true
	result_title_label.text = "寻牛已毕"
	result_summary_label.text = "牛奔于野，心亦随之\n初见此心，方知其难驯"
	result_score_label.text = str(score)
	status_label.text = "本轮结束，点击重新开始再来一局"
	status_label.modulate.a = 1.0
	_post_seek_event("godot:seek-complete")


func _on_restart_button_pressed() -> void:
	_reset_round()


func _on_continue_button_pressed() -> void:
	_post_seek_event("godot:seek-continue")


func _on_cow_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not is_round_active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		player_direction = (cow_area.position - seeker.position).normalized()
		_flash_status("盯住它，别让它跑了！")


func _on_back_button_pressed() -> void:
	exit_requested.emit()


func _flash_status(message: String) -> void:
	status_label.text = message
	status_label.modulate.a = 1.0
	status_flash_left = STATUS_FLASH_SECONDS


func _post_seek_event(event_type: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval(
			"window.parent.postMessage({type:'%s', caught:%d}, '*')" % [event_type, score]
		)


func _post_audio(cue: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.parent.postMessage({type:'godot:audio', cue:'%s'}, '*')" % cue)


func _update_status_flash(delta: float) -> void:
	if status_flash_left <= 0.0:
		return

	status_flash_left = maxf(status_flash_left - delta, 0.0)
	var progress := status_flash_left / STATUS_FLASH_SECONDS
	status_label.modulate.a = 0.35 + progress * 0.65
