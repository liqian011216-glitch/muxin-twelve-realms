# 《牧心十二境》React + Vite 网页基础架构 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在独立的 `frontend/` 目录中建立可运行、可测试并可继续接入 Godot Web 的《牧心十二境》React + Vite 网页基础架构。

**Architecture:** 使用 React Router 的声明式路由串联七个叙事页面，公共组件负责导航、按钮与页面转场，三个数据模块分别保存石刻、十二境和牧心签配置。CSS 只建立宋韵宣纸视觉骨架；Games 页面保留 Godot Web 挂载边界，不加载第一阶段之外的游戏代码。

**Tech Stack:** React 19、Vite 8、React Router、Vitest、Testing Library、ESLint、CSS

## Global Constraints

- 所有新增应用代码必须位于 `frontend/`；不得修改现有 `web/`、Godot 场景、脚本和素材。
- 路由必须是 `/`、`/question`、`/stone`、`/rubbing`、`/realm`、`/games`、`/sign`。
- 第一阶段不得开发、复制或加载 Godot Web 游戏构建产物。
- 视觉必须体现大足石刻、宋代美学、宣纸、淡墨、描金和留白，不得使用 Q 版、卡通或游戏大厅式设计。
- 每个页面必须包含标题、说明、返回与下一步操作；首页返回禁用，牧心签页可重新游历。
- 数据必须与页面组件分离，并为未来图片、交互和 Godot 消息扩展保留稳定字段。

---

## File Map

- `frontend/package.json`：依赖和开发、测试、检查、构建命令。
- `frontend/vite.config.js`：Vite React 插件与 Vitest 浏览器环境。
- `frontend/eslint.config.js`：React 项目静态检查规则。
- `frontend/index.html`：Vite HTML 入口与中文元信息。
- `frontend/src/main.jsx`：挂载 React 与 BrowserRouter。
- `frontend/src/App.jsx`：全局外壳和七条路由。
- `frontend/src/styles.css`：宣纸、淡墨、描金视觉与响应式规则。
- `frontend/src/pages/*.jsx`：七个页面内容与相邻页面导航。
- `frontend/src/components/Navigation.jsx`：品牌和章节导航。
- `frontend/src/components/Button.jsx`：链接式/按钮式操作控件。
- `frontend/src/components/PageTransition.jsx`：页面内容壳和淡入过渡。
- `frontend/src/data/stoneData.js`：石刻资料对象。
- `frontend/src/data/realmData.js`：十二境数组。
- `frontend/src/data/signData.js`：牧心签维度与模板。
- `frontend/src/test/setup.js`：Testing Library DOM 断言配置。
- `frontend/src/test/data.test.js`：数据契约测试。
- `frontend/src/test/routes.test.jsx`：路由与页面导航测试。
- `frontend/src/assets/.gitkeep`：保留后续视觉素材目录。
- `frontend/public/games/.gitkeep`：保留未来 Godot Web 导出目录。
- `frontend/README.md`：运行方式与 Godot 接入约定。

---

### Task 1: 创建可测试的 React + Vite 应用壳

**Files:**
- Create: `frontend/package.json`
- Create: `frontend/vite.config.js`
- Create: `frontend/eslint.config.js`
- Create: `frontend/index.html`
- Create: `frontend/src/main.jsx`
- Create: `frontend/src/test/setup.js`
- Create: `frontend/src/test/smoke.test.jsx`

**Interfaces:**
- Consumes: Node.js `>=22.13.0`。
- Produces: `npm run dev`、`npm test`、`npm run lint`、`npm run build`；`main.jsx` 挂载点 `#root`。

- [ ] **Step 1: 创建依赖与工具配置**

`package.json` 使用 ES modules，并声明以下脚本：

```json
{
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "lint": "eslint .",
    "test": "vitest run"
  }
}
```

依赖为 `react`、`react-dom`、`react-router-dom`；开发依赖为 `@vitejs/plugin-react`、`vite`、`vitest`、`jsdom`、`@testing-library/react`、`@testing-library/jest-dom`、`eslint`、`@eslint/js`、`eslint-plugin-react-hooks`、`eslint-plugin-react-refresh` 和 `globals`。

- [ ] **Step 2: 安装依赖**

Run: `cd frontend && npm install`

Expected: 生成 `frontend/package-lock.json`，命令退出码为 0。

- [ ] **Step 3: 写入口烟雾测试**

测试临时导入 `../App.jsx` 并断言页面能出现站点名称：

```jsx
render(<MemoryRouter><App /></MemoryRouter>);
expect(screen.getByText("牧心十二境")).toBeInTheDocument();
```

- [ ] **Step 4: 运行测试并确认红灯**

Run: `cd frontend && npm test -- src/test/smoke.test.jsx`

Expected: FAIL，错误指出 `src/App.jsx` 不存在。

- [ ] **Step 5: 创建最小应用入口**

创建 `App.jsx`，暂时返回 `<main>牧心十二境</main>`；`main.jsx` 使用 `createRoot` 和 `BrowserRouter` 挂载 `<App />`；`index.html` 声明 `lang="zh-CN"`、页面标题和 `#root`。

- [ ] **Step 6: 运行烟雾测试并确认绿灯**

Run: `cd frontend && npm test -- src/test/smoke.test.jsx`

Expected: PASS，1 个测试通过。

- [ ] **Step 7: 提交任务**

```bash
git add frontend/package.json frontend/package-lock.json frontend/vite.config.js frontend/eslint.config.js frontend/index.html frontend/src/main.jsx frontend/src/App.jsx frontend/src/test/setup.js frontend/src/test/smoke.test.jsx
git commit -m "chore: scaffold muxin React frontend"
```

---

### Task 2: 建立石刻、十二境与牧心签数据契约

**Files:**
- Create: `frontend/src/test/data.test.js`
- Create: `frontend/src/data/stoneData.js`
- Create: `frontend/src/data/realmData.js`
- Create: `frontend/src/data/signData.js`

**Interfaces:**
- Consumes: 无运行时依赖。
- Produces: 默认导出 `stoneData`、`realmData`、`signData`；其中 `realmData` 是包含 12 项的数组。

- [ ] **Step 1: 写数据契约测试**

断言：

```js
expect(Object.keys(stoneData)).toEqual(expect.arrayContaining([
  "name", "period", "location", "image", "professionalIntro", "funIntro"
]));
expect(realmData.map(({ id, name }) => [id, name])).toEqual([
  [1, "未牧"], [2, "初调"], [3, "受制"], [4, "回首"],
  [5, "驯伏"], [6, "无碍"], [7, "任运"], [8, "相忘"],
  [9, "独照"], [10, "双泯"], [11, "入世"], [12, "牧心"]
]);
expect(signData).toEqual(expect.objectContaining({ dimensions: expect.any(Array), templates: expect.any(Array) }));
```

- [ ] **Step 2: 运行数据测试并确认红灯**

Run: `cd frontend && npm test -- src/test/data.test.js`

Expected: FAIL，错误指出三个数据模块不存在。

- [ ] **Step 3: 实现最小数据模块**

`stoneData` 填写大足石刻《牧牛图》的名称、南宋年代、重庆大足宝顶山位置、`null` 图片值、专业介绍和趣味介绍；`realmData` 严格使用需求中的 12 个编号与名称，并为每项加入一句 `description`；`signData` 提供“持、观、和、放”四个维度和至少四个基础签文模板。

- [ ] **Step 4: 运行数据测试并确认绿灯**

Run: `cd frontend && npm test -- src/test/data.test.js`

Expected: PASS，所有数据契约断言通过。

- [ ] **Step 5: 提交任务**

```bash
git add frontend/src/data frontend/src/test/data.test.js
git commit -m "feat: add cultural narrative data"
```

---

### Task 3: 实现七条路由与统一页面组件

**Files:**
- Create: `frontend/src/test/routes.test.jsx`
- Create: `frontend/src/components/Navigation.jsx`
- Create: `frontend/src/components/Button.jsx`
- Create: `frontend/src/components/PageTransition.jsx`
- Create: `frontend/src/pages/Home.jsx`
- Create: `frontend/src/pages/Question.jsx`
- Create: `frontend/src/pages/StoneIntro.jsx`
- Create: `frontend/src/pages/Rubbing.jsx`
- Create: `frontend/src/pages/Realm.jsx`
- Create: `frontend/src/pages/Games.jsx`
- Create: `frontend/src/pages/Sign.jsx`
- Modify: `frontend/src/App.jsx`
- Modify: `frontend/src/test/smoke.test.jsx`

**Interfaces:**
- Consumes: `stoneData`, `realmData`, `signData`；React Router 的 `Routes`、`Route`、`Navigate`、`NavLink` 和 `Link`。
- Produces: `Button({ to, variant, disabled, children })`、`PageTransition({ eyebrow, title, description, backTo, nextTo, nextLabel, children })` 与七条可直接访问的路由。

- [ ] **Step 1: 写页面路由测试**

对以下表格逐项用 `MemoryRouter initialEntries={[path]}` 渲染 `App` 并断言一级标题：

```js
[
  ["/", "牧心十二境"], ["/question", "问心"],
  ["/stone", "石刻认识"], ["/rubbing", "拓印体验"],
  ["/realm", "十二境修心旅程"], ["/games", "互动小境"],
  ["/sign", "牧心签"]
]
```

另断言 `/question` 的“返回”指向 `/`、“下一步”指向 `/stone`；`/sign` 的“重新游历”指向 `/`；未知路径渲染首页。

- [ ] **Step 2: 运行路由测试并确认红灯**

Run: `cd frontend && npm test -- src/test/routes.test.jsx`

Expected: FAIL，七个页面标题和路由尚不存在。

- [ ] **Step 3: 实现公共组件**

`Button` 在有 `to` 时渲染 `Link`，禁用时渲染带 `aria-disabled="true"` 的 `span`；`Navigation` 使用 `NavLink` 输出七个章节入口；`PageTransition` 输出题签、一级标题、说明、内容插槽和底部前后操作。

- [ ] **Step 4: 实现七个基础页面**

每页提供明确文案并设置相邻路径。`StoneIntro` 读取 `stoneData`，`Realm` 显示 `realmData` 的十二个境名，`Sign` 读取 `signData` 的基础维度，`Games` 使用 `data-godot-mount="reserved"` 标记未来嵌入区域，并显示“第一阶段暂不加载游戏”。

- [ ] **Step 5: 完成 App 路由**

`App.jsx` 在公共 `Navigation` 下声明七条 `Route`，最后使用 `<Route path="*" element={<Navigate to="/" replace />} />`。保留烟雾测试作为最快的基础渲染检查。

- [ ] **Step 6: 运行路由与全部测试并确认绿灯**

Run: `cd frontend && npm test`

Expected: PASS，数据与路由测试全部通过。

- [ ] **Step 7: 提交任务**

```bash
git add frontend/src/App.jsx frontend/src/components frontend/src/pages frontend/src/test
git commit -m "feat: add muxin narrative routes"
```

---

### Task 4: 建立宋韵视觉、资源边界与交付文档

**Files:**
- Create: `frontend/src/styles.css`
- Create: `frontend/src/assets/.gitkeep`
- Create: `frontend/public/games/.gitkeep`
- Create: `frontend/README.md`
- Create: `frontend/src/test/visual-contract.test.js`
- Modify: `frontend/src/main.jsx`
- Modify: `frontend/src/test/routes.test.jsx`

**Interfaces:**
- Consumes: Task 3 的语义类名和 `data-godot-mount="reserved"`。
- Produces: 响应式宣纸视觉、减少动态效果支持、稳定的 Godot 导出目录与运行说明。

- [ ] **Step 1: 补充视觉、可访问性与 Godot 边界测试**

在路由测试中断言 Games 页面存在 `[data-godot-mount="reserved"]`；首页禁用返回具有 `aria-disabled="true"`；导航当前项具有 `aria-current="page"`。新增 `visual-contract.test.js`，读取 `styles.css` 并断言存在 `--paper`、`--ink`、`--gold`、`prefers-reduced-motion` 和 `max-width: 720px`。

- [ ] **Step 2: 运行测试并确认红灯**

Run: `cd frontend && npm test -- src/test/routes.test.jsx`

Expected: FAIL，错误指出 `styles.css` 不存在。

- [ ] **Step 3: 实现统一 CSS**

在 `styles.css` 定义 `--paper`、`--ink`、`--muted-ink`、`--cinnabar`、`--gold`；使用多层径向渐变形成低对比宣纸与墨晕，使用细金线、宋体字族、宽松行高和留白构图。加入 `@media (max-width: 720px)` 的窄屏规则和 `@media (prefers-reduced-motion: reduce)` 的无动画规则，并由 `main.jsx` 导入样式。

- [ ] **Step 4: 建立资源目录与 README**

创建两个 `.gitkeep`。README 记录 `npm install`、`npm run dev`、`npm test`、`npm run lint`、`npm run build`，并约定 Godot 导出至 `public/games/<game-name>/`、未来由独立组件通过 `iframe` 与 `postMessage` 接入。

- [ ] **Step 5: 运行全部质量检查**

Run: `cd frontend && npm test && npm run lint && npm run build`

Expected: 三个命令退出码均为 0；测试无失败，ESLint 无错误，Vite 在 `frontend/dist/` 生成生产构建。

- [ ] **Step 6: 核对现有项目未被修改**

Run: `git status --short -- web project.godot main.tscn scripts games`

Expected: 输出与实施前已记录的状态相同；本计划没有新增这些路径的修改。

- [ ] **Step 7: 提交任务**

```bash
git add frontend/src/styles.css frontend/src/main.jsx frontend/src/test/routes.test.jsx frontend/src/test/visual-contract.test.js frontend/src/assets/.gitkeep frontend/public/games/.gitkeep frontend/README.md
git commit -m "feat: style muxin cultural journey"
```

---

### Task 5: 最终验收与交付清单

**Files:**
- Inspect: `frontend/`
- Inspect: `docs/superpowers/specs/2026-08-14-muxin-react-vite-foundation-design.md`

**Interfaces:**
- Consumes: Tasks 1–4 的完整应用。
- Produces: 可复现的测试、Lint、构建和需求覆盖证据。

- [ ] **Step 1: 重新运行完整验证**

Run: `cd frontend && npm test && npm run lint && npm run build`

Expected: 所有命令退出码为 0。

- [ ] **Step 2: 核对目录和路由**

Run: `find frontend/src -maxdepth 3 -type f | sort`

Expected: 七个页面、三个组件、三个数据文件、`assets/.gitkeep`、入口、样式和测试均存在。

- [ ] **Step 3: 核对依赖与工作区范围**

Run: `cd frontend && npm ls react react-dom react-router-dom vite --depth=0`

Expected: 四项均已安装且无缺失依赖；现有 `web/` 和 Godot 文件未因本次实施产生新修改。

- [ ] **Step 4: 准备交付说明**

交付说明必须列出新增/修改文件、`cd frontend && npm install && npm run dev` 的运行方式，以及下一步优先开发“问心选择状态 + 行为记录”，再设计 Godot Web 消息协议和游戏嵌入组件。
