# 独木桥点击平衡交互 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将独木桥改为点击左右区域修正重心，并修复计时、自动通关和失败反馈问题。

**Architecture:** 保留现有 `scripts/bridge.gd` 的随机摆动和桥上移动模型，将鼠标输入从横向拖动改为一次点击产生一次有限的 `player_lean` 修正。每轮开始统一清空计时、进度、倾斜和失败状态；进度仅在平衡状态良好时增长。

**Tech Stack:** Godot 4.7 GDScript、Godot Web export、Node.js `node:test` 静态回归测试。

## Global Constraints

- 不使用鼠标按住或拖拽。
- 点击桥面左侧向左修正，点击桥面右侧向右修正。
- 键盘左右键保留为桌面端备用操作。
- 每次重新开始计时从 0 秒开始。
- 不点击时不能稳定自动通关。
- 失败提示必须可见，结算按钮使用“再走一次”。

---

### Task 1: 添加独木桥交互回归检查

**Files:**
- Create: `tests/bridge_click_control.test.mjs`
- Test: `tests/bridge_click_control.test.mjs`

**Interfaces:**
- Consumes: `scripts/bridge.gd` and `games/bridge/bridge.tscn` as text fixtures.
- Produces: static contracts for input copy, click-based correction, timer reset, gated progress, and restart button copy.

- [ ] **Step 1: Write the failing test**

```js
test('独木桥使用左右点击修正而不是拖拽', () => {
  assert.match(script, /InputEventMouseButton/);
  assert.match(script, /player_lean -= CLICK_MAX_FORCE/);
  assert.match(script, /player_lean \+= CLICK_MAX_FORCE/);
  assert.doesNotMatch(script, /is_pulling/);
});

test('独木桥每轮归零计时并限制自动进度', () => {
  assert.match(script, /elapsed_seconds = 0\.0/);
  assert.match(script, /balance > 0\.35/);
});

test('独木桥提示和结算按钮与点击操作一致', () => {
  assert.match(script, /点击左右两侧，保持平衡/);
  assert.match(scene, /text = "再走一次"/);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
/Users/yizhixiaojinli/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node --test tests/bridge_click_control.test.mjs
```

Expected: FAIL because the current script still contains `is_pulling`, does not reset `elapsed_seconds`, and allows progress to grow continuously.

### Task 2: Implement click-based balancing and round reset

**Files:**
- Modify: `scripts/bridge.gd:5-190`
- Modify: `games/bridge/bridge.tscn:90-400`
- Test: `tests/bridge_click_control.test.mjs`

**Interfaces:**
- Consumes: the failing contracts from Task 1.
- Produces: `_apply_balance_click(position: Vector2) -> void`, which applies one left/right correction based on `BRIDGE_CENTER_X` and the click position.

- [ ] **Step 1: Replace mouse drag state with click correction**

Remove `is_pulling`, `lateral_target_x`, and `lateral_drift_target_x` from the input path. Add:

```gdscript
func _apply_balance_click(click_position: Vector2) -> void:
    if click_position.x < BRIDGE_CENTER_X:
        player_lean = clampf(player_lean - CLICK_MAX_FORCE, -1.0, 1.0)
        status_label.text = "向左修正重心"
    else:
        player_lean = clampf(player_lean + CLICK_MAX_FORCE, -1.0, 1.0)
        status_label.text = "向右修正重心"
```

Call it from a pressed left mouse button event, and retain the existing left/right keyboard correction as fallback.

- [ ] **Step 2: Reset timer and state at round start**

At the top of `_reset_round()` set:

```gdscript
elapsed_seconds = 0.0
progress = 0.0
player_lean = 0.0
is_falling = false
is_round_active = true
timer_value_label.text = "0"
```

Keep the existing `game_timer.start()` after all reset state is applied.

- [ ] **Step 3: Gate progress by balance**

After calculating `balance`, change progress growth to:

```gdscript
if balance > 0.35:
    progress = minf(progress + WALK_SPEED * delta * (0.45 + balance * 0.55), 1.0)
else:
    progress = maxf(progress - WALK_SPEED * delta * 0.18, 0.0)
```

This prevents a no-input run from reliably completing.

- [ ] **Step 4: Update visible instructions**

Set both the scene default status and runtime goal/status copy to:

```text
点击左右两侧，保持平衡，带着牛走过独木桥。
```

Change the result button text to `再走一次`.

- [ ] **Step 5: Run the focused test**

Run the same Node test command from Task 1. Expected: PASS.

### Task 3: Godot validation and Web export

**Files:**
- Modify: `web/public/games/bridge/index.html`, `index.js`, `index.pck`, `index.wasm` through Godot export.
- Verify: `project.godot:14` remains `run/main_scene="res://main.tscn"` after export.

**Interfaces:**
- Consumes: the fixed bridge scene and script from Task 2.
- Produces: a Web export whose packaged main scene is `res://games/bridge/bridge.tscn`.

- [ ] **Step 1: Run the Godot headless editor validation**

```bash
/Users/yizhixiaojinli/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/yizhixiaojinli/牧心十二境 --editor --quit
```

Expected: exit code 0; the editor-settings permission warning may remain external to the project.

- [ ] **Step 2: Temporarily set the export main scene to bridge**

Change `project.godot` only during export to:

```ini
run/main_scene="res://games/bridge/bridge.tscn"
```

- [ ] **Step 3: Export bridge Web package**

```bash
/Users/yizhixiaojinli/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/yizhixiaojinli/牧心十二境 --export-release Web /Users/yizhixiaojinli/牧心十二境/web/public/games/bridge/index.html
```

- [ ] **Step 4: Restore the project main scene**

Restore:

```ini
run/main_scene="res://main.tscn"
```

- [ ] **Step 5: Verify the export and interactions in the browser**

Open `http://127.0.0.1:8767/index.html`, capture the start state, click left and right bridge zones, verify the status changes, restart, and confirm the timer returns to 0. Save evidence under `.audit/bridge-fixed/`.

### Task 4: Full verification

**Files:**
- Verify: `tests/bridge_click_control.test.mjs`, existing seek tests, Godot export files.

- [ ] **Step 1: Run all focused tests**

```bash
/Users/yizhixiaojinli/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node --test tests/bridge_click_control.test.mjs tests/seek_cow_contract.test.mjs tests/seek_cow_transparency.test.mjs tests/seek_cow_copy.test.mjs
```

- [ ] **Step 2: Confirm project state**

```bash
rg -n '^run/main_scene' project.godot
```

Expected: `run/main_scene="res://main.tscn"`.

- [ ] **Step 3: Report verification evidence**

Report the test result, export path, browser URL, and any remaining Godot environment warning without claiming unverified behavior.
