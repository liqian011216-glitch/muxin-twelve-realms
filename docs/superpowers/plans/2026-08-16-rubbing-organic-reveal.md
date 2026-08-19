# 拓印柔边不规则显影 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将拓印第 3 步从 6×4 方块显影改为触点中心的柔边不规则墨迹，并在真实遮罩覆盖率达到 85% 时自动补全。

**Architecture:** 新建独立的 `RubbingRevealMask`，负责动态灰度遮罩、确定性不规则墨斑、覆盖率和重置；`stone_rubbing.gd` 只负责输入、阶段切换和把遮罩纹理传给 CanvasItem Shader。最终作品通过 Shader 采样遮罩显影，完成时用 `completion_mix` 从当前遮罩柔和补至全图。

**Tech Stack:** Godot 4.7.1、GDScript、CanvasItem Shader、Image/ImageTexture、Godot Web 导出、Node.js 合约测试、浏览器截图验收

## Global Constraints

- 只修改拓印第 3 步的显影效果与完成判定。
- 保留第 1 步“清扫石面”、第 2 步“铺上宣纸”和现有美术。
- 保留“先选择拓包，再点击宣纸”的操作，不改为连续拖动。
- 每次墨迹必须围绕玩家触点，不得随机偏移到其他区域。
- 覆盖率达到 `0.85` 后自动补全；没有倒计时，没有失败。
- 完成后保留现有约 `1.2` 秒停留和单次完成信号。
- 鼠标点击和手机触控都必须可用。
- 不修改寻牛、独木桥、莲花跳跃或正式十二境。

---

## File Structure

- Create: `scripts/rubbing_reveal_mask.gd` — 生成柔边不规则遮罩、计算覆盖率、提供重置和确定性随机。
- Create: `tests/rubbing_reveal_mask_test.gd` — 直接运行真实遮罩实现，验证非矩形、触点定位、85% 完成和重置。
- Modify: `games/stone_rubbing/stone_rubbing.tscn` — 为最终拓印图配置遮罩 ShaderMaterial，移除旧矩形显影容器依赖。
- Modify: `scripts/stone_rubbing.gd` — 接入遮罩、手机触控、完成补全 Tween，删除 6×4 图块逻辑。
- Create: `tests/stone_rubbing_organic_reveal_test.gd` — 实例化真实拓印场景，验证输入到显影和完成信号前的状态流。
- Modify generated: `web/.worktrees/muxin-cover-step/public/games/godot/index.html`
- Modify generated: `web/.worktrees/muxin-cover-step/public/games/godot/index.pck`

---

### Task 1: 建立可测试的不规则显影遮罩

**Files:**
- Create: `scripts/rubbing_reveal_mask.gd`
- Create: `tests/rubbing_reveal_mask_test.gd`

**Interfaces:**
- Consumes: Godot `Vector2`、`Image`、`ImageTexture`、`RandomNumberGenerator`。
- Produces: `class_name RubbingRevealMask`；`reset() -> void`；`stamp(local_point: Vector2, target_size: Vector2) -> float`；`get_coverage() -> float`；`is_complete() -> bool`；`get_texture() -> ImageTexture`；`get_image() -> Image`。

- [ ] **Step 1: 写遮罩行为失败测试**

创建 `tests/rubbing_reveal_mask_test.gd`：

```gdscript
extends SceneTree

const RevealMask = preload("res://scripts/rubbing_reveal_mask.gd")

func _init() -> void:
	var reveal = RevealMask.new(256, 176, 1208)
	assert(is_equal_approx(reveal.get_coverage(), 0.0))

	var before := reveal.get_image().duplicate()
	var coverage := reveal.stamp(Vector2(484, 336), Vector2(968, 672))
	assert(coverage > 0.0)
	assert(reveal.get_image().get_pixel(128, 88).r > 0.1)
	assert(reveal.get_image().get_pixel(0, 0).r == 0.0)

	var changed := 0
	var transparent_inside_bounds := 0
	for y in range(50, 127):
		for x in range(75, 182):
			if reveal.get_image().get_pixel(x, y).r > 0.1:
				changed += 1
			else:
				transparent_inside_bounds += 1
	assert(changed > 0)
	assert(transparent_inside_bounds > 0, "stamp must not fill a rectangle")

	var outside_coverage := reveal.stamp(Vector2(-20, 30), Vector2(968, 672))
	assert(is_equal_approx(outside_coverage, coverage))

	for row in range(9):
		for column in range(13):
			reveal.stamp(Vector2(40 + column * 74, 35 + row * 74), Vector2(968, 672))
	assert(reveal.get_coverage() >= 0.85)
	assert(reveal.is_complete())

	reveal.reset()
	assert(is_equal_approx(reveal.get_coverage(), 0.0))
	assert(reveal.get_image().get_pixel(128, 88).r == 0.0)
	quit(0)
```

- [ ] **Step 2: 运行测试并确认 RED**

Run:

```bash
/Users/yizhixiaojinli/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/yizhixiaojinli/牧心十二境 --script res://tests/rubbing_reveal_mask_test.gd
```

Expected: FAIL，因为 `res://scripts/rubbing_reveal_mask.gd` 尚不存在。

- [ ] **Step 3: 实现最小遮罩类**

创建 `scripts/rubbing_reveal_mask.gd`。固定 `COMPLETION_THRESHOLD := 0.85`、`VISIBLE_THRESHOLD := 0.18`。`stamp()` 先把触点换算到 256×176 遮罩坐标，再叠加 4 个椭圆柔边墨斑：主半径 x 为 30–42、y 为 22–34；子墨斑中心只允许在主中心半径 8 像素内变化。每个候选像素用旋转椭圆距离计算 `smoothstep` 衰减，并乘以 `0.86–1.0` 的确定性颗粒；用 `max(old, new)` 写入遮罩。

核心结构必须是：

```gdscript
class_name RubbingRevealMask
extends RefCounted

const COMPLETION_THRESHOLD := 0.85
const VISIBLE_THRESHOLD := 0.18

var _image: Image
var _texture: ImageTexture
var _rng := RandomNumberGenerator.new()
var _coverage := 0.0

func _init(width := 256, height := 176, seed := 1208) -> void:
	_image = Image.create(width, height, false, Image.FORMAT_RF)
	_texture = ImageTexture.create_from_image(_image)
	_rng.seed = seed

func stamp(local_point: Vector2, target_size: Vector2) -> float:
	if local_point.x < 0.0 or local_point.y < 0.0 or local_point.x > target_size.x or local_point.y > target_size.y:
		return _coverage
	var center := local_point / target_size * Vector2(_image.get_width(), _image.get_height())
	for lobe in range(4):
		_stamp_lobe(center, lobe == 0)
	_texture.update(_image)
	_recalculate_coverage()
	return _coverage

func is_complete() -> bool:
	return _coverage >= COMPLETION_THRESHOLD
```

`reset()` 必须清空图像、将随机种子恢复为 `1208` 并更新同一个 `ImageTexture`，不能换掉外部已经绑定的纹理对象。

- [ ] **Step 4: 运行遮罩测试并确认 GREEN**

Run: 与 Step 2 相同。  
Expected: PASS，进程退出码为 0。

- [ ] **Step 5: 提交遮罩模型与测试**

```bash
git add scripts/rubbing_reveal_mask.gd tests/rubbing_reveal_mask_test.gd
git commit -m "feat: add organic rubbing reveal mask"
```

---

### Task 2: 将真实拓印场景接入遮罩和 85% 完成过渡

**Files:**
- Modify: `games/stone_rubbing/stone_rubbing.tscn`
- Modify: `scripts/stone_rubbing.gd`
- Create: `tests/stone_rubbing_organic_reveal_test.gd`

**Interfaces:**
- Consumes: `RubbingRevealMask` 的 `stamp()`、`get_texture()`、`get_coverage()`、`is_complete()`、`reset()`。
- Produces: `stone_rubbing.gd` 中的 `_apply_ink_stamp(global_position: Vector2) -> void`、`_complete_ink_reveal() -> void`；Shader 参数 `reveal_mask: sampler2D` 与 `completion_mix: float`。

- [ ] **Step 1: 写场景集成失败测试**

创建 `tests/stone_rubbing_organic_reveal_test.gd`：

```gdscript
extends SceneTree

const Scene = preload("res://games/stone_rubbing/stone_rubbing.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = Scene.instantiate()
	root.add_child(game)
	await process_frame
	game.stage = game.STAGE_INK
	game.paper_placed = true
	game.selected_tool = game.STAGE_INK
	game._update_visuals()

	var target_rect: Rect2 = game.paper_target.get_global_rect()
	game._apply_ink_stamp(target_rect.position + target_rect.size * 0.5)
	assert(game.ink_progress > 0.0)
	assert(game.final_artwork.visible)
	assert(game.final_artwork.material.get_shader_parameter("reveal_mask") != null)
	assert(game.stage == game.STAGE_INK)

	for row in range(9):
		for column in range(13):
			var point := target_rect.position + Vector2(40 + column * 74, 35 + row * 74)
			game._apply_ink_stamp(point)
			if game.stage == game.STAGE_COMPLETE:
				break
		if game.stage == game.STAGE_COMPLETE:
			break
	assert(game.stage == game.STAGE_COMPLETE)
	assert(game.ink_progress >= 0.85)
	quit(0)
```

- [ ] **Step 2: 运行集成测试并确认 RED**

Run:

```bash
/Users/yizhixiaojinli/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/yizhixiaojinli/牧心十二境 --script res://tests/stone_rubbing_organic_reveal_test.gd
```

Expected: FAIL，因为 `_apply_ink_stamp()` 和遮罩 Shader 参数尚不存在。

- [ ] **Step 3: 在场景中加入遮罩 ShaderMaterial**

在 `stone_rubbing.tscn` 新增 CanvasItem Shader：

```glsl
shader_type canvas_item;

uniform sampler2D reveal_mask : filter_linear;
uniform float completion_mix : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float mask_value = texture(reveal_mask, UV).r;
	float reveal = max(mask_value, completion_mix);
	COLOR = vec4(source.rgb, source.a * smoothstep(0.08, 0.42, reveal));
}
```

把 ShaderMaterial 绑定到 `GameShell/PaperTarget/FinalArtwork`。保留原最终图片纹理和节点尺寸。

- [ ] **Step 4: 用遮罩替换 6×4 图块逻辑**

在 `stone_rubbing.gd` 中：

- preload `res://scripts/rubbing_reveal_mask.gd`；
- 删除 `INK_COLUMNS`、`INK_ROWS`、`ink_cells`、`ink_tiles`、`_build_ink_tiles()`、`_show_ink_tile()`；
- `_ready()` 创建 `reveal_mask := RubbingRevealMask.new(256, 176, 1208)` 并绑定 `reveal_mask.get_texture()`；
- `STAGE_INK` 的点击调用 `_apply_ink_stamp()`；
- `_apply_ink_stamp()` 只接受宣纸区域内的坐标，更新 `ink_progress` 和 Shader 遮罩；
- `reveal_mask.is_complete()` 时设置 `stage = STAGE_COMPLETE`、停止输入，并调用 `_complete_ink_reveal()`；
- `_complete_ink_reveal()` 用 `create_tween().tween_method()` 在 `0.35` 秒内把 `completion_mix` 从 `0.0` 变为 `1.0`，然后 `call_deferred("_announce_completion")`；
- `_reset_game()` 调用 `reveal_mask.reset()` 并把 `completion_mix` 设回 `0.0`；
- `final_artwork.visible` 在 `STAGE_INK` 和 `STAGE_COMPLETE` 都为 `true`。

手机输入显式加入：

```gdscript
elif event is InputEventScreenTouch:
	if event.pressed:
		_handle_press(event.position)
	else:
		_handle_release(event.position)
elif event is InputEventScreenDrag:
	_handle_drag(event.position)
```

- [ ] **Step 5: 运行两个 Godot 测试并确认 GREEN**

Run:

```bash
/Users/yizhixiaojinli/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/yizhixiaojinli/牧心十二境 --script res://tests/rubbing_reveal_mask_test.gd
/Users/yizhixiaojinli/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/yizhixiaojinli/牧心十二境 --script res://tests/stone_rubbing_organic_reveal_test.gd
node --test tests/*.test.mjs
```

Expected: 两个 Godot 测试退出码 0；现有 Node 游戏测试全部通过。

- [ ] **Step 6: 提交场景接入**

```bash
git add games/stone_rubbing/stone_rubbing.tscn scripts/stone_rubbing.gd tests/stone_rubbing_organic_reveal_test.gd
git commit -m "feat: reveal rubbing with organic ink stamps"
```

---

### Task 3: Web 导出、真实交互验收和用户检查点

**Files:**
- Modify generated: `web/.worktrees/muxin-cover-step/public/games/godot/index.html`
- Modify generated: `web/.worktrees/muxin-cover-step/public/games/godot/index.pck`
- Create audit images under `.audit/step-reviews/`

**Interfaces:**
- Consumes: Task 2 完成的 Godot 场景和 `?game=stone` Web 入口。
- Produces: 当前本地预览可加载的新拓印包，以及第 3 步多次拍拓后的审查截图。

- [ ] **Step 1: 导出到当前批准的 Web 工作树**

Run:

```bash
/Users/yizhixiaojinli/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/yizhixiaojinli/牧心十二境 --export-release Web /Users/yizhixiaojinli/牧心十二境/web/.worktrees/muxin-cover-step/public/games/godot/index.html
```

Expected: Godot 输出 `[ DONE ] savepack`，`index.pck` 修改时间更新。

- [ ] **Step 2: 运行完整网页验证**

Run:

```bash
cd /Users/yizhixiaojinli/牧心十二境/web/.worktrees/muxin-cover-step
npm test
git diff --check
```

Expected: Web 构建成功，全部测试通过，`git diff --check` 无输出。

- [ ] **Step 3: 浏览器真实验收第 3 步**

打开：

```text
http://localhost:3000/games/godot/?game=stone&organic=1
```

实际完成清扫和覆纸后，执行以下检查：

1. 点击拓包；
2. 在宣纸中央单击一次，确认出现柔边非矩形墨迹；
3. 在相邻位置单击，确认墨迹自然重叠且无方块接缝；
4. 在宣纸外点击，确认进度不增加；
5. 持续拍拓至 85%，确认自动柔和补全；
6. 确认完成信号只发送一次。

保存至少三张截图：

- `.audit/step-reviews/06-rubbing-organic-first-stamp.jpg`
- `.audit/step-reviews/06-rubbing-organic-overlap.jpg`
- `.audit/step-reviews/06-rubbing-organic-complete.jpg`

- [ ] **Step 4: 提交 Web 导出包**

```bash
cd /Users/yizhixiaojinli/牧心十二境/web/.worktrees/muxin-cover-step
git add public/games/godot/index.html public/games/godot/index.pck
git commit -m "feat: export organic rubbing reveal"
```

- [ ] **Step 5: 向用户展示检查点**

只展示第 3 步的三张审查图和本地链接。用户确认前不继续修改拓印完成后的正式十二境，也不接入其他小游戏。

