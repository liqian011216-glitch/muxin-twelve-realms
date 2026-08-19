# 《牧心十二境》Phase 2 Godot 游戏整合实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将拓印、寻牛、独木桥、莲花跳跃整合为一个 Web 导出包，并可靠回传旅程结果。

**Architecture:** Godot 使用统一入口根据 URL 参数打开场景，通过 JSON `postMessage` 回传版本化结果；React `GameHost` 负责 origin、会话和数据范围校验。每个互动只允许以 `interactionId` 结算一次。

**Tech Stack:** Godot 4.7、GDScript、JavaScriptBridge、React、TypeScript、Node.js tests。

## Global Constraints

- 保留现有游戏视觉风格。
- 拓印只回传完成状态，不参与牧心签。
- 寻牛固定 60 秒，核心结果为碰牛次数。
- 独木桥掉落后从桥头重来但总计时继续，核心结果为总用时。
- 莲花自动前进、点击跳跃、二段跳，核心结果为莲花数量。
- 所有游戏不出现失败结算。

---

### Task 1: 定义网页与 Godot 的版本化协议

**Files:**
- Create: `web/app/games/protocol.ts`
- Create: `web/tests/game-protocol.test.mjs`
- Create: `scripts/web_result_bridge.gd`

**Interfaces:**
- Produces TypeScript: `GameKind`, `GameResultMessage`, `parseGameResult(event, expected)`.
- Produces GDScript: `WebResultBridge.post_result(game, interaction_id, payload)`.

- [ ] **Step 1: 写协议解析失败测试**

```js
test("accepts only matching version, interaction and game", () => {
  const expected = { origin: "https://example.test", interactionId: "i-1", game: "seek" };
  assert.equal(parseGameResult(fakeEvent("https://evil.test", validSeek), expected), null);
  assert.equal(parseGameResult(fakeEvent(expected.origin, { ...validSeek, interactionId: "i-2" }), expected), null);
  assert.equal(parseGameResult(fakeEvent(expected.origin, validSeek), validSeek);
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `cd web && node --test tests/game-protocol.test.mjs`  
Expected: FAIL with missing protocol module.

- [ ] **Step 3: 实现严格 JSON 协议**

```ts
export type GameResultMessage =
  | { source: "muxin-godot"; version: 1; interactionId: string; game: "stone"; completed: true }
  | { source: "muxin-godot"; version: 1; interactionId: string; game: "seek"; catches: number; durationSeconds: 60 }
  | { source: "muxin-godot"; version: 1; interactionId: string; game: "bridge"; elapsedSeconds: number; falls: number; assisted: boolean }
  | { source: "muxin-godot"; version: 1; interactionId: string; game: "jump"; lotuses: number; elapsedSeconds: number; falls: number };
```

解析器必须拒绝负数、非有限数字、错误 origin、未知字段组合与不匹配的 interactionId。

- [ ] **Step 4: 实现 Godot JSON 回传助手**

```gdscript
class_name WebResultBridge

static func post_result(game: String, interaction_id: String, payload: Dictionary) -> void:
	if not OS.has_feature("web"):
		return
	var message := {"source": "muxin-godot", "version": 1, "interactionId": interaction_id, "game": game}
	message.merge(payload, true)
	var json := JSON.stringify(message)
	var js_string_literal := JSON.stringify(json)
	JavaScriptBridge.eval("window.parent.postMessage(JSON.parse(%s), window.location.origin)" % js_string_literal)
```

- [ ] **Step 5: 运行协议测试并提交**

Run: `cd web && node --test tests/game-protocol.test.mjs`  
Expected: PASS.

```bash
git -C web add app/games/protocol.ts tests/game-protocol.test.mjs
git -C web commit -m "feat: define secure Godot result protocol"
git add scripts/web_result_bridge.gd
git commit -m "feat: add Godot web result bridge"
```

### Task 2: 统一 Godot 入口并自动打开指定互动

**Files:**
- Modify: `scripts/menu.gd`
- Modify: `main.tscn`
- Modify: `tests/seek_cow_copy.test.mjs`
- Create: `tests/godot_web_entry_contract.test.mjs`

**Interfaces:**
- Consumes query parameters: `game=stone|seek|bridge|jump`, `interaction=<uuid>`.
- Produces: direct scene launch without visible game menu in embedded mode.

- [ ] **Step 1: 写入口契约测试**

```js
test("web entry supports all four interactions and requires an interaction id", () => {
  assert.match(menu, /"stone": STONE_RUBBING_SCENE/);
  assert.match(menu, /"seek": SEEK_COW_SCENE/);
  assert.match(menu, /"bridge": BRIDGE_SCENE/);
  assert.match(menu, /"jump": JUMP_SCENE/);
  assert.match(menu, /interaction_id/);
});
```

- [ ] **Step 2: 运行测试确认现有 if 链不满足契约**

Run: `node --test tests/godot_web_entry_contract.test.mjs`  
Expected: FAIL.

- [ ] **Step 3: 用映射替换菜单 if 链**

```gdscript
const GAME_SCENES := {
	"stone": STONE_RUBBING_SCENE,
	"seek": SEEK_COW_SCENE,
	"bridge": BRIDGE_SCENE,
	"jump": JUMP_SCENE,
}
```

Web 模式读取两个参数并直接打开场景；场景实例若有 `configure_web(interaction_id)` 就立即调用。嵌入模式隐藏菜单和退出按钮。

- [ ] **Step 4: 运行入口和现有 Godot 契约测试**

Run: `node --test tests/*.test.mjs`  
Expected: all PASS.

- [ ] **Step 5: 提交**

```bash
git add scripts/menu.gd main.tscn tests
git commit -m "feat: launch all interactions from one Godot web entry"
```

### Task 3: 让拓印和寻牛自动结算回传

**Files:**
- Modify: `scripts/stone_rubbing.gd`
- Modify: `scripts/seek_cow.gd`
- Modify: `games/seek_cow/seek_cow.tscn`
- Create: `tests/game_result_contract.test.mjs`

**Interfaces:**
- Produces stone payload `{ completed: true }`.
- Produces seek payload `{ catches, durationSeconds: 60 }`.

- [ ] **Step 1: 写结果契约测试**

```js
test("stone and seek post structured terminal results once", () => {
  assert.match(stone, /post_result\("stone"/);
  assert.match(seek, /post_result\("seek"/);
  assert.match(seek, /"catches": score/);
  assert.doesNotMatch(seek, /result_restart_button/);
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `node --test tests/game_result_contract.test.mjs`  
Expected: FAIL because stone posts a string and seek has no structured result.

- [ ] **Step 3: 修改拓印为单次 JSON 回传**

保存 `interaction_id`，`completion_announced` 保证一次结算；完成动画 1.2 秒后调用 `WebResultBridge.post_result("stone", interaction_id, {"completed": true})`。

- [ ] **Step 4: 修改寻牛结束流程**

60 秒结束时隐藏重开/继续结算层，显示“寻牛已毕”反馈 1.2 秒，然后回传 `score`。将“抓到一头牛”改为“又一次与牛相逢”，计分单位改为“次”。

- [ ] **Step 5: 运行结果契约和全部 Godot 测试**

Run: `node --test tests/*.test.mjs`  
Expected: all PASS.

- [ ] **Step 6: 提交**

```bash
git add scripts/stone_rubbing.gd scripts/seek_cow.gd games/seek_cow/seek_cow.tscn tests/game_result_contract.test.mjs
git commit -m "feat: return rubbing and seek results to journey"
```

### Task 4: 重构独木桥为无失败连续计时

**Files:**
- Modify: `scripts/bridge.gd`
- Modify: `games/bridge/bridge.tscn`
- Modify: `tests/bridge_click_control.test.mjs`
- Modify: `tests/game_result_contract.test.mjs`

**Interfaces:**
- Produces bridge payload `{ elapsedSeconds, falls, assisted }`.

- [ ] **Step 1: 写总计时、掉落计数和辅助模式测试**

```js
test("bridge preserves elapsed time and offers assistance after 180 seconds", () => {
  assert.match(bridge, /fall_count \+= 1/);
  assert.match(bridge, /elapsed_seconds >= 180\.0/);
  assert.match(bridge, /assisted = true/);
  assert.match(bridge, /post_result\("bridge"/);
  assert.doesNotMatch(bridge, /失败|成功过桥/);
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `node --test tests/bridge_click_control.test.mjs tests/game_result_contract.test.mjs`  
Expected: FAIL for missing assist/result fields and disallowed copy.

- [ ] **Step 3: 实现连续总计时与柔和措辞**

新增 `fall_count := 0`、`assisted := false`。掉落只重置 `progress` 和角色位置，不重置 `elapsed_seconds`。状态改为“水波轻动，再从桥头起步”。

- [ ] **Step 4: 实现三分钟辅助按钮**

180 秒后显示“让风扶你一程”；点击后设置 `assisted=true`，将摇摆目标范围从 `[-0.55, 0.55]` 缩到 `[-0.28, 0.28]`，`FALL_ANGLE` 判定提高到 `0.94`。仍需到达对岸。

- [ ] **Step 5: 到岸后自动回传**

停表并回传整数秒、掉落次数和辅助标志；不显示重玩结算按钮。

- [ ] **Step 6: 运行测试并提交**

Run: `node --test tests/*.test.mjs`  
Expected: all PASS.

```bash
git add scripts/bridge.gd games/bridge/bridge.tscn tests
git commit -m "feat: make bridge a continuous no-failure journey"
```

### Task 5: 将莲花跳跃改为自动前进和检查点恢复

**Files:**
- Modify: `scripts/jump_game.gd`
- Modify: `games/jump/jump_game.tscn`
- Modify: `tests/jump_game_contract.test.mjs`
- Modify: `tests/game_result_contract.test.mjs`

**Interfaces:**
- Produces jump payload `{ lotuses, elapsedSeconds, falls }`.

- [ ] **Step 1: 写自动前进、二段跳和检查点测试**

```js
test("jump auto-runs and recovers from the nearest checkpoint", () => {
  assert.match(script, /velocity\.x = RUN_SPEED/);
  assert.match(script, /remaining_air_jumps := 1/);
  assert.match(script, /checkpoint_x/);
  assert.match(script, /fall_count \+= 1/);
  assert.doesNotMatch(script, /_show_failure|失败/);
});
```

- [ ] **Step 2: 运行测试确认现有失败结算不符合要求**

Run: `node --test tests/jump_game_contract.test.mjs tests/game_result_contract.test.mjs`  
Expected: FAIL.

- [ ] **Step 3: 实现自动前进与点击跳跃**

移除左右输入状态与触摸左右按钮；游戏进行时固定 `velocity.x = RUN_SPEED`。地面跳跃后允许一次空中跳跃，落地重置。

- [ ] **Step 4: 实现最近检查点恢复**

每通过世界宽度的 20% 更新 `checkpoint_x`；掉落时增加 `fall_count`，恢复到该位置对应碰撞面，不清空莲花和总计时。

- [ ] **Step 5: 到达终点后回传并自动离开**

终点回传莲花数、整数秒与掉落次数；移除失败层和重新开始按钮。

- [ ] **Step 6: 运行全部 Godot 测试并提交**

Run: `node --test tests/*.test.mjs`  
Expected: all PASS.

```bash
git add scripts/jump_game.gd games/jump/jump_game.tscn tests
git commit -m "feat: make lotus journey auto-run without failure"
```

### Task 6: 在网页中嵌入统一游戏包

**Files:**
- Create: `web/app/components/GameHost.tsx`
- Modify: `web/app/components/JourneyApp.tsx`
- Modify: `web/app/journey/types.ts`
- Modify: `web/app/journey/machine.ts`
- Create: `web/tests/game-host-contract.test.mjs`

**Interfaces:**
- Consumes: Phase 2 protocol and Phase 1 journey reducer.
- Produces: validated `RECORD_GAME_RESULT` events and exactly-once completion.

- [ ] **Step 1: 写 iframe 与消息清理契约测试**

```js
test("GameHost uses the unified export and removes its listener", async () => {
  const source = await readFile(new URL("../app/components/GameHost.tsx", import.meta.url), "utf8");
  assert.match(source, /\/games\/godot\/index\.html/);
  assert.match(source, /removeEventListener\("message"/);
  assert.match(source, /parseGameResult/);
});
```

- [ ] **Step 2: 运行测试确认组件不存在**

Run: `cd web && node --test tests/game-host-contract.test.mjs`  
Expected: FAIL.

- [ ] **Step 3: 实现 `GameHost`**

构造同源 URL：`/games/godot/index.html?game=<kind>&interaction=<uuid>`。监听 `message`，用 `parseGameResult` 校验后通过 `handledRef` 保证只处理一次，卸载时移除监听。

- [ ] **Step 4: 将四个互动接入旅程步骤**

`rubbing`、`realm_02_first_taming`、`realm_05_tamed`、`realm_08_forgotten` 渲染 `GameHost`。结果写入 `JourneySnapshot.gameResults` 后自动推进。

- [ ] **Step 5: 运行 Web 和 Godot 全部测试**

Run: `node --test tests/*.test.mjs && cd web && npm test`  
Expected: both suites PASS and build exits 0.

- [ ] **Step 6: 重新导出唯一 Web 包并移除重复包**

使用 `export_presets.cfg` 的 `Web` preset 输出到 `web/public/games/godot/index.html`。确认该目录可启动后，移除 `web/public/games/stone`、`seek`、`bridge`、`jump` 四个重复导出目录。

- [ ] **Step 7: 提交**

```bash
git add scripts games tests export_presets.cfg
git commit -m "feat: integrate journey-aware Godot interactions"
git -C web add app tests public/games/godot
git -C web add -u public/games
git -C web commit -m "feat: embed one optimized Godot interaction bundle"
```
