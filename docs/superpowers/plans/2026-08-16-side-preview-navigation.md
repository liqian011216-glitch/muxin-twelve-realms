# 两侧预览图导航修复实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让境界画面的左右淡化预览图分别跳转上一境和下一境，同时保留现有右下角箭头导航。

**Architecture:** 继续使用 `FRAME_SCREENS` 作为唯一交互注册表；在 `realmHotspots()` 中按画面索引加入侧图热点，不在 React 页面组件中添加坐标判断。所有新增热点仍由现有原生按钮、加载闸门和 `getTargetIndex()` 统一处理。

**Tech Stack:** TypeScript、React、Node.js `node:test`、Vinext

## Global Constraints

- 画板固定为 `1066 × 600`，不得修改或重绘 `/public/frames/*.png`。
- 索引 `4–14` 保留现有 `previous`、`next` 箭头热点。
- 索引 `5–14` 的左侧淡化预览区域增加上一境热点；索引 `4–13` 的右侧淡化预览区域增加下一境热点。
- 预览矩形按下表逐屏设置；所有数值为画板百分比，均使用 `top: 13.3`、`height: 56`。空值表示该侧没有可见预览，不创建热点：

| index | previous `{ left, width }` | next `{ left, width }` |
|---:|---|---|
| 4 | — | `{ 71.3, 28.7 }` |
| 5 | `{ 0, 30 }` | `{ 70.3, 24.2 }` |
| 6 | `{ 2.6, 32.6 }` | `{ 65.9, 28.6 }` |
| 7 | `{ 0, 31.6 }` | `{ 67.4, 32.6 }` |
| 8 | `{ 0, 22.6 }` | `{ 83, 17 }` |
| 9 | `{ 0, 31.3 }` | `{ 69.3, 30.7 }` |
| 10 | `{ 0, 24.9 }` | `{ 77.1, 22.9 }` |
| 11 | `{ 0, 26.5 }` | `{ 74.9, 25.1 }` |
| 12 | `{ 0, 15.4 }` | `{ 85.7, 14.3 }` |
| 13 | `{ 0, 35.2 }` | `{ 64.5, 23.3 }` |
| 14 | `{ 0, 36.2 }` | — |
- 索引 `4` 不创建不存在的左侧预览热点；索引 `14` 不创建不存在的右侧预览热点。
- 新热点必须使用原生透明按钮并遵守现有图片加载闸门；不得遮挡中央主图、正文或右下角箭头。
- 不新增依赖，不修改无关游戏或旅程文件。

---

### Task 1: 注册并验证左右侧图导航热点

**Files:**
- Modify: `web/app/frame-flow.ts`
- Test: `web/tests/frame-flow.test.mjs`

**Interfaces:**
- Consumes: `realmHotspots(index: number): readonly FrameHotspot[]`、`getTargetIndex(screenIndex: number, hotspotId: string): number`
- Produces: hotspot IDs `preview-previous` 与 `preview-next`，分别指向 `index - 1` 与 `index + 1`

- [ ] **Step 1: 写入会失败的回归测试**

在 `web/tests/frame-flow.test.mjs` 增加：

```js
test("side preview images navigate without replacing arrow controls", () => {
  const firstRealm = flow.FRAME_SCREENS[4].hotspots;
  const middleRealm = flow.FRAME_SCREENS[8].hotspots;
  const lastRealm = flow.FRAME_SCREENS[14].hotspots;

  assert.equal(firstRealm.find(({ id }) => id === "preview-previous"), undefined);
  assert.deepEqual(firstRealm.find(({ id }) => id === "preview-next"), {
    id: "preview-next",
    label: "点击右侧预览，进入下一境",
    rect: { left: 71.3, top: 13.3, width: 28.7, height: 56 },
    targetIndex: 5,
  });
  assert.deepEqual(middleRealm.find(({ id }) => id === "preview-previous"), {
    id: "preview-previous",
    label: "点击左侧预览，进入上一境",
    rect: { left: 0, top: 13.3, width: 22.6, height: 56 },
    targetIndex: 7,
  });
  assert.deepEqual(middleRealm.find(({ id }) => id === "preview-next"), {
    id: "preview-next",
    label: "点击右侧预览，进入下一境",
    rect: { left: 83, top: 13.3, width: 17, height: 56 },
    targetIndex: 9,
  });
  assert.equal(lastRealm.find(({ id }) => id === "preview-next"), undefined);
  assert.ok(firstRealm.some(({ id }) => id === "previous"));
  assert.ok(firstRealm.some(({ id }) => id === "next"));
  assert.ok(lastRealm.some(({ id }) => id === "previous"));
  assert.ok(lastRealm.some(({ id }) => id === "next"));
});
```

同时更新 `defines the complete expected transition graph and opening choice values` 的索引 `4–14` 期望值，使它精确包含适用的 `preview-previous`、`preview-next`，并保留 `previous`、`next`。增加一张中央主图水平边界表并断言：每个左侧热点的右边缘不大于中央主图左边缘，每个右侧热点的左边缘不小于中央主图右边缘。

- [ ] **Step 2: 运行聚焦测试并确认 RED**

Run:

```bash
node --test tests/frame-flow.test.mjs
```

Expected: FAIL；失败原因是 `preview-next` / `preview-previous` 尚不存在，而不是语法或导入错误。

- [ ] **Step 3: 最小实现侧图热点**

在 `web/app/frame-flow.ts` 增加逐屏矩形表并修改 `realmHotspots()`：

```ts
const realmPreviewRects: Partial<Record<number, { previous?: FrameRect; next?: FrameRect }>> = {
  4: { next: { left: 71.3, top: 13.3, width: 28.7, height: 56 } },
  5: { previous: { left: 0, top: 13.3, width: 30, height: 56 }, next: { left: 70.3, top: 13.3, width: 24.2, height: 56 } },
  6: { previous: { left: 2.6, top: 13.3, width: 32.6, height: 56 }, next: { left: 65.9, top: 13.3, width: 28.6, height: 56 } },
  7: { previous: { left: 0, top: 13.3, width: 31.6, height: 56 }, next: { left: 67.4, top: 13.3, width: 32.6, height: 56 } },
  8: { previous: { left: 0, top: 13.3, width: 22.6, height: 56 }, next: { left: 83, top: 13.3, width: 17, height: 56 } },
  9: { previous: { left: 0, top: 13.3, width: 31.3, height: 56 }, next: { left: 69.3, top: 13.3, width: 30.7, height: 56 } },
  10: { previous: { left: 0, top: 13.3, width: 24.9, height: 56 }, next: { left: 77.1, top: 13.3, width: 22.9, height: 56 } },
  11: { previous: { left: 0, top: 13.3, width: 26.5, height: 56 }, next: { left: 74.9, top: 13.3, width: 25.1, height: 56 } },
  12: { previous: { left: 0, top: 13.3, width: 15.4, height: 56 }, next: { left: 85.7, top: 13.3, width: 14.3, height: 56 } },
  13: { previous: { left: 0, top: 13.3, width: 35.2, height: 56 }, next: { left: 64.5, top: 13.3, width: 23.3, height: 56 } },
  14: { previous: { left: 0, top: 13.3, width: 36.2, height: 56 } },
};

function realmHotspots(index: number): readonly FrameHotspot[] {
  const previews = realmPreviewRects[index] ?? {};
  return [
    ...(previews.previous
      ? [{ id: "preview-previous", label: "点击左侧预览，进入上一境", rect: previews.previous, targetIndex: index - 1 }]
      : []),
    ...(previews.next
      ? [{ id: "preview-next", label: "点击右侧预览，进入下一境", rect: previews.next, targetIndex: index + 1 }]
      : []),
    { id: "previous", label: "上一境", rect: previous, targetIndex: index - 1 },
    { id: "next", label: index === 14 ? "开启牧心十二境总结" : "下一境", rect: next, targetIndex: index + 1 },
  ];
}
```

- [ ] **Step 4: 运行聚焦测试并确认 GREEN**

Run:

```bash
node --test tests/frame-flow.test.mjs
```

Expected: 全部通过。

- [ ] **Step 5: 运行完整构建与测试**

Run:

```bash
node scripts/test.mjs
```

Expected: 构建成功，全部测试通过，零失败。

- [ ] **Step 6: 浏览器回归验证**

在 `http://localhost:3000/` 导航到中间境界：

1. 点击左侧淡化预览图，确认 `data-screen-index` 减一。
2. 点击右侧淡化预览图，确认 `data-screen-index` 加一。
3. 点击右下角上一境与下一境箭头，确认两者仍然工作。
4. 在索引 `4` 确认左侧空白区域不跳转；在索引 `14` 确认右侧空白区域不跳转。

- [ ] **Step 7: 提交修复**

```bash
git add app/frame-flow.ts tests/frame-flow.test.mjs
git commit -m "fix: make side previews navigate realms"
```
