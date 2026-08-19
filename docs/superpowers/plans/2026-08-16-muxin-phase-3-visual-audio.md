# 《牧心十二境》Phase 3 分层视觉与声音实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用固定牧人与水牛角色、克制分层动画、竖排文字和原创程序化声音完成十二境的沉浸表达。

**Architecture:** 每境由静态背景、角色透明层和前景气氛层组成；统一 `RealmScene` 根据 manifest 渲染并自动完成。声音由 Web Audio 程序化生成五声音阶背景、风声、水声和操作音，避免新增大体积音频。

**Tech Stack:** React、CSS animations、Canvas/Web Audio、ImageGen、现有水墨素材。

## Global Constraints

- 视觉基准为 `审查版_H5制作包/12境审查总览.png`。
- 牧人与水牛必须严格保持已提供三视图的身份一致性。
- 第 11 境为“入世”，第 12 境为“牧心”。
- 每境文字淡入后自动淡出；互动完成后自动转场。
- 不采用整段视频，也不只做整图缩放。

---

### Task 1: 建立十二境资产与动作清单

**Files:**
- Create: `web/app/realms/manifest.ts`
- Create: `web/app/realms/types.ts`
- Create: `web/tests/realm-manifest-final.test.mjs`

**Interfaces:**
- Produces: `RealmVisualDefinition`, `REALM_VISUALS` with 12 entries.

- [ ] **Step 1: 写完整性测试**

```js
test("every realm declares three layers, copy and motion", () => {
  assert.equal(REALM_VISUALS.length, 12);
  for (const realm of REALM_VISUALS) {
    assert.deepEqual(Object.keys(realm.layers).sort(), ["actors", "atmosphere", "background"]);
    assert.ok(realm.title.length === 2);
    assert.ok(realm.durationMs >= 5000);
  }
  assert.deepEqual(REALM_VISUALS.slice(-3).map(r => r.title), ["双泯", "入世", "牧心"]);
});
```

- [ ] **Step 2: 运行测试确认缺少 manifest**

Run: `cd web && node --test tests/realm-manifest-final.test.mjs`  
Expected: FAIL.

- [ ] **Step 3: 定义每境动作**

```ts
export type RealmVisualDefinition = {
  id: number;
  title: string;
  meaning: string;
  prompt: string;
  layers: { background: string; actors: string; atmosphere: string };
  motion: "struggle" | "approach" | "tension" | "turn" | "balance" | "follow" | "walk" | "forget" | "observe" | "dissolve" | "return" | "merge";
  durationMs: number;
};
```

路径固定为 `/realms/NN/background.webp`、`actors.webp`、`atmosphere.webp`。每境 `meaning` 与 `prompt` 使用设计规格中对应寓意，不加入评分选择。

- [ ] **Step 4: 运行测试并提交**

Run: `cd web && node --test tests/realm-manifest-final.test.mjs`  
Expected: PASS.

```bash
git -C web add app/realms tests/realm-manifest-final.test.mjs
git -C web commit -m "feat: define final twelve-realm visual manifest"
```

### Task 2: 逐境制作和审查十二境分层资产

**Files:**
- Create: `web/public/realms/01` through `web/public/realms/12`
- Create: `docs/art/2026-08-16-realm-asset-register.md`

**Interfaces:**
- Consumes: overall reference `审查版_H5制作包/12境审查总览.png`, the 12 approved scene images, and the supplied herder/buffalo three-view references.
- Produces: 36 WebP layers at 1920×1080 with identical framing per realm.

- [ ] **Step 1: 先以“未牧”完成一套分层样板**

仅处理第 1 境。按下列 Step 2～5 依次完成无角色背景、固定角色层、气氛层、合成静帧与动画预览，向用户展示复用的原图、三层单图和合成效果。用户确认“未牧”后才允许创建第 2 境资产。

- [ ] **Step 2: 为当前境生成无角色背景**

每次编辑对应的已批准场景图，统一提示：

```text
保留原图淡米色绢纸、南宋工笔线描、浅水墨、石青黛蓝与少量赭朱点缀、横向山水和大面积留白。移除牧人与水牛并自然补全被遮挡的山石、草木和水面。不得增加文字、边框、现代物件或新角色。保持 16:9、1920×1080，并与原图构图位置一致。
```

第 11 境须包含大足石刻现实空间、千手观音与牧牛图的远景意象；第 12 境只保留月、莲台、石碑和可供角色溶解的留白。

- [ ] **Step 3: 为当前境生成固定角色透明层**

每境同时引用牧人与水牛三视图，提示必须写明该境动作；输出透明背景、1920×1080、角色位置与背景吻合。12 个动作依次为挣脱、追寻、拉扯、回首、同行过桥、主动跟随、自然前行、笛声相忘、静观、彼此淡化、走入石窟、化入山水。

- [ ] **Step 4: 为当前境生成透明气氛前景层**

只包含可轻微移动的云雾、水纹、近景草叶、花瓣或墨痕；不得重复角色和固定山石。

- [ ] **Step 5: 合成静帧、动画预览并登记尺寸与文件大小**

每层必须为 1920×1080。背景使用 WebP quality 76，角色使用带透明度的 WebP quality 80，气氛层使用 WebP quality 72。单境三层的压缩预算不超过 1MB。资产登记表逐项记录源图、输出路径、尺寸、大小和人工审查结果。

- [ ] **Step 6: 当前境用户验收**

检查同一牧人脸型、斗笠、服饰和赤足一致；同一水牛牛角、体型、毛色一致；透明边缘无白边；背景补全无重复肢体。向用户展示并等待明确确认；任何一项不合格则只重做该层，不得开始下一境。

- [ ] **Step 7: 按相同步骤依次完成第 2～12 境**

每一境单独重复 Step 2～6。第 10～12 境额外核对“双泯、入世、牧心”的最终名称和内容。不得并行生成尚未批准的后续境界。

- [ ] **Step 8: 提交全部逐境批准资产**

```bash
git -C web add public/realms
git -C web commit -m "feat: add approved layered twelve-realm artwork"
git add docs/art/2026-08-16-realm-asset-register.md
git commit -m "docs: register approved twelve-realm artwork"
```

### Task 3: 实现分层场景、竖排文字与自动完成

**Files:**
- Create: `web/app/components/RealmScene.tsx`
- Create: `web/app/components/VerticalRealmCopy.tsx`
- Create: `web/app/realms/motion.ts`
- Modify: `web/app/components/JourneyApp.tsx`
- Modify: `web/app/globals.css`
- Create: `web/tests/realm-scene-contract.test.mjs`

**Interfaces:**
- Consumes: `RealmVisualDefinition`.
- Produces: `<RealmScene realm onComplete />` with exactly-once completion.

- [ ] **Step 1: 写分层和无按钮契约测试**

```js
test("RealmScene renders three layers and no forward button", async () => {
  const source = await readFile(new URL("../app/components/RealmScene.tsx", import.meta.url), "utf8");
  assert.match(source, /background/);
  assert.match(source, /actors/);
  assert.match(source, /atmosphere/);
  assert.match(source, /writingMode:\s*["']vertical-rl/);
  assert.doesNotMatch(source, /循迹前行|下一步/);
});
```

- [ ] **Step 2: 运行测试确认组件不存在**

Run: `cd web && node --test tests/realm-scene-contract.test.mjs`  
Expected: FAIL.

- [ ] **Step 3: 实现三层渲染与 motion 类**

背景只做 1.0→1.025 缓慢推进；角色根据 `motion` 使用 4～12px 位移、1～2°旋转或透明度变化；气氛层使用 8～20px 漂移。所有动画在 `prefers-reduced-motion` 下改为淡入淡出。

- [ ] **Step 4: 实现文字与完成时序**

0～600ms 场景淡入；500～3500ms 显示竖排文字；`durationMs - 1200` 时进入反馈；结束后调用一次 `onComplete`，由 Phase 1 壳层负责转场。

- [ ] **Step 5: 运行测试与构建并提交**

Run: `cd web && npm test`  
Expected: all PASS and build exits 0.

```bash
git -C web add app tests
git -C web commit -m "feat: render layered animated twelve-realm scenes"
```

### Task 4: 实现原创程序化背景音乐与音效

**Files:**
- Create: `web/app/audio/engine.ts`
- Create: `web/app/audio/provider.tsx`
- Create: `web/tests/audio-engine.test.mjs`
- Modify: `web/app/components/JourneyApp.tsx`
- Modify: `web/app/components/EssentialControls.tsx`

**Interfaces:**
- Produces: `createMuxinAudioEngine()`, `unlock()`, `setMuted(boolean)`, `setRealm(number)`, `playCue("tap"|"water"|"seal")`, `dispose()`.

- [ ] **Step 1: 写音频生命周期测试**

```js
test("audio engine is silent before unlock and disposes every node", () => {
  const engine = createMuxinAudioEngine(fakeAudioContext);
  assert.equal(fakeAudioContext.startedOscillators, 0);
  engine.unlock();
  assert.ok(fakeAudioContext.startedOscillators > 0);
  engine.dispose();
  assert.equal(fakeAudioContext.liveNodes, 0);
});
```

- [ ] **Step 2: 运行测试确认模块不存在**

Run: `cd web && node --test tests/audio-engine.test.mjs`  
Expected: FAIL.

- [ ] **Step 3: 实现五声音阶与环境声**

使用 D、F、G、A、C 五声音阶的低音 drone 和稀疏钟音；过滤白噪声形成风声；短促正弦波和滤波噪声形成水滴与印章音。总输出连接 master gain，默认音量不超过 0.18。

- [ ] **Step 4: 首次点击解锁并持久化静音**

首页“开始旅程”调用 `unlock()`。静音状态保存为 `muxin.audio.muted.v1`。页面卸载时 `dispose()`，不得留下重复声部。

- [ ] **Step 5: 运行测试与构建并提交**

Run: `cd web && npm test`  
Expected: PASS.

```bash
git -C web add app/audio app/components tests/audio-engine.test.mjs
git -C web commit -m "feat: add procedural contemplative audio system"
```

### Task 5: 实现真实完整加载进度

**Files:**
- Create: `web/app/loading/asset-list.ts`
- Create: `web/app/loading/preloader.ts`
- Create: `web/app/components/LoadingGate.tsx`
- Create: `web/tests/preloader.test.mjs`
- Modify: `web/app/components/JourneyApp.tsx`

**Interfaces:**
- Produces: `preloadJourneyAssets(onProgress, signal)` returning only after all realm images and Godot core files are cached.

- [ ] **Step 1: 写真实字节进度和重试测试**

```js
test("progress is based on completed asset bytes and retry keeps successful entries", async () => {
  const cache = new Map();
  const first = await runPreload({ fail: ["index.pck"], cache });
  assert.equal(first.ok, false);
  const second = await runPreload({ fail: [], cache });
  assert.equal(second.refetched.includes("background.webp"), false);
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `cd web && node --test tests/preloader.test.mjs`  
Expected: FAIL.

- [ ] **Step 3: 实现资产清单与并发限制**

清单包含 36 个境界层、Godot `index.js`、`index.wasm`、`index.pck`、字体和关键 UI 图。最多并发 4 个请求；读取 `Content-Length` 时按字节计算，无长度时按已完成文件权重计算。

- [ ] **Step 4: 实现水墨加载页与失败重试**

显示真实百分比、当前阶段和“重新加载”。成功项存入 Cache Storage `muxin-assets-v1`；重试只请求失败项。所有必需资源成功后才显示首页。

- [ ] **Step 5: 运行测试、构建与人工断网测试**

Run: `cd web && npm test`  
Expected: PASS. DevTools 中断一个资源时显示重试，恢复后继续而不是从零开始。

- [ ] **Step 6: 提交**

```bash
git -C web add app/loading app/components tests/preloader.test.mjs
git -C web commit -m "feat: preload the complete journey with real progress"
```
