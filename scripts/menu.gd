extends Control

const SEEK_COW_SCENE := preload("res://games/seek_cow/seek_cow.tscn")
const STONE_RUBBING_SCENE := preload("res://games/stone_rubbing/stone_rubbing.tscn")
const BRIDGE_SCENE := preload("res://games/bridge/bridge.tscn")
const JUMP_SCENE := preload("res://games/jump/jump_game.tscn")

@onready var menu_layer: Control = $MenuLayer
@onready var subtitle_label: Label = $MenuLayer/MenuPanel/SubtitleLabel
@onready var game_root: Control = $GameRoot

var current_game: CanvasItem = null


func _ready() -> void:
	$MenuLayer/MenuPanel/SeekCowButton.pressed.connect(_on_seek_cow_button_pressed)
	$MenuLayer/MenuPanel/StoneRubbingButton.pressed.connect(_on_stone_rubbing_button_pressed)
	$MenuLayer/MenuPanel/BridgeButton.pressed.connect(_on_bridge_button_pressed)
	$MenuLayer/MenuPanel/QuitButton.pressed.connect(_on_quit_button_pressed)
	if OS.has_feature("web"):
		var requested_game := str(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('game') || ''"))
		if requested_game == "stone":
			_open_game(STONE_RUBBING_SCENE, "石刻拓印")
			return
		if requested_game == "seek":
			_open_game(SEEK_COW_SCENE, "初调｜寻牛")
			return
		if requested_game == "bridge":
			_open_game(BRIDGE_SCENE, "驯服｜过桥")
			return
		if requested_game == "jump":
			_open_game(JUMP_SCENE, "相忘｜横向跳跃")
			return
	_show_menu("在十二境里拣一境先行。")


func _on_seek_cow_button_pressed() -> void:
	_open_game(SEEK_COW_SCENE, "第一境｜初调｜寻牛")


func _on_stone_rubbing_button_pressed() -> void:
	_open_game(STONE_RUBBING_SCENE, "第二境｜拓迹寻心｜石刻拓印")


func _on_bridge_button_pressed() -> void:
	_open_game(BRIDGE_SCENE, "第三境｜驯服｜过桥")


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _open_game(scene: PackedScene, subtitle: String) -> void:
	if current_game:
		current_game.queue_free()
		current_game = null

	var instance := scene.instantiate()
	if not instance is CanvasItem:
		push_error("Game scene must inherit CanvasItem: %s" % subtitle)
		return

	current_game = instance
	game_root.add_child(current_game)
	menu_layer.visible = false

	if current_game.has_signal("exit_requested"):
		current_game.connect("exit_requested", Callable(self, "_on_game_exit_requested"))

	subtitle_label.text = subtitle


func _on_game_exit_requested() -> void:
	if current_game:
		current_game.queue_free()
		current_game = null
	_show_menu("在十二境里拣一境先行。")


func _show_menu(message: String) -> void:
	menu_layer.visible = true
	subtitle_label.text = message
