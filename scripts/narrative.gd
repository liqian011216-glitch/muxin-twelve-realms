extends Control

## 牧心十二境｜离线 AI 叙事原型
## 以心性向量驱动分支：执着、迟缓、观照。每次选择都会改变 NPC 的回应与结局。

const FONT_PATH := "res://Fonts/思印宋1.00/SiyinSong-Regular.ttf"
const STAGES := [
	["第一阶段｜寻牛", "1 未牧", "牛从苔痕深处挣脱，牧童第一次听见自己的心声。"],
	["第一阶段｜寻牛", "2 初调", "追逐不是为了占有，而是为了看清：是谁在奔逃？"],
	["第一阶段｜寻牛", "3 受制", "牛绳落在手里，心却还没有被安放。"],
	["第二阶段｜驯牛", "4 回首", "回头看时，牛已不再只是牛。"],
	["第二阶段｜驯牛", "5 驯伏", "独木桥只容一人宽，人与牛要学会共享重心。"],
	["第二阶段｜驯牛", "6 无碍", "不再用力拉扯，脚下的路便慢慢显出来。"],
	["第三阶段｜忘牛", "7 任运", "风把缰绳吹成一条线，去处不必预先命名。"],
	["第三阶段｜忘牛", "8 相忘", "横向跃过莲叶，跃过的也是分别心。"],
	["第三阶段｜忘牛", "9 独照", "水面只剩一轮月，照见来时，也照见未曾离开。"]
]

const CHOICES := [
	["追上它，先把缰绳握紧。", Vector3(2, 0, -1), "牧童：我听见你了——急促的脚步，也是一种回答。"],
	["停下来，听它为什么奔跑。", Vector3(-1, 2, 2), "牧童：原来它不是要逃，只是不愿被忘记。"],
	["沿着旧碑的拓痕，慢慢走。", Vector3(0, 1, 3), "牧童：拓下来的不是图案，是你此刻留下的重量。"]
]

var stage_index := 0
var choice_count := 0
var spirit := Vector3(0, 0, 0) # x=执，y=慢，z=观
var rng := RandomNumberGenerator.new()
var title_label: Label
var stage_label: Label
var scene_label: Label
var npc_label: Label
var memory_label: Label
var progress_label: Label
var choice_box: VBoxContainer
var continue_button: Button
var ending_panel: Panel

func _ready() -> void:
	rng.seed = 1208
	_build_ui()
	_refresh_scene()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#efe6d0"))
	draw_circle(Vector2(size.x - 190, 160), 105.0, Color("#d8b56a", 0.32))
	draw_arc(Vector2(size.x - 190, 160), 138.0, 0.0, TAU, 64, Color("#9e6d3d", 0.25), 2.0)
	# 简化的水墨山形，让作品即使缺少外部背景也有完整舞台。
	var mountain := PackedVector2Array([Vector2(0, 720), Vector2(250, 480), Vector2(480, 650), Vector2(720, 420), Vector2(980, 700), Vector2(1250, 500), Vector2(1540, 680), Vector2(1920, 470), Vector2(1920, 1080), Vector2(0, 1080)])
	draw_colored_polygon(mountain, Color("#42616a", 0.16))
	draw_line(Vector2(0, 760), Vector2(size.x, 760), Color("#9e6d3d", 0.25), 2.0)
	for i in range(7):
		var x := 210.0 + i * 245.0
		draw_arc(Vector2(x, 780), 55.0 + i * 5.0, PI, TAU, 24, Color("#42616a", 0.20), 2.0)

func _build_ui() -> void:
	var font := load(FONT_PATH)
	title_label = _label("牧心十二境", 64, Color("#2f5962"))
	title_label.position = Vector2(92, 54)
	add_child(title_label)
	var sub := _label("AI 互动叙事｜拓印风格转换", 22, Color("#a24b25"))
	sub.position = Vector2(100, 132)
	add_child(sub)
	stage_label = _label("", 23, Color("#a24b25"))
	stage_label.position = Vector2(100, 220)
	add_child(stage_label)
	scene_label = _label("", 42, Color("#2f5962"))
	scene_label.position = Vector2(96, 262)
	scene_label.size = Vector2(850, 76)
	add_child(scene_label)

	var story := _label("", 27, Color("#443c32"))
	story.name = "StoryLabel"
	story.position = Vector2(100, 350)
	story.size = Vector2(850, 130)
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(story)

	var npc_title := _label("AI 牧童｜记忆回应", 21, Color("#a24b25"))
	npc_title.position = Vector2(1110, 270)
	add_child(npc_title)
	npc_label = _label("", 26, Color("#443c32"))
	npc_label.position = Vector2(1110, 320)
	npc_label.size = Vector2(630, 160)
	npc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(npc_label)
	memory_label = _label("", 20, Color("#42616a"))
	memory_label.position = Vector2(1110, 505)
	memory_label.size = Vector2(620, 120)
	memory_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(memory_label)

	var prompt := _label("你会如何回应？", 25, Color("#a24b25"))
	prompt.position = Vector2(100, 545)
	add_child(prompt)
	choice_box = VBoxContainer.new()
	choice_box.position = Vector2(100, 590)
	choice_box.size = Vector2(850, 240)
	choice_box.add_theme_constant_override("separation", 12)
	add_child(choice_box)
	progress_label = _label("", 20, Color("#42616a"))
	progress_label.position = Vector2(1110, 700)
	add_child(progress_label)
	continue_button = _button("继续入境 →", 24)
	continue_button.position = Vector2(1110, 790)
	continue_button.size = Vector2(340, 74)
	continue_button.pressed.connect(_next_stage)
	add_child(continue_button)
	var back := _button("返回主菜单", 20)
	back.position = Vector2(100, 950)
	back.size = Vector2(190, 58)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://main.tscn"))
	add_child(back)

func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_override("font", load(FONT_PATH))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text_value: String, font_size: int) -> Button:
	var button := Button.new()
	button.text = text_value
	button.add_theme_font_override("font", load(FONT_PATH))
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color("#2f5962"))
	return button

func _refresh_scene() -> void:
	var stage: Array = STAGES[stage_index]
	stage_label.text = "%s  ｜   %02d / 09" % [stage[0], stage_index + 1]
	scene_label.text = stage[1]
	$StoryLabel.text = stage[2]
	npc_label.text = _npc_line()
	memory_label.text = "心性向量\n执 %02d   慢 %02d   观 %02d\n\n“每一次选择，都会被它记住。”" % [int(spirit.x + 5), int(spirit.y + 5), int(spirit.z + 5)]
	progress_label.text = "已走过 %d 境｜记忆片段 %d 条" % [stage_index, choice_count]
	continue_button.visible = choice_count > 0
	for child in choice_box.get_children(): child.queue_free()
	if choice_count == 0 or stage_index < 8:
		for i in range(3):
			var button := _button(CHOICES[i][0], 23)
			button.custom_minimum_size = Vector2(820, 62)
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.pressed.connect(_choose.bind(i))
			choice_box.add_child(button)
	else:
		var finish := _button("收下这段故事，查看你的心迹", 23)
		finish.custom_minimum_size = Vector2(820, 62)
		finish.pressed.connect(_show_ending)
		choice_box.add_child(finish)

func _choose(index: int) -> void:
	spirit += CHOICES[index][1]
	choice_count += 1
	npc_label.text = CHOICES[index][2]
	continue_button.visible = true
	progress_label.text = "已走过 %d 境｜记忆片段 %d 条｜NPC 已更新回应" % [stage_index, choice_count]
	for child in choice_box.get_children(): child.disabled = true

func _next_stage() -> void:
	if stage_index < 8:
		stage_index += 1
		_refresh_scene()
	else:
		_show_ending()

func _npc_line() -> String:
	if choice_count == 0: return "牧童：你从哪一处来？\n牛认得路，心却未必。"
	if spirit.z >= spirit.x and spirit.z >= spirit.y: return "牧童：你越来越会看见细处。\n这条路，也许不必急着抵达。"
	if spirit.x > spirit.y: return "牧童：缰绳在手，方向在心。\n只是别把握紧，误认成拥有。"
	return "牧童：慢一点，风会替你说完。\n我把你的沉默也记下了。"

func _show_ending() -> void:
	for child in choice_box.get_children(): child.queue_free()
	var ending := "执着之心" if spirit.x > spirit.z + 2 else ("观照之心" if spirit.z >= spirit.x else "和缓之心")
	var end_text := "你的九次选择，留下了「%s」。\n牛没有消失，只是从被追逐的对象，变成了同行者。\n\n这一次生成的故事线：%s。" % [ending, _ending_hint(ending)]
	npc_label.text = "牧童：我不能替你命名答案。\n但我能把你走过的路，拓印下来。"
	memory_label.text = end_text
	progress_label.text = "故事完成｜可重新进入，生成另一条心迹"
	continue_button.text = "重新开始"
	continue_button.visible = true
	continue_button.pressed.disconnect(_next_stage)
	continue_button.pressed.connect(_restart)

func _ending_hint(ending: String) -> String:
	if ending == "观照之心": return "由拓痕而入，由相忘而明"
	if ending == "和缓之心": return "在独木桥上，与不确定共处"
	return "从追逐开始，学会把力量收回自己"

func _restart() -> void:
	stage_index = 0
	choice_count = 0
	spirit = Vector3.ZERO
	continue_button.pressed.disconnect(_restart)
	continue_button.pressed.connect(_next_stage)
	_refresh_scene()
