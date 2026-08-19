# 《牧心十二境》Phase 5 集成验收与发布实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在目标浏览器和普通 4G 条件下完成端到端验收，先交付测试版本，确认后公开发布并生成二维码。

**Architecture:** 自动化测试覆盖状态、协议、签文、API 和构建；浏览器人工矩阵覆盖触摸、音频、横屏、保存与恢复；Sites 承担 D1、秘密、版本与公开访问。发布只使用通过验收的同一构建产物。

**Tech Stack:** Node.js tests、vinext build、Godot Web export、Chrome DevTools throttling、OpenAI Sites、QR PNG。

## Global Constraints

- 不得在测试失败时发布。
- 先交付测试版本，用户确认后才切换为完全公开。
- 正式交付包括一个公开网址和二维码 PNG。
- 首次完整加载目标为普通 4G 约 30 秒内。

---

### Task 1: 建立端到端旅程契约测试

**Files:**
- Create: `web/tests/end-to-end-journey.test.mjs`
- Modify: `web/scripts/test.mjs`

**Interfaces:**
- Consumes all prior public interfaces.
- Produces deterministic simulated journeys covering three cow choices and all 12 sign archetypes.

- [ ] **Step 1: 写三条完整旅程和恢复测试**

```js
test("a complete journey records the four approved inputs and reaches a stable sign", () => {
  const result = simulateJourney({ openingCow: "untrained", catches: 7, bridgeSeconds: 123, lotuses: 18 });
  assert.equal(result.snapshot.step, "sign");
  assert.equal(result.snapshot.completedOnce, true);
  assert.deepEqual(result.sign, deriveSign(result.input, result.snapshot.sessionId));
});
```

- [ ] **Step 2: 运行测试确认缺少集成模拟器**

Run: `cd web && node --test tests/end-to-end-journey.test.mjs`  
Expected: FAIL.

- [ ] **Step 3: 实现只使用公开接口的测试模拟器**

模拟器必须通过 `reduceJourney`、`parseGameResult`、storage serialization 和 `deriveSign` 完成，不得直接篡改最终状态。

- [ ] **Step 4: 添加 12 个签型校准旅程**

每个 fixture 使用明确的 opening cow、catches、bridgeSeconds、lotuses，断言覆盖 12 个不同 archetype，且相同 session 重放不变化。

- [ ] **Step 5: 运行全部自动化测试**

Run: `node --test tests/*.test.mjs && cd web && npm test`  
Expected: root and web suites all PASS; build exits 0.

- [ ] **Step 6: 提交**

```bash
git -C web add tests/end-to-end-journey.test.mjs scripts/test.mjs
git -C web commit -m "test: cover complete muxin journeys end to end"
```

### Task 2: 执行资源体积与 4G 性能门槛

**Files:**
- Create: `web/scripts/check-asset-budget.mjs`
- Create: `web/tests/asset-budget.test.mjs`
- Modify: `web/package.json`

**Interfaces:**
- Produces: `npm run check:assets` with hard failure on budget breach.

- [ ] **Step 1: 写预算测试**

```js
test("deployment has one Godot pack and no duplicate exports", async () => {
  assert.deepEqual(await gameDirectories(), ["godot"]);
  assert.ok((await totalCompressedBytes()) <= 30 * 1024 * 1024);
});
```

- [ ] **Step 2: 运行测试并记录当前失败体积**

Run: `cd web && node --test tests/asset-budget.test.mjs`  
Expected: FAIL until duplicate packs are removed and assets compressed.

- [ ] **Step 3: 实现预算脚本**

预算：部署静态资源 Brotli 估算总量不超过 30MB；轻量加载壳不超过 1.5MB；12 境全部分层图不超过 12MB；Godot wasm、pck、脚本与必要启动图合计压缩后不超过 15MB；其余应用资源不超过 1.5MB；不得存在 `stone/seek/bridge/jump` 重复导出目录。

- [ ] **Step 4: 优化超限资源**

Godot 移除未使用导入、调低 Web 纹理尺寸、关闭桌面 VRAM 压缩副本；WebP 按 Phase 3 参数重编码；字体只保留实际使用字形可行时进行子集化。每次优化后重新导出并运行功能测试。

- [ ] **Step 5: 运行预算、全部测试和构建**

Run: `cd web && npm run check:assets && npm test`  
Expected: both exit 0.

- [ ] **Step 6: 在普通 4G 模拟下计时**

清空缓存，使用 4G 限速完整加载三次，记录中位数；目标不超过 30 秒。结果写入 `docs/qa/2026-08-16-performance.md`，包含总传输量、首次加载和二次缓存加载时间。

- [ ] **Step 7: 提交**

```bash
git -C web add scripts tests package.json public
git -C web commit -m "perf: enforce muxin web asset and loading budgets"
git add docs/qa/2026-08-16-performance.md
git commit -m "docs: record muxin loading performance"
```

### Task 3: 执行目标浏览器人工验收

**Files:**
- Create: `docs/qa/2026-08-16-browser-matrix.md`

**Interfaces:**
- Produces: signed-off matrix for WeChat, iPhone Safari, Android Chrome, desktop Chrome.

- [ ] **Step 1: 准备固定验收脚本**

每台设备按相同步骤执行：竖屏进入→横屏提示→旋转→加载→选牛→拓印→寻牛→中途关闭恢复→独木桥掉落后计时继续→莲花掉落检查点恢复→完成十二境→保存签图→重新打开签保持一致→通关回看。

- [ ] **Step 2: 微信内置浏览器验收**

记录音频解锁、横屏、触摸、iframe、缓存、Canvas 保存和返回恢复；每项写 PASS 或具体故障与复现步骤。

- [ ] **Step 3: iPhone Safari 验收**

重点验证安全区域、地址栏高度变化、系统分享签图和 AudioContext 恢复。

- [ ] **Step 4: Android Chrome 验收**

重点验证二段跳点击、独木桥左右半屏、WebAssembly 内存和返回恢复。

- [ ] **Step 5: 电脑 Chrome 验收**

重点验证 16:9 居中、键鼠输入、缩放和管理 CSV 下载。

- [ ] **Step 6: 修复所有阻断项并重新运行相关测试**

任何无法完成旅程、结果丢失、签图无法保存、后台越权或加载超过目标的项目均为阻断项。修复后重新执行该浏览器整条脚本，不接受局部目测。

- [ ] **Step 7: 提交验收记录与修复**

```bash
git add docs/qa scripts games tests
git commit -m "fix: close Godot cross-browser acceptance gaps"
git -C web add app public tests
git -C web commit -m "fix: close web cross-browser acceptance gaps"
```

### Task 4: 配置测试站点与管理员秘密

**Files:**
- Modify: `web/.openai/hosting.json` only if a new Sites project id or D1 binding is issued.

**Interfaces:**
- Consumes: validated `web/dist`, D1 migration, `ADMIN_PASSWORD`, `ADMIN_SESSION_SECRET`.
- Produces: non-public test deployment URL.

- [ ] **Step 1: 运行发布前验证**

Run: `node --test tests/*.test.mjs && cd web && npm run check:assets && npm test`  
Expected: every command exits 0 with zero failing tests.

- [ ] **Step 2: 创建或重新连接 Sites 项目**

现有项目记录若返回 not found，则创建新的 Sites 项目一次，并把返回的 opaque project id 原样写入 `.openai/hosting.json`；不得自行构造 id。

- [ ] **Step 3: 配置 D1 和秘密**

应用迁移；设置 `ADMIN_PASSWORD` 为发布时由项目方提供的密码，设置随机至少 32 字节的 `ADMIN_SESSION_SECRET`。两者均标记为 secret，不输出到日志或源码。

- [ ] **Step 4: 保存并部署测试版本**

打包通过验证的同一 commit，保存一个 Sites version，按平台允许的最小访问范围部署测试版本并轮询到 succeeded。

- [ ] **Step 5: 执行线上冒烟测试**

打开准确部署 URL，完成首页加载、一次选牛、一个游戏回传、一次后台登录和一条 CSV 下载；线上故障必须修复、重建、保存新版本后再验收。

- [ ] **Step 6: 将测试链接交给用户验收**

只交付准确的测试 URL 和一份简短验收说明，等待用户明确确认后才执行 Task 5。

### Task 5: 公开发布并生成二维码

**Files:**
- Create: `web/public/release/牧心十二境-二维码.png`
- Create: `docs/qa/2026-08-16-release-record.md`

**Interfaces:**
- Produces: public production URL and QR PNG encoding exactly that URL.

- [ ] **Step 1: 确认用户已批准测试版本**

必须有明确“可以公开发布”或同义确认；没有确认时停止，不改变访问权限。

- [ ] **Step 2: 将 Sites 访问模式切换为 public**

部署已验收的同一版本，不在公开前加入未测试改动。轮询状态直到 succeeded，并读取平台返回的 `current_live_url`。

- [ ] **Step 3: 生成二维码并验证内容**

二维码使用最终 `current_live_url`，输出 1024×1024 PNG，白色 quiet zone 不少于 4 modules。解码生成文件并断言结果与 live URL 完全一致。

- [ ] **Step 4: 最终线上验证**

未登录窗口打开 live URL，确认无需账号；走到加载完成，验证 D1 写入、管理密码保护和签图保存。再次运行 `npm test`，记录 commit、版本、URL、测试总数和时间。

- [ ] **Step 5: 提交二维码和发布记录**

```bash
git -C web add public/release/牧心十二境-二维码.png
git -C web commit -m "feat: add public muxin release QR code"
git add docs/qa/2026-08-16-release-record.md
git commit -m "docs: record public muxin release"
```

- [ ] **Step 6: 最终交付**

向用户提供一个可点击的公开网址和二维码 PNG；不要求用户安装软件或配置服务器。
