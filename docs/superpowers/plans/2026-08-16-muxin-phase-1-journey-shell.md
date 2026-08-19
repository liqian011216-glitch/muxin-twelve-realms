# 《牧心十二境》Phase 1 网页旅程骨架实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在保留现有封面、序言、问心和场景画面的基础上，建成可按顺序自动推进、可中断恢复并在通关后自由回看的网页旅程骨架。

**Architecture:** 用纯 TypeScript 状态机作为唯一旅程真相源，React 只渲染状态并派发事件；localStorage 负责本机恢复。复用现有 `public/frames` 开场画面、`审查版_H5制作包` 十二境图和已经验证的横向舞台尺寸，只替换当前仅支持透明热点翻页的编排层。分层视觉在 Phase 3 逐境批准后接入，不改变状态接口。

**Tech Stack:** React 19、TypeScript、vinext、Node.js test runner、localStorage。

## Global Constraints

- 项目名称统一为《牧心十二境》。
- 十二境顺序固定为未牧、初调、受制、回首、驯伏、无碍、任运、相忘、独照、双泯、入世、牧心。
- 互动完成后自动推进，不显示“下一步”或“循迹前行”。
- 首次完成后才能自由回看。
- 手机竖屏必须先出现横屏提示。

---

### Task 1: 建立旅程类型与纯状态机

**Files:**
- Create: `web/app/journey/types.ts`
- Create: `web/app/journey/machine.ts`
- Create: `web/tests/journey-machine.test.mjs`
- Modify: `web/scripts/test.mjs`

**Interfaces:**
- Produces: `JourneySnapshot`, `JourneyStep`, `JourneyEvent`, `createJourney(sessionId)`, `reduceJourney(snapshot, event)`。

- [ ] **Step 1: 写失败测试，锁定顺序与自动推进规则**

```js
test("first journey follows the approved sequence", () => {
  let state = createJourney("session-1");
  state = reduceJourney(state, { type: "COMPLETE_STEP", step: "cover" });
  assert.equal(state.step, "intro");
  for (const step of ["intro", "cow_choice", "rubbing", "realm_01_untrained"]) {
    state = reduceJourney(state, { type: "COMPLETE_STEP", step });
  }
  assert.equal(state.step, "realm_02_first_taming");
});

test("a stale completion cannot skip a step", () => {
  const state = createJourney("session-1");
  assert.throws(
    () => reduceJourney(state, { type: "COMPLETE_STEP", step: "realm_12_mind" }),
    /Cannot complete realm_12_mind while current step is cover/,
  );
});
```

- [ ] **Step 2: 运行测试并确认因模块不存在而失败**

Run: `cd web && node --test tests/journey-machine.test.mjs`  
Expected: FAIL with `ERR_MODULE_NOT_FOUND` for `app/journey/machine.ts`.

- [ ] **Step 3: 实现明确的旅程类型与 reducer**

```ts
export const JOURNEY_STEPS = [
  "cover", "intro", "cow_choice", "rubbing",
  "realm_01_untrained", "realm_02_first_taming", "realm_03_restrained",
  "realm_04_turning_back", "realm_05_tamed", "realm_06_unforced",
  "realm_07_natural", "realm_08_forgotten", "realm_09_solitary",
  "realm_10_both_gone", "realm_11_return", "realm_12_mind", "sign",
] as const;

export type JourneyStep = (typeof JOURNEY_STEPS)[number];
export type OpeningCow = "untrained" | "restrained" | "free";
export type JourneySnapshot = {
  schemaVersion: 1;
  sessionId: string;
  step: JourneyStep;
  completedSteps: JourneyStep[];
  openingCow: OpeningCow | null;
  completedOnce: boolean;
  startedAt: string;
  updatedAt: string;
};
```

`reduceJourney` 只接受当前步骤的 `COMPLETE_STEP`，`CHOOSE_COW` 只允许在 `cow_choice`，`OPEN_REVIEW` 只允许 `completedOnce === true`。

- [ ] **Step 4: 运行状态机测试**

Run: `cd web && node --test tests/journey-machine.test.mjs`  
Expected: PASS, including strict step ordering and stale-event rejection.

- [ ] **Step 5: 将新测试加入总测试入口并提交**

```bash
git -C web add app/journey/types.ts app/journey/machine.ts tests/journey-machine.test.mjs scripts/test.mjs
git -C web commit -m "feat: add deterministic muxin journey machine"
```

### Task 2: 建立可迁移的本机进度存储

**Files:**
- Create: `web/app/journey/storage.ts`
- Create: `web/tests/journey-storage.test.mjs`

**Interfaces:**
- Consumes: `JourneySnapshot` from Task 1.
- Produces: `JOURNEY_STORAGE_KEY`, `serializeJourney`, `parseJourney`, `loadJourney`, `saveJourney`, `clearJourney`。

- [ ] **Step 1: 写损坏数据与版本校验测试**

```js
test("rejects corrupt and unknown journey snapshots", () => {
  assert.equal(parseJourney("not-json"), null);
  assert.equal(parseJourney(JSON.stringify({ schemaVersion: 99 })), null);
});

test("round trips the approved snapshot", () => {
  const state = createJourney("session-1");
  assert.deepEqual(parseJourney(serializeJourney(state)), state);
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `cd web && node --test tests/journey-storage.test.mjs`  
Expected: FAIL with missing `storage.ts`.

- [ ] **Step 3: 实现显式解析，不直接信任 JSON**

```ts
export const JOURNEY_STORAGE_KEY = "muxin.journey.v1";

export function parseJourney(raw: string | null): JourneySnapshot | null {
  if (!raw) return null;
  try {
    const value = JSON.parse(raw) as Partial<JourneySnapshot>;
    if (value.schemaVersion !== 1 || typeof value.sessionId !== "string") return null;
    if (!JOURNEY_STEPS.includes(value.step as JourneyStep)) return null;
    if (!Array.isArray(value.completedSteps)) return null;
    return value as JourneySnapshot;
  } catch {
    return null;
  }
}
```

- [ ] **Step 4: 运行存储与状态机测试**

Run: `cd web && node --test tests/journey-storage.test.mjs tests/journey-machine.test.mjs`  
Expected: PASS.

- [ ] **Step 5: 提交**

```bash
git -C web add app/journey/storage.ts tests/journey-storage.test.mjs
git -C web commit -m "feat: persist resumable muxin journeys"
```

### Task 3: 保留现有画面并将热点翻页升级为旅程壳层

**Files:**
- Create: `web/app/components/JourneyApp.tsx`
- Create: `web/app/components/OrientationGate.tsx`
- Create: `web/app/components/EssentialControls.tsx`
- Create: `web/app/components/FlatRealmScene.tsx`
- Create: `web/app/journey/realm-manifest.ts`
- Modify: `web/app/page.tsx`
- Modify: `web/app/globals.css`
- Modify: `web/app/layout.tsx`
- Create: `web/tests/journey-render-contract.test.mjs`

**Interfaces:**
- Consumes: Task 1 reducer and Task 2 storage.
- Produces: `JourneyApp`, `REALM_MANIFEST`, automatic transition callback `onSceneComplete()`.

- [ ] **Step 1: 写渲染契约测试**

```js
test("page renders the journey app instead of the Figma hotspot navigator", async () => {
  const page = await readFile(new URL("../app/page.tsx", import.meta.url), "utf8");
  assert.match(page, /JourneyApp/);
  assert.doesNotMatch(page, /figma-hotspot/);
});

test("realm manifest uses the approved final names", () => {
  assert.deepEqual(REALM_MANIFEST.slice(-3).map(({ title }) => title), ["双泯", "入世", "牧心"]);
});
```

- [ ] **Step 2: 运行测试确认旧页面不满足契约**

Run: `cd web && node --test tests/journey-render-contract.test.mjs`  
Expected: FAIL because `page.tsx` still uses transparent hotspots as the only journey logic.

- [ ] **Step 3: 实现旅程壳层与横屏门槛**

`JourneyApp` 初始化时读取本机快照；有未完成快照时显示“继续旅程 / 重新开始”；没有快照时创建 `crypto.randomUUID()` 会话。`OrientationGate` 仅在窄屏且 `matchMedia('(orientation: portrait)')` 为真时覆盖画面。现有开场 frame 文件原样复用，不重新导出或重新生成。

```tsx
export default function Home() {
  return <JourneyApp />;
}
```

`EssentialControls` 只包含静音和退出旅程，不包含前进按钮。`FlatRealmScene` 使用现有 `public/frames` 或 `public/assets/stone-*.jpg` 作为 Phase 1 临时画面，并在内部互动完成后调用 `onSceneComplete`。

- [ ] **Step 4: 更新元数据与样式**

将标题改为 `牧心十二境`，描述改为 `循大足石刻牧牛图，在十二境中观照自己的心。`。CSS 保持 16:9 横向舞台，横屏手机占满安全区域，竖屏显示旋转提示。

- [ ] **Step 5: 运行单元测试与构建**

Run: `cd web && npm test`  
Expected: all journey tests PASS and vinext build exits 0.

- [ ] **Step 6: 提交**

```bash
git -C web add app tests scripts/test.mjs
git -C web commit -m "feat: replace frame demo with resumable journey shell"
```

### Task 4: 实现自动衔接与通关回看

**Files:**
- Modify: `web/app/components/JourneyApp.tsx`
- Create: `web/app/components/ResumePrompt.tsx`
- Create: `web/app/components/RealmReview.tsx`
- Modify: `web/app/journey/machine.ts`
- Modify: `web/tests/journey-machine.test.mjs`
- Modify: `web/tests/journey-render-contract.test.mjs`

**Interfaces:**
- Produces: `scheduleAdvance(step, delayMs)` behavior; review navigation isolated from canonical first-run sequence.

- [ ] **Step 1: 写自动前进与回看解锁测试**

```js
test("finishing realm twelve unlocks review and enters sign", () => {
  const before = stateAt("realm_12_mind");
  const after = reduceJourney(before, { type: "COMPLETE_STEP", step: "realm_12_mind" });
  assert.equal(after.step, "sign");
  assert.equal(after.completedOnce, true);
  assert.doesNotThrow(() => reduceJourney(after, { type: "OPEN_REVIEW", step: "realm_04_turning_back" }));
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `cd web && node --test tests/journey-machine.test.mjs`  
Expected: FAIL until completion unlock and review event exist.

- [ ] **Step 3: 实现无按钮自动转场**

场景完成后先设置 `transitioning=true`，保留反馈 1200ms，再淡出 600ms，随后派发 `COMPLETE_STEP`。组件卸载时清除 timeout，避免快速恢复或退出造成重复推进。

- [ ] **Step 4: 实现继续、重启和回看**

“继续旅程”读取原快照；“重新开始”先确认，再清除旧快照并创建新会话。`RealmReview` 仅在 `completedOnce` 后可见，回看不修改原始游戏结果或签文。

- [ ] **Step 5: 运行完整 Web 测试与构建**

Run: `cd web && npm test`  
Expected: build exits 0 and all tests PASS.

- [ ] **Step 6: 人工阶段验收**

从首页走到临时签页，确认无任何前进按钮；在任意境界刷新后能够继续；完成后能回看但不能提前跳关。

- [ ] **Step 7: 提交**

```bash
git -C web add app tests
git -C web commit -m "feat: add automatic realm transitions and unlocked review"
```
