# 问心选牛反馈与记录实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在不修改已确认三牛静态画面的前提下，实现点选即锁定、朱红反馈、另外两项淡化、记录选择并在 0.8 秒后自动进入拓印引导。

**Architecture:** 继续复用 `FRAME_SCREENS[2]` 的三处触控区域和 `Home` 现有 `openingChoice` 状态。点选时只设置一次 `openingChoice`；React effect 负责 800ms 后切换到第 3 张拓印引导画面，并在卸载或状态变化时清除计时器。视觉反馈只使用热点按钮内部的圆形描边和未选项淡化，不修改 `02-choice.png`。

**Tech Stack:** React 19、TypeScript、CSS、Node.js test runner、vinext。

## Global Constraints

- 完整保留 `public/frames/02-choice.png`。
- 三个选择固定为 `untrained`、`restrained`、`free`。
- 第一次有效点击立即锁定，后续点击不得改变结果。
- 选中项只显示朱红描边，另外两项降低亮度；不显示“已择”或其他文字印记。
- 反馈持续 800ms 后自动进入 `/frames/03-stone-intro.png`。
- 不显示确认弹窗、继续按钮或心理含义解释。
- 本 Task 不修改拓印引导画面或任何小游戏。

---

### Task 1: 实现锁定式选牛反馈与自动衔接

**Files:**
- Create: `web/app/choice-feedback.ts`
- Modify: `web/app/page.tsx`
- Modify: `web/app/globals.css`
- Create: `web/tests/cow-choice-feedback.test.mjs`
- Modify: `web/scripts/test.mjs`

**Interfaces:**
- Consumes: `FrameHotspot.choice: "untrained" | "restrained" | "free"` and existing `openingChoice` state.
- Produces: `lockCowChoice(current, requested)`, `getCowChoiceState(selected, candidate)`, `chooseCow(choice)`, `data-choice-state="selected|dimmed|idle"`, locked `data-opening-choice`, and an 800ms transition to screen index `3`.

- [ ] **Step 1: 写锁定、反馈和 800ms 自动衔接失败测试**

```js
const feedback = await import("../app/choice-feedback.ts");

test("the first cow choice remains locked when another tap follows", () => {
  const first = feedback.lockCowChoice(null, "untrained");
  assert.equal(first, "untrained");
  assert.equal(feedback.lockCowChoice(first, "free"), "untrained");
});

test("one selected cow dims exactly the other two", () => {
  assert.equal(feedback.getCowChoiceState(null, "untrained"), "idle");
  assert.equal(feedback.getCowChoiceState("restrained", "restrained"), "selected");
  assert.equal(feedback.getCowChoiceState("restrained", "untrained"), "dimmed");
  assert.equal(feedback.getCowChoiceState("restrained", "free"), "dimmed");
});
```

- [ ] **Step 2: 运行测试并确认旧版立即跳转不符合要求**

Run: `cd web && node --test tests/cow-choice-feedback.test.mjs`

Expected: FAIL with `ERR_MODULE_NOT_FOUND` because `choice-feedback.ts` does not exist.

- [ ] **Step 3: 实现第一次点击锁定和 800ms 自动进入拓印引导**

先在 `choice-feedback.ts` 中实现：

```ts
export type OpeningCow = "untrained" | "restrained" | "free";
export type CowChoiceState = "idle" | "selected" | "dimmed";

export function lockCowChoice(current: OpeningCow | null, requested: OpeningCow): OpeningCow {
  return current ?? requested;
}

export function getCowChoiceState(selected: OpeningCow | null, candidate: OpeningCow): CowChoiceState {
  if (selected === null) return "idle";
  return selected === candidate ? "selected" : "dimmed";
}
```

再在 `page.tsx` 中加入：

```tsx
const COW_CHOICE_FEEDBACK_MS = 800;

const chooseCow = (choice: Exclude<OpeningChoice, null>) => {
  setOpeningChoice((current) => lockCowChoice(current, choice));
};

useEffect(() => {
  if (screenIndex !== 2 || openingChoice === null) return;
  const advanceTimer = window.setTimeout(() => {
    setLoadedImage(null);
    setScreenIndex(3);
  }, COW_CHOICE_FEEDBACK_MS);
  return () => window.clearTimeout(advanceTimer);
}, [screenIndex, openingChoice]);
```

普通热点仍调用 `activate(hotspot.id)`；带 `choice` 的热点调用 `chooseCow(hotspot.choice)`。`openingChoice !== null` 后三个按钮全部禁用；纯函数同时保证即使连续事件已进入队列，后来的 choice 也不能覆盖第一次结果。

- [ ] **Step 4: 实现朱红描边与未选项淡化**

选择按钮通过 `getCowChoiceState(openingChoice, hotspot.choice)` 写入 `data-choice-state`：当前 choice 等于 `openingChoice` 时为 `selected`，另两项为 `dimmed`，未选择时为 `idle`。按钮内部仅渲染圆形描边层：

```tsx
<span className="cow-choice-ring" aria-hidden="true" />
```

CSS 使用 `#a45135` 朱红色圆形描边；`dimmed` 使用半透明宣纸色覆盖，选中项不移动、不缩放，触控区域保持原尺寸。

- [ ] **Step 5: 运行局部与完整测试**

Run: `cd web && node --test tests/cow-choice-feedback.test.mjs`

Expected: PASS.

Run: `cd web && npm test`

Expected: production build succeeds and all tests PASS.

- [ ] **Step 6: 真实浏览器验收三种选择**

依次重新加载页面，完成封面和序言，分别点击未牧、受制、自在。每轮检查：第一次值立即写入 `data-opening-choice`；选中项只出现朱红描边且不出现文字印记；另外两项淡化；800ms 后图像变为 `/frames/03-stone-intro.png`。在 800ms 内尝试第二次点击，值不得变化。

- [ ] **Step 7: 保存候选检查点**

```bash
git -C web add app/choice-feedback.ts app/page.tsx app/globals.css tests/cow-choice-feedback.test.mjs scripts/test.mjs
git -C web commit -m "feat: add locked cow choice feedback"
```

完成后只交付选牛可点击预览给用户；用户确认前不得修改拓印引导。
