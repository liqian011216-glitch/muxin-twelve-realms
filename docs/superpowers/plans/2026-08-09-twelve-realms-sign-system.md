# 牧心十二境随机签叙事系统 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将现有 Figma 前置页面、开场拓印、12 境剧情交互和四个小游戏串成完整 H5 流程，并根据玩家心迹随机生成 60–120 种签文结果。

**Architecture:** 网页作为唯一流程控制器，使用集中式 `JourneyState` 累计章节选择和小游戏行为；每一境由数据驱动的剧情卡渲染。小游戏通过统一的 `GameResult` 适配器返回标签，暂时未接通 Godot 时使用可替换的网页模拟结果。最终签由“行为最高两类 + 最终拓印选择”决定签型，再从匹配版本中随机抽取。

**Tech Stack:** Next.js/Vinext、React、TypeScript、CSS、现有 Godot Web 导出。

## Global Constraints

- Figma 前置页面必须位于开场拓印之前。
- 12 境除小游戏节点外，每境必须有剧情、简单交互、选择反馈和继续操作。
- 游戏不显示传统分数，只输出行为标签。
- 同一路径重复游玩可得到同签型下的不同签文。
- 最终至少提供 60 种实际签文结果。
- 移动端保持单屏可操作，所有热点提供可访问标签和焦点样式。
- 不新增不必要的外部依赖。

---

### Task 1: 建立旅程状态、行为标签和随机签库

**Files:**
- Create: `web/app/journey.ts`
- Create: `web/app/signs.ts`
- Test: `web/tests/journey.test.mjs`

**Interfaces:**
- Produces `JourneyState`, `GameResult`, `ChoiceTag`, `createJourneyState()`, `recordChoice()`, `recordGameResult()`, `getSignArchetype()`, `drawSign()`。
- `drawSign(state, randomValue)` 返回 `{ archetype, variant, grade, title, verse, explanation }`，`randomValue` 可选，便于测试随机结果。

- [ ] **Step 1: 写状态和签判定测试**

测试覆盖：初始状态为空；记录选择会累计对应标签；游戏结果会追加到 `gameResults` 并累计标签；最高两类行为相同时使用最近行为和 `finalSeal` 打破平分；同一签型的不同随机值会返回不同版本。

- [ ] **Step 2: 运行测试确认失败**

Run: `cd web && npm test -- --runInBand`

Expected: 新增测试因 `journey.ts` 和 `signs.ts` 尚未实现而失败。

- [ ] **Step 3: 实现最小状态 API**

使用不可变更新，标签键统一为 `chase | wait | look_back | let_go | control | together`，中文只用于展示。`recordChoice` 和 `recordGameResult` 都只写入标签和事件，不做最终结算。

- [ ] **Step 4: 实现签型和签文数据**

准备至少 20 个签型，每个签型 3 个版本，合计至少 60 个版本。签文数据包含 `title`、`verse`、`explanation`、`grade` 和 `sealDetail`；随机只在当前签型的版本中抽取。

- [ ] **Step 5: 运行测试确认通过**

Run: `cd web && npm test -- --runInBand`

Expected: PASS，且签型判定和随机版本测试全部通过。

### Task 2: 将 Figma 前置页面与开场拓印接入主流程

**Files:**
- Modify: `web/app/page.tsx`
- Modify: `web/app/globals.css`
- Test: `web/tests/rendered-html.test.mjs`

**Interfaces:**
- Consumes Task 1 的 `JourneyState` 和 `recordChoice`。
- Produces 页面顺序：`cover → intro → choice → stoneIntro → openingRubbing → realm(1)`。

- [ ] **Step 1: 增加流程测试断言**

检查渲染页面包含 Figma 前置文案、开场拓印标题和第一境标题；检查初始选择会写入状态，而不是直接跳过记录。

- [ ] **Step 2: 实现主状态机**

把现有 `PageId` 扩展为 `stone-intro`、`opening-rubbing`、`realm`、`game`、`sign` 等状态。保留现有 Figma frame 热点，并将拓印完成作为进入第 1 境的条件。

- [ ] **Step 3: 运行页面构建测试**

Run: `cd web && npm test`

Expected: 构建和渲染检查通过，Figma 页面仍保持 16:9 居中显示。

### Task 3: 实现 12 境数据驱动剧情卡与简单交互

**Files:**
- Create: `web/app/realms.ts`
- Modify: `web/app/page.tsx`
- Modify: `web/app/globals.css`
- Test: `web/tests/realms.test.mjs`

**Interfaces:**
- `realms.ts` 导出 12 个 `RealmDefinition`，字段为 `id`、`title`、`image`、`story`、`prompt`、`choices`、`next`、`game`。
- 每个 choice 具有 `id`、`label`、`feedback`、`tags`。

- [ ] **Step 1: 写 12 境数据测试**

断言每境有对应审查包图片、至少两个选择、反馈文案和下一节点；1、5、8 标记为小游戏前置；12 标记为最终拓印。

- [ ] **Step 2: 写完整 12 境文案数据**

按设计文档完成未牧、初调、受制、回首、驯伏、无碍、任运、相忘、独照、双忘、禅定、心月图的短剧情和选择反馈。

- [ ] **Step 3: 实现通用 RealmPage**

使用统一的插画、境名、短文、选项、反馈和继续按钮。选择前禁用继续，选择后高亮选项并显示反馈；点击继续记录并进入下一境或游戏节点。

- [ ] **Step 4: 添加图片映射和响应式布局**

将 `审查版_H5制作包/01_未牧.png` 到 `12_心月图.png` 复制/映射到 web public 可访问路径，统一使用图片映射表，不在组件中散落文件名。桌面和移动端均保持核心人物、牛和交互区可见。

- [ ] **Step 5: 运行测试**

Run: `cd web && npm test`

Expected: 12 境数据测试和构建通过。

### Task 4: 接入四个小游戏的统一行为结果适配器

**Files:**
- Create: `web/app/gameAdapter.ts`
- Modify: `web/app/page.tsx`
- Modify: `web/app/globals.css`
- Test: `web/tests/game-adapter.test.mjs`

**Interfaces:**
- `startGame(game, onComplete)` 负责打开指定游戏节点。
- `normalizeGameResult(raw)` 返回合法 `GameResult`，缺少结果时返回 `wait`。
- `mockGameResult(game)` 提供开发期模拟结果。

- [ ] **Step 1: 写适配器测试**

覆盖 seek、bridge、jump、stone 四种游戏；覆盖未知动作、空结果、退出游戏和缺少分数等情况，确认统一归一化为行为标签且不会阻塞主流程。

- [ ] **Step 2: 实现游戏适配器**

先支持网页模拟完成按钮，并预留 Godot Web `postMessage`/JavaScriptBridge 结果入口。不得依赖分数；若 Godot 只返回动作数组，按动作映射到标签。

- [ ] **Step 3: 串联游戏节点**

将寻牛放在未牧之后、独木桥放在驯伏之后、横向跳跃放在相忘之后；保留拓印作为网页互动。第四个游戏为现有拓印节点，纳入同一适配器但不参与分数。

- [ ] **Step 4: 运行测试**

Run: `cd web && npm test`

Expected: 游戏适配器测试通过，所有游戏节点都能返回后续章节。

### Task 5: 实现心月图结算和随机签展示

**Files:**
- Modify: `web/app/page.tsx`
- Modify: `web/app/globals.css`
- Test: `web/tests/signs-render.test.mjs`

**Interfaces:**
- Consumes `JourneyState` 和 Task 1 的 `drawSign`。
- Produces最终签页，包含签号、签名、等级、签文、解签、行为记录和重新开始按钮。

- [ ] **Step 1: 写签页测试**

断言心月图的三种选择会写入 `finalSeal`；结算只发生一次；刷新前不重复抽签；不同随机值可在同签型中得到不同签文。

- [ ] **Step 2: 实现心月图交互**

用户选择留下牛、留下脚下的路或留下空白后，调用 `drawSign`，将结果锁定在本次旅程状态中。

- [ ] **Step 3: 实现签页视觉**

使用宣纸、拓印、朱砂印章和留白层次；不显示数字分数。展示“心迹已记录”而不是成功/失败评价，并提供重新开始入口。

- [ ] **Step 4: 运行测试**

Run: `cd web && npm test`

Expected: 签页测试和构建通过。

### Task 6: 端到端验证与交付检查

**Files:**
- Modify: `web/tests/rendered-html.test.mjs` only if assertions need updating
- Modify: `web/README.md` to document local run and game fallback behavior

- [ ] **Step 1: 运行完整测试**

Run: `cd web && npm test`

Expected: 所有测试 PASS，`npm run build` 成功。

- [ ] **Step 2: 进行主流程检查**

验证 Figma 前置页 → 开场拓印 → 12 境 → 三个 Godot 游戏节点 → 心月图 → 随机签完整可走通；验证退出游戏会使用 `wait` 默认标签继续。

- [ ] **Step 3: 进行移动端检查**

验证 390px 宽度下热点、选项、反馈、继续按钮和签页不溢出，键盘可聚焦所有按钮。

- [ ] **Step 4: 更新 README**

说明开发期使用模拟游戏结果，真实 Godot Web 回传接通后只需替换适配器入口。
