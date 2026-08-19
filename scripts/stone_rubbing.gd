extends Control

signal exit_requested
signal completed

const STAGE_CLEAN := "clean"
const STAGE_PAPER := "paper"
const STAGE_INK := "ink"
const STAGE_COMPLETE := "complete"

const CLEAN_THRESHOLD := 0.8
const INK_THRESHOLD := 0.85
const CLEAN_COLUMNS := 16
const CLEAN_ROWS := 10

const RevealMask = preload("res://scripts/rubbing_reveal_mask.gd")

const STAGE_COPY := {
	STAGE_CLEAN: ["壹  清尘", "拖动棕刷轻扫石刻表面，拂去浮尘，还原刻痕"],
	STAGE_PAPER: ["二  覆纸", "将宣纸轻覆于石刻之上，使纸面贴合纹理"],
	STAGE_INK: ["叁  拍拓", "选中拓包后点击纸面，让石刻纹样逐块显现"],
	STAGE_COMPLETE: ["拓印已成", "石上旧痕，经手而现"]
}

@onready var game_shell: Control = $GameShell
@onready var clean_frame: TextureRect = $GameShell/CleanFrame
@onready var paper_frame: TextureRect = $GameShell/PaperFrame
@onready var ink_frame: TextureRect = $GameShell/InkFrame
@onready var paper_target: Control = $GameShell/PaperTarget
@onready var final_artwork: TextureRect = $GameShell/PaperTarget/FinalArtwork
@onready var dust_overlay: Control = $GameShell/PaperTarget/DustOverlay
@onready var ink_reveal: Control = $GameShell/PaperTarget/InkReveal
@onready var brush_button: Button = $GameShell/ToolHotspots/BrushButton
@onready var paper_button: Button = $GameShell/ToolHotspots/PaperButton
@onready var ink_button: Button = $GameShell/ToolHotspots/InkButton
@onready var floating_tool: TextureRect = $GameShell/FloatingTool
@onready var step_progress: Control = $GameShell/StepProgress
@onready var step_eyebrow_label: Label = $GameShell/StepProgress/EyebrowLabel
@onready var step_label: Label = $GameShell/StepProgress/StepLabel
@onready var progress_fill: ColorRect = $GameShell/StepProgress/ProgressTrack/ProgressFill
@onready var progress_output_label: Label = $GameShell/StepProgress/OutputLabel
@onready var instruction_title_label: Label = $GameShell/InstructionBlock/TitleLabel
@onready var instruction_body_label: Label = $GameShell/InstructionBlock/BodyLabel
@onready var restart_button: Button = $GameShell/RestartButton

var brush_texture := preload("res://games/stone_rubbing/assets/tools/brush.png")
var paper_texture := preload("res://games/stone_rubbing/assets/tools/paper.png")
var ink_texture := preload("res://games/stone_rubbing/assets/tools/ink-pad.png")

var stage := STAGE_CLEAN
var clean_progress := 0.0
var ink_progress := 0.0
var paper_placed := false
var selected_tool := ""
var active_action := ""
var paper_dragging := false
var clean_cells: Dictionary = {}
var dust_tiles: Array[ColorRect] = []
var completion_announced := false
var reveal_mask: RefCounted


func _ready() -> void:
	reveal_mask = RevealMask.new(256, 176, 1208)
	var reveal_material := final_artwork.material as ShaderMaterial
	reveal_material.set_shader_parameter("reveal_mask", reveal_mask.get_texture())
	_build_dust_tiles()
	brush_button.button_down.connect(_on_brush_button_pressed)
	paper_button.button_down.connect(_on_paper_button_down)
	ink_button.button_down.connect(_on_ink_button_pressed)
	restart_button.pressed.connect(_reset_game)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reset_game()


func _process(_delta: float) -> void:
	if floating_tool.visible:
		floating_tool.global_position = get_global_mouse_position() - floating_tool.size * 0.5


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		exit_requested.emit()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_handle_press(event.position)
		else:
			_handle_release(event.position)
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_handle_drag(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_handle_press(event.position)
		else:
			_handle_release(event.position)
	elif event is InputEventScreenDrag:
		_handle_drag(event.position)


func _handle_press(global_position: Vector2) -> void:
	if stage == STAGE_CLEAN and selected_tool == STAGE_CLEAN:
		active_action = STAGE_CLEAN
		_show_floating_tool(brush_texture, Vector2(190, 285))
		_apply_coverage(STAGE_CLEAN, global_position)
	elif stage == STAGE_INK and selected_tool == STAGE_INK:
		active_action = STAGE_INK
		_show_floating_tool(ink_texture, Vector2(180, 180))
		_apply_ink_stamp(global_position)


func _handle_drag(global_position: Vector2) -> void:
	if paper_dragging:
		return
	if active_action == STAGE_CLEAN:
		_apply_coverage(STAGE_CLEAN, global_position)


func _handle_release(global_position: Vector2) -> void:
	if paper_dragging:
		paper_dragging = false
		floating_tool.visible = false
		if paper_target.get_global_rect().has_point(global_position):
			paper_placed = true
			stage = STAGE_INK
			selected_tool = ""
		_update_visuals()
		return

	active_action = ""
	floating_tool.visible = false


func _on_brush_button_pressed() -> void:
	if stage != STAGE_CLEAN:
		return
	_post_audio("brush")
	selected_tool = STAGE_CLEAN
	active_action = STAGE_CLEAN
	_show_floating_tool(brush_texture, Vector2(190, 285))
	_update_visuals()


func _on_paper_button_down() -> void:
	if stage != STAGE_PAPER or paper_placed:
		return
	_post_audio("paper")
	paper_dragging = true
	selected_tool = ""
	_show_floating_tool(paper_texture, Vector2(210, 280))
	_update_visuals()


func _on_ink_button_pressed() -> void:
	if stage != STAGE_INK:
		return
	selected_tool = STAGE_INK
	active_action = STAGE_INK
	_show_floating_tool(ink_texture, Vector2(180, 180))
	_update_visuals()


func _reset_game() -> void:
	stage = STAGE_CLEAN
	clean_progress = 0.0
	ink_progress = 0.0
	paper_placed = false
	selected_tool = ""
	active_action = ""
	paper_dragging = false
	clean_cells.clear()
	completion_announced = false
	if reveal_mask:
		reveal_mask.reset()
		var reveal_material := final_artwork.material as ShaderMaterial
		reveal_material.set_shader_parameter("reveal_mask", reveal_mask.get_texture())
		reveal_material.set_shader_parameter("completion_mix", 0.0)
	_reset_effect_tiles()
	floating_tool.visible = false
	_update_visuals()


func _apply_coverage(action: String, global_position: Vector2) -> void:
	if action != STAGE_CLEAN:
		return
	var rect := paper_target.get_global_rect()
	if not rect.has_point(global_position):
		return

	var point := (global_position - rect.position) / rect.size
	var columns := CLEAN_COLUMNS
	var rows := CLEAN_ROWS
	var cells := clean_cells

	var column := clampi(int(floor(point.x * columns)), 0, columns - 1)
	var row := clampi(int(floor(point.y * rows)), 0, rows - 1)
	var radius := 1
	for marked_row in range(row - radius, row + radius + 1):
		for marked_column in range(column - radius, column + radius + 1):
			if marked_row >= 0 and marked_row < rows and marked_column >= 0 and marked_column < columns:
				cells["%s:%s" % [marked_column, marked_row]] = true
				_hide_dust_tile(marked_column, marked_row)

	var coverage := float(cells.size()) / float(columns * rows)
	clean_progress = coverage
	if clean_progress >= CLEAN_THRESHOLD:
		clean_progress = 1.0
		stage = STAGE_PAPER
		selected_tool = ""
		active_action = ""
		floating_tool.visible = false

	_update_visuals()


func _apply_ink_stamp(global_position: Vector2) -> void:
	if stage != STAGE_INK or selected_tool != STAGE_INK:
		return
	var rect := paper_target.get_global_rect()
	if not rect.has_point(global_position):
		return
	ink_progress = reveal_mask.stamp(global_position - rect.position, rect.size)
	if reveal_mask.is_complete():
		stage = STAGE_COMPLETE
		selected_tool = ""
		active_action = ""
		floating_tool.visible = false
		_update_visuals()
		_complete_ink_reveal()
		return
	_update_visuals()


func _complete_ink_reveal() -> void:
	var reveal_material := final_artwork.material as ShaderMaterial
	var tween := create_tween()
	tween.tween_method(
		func(value: float) -> void: reveal_material.set_shader_parameter("completion_mix", value),
		0.0,
		1.0,
		0.35
	)
	await tween.finished
	call_deferred("_announce_completion")


func _announce_completion() -> void:
	if completion_announced:
		return
	completion_announced = true
	await get_tree().create_timer(1.2).timeout
	if stage != STAGE_COMPLETE:
		return
	completed.emit()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.parent.postMessage('godot:stone-rubbing-complete', '*')")


func _post_audio(cue: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.parent.postMessage({type:'godot:audio', cue:'%s'}, '*')" % cue)


func _update_visuals() -> void:
	clean_frame.visible = false
	dust_overlay.visible = stage == STAGE_CLEAN
	paper_frame.visible = paper_placed or stage == STAGE_INK or stage == STAGE_COMPLETE
	final_artwork.visible = stage == STAGE_INK or stage == STAGE_COMPLETE
	final_artwork.modulate.a = 1.0
	ink_reveal.visible = false
	ink_frame.visible = false
	instruction_title_label.text = STAGE_COPY[stage][0]
	instruction_body_label.text = STAGE_COPY[stage][1]
	_update_progress()
	_update_hotspots()


func _update_progress() -> void:
	step_progress.visible = stage != STAGE_COMPLETE
	var progress := 0.0
	match stage:
		STAGE_CLEAN:
			step_eyebrow_label.text = "当前步骤  壹"
			step_label.text = "清扫石面"
			progress = clampf(clean_progress / CLEAN_THRESHOLD, 0.0, 1.0)
			progress_output_label.text = "%d%%" % int(round(progress * 100.0))
		STAGE_PAPER:
			step_eyebrow_label.text = "当前步骤  二"
			step_label.text = "铺上宣纸"
			progress = 0.0
			progress_output_label.text = "进行中"
		STAGE_INK:
			step_eyebrow_label.text = "当前步骤  叁"
			step_label.text = "拓包上墨"
			progress = clampf(ink_progress / INK_THRESHOLD, 0.0, 1.0)
			progress_output_label.text = "%d%%" % int(round(progress * 100.0))
	progress_fill.scale.x = progress


func _update_hotspots() -> void:
	brush_button.disabled = stage != STAGE_CLEAN
	paper_button.disabled = stage != STAGE_PAPER or paper_placed
	ink_button.disabled = stage != STAGE_INK

	brush_button.modulate.a = 0.01
	paper_button.modulate.a = 0.01
	ink_button.modulate.a = 0.01


func _show_floating_tool(texture: Texture2D, size: Vector2) -> void:
	floating_tool.texture = texture
	floating_tool.custom_minimum_size = size
	floating_tool.size = size
	floating_tool.visible = true


func _build_dust_tiles() -> void:
	var tile_size := dust_overlay.size / Vector2(CLEAN_COLUMNS, CLEAN_ROWS)
	for row in range(CLEAN_ROWS):
		for column in range(CLEAN_COLUMNS):
			var tile := ColorRect.new()
			tile.position = Vector2(column, row) * tile_size
			tile.size = tile_size + Vector2.ONE
			tile.color = Color(0.12, 0.12, 0.12, 0.10)
			tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
			dust_overlay.add_child(tile)
			dust_tiles.append(tile)


func _reset_effect_tiles() -> void:
	for tile in dust_tiles:
		tile.visible = true


func _hide_dust_tile(column: int, row: int) -> void:
	var index := row * CLEAN_COLUMNS + column
	if index >= 0 and index < dust_tiles.size():
		dust_tiles[index].visible = false
