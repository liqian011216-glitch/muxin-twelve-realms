extends Node2D

signal exit_requested

const FALL_ANGLE := 0.86
const WALK_SPEED := 0.065
const FALL_RESTART_DELAY := 0.7
const CLICK_MIN_FORCE := 0.16
const CLICK_MAX_FORCE := 0.52
const BRIDGE_CENTER_X := 960.0
const BRIDGE_LEFT_X := 890.0
const BRIDGE_RIGHT_X := 1030.0
const WALK_TEXTURE := preload("res://games/bridge/assets/character/walk_sheet_v2.png")
const FALL_TEXTURE := preload("res://games/bridge/assets/character/fall_sheet_v2.png")

@onready var bridge_background: Sprite2D = $BackgroundLayer/PlayfieldBackground
@onready var bridge_frame: Sprite2D = $BackgroundLayer/PlayfieldFrame
@onready var character: Sprite2D = $Actors/Seeker
@onready var game_timer: Timer = $GameTimer
@onready var progress_value_label: Label = $HUD/ScorePanel/ScoreValueLabel
@onready var progress_unit_label: Label = $HUD/ScorePanel/ScoreUnitLabel
@onready var timer_value_label: Label = $HUD/TimerValueLabel
@onready var goal_body_label: Label = $HUD/GoalBodyLabel
@onready var status_label: Label = $HUD/StatusLabel
@onready var result_overlay: Control = $Overlays/ResultOverlay
@onready var result_title_label: Label = $Overlays/ResultOverlay/ResultPanel/ResultTitleLabel
@onready var result_summary_label: Label = $Overlays/ResultOverlay/ResultPanel/ResultSummaryLabel
@onready var result_score_label: Label = $Overlays/ResultOverlay/ResultPanel/ResultScoreValueLabel
@onready var result_continue_button: Button = $Overlays/ResultOverlay/ResultPanel/ContinueButton
@onready var back_button: Button = $HUD/BackButton

var elapsed_seconds := 0.0
var progress := 0.0
var player_lean := 0.0
var cow_sway := 0.0
var bridge_angle := 0.0
var fall_restart_left := 0.0
var is_round_active := true
var is_falling := false
var bridge_start_y := 804.0
var bridge_end_y := 300.0
var rng := RandomNumberGenerator.new()
var sway_time := 0.0
var sway_target := 0.0
var sway_change_left := 0.0
var walk_frame_time := 0.0
var fall_elapsed := 0.0


func _ready() -> void:
	rng.randomize()
	bridge_start_y = character.position.y
	game_timer.wait_time = 1.0
	game_timer.timeout.connect(_on_game_timer_timeout)
	result_continue_button.pressed.connect(_on_continue_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)
	goal_body_label.text = "人物会随机向左或向右倾斜，点击左右两侧修正重心。\n保持平衡，带着牛走过独木桥。"
	progress_unit_label.text = "%"
	$HUD/TimerUnitLabel.text = "秒"
	result_overlay.visible = false
	$Actors/Cow.visible = false
	_reset_round()


func _process(delta: float) -> void:
	if not is_round_active:
		return

	if is_falling:
		fall_elapsed += delta
		character.frame = mini(int(fall_elapsed / (FALL_RESTART_DELAY / 4.0)), 3)
		fall_restart_left -= delta
		if fall_restart_left <= 0.0:
			_reset_round(false)
		return

	character.position.x = BRIDGE_CENTER_X
	walk_frame_time += delta
	character.frame = int(walk_frame_time * 4.0) % 4

	sway_time += delta
	sway_change_left -= delta
	if sway_change_left <= 0.0:
		sway_target = rng.randf_range(-0.55, 0.55)
		sway_change_left = rng.randf_range(0.9, 1.8)
	cow_sway = move_toward(cow_sway, sway_target, delta * rng.randf_range(0.35, 0.9))
	bridge_angle = clampf(cow_sway + player_lean, -1.0, 1.0)

	# 画面中人物素材本身就是“牛背着牧人”，整组一起倾斜。
	var target_rotation := bridge_angle * 0.62
	character.rotation = lerp_angle(
		character.rotation,
		target_rotation,
		1.0 - exp(-6.0 * delta)
	)

	var balance: float = 1.0 - minf(absf(bridge_angle), 1.0)
	if balance > 0.25:
		progress = minf(progress + WALK_SPEED * delta * (0.45 + balance * 0.55), 1.0)
	else:
		progress = maxf(progress - WALK_SPEED * delta * 0.18, 0.0)
	character.position.y = lerpf(bridge_start_y, bridge_end_y, progress)
	progress_value_label.text = str(int(progress * 100.0))

	if absf(bridge_angle) >= FALL_ANGLE:
		_fall()
	elif character.position.x <= BRIDGE_LEFT_X or character.position.x >= BRIDGE_RIGHT_X:
		_fall()
	elif progress >= 1.0:
		_complete()
	elif bridge_angle < -0.12:
		status_label.text = "向左偏了，点击右侧修正"
	elif bridge_angle > 0.12:
		status_label.text = "向右偏了，点击左侧修正"
	else:
		status_label.text = "平衡"


func _input(event: InputEvent) -> void:
	if not is_round_active or is_falling:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_apply_balance_click(event.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_LEFT or event.keycode == KEY_A:
			player_lean -= CLICK_MAX_FORCE
		elif event.keycode == KEY_RIGHT or event.keycode == KEY_D:
			player_lean += CLICK_MAX_FORCE


func _apply_balance_click(click_position: Vector2) -> void:
	if click_position.x < BRIDGE_CENTER_X:
		player_lean = clampf(player_lean - CLICK_MAX_FORCE, -1.0, 1.0)
		status_label.text = "向左修正重心"
	else:
		player_lean = clampf(player_lean + CLICK_MAX_FORCE, -1.0, 1.0)
		status_label.text = "向右修正重心"


func _reset_round(reset_timer: bool = true) -> void:
	if reset_timer:
		elapsed_seconds = 0.0
	progress = 0.0
	player_lean = 0.0
	cow_sway = 0.0
	bridge_angle = 0.0
	sway_time = rng.randf_range(0.0, TAU)
	sway_target = 0.0
	sway_change_left = rng.randf_range(0.9, 1.5)
	walk_frame_time = 0.0
	fall_elapsed = 0.0
	fall_restart_left = 0.0
	is_falling = false
	is_round_active = true
	character.visible = true
	character.texture = WALK_TEXTURE
	character.hframes = 4
	character.vframes = 1
	character.frame = 0
	character.modulate = Color.WHITE
	character.position = Vector2(960.0, bridge_start_y)
	character.rotation = 0.0
	progress_value_label.text = "0"
	if reset_timer:
		timer_value_label.text = "0"
	status_label.text = "点击左右两侧，保持平衡"
	result_overlay.visible = false
	game_timer.start()


func _on_game_timer_timeout() -> void:
	if is_round_active:
		elapsed_seconds += 1.0
		timer_value_label.text = str(int(elapsed_seconds))


func _fall() -> void:
	_post_audio("fall")
	is_falling = true
	fall_restart_left = FALL_RESTART_DELAY
	fall_elapsed = 0.0
	character.texture = FALL_TEXTURE
	character.hframes = 4
	character.vframes = 1
	character.frame = 0
	var fall_direction := signf(bridge_angle)
	if is_zero_approx(fall_direction):
		fall_direction = 1.0
	var fall_tween := create_tween()
	fall_tween.set_parallel(true)
	fall_tween.tween_property(character, "rotation", fall_direction * 1.25, FALL_RESTART_DELAY).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall_tween.tween_property(character, "modulate:a", 0.0, FALL_RESTART_DELAY).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	progress = 0.0
	status_label.text = "落水了，从桥头重新开始"


func _complete() -> void:
	is_round_active = false
	game_timer.stop()
	result_overlay.visible = true
	result_title_label.text = "过桥已毕"
	result_summary_label.text = "人与牛同心，终于渡过此桥\n稳住重心，便能行远"
	result_score_label.text = str(int(elapsed_seconds))
	status_label.text = "成功过桥！"


func _on_continue_button_pressed() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval(
			"window.parent.postMessage({type:'godot:bridge-complete', seconds:%d}, '*')" % int(elapsed_seconds)
		)
	else:
		exit_requested.emit()


func _on_back_button_pressed() -> void:
	exit_requested.emit()


func _post_audio(cue: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.parent.postMessage({type:'godot:audio', cue:'%s'}, '*')" % cue)
