# 《牧心十二境》Phase 4 牧心签与匿名后台实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 根据四项核心输入稳定生成 12×5 牧心签，并保存匿名旅程、提供密码管理统计和 CSV 导出。

**Architecture:** 纯函数签文引擎在浏览器和服务端共享；D1 保存会话、游戏结果和签文结果；管理员使用服务端校验密码后获得 HttpOnly 签名 cookie。玩家写接口只接受白名单字段并具有幂等键。

**Tech Stack:** TypeScript、React、Drizzle ORM、Cloudflare D1、Web Crypto、Canvas。

## Global Constraints

- 牧心签唯一输入为问心选牛、寻牛碰牛次数、独木桥总用时、莲花数量。
- 12 种核心签型，每种 5 条；不分吉凶。
- 同一旅程签型和签文固定。
- 后台不保存直接身份、精确位置或设备指纹。
- 管理密码只能保存在托管环境秘密中。

---

### Task 1: 实现可解释的 12 签型加权引擎

**Files:**
- Replace: `web/app/signs.ts`
- Create: `web/app/signs/types.ts`
- Create: `web/app/signs/weights.ts`
- Modify: `web/tests/journey.test.mjs`
- Create: `web/tests/sign-engine.test.mjs`

**Interfaces:**
- Produces: `SignInput`, `SignArchetypeId`, `classifySign(input)`, `variantIndex(sessionId)`, `deriveSign(input, sessionId)`.

- [ ] **Step 1: 写边界与稳定性测试**

```js
test("same journey and input always yield the same sign", () => {
  const input = { openingCow: "free", seekCatches: 8, bridgeSeconds: 92, lotusCount: 17 };
  assert.deepEqual(deriveSign(input, "session-a"), deriveSign(input, "session-a"));
});

test("the twelve calibration fixtures cover all archetypes", () => {
  assert.equal(new Set(CALIBRATION_FIXTURES.map(f => classifySign(f.input))).size, 12);
});
```

- [ ] **Step 2: 运行测试确认现有随机签系统失败**

Run: `cd web && node --test tests/sign-engine.test.mjs tests/journey.test.mjs`  
Expected: FAIL because current `drawSign` ignores the four approved inputs.

- [ ] **Step 3: 定义标准化与 12 个中心向量**

将碰牛次数按 `min(value, 20)/20`、过桥用时按 `min(max(value, 30), 240)` 反向标准化、莲花按 `min(value, 40)/40`。选牛映射为三维初始偏置。12 个签型 ID 固定为：

```ts
export const SIGN_ARCHETYPES = [
  "seeking", "holding", "turning", "balancing", "walking_together", "unhindered",
  "natural", "forgetting", "self_illumination", "both_gone", "returning", "mind_moon",
] as const;
```

每个签型使用明确中心向量；选择欧氏距离最近者，距离相同时按上表顺序稳定决胜。

- [ ] **Step 4: 用 FNV-1a 哈希固定 0～4 的版本**

```ts
export function variantIndex(sessionId: string): number {
  let hash = 0x811c9dc5;
  for (const char of sessionId) hash = Math.imul(hash ^ char.charCodeAt(0), 0x01000193);
  return (hash >>> 0) % 5;
}
```

- [ ] **Step 5: 运行测试并提交**

Run: `cd web && node --test tests/sign-engine.test.mjs tests/journey.test.mjs`  
Expected: PASS with all 12 calibration fixtures covered.

```bash
git -C web add app/signs.ts app/signs tests
git -C web commit -m "feat: derive twelve stable sign archetypes from journey data"
```

### Task 2: 编写 60 条签文库并验证完整性

**Files:**
- Create: `web/app/signs/library.ts`
- Create: `web/tests/sign-library.test.mjs`

**Interfaces:**
- Produces: `SIGN_LIBRARY: Record<SignArchetypeId, readonly [SignCopy, SignCopy, SignCopy, SignCopy, SignCopy]>`.

- [ ] **Step 1: 写数量、禁用评级和重复检测**

```js
test("library contains five unique non-judgmental copies for all twelve archetypes", () => {
  assert.equal(Object.keys(SIGN_LIBRARY).length, 12);
  const verses = [];
  for (const copies of Object.values(SIGN_LIBRARY)) {
    assert.equal(copies.length, 5);
    verses.push(...copies.map(copy => copy.verse));
  }
  assert.equal(new Set(verses).size, 60);
  assert.doesNotMatch(JSON.stringify(SIGN_LIBRARY), /上签|中签|下签|吉|凶/);
});
```

- [ ] **Step 2: 运行测试确认签文库不存在**

Run: `cd web && node --test tests/sign-library.test.mjs`  
Expected: FAIL.

- [ ] **Step 3: 写入 12×5 结构化签文**

12 个显示名固定为“寻迹、持绳、回首、平衡、同行、无碍、任运、相忘、独照、双泯、入世、牧心”。每条包含 `title`、两行 `verse`、`reflection` 和 `sealText`；同签型五条保持同一核心解释但使用不同自然意象。不得出现吉凶、成功、失败和人格诊断。

- [ ] **Step 4: 运行完整性测试与人工文案审读**

Run: `cd web && node --test tests/sign-library.test.mjs tests/sign-engine.test.mjs`  
Expected: PASS, 60 unique verses.

- [ ] **Step 5: 提交**

```bash
git -C web add app/signs/library.ts tests/sign-library.test.mjs
git -C web commit -m "feat: add sixty non-judgmental muxin signs"
```

### Task 3: 设计匿名 D1 数据模型与迁移

**Files:**
- Replace: `web/db/schema.ts`
- Modify: `web/.openai/hosting.json`
- Create: `web/tests/db-schema.test.mjs`
- Generate: `web/drizzle/0000_muxin_journeys.sql`

**Interfaces:**
- Produces tables: `journeys`, `game_results`, `journey_events`.

- [ ] **Step 1: 写 schema 契约测试**

```js
test("schema stores anonymous journey and idempotent game results", async () => {
  const source = await readFile(new URL("../db/schema.ts", import.meta.url), "utf8");
  assert.match(source, /journeys/);
  assert.match(source, /gameResults/);
  assert.match(source, /interactionId.*unique/si);
  assert.doesNotMatch(source, /email|phone|latitude|longitude|fingerprint/i);
});
```

- [ ] **Step 2: 运行测试确认空 schema 失败**

Run: `cd web && node --test tests/db-schema.test.mjs`  
Expected: FAIL.

- [ ] **Step 3: 实现表结构**

`journeys` 保存 `id`、时间、状态、当前步骤、opening cow、设备类别、方向、浏览器、签型和签文索引；`game_results` 保存 interactionId 唯一键、game kind、catches、elapsedSeconds、lotuses、falls、assisted；`journey_events` 保存白名单事件名与 step。所有时间为 ISO 字符串或整数毫秒，不保存 IP 或用户代理原文。

- [ ] **Step 4: 启用 D1 binding 并生成迁移**

将 `.openai/hosting.json` 的 `d1` 设为 `DB`。Run: `cd web && npm run db:generate`  
Expected: a migration creating all three tables and the unique interaction index.

- [ ] **Step 5: 运行测试并提交**

Run: `cd web && node --test tests/db-schema.test.mjs`  
Expected: PASS.

```bash
git -C web add db/schema.ts .openai/hosting.json drizzle tests/db-schema.test.mjs
git -C web commit -m "feat: add anonymous journey database schema"
```

### Task 4: 实现玩家写入 API 与离线重试队列

**Files:**
- Create: `web/app/api/journeys/route.ts`
- Create: `web/app/api/journeys/[id]/events/route.ts`
- Create: `web/app/api/journeys/[id]/games/route.ts`
- Create: `web/app/data/journey-client.ts`
- Create: `web/app/data/retry-queue.ts`
- Create: `web/tests/journey-api.test.mjs`

**Interfaces:**
- Produces: `POST /api/journeys`, `POST /api/journeys/:id/events`, `PUT /api/journeys/:id/games`.

- [ ] **Step 1: 写白名单、范围和幂等测试**

```js
test("duplicate interaction id updates once and rejects identity fields", async () => {
  assert.equal((await putGame(validBridge)).status, 204);
  assert.equal((await putGame(validBridge)).status, 204);
  assert.equal(await countGameRows(), 1);
  assert.equal((await createJourney({ ...validJourney, email: "x@example.com" })).status, 400);
});
```

- [ ] **Step 2: 运行测试确认路由不存在**

Run: `cd web && node --test tests/journey-api.test.mjs`  
Expected: FAIL.

- [ ] **Step 3: 实现服务端 Zod-free 显式校验**

不新增验证依赖。使用类型守卫只允许设计规格字段；游戏数字范围为 catches 0～200、bridge seconds 1～3600、lotuses 0～40、falls 0～1000。使用 interactionId upsert 保证幂等。

- [ ] **Step 4: 实现本机重试队列**

失败请求以 `{ id, method, path, body, attempts }` 存入 `muxin.telemetry.queue.v1`。网络恢复或下一次境界完成时按 FIFO 重试，最多 8 次；统计写入失败不得阻断旅程或签图。

- [ ] **Step 5: 运行 API 测试与构建并提交**

Run: `cd web && npm test`  
Expected: PASS.

```bash
git -C web add app/api app/data tests/journey-api.test.mjs
git -C web commit -m "feat: persist anonymous journey telemetry safely"
```

### Task 5: 实现牧心签页面与可保存签图

**Files:**
- Create: `web/app/components/SignResult.tsx`
- Create: `web/app/signs/render-card.ts`
- Create: `web/tests/sign-card.test.mjs`
- Modify: `web/app/components/JourneyApp.tsx`
- Modify: `web/app/globals.css`

**Interfaces:**
- Produces: `renderSignCard(sign): Promise<Blob>` at 1080×1440 PNG.

- [ ] **Step 1: 写稳定画布尺寸和下载测试**

```js
test("sign card renders a 1080 by 1440 png", async () => {
  const blob = await renderSignCard(sampleSign, fakeCanvas);
  assert.deepEqual(fakeCanvas.size, [1080, 1440]);
  assert.equal(blob.type, "image/png");
});
```

- [ ] **Step 2: 运行测试确认模块不存在**

Run: `cd web && node --test tests/sign-card.test.mjs`  
Expected: FAIL.

- [ ] **Step 3: 实现签页和 Canvas 签图**

签图使用淡绢纸底、石青竖排签名、两行签诗、简短回照文字和朱印；不显示分数、等级或原始数据。按钮只有“保存图片”和“再走一程”。

- [ ] **Step 4: 兼容移动端保存**

支持 `navigator.share({ files })` 时优先打开系统分享；不支持时下载 `牧心签-<title>.png`。同一旅程调用 `deriveSign` 结果固定。

- [ ] **Step 5: 运行测试、构建与手机保存人工测试并提交**

Run: `cd web && npm test`  
Expected: PASS; iPhone Safari 和微信内置浏览器可以长按或系统分享保存。

```bash
git -C web add app/components/SignResult.tsx app/signs app/globals.css tests/sign-card.test.mjs
git -C web commit -m "feat: render stable saveable muxin sign cards"
```

### Task 6: 实现安全的管理员会话

**Files:**
- Create: `web/app/admin/auth.ts`
- Create: `web/app/api/admin/login/route.ts`
- Create: `web/app/api/admin/logout/route.ts`
- Create: `web/tests/admin-auth.test.mjs`

**Interfaces:**
- Consumes env secrets: `ADMIN_PASSWORD`, `ADMIN_SESSION_SECRET`.
- Produces: `requireAdmin(request)`, HttpOnly cookie `muxin_admin` valid 8 hours.

- [ ] **Step 1: 写错误密码、篡改 cookie 和过期测试**

```js
test("admin cookie is signed, httpOnly and expires after eight hours", async () => {
  assert.equal((await login("wrong")).status, 401);
  const response = await login(validPassword);
  assert.match(response.headers.get("set-cookie"), /HttpOnly;.*SameSite=Strict;.*Path=\/;.*Max-Age=28800/);
  assert.equal(await requireAdmin(tamperedRequest), false);
});
```

- [ ] **Step 2: 运行测试确认模块不存在**

Run: `cd web && node --test tests/admin-auth.test.mjs`  
Expected: FAIL.

- [ ] **Step 3: 实现恒定时间密码比较与 HMAC cookie**

用 Web Crypto HMAC-SHA256 签署 `{ issuedAt, expiresAt }`，Secure、HttpOnly、SameSite=Strict、Path=/。使用 Path=/ 是为了让 `/api/admin/*` 接口能收到 cookie；HttpOnly 保证前端脚本不能读取。缺少环境秘密时管理接口返回 503，不使用默认密码。

- [ ] **Step 4: 运行认证测试并提交**

Run: `cd web && node --test tests/admin-auth.test.mjs`  
Expected: PASS.

```bash
git -C web add app/admin app/api/admin tests/admin-auth.test.mjs
git -C web commit -m "feat: protect muxin administration with signed sessions"
```

### Task 7: 实现统计页、详情、CSV 和安全清空

**Files:**
- Create: `web/app/admin/page.tsx`
- Create: `web/app/admin/AdminDashboard.tsx`
- Create: `web/app/api/admin/stats/route.ts`
- Create: `web/app/api/admin/journeys/[id]/route.ts`
- Create: `web/app/api/admin/export/route.ts`
- Create: `web/app/api/admin/clear/route.ts`
- Create: `web/tests/admin-api.test.mjs`

**Interfaces:**
- Produces admin-only stats, detail, CSV and two-step clear endpoint.

- [ ] **Step 1: 写权限、聚合、CSV 转义和清空确认测试**

```js
test("all admin endpoints reject anonymous requests", async () => {
  for (const endpoint of [stats, detail, csv, clear]) assert.equal((await endpoint(anonymous)).status, 401);
});

test("clear requires the exact confirmation phrase", async () => {
  assert.equal((await clear(admin, { confirmation: "清除" })).status, 400);
  assert.equal((await clear(admin, { confirmation: "永久清空全部匿名旅程" })).status, 204);
});
```

- [ ] **Step 2: 运行测试确认路由不存在**

Run: `cd web && node --test tests/admin-api.test.mjs`  
Expected: FAIL.

- [ ] **Step 3: 实现统计查询与界面**

显示体验人数、完成率、平均时长、三种选牛比例、碰牛次数分布、过桥用时分布、莲花数量分布、12 签型分布、设备和浏览器分布；单次详情显示匿名时间线，不显示 IP 或完整 UA。

- [ ] **Step 4: 实现 CSV 与清空**

CSV 使用 UTF-8 BOM，包含 approved 字段，双引号按 RFC 4180 转义。清空要求重新输入管理员密码并提交固定确认短语，事务中依次删除 events、game_results、journeys。

- [ ] **Step 5: 运行测试与构建并提交**

Run: `cd web && npm test`  
Expected: all PASS.

```bash
git -C web add app/admin app/api/admin tests/admin-api.test.mjs
git -C web commit -m "feat: add anonymous journey administration and exports"
```
