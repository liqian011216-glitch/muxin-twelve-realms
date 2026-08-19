# 牧心十二境现有网页改造 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor the existing `web/` Vinext app into a game-free 16:9 twelve-realm narrative with Zen personality signs.

**Architecture:** Retain the existing React/Vinext app and its tested content modules. Replace the game-routing page state with browser-native interactions, map existing choice tags into four internal heart-actions, and generate four principal signs plus transition wording. No Godot iframe may be rendered.

**Tech Stack:** Existing Vinext/React 19/TypeScript/CSS/Node test stack.

## Global Constraints

- Work only under `web/`; do not remove the existing Godot files from `web/public/games/`.
- Do not render a game iframe or route to a game page.
- Keep the app horizontal (16:9) with no document scrolling, and use existing local image assets.
- Use `hold`, `observe`, `harmonize`, `release` internally; render 签 as 持绳签、观照签、同行签、任运签.
- Do not show scores, rankings, personality diagnoses, accounts, or data collection.
- From realm 8 reduce chrome; from realm 10 remove visible interaction hints and allow automatic continuation.

### Task 1: Replace scoring with four heart-actions

**Files:** Modify `web/app/journey.ts`, `web/app/signs.ts`; modify `web/tests/journey.test.mjs`.

**Interfaces:** Export `HeartAction`, `HeartTotals`, `recordHeartAction`, `deriveSign`; `deriveSign()` returns `{ primary, transition }`.

- [ ] Write failing Node tests asserting a release-heavy state produces `任运签`, a hold-heavy state produces `持绳签`, and close hold/observe totals produce `持绳而能回首`.
- [ ] Run `npm test -- --test-name-pattern="心行|签"` from `web/`; expect failure.
- [ ] Implement the four totals, deterministic tie order `release > harmonize > observe > hold`, the four non-diagnostic reflections, and the transition phrase only when the runner-up is within one point.
- [ ] Run `npm test` from `web/`; expect all Node tests to pass.
- [ ] Commit only `web/app/journey.ts`, `web/app/signs.ts`, and `web/tests/journey.test.mjs` with message `feat: add zen heart-action signs`.

### Task 2: Convert twelve-realm data to browser-native interactions

**Files:** Modify `web/app/realms.ts`; modify `web/tests/realms.test.mjs`.

**Interfaces:** Each realm exports `interaction: "drag" | "observe" | "choice" | "autoplay" | "imprint"`, `showProgress`, `showHint`, and choices that carry `HeartAction` weights.

- [ ] Write failing tests for exactly 12 ordered realms, no `game` property, hints disabled for realms 10–12, and an imprint choice at realm 12.
- [ ] Run `npm test -- --test-name-pattern="realm"`; expect failure.
- [ ] Encode the approved interactions: drag (1), observe (2), choices (3, 4, 6, 7), light observe (5, 8, 9), autoplay (10, 11), imprint (12). Map each option to one or two heart-action weights; later scenes use higher weights.
- [ ] Run `npm test`; expect all tests to pass.
- [ ] Commit only realm data and its test with message `feat: make twelve realms game-free`.

### Task 3: Refactor the page into progressive browser narrative

**Files:** Modify `web/app/page.tsx`, `web/app/globals.css`; modify `web/tests/rendered-html.test.mjs`.

**Interfaces:** The page may render only `cover`, `intro`, `openingRubbing`, `realm`, and `sign` states. Realm interaction completion calls `recordHeartAction()` and advances to the next realm.

- [ ] Write failing rendered-HTML tests that assert no `<iframe>` or `/games/` string, stage includes `aspect-ratio: 16 / 9`, and the sign heading is absent before completion.
- [ ] Run `npm test`; expect failure.
- [ ] Delete `MiniGame`, `GameTop`, and the `game` state/page branch. Implement pointer/keyboard drag for realm 1, a 2-second dwell completion for observe modes, choices as ink-style buttons, and 4-second auto-advance for realms 10–11 with an accessible continue control. Hide progress after 8 and hints after 10; honor reduced-motion.
- [ ] Run `npm test` and `npm run build` from `web/`; expect success.
- [ ] Commit only page, CSS, and rendered test with message `feat: replace games with progressive browser interactions`.

### Task 4: Present and save the Zen personality sign

**Files:** Modify `web/app/page.tsx`, `web/app/globals.css`, `web/tests/rendered-html.test.mjs`.

**Interfaces:** `SignPage` shows title `你此刻所持的一签`, primary sign, optional transition phrase, reflection, `保存此签`, and `再游一程`.

- [ ] Write failing rendered-HTML assertions for the title, the non-diagnostic sentence `它不定义你，只映照你走过的这一程。`, and save/restart controls.
- [ ] Run `npm test`; expect failure.
- [ ] Render a paper-and-seal result page. Save via `navigator.share` when available, otherwise download an SVG text sign; a share/download error must leave title and reflection visible. Restart clears in-memory journey state.
- [ ] Run `npm test && npm run build`; expect success.
- [ ] Commit only edited page/CSS/tests with message `feat: present shareable zen personality sign`.

### Task 5: Final no-game and horizontal QA

**Files:** Modify `web/README.md`; modify or create `web/tests/rendered-html.test.mjs`.

**Interfaces:** Test suite validates completion, four-sign variation, no iframe, and no vertical-scroll CSS contract.

- [ ] Add tests that exercise hold-oriented and release-oriented sequences and assert different principal signs, plus assertions for no iframe and `overflow: hidden` on the app shell.
- [ ] Run `npm test`; expect failure before the final assertions and documentation are added.
- [ ] Document `npm install`, `npm run dev`, `npm test`, and `npm run build`, including the fact that the first browser release does not embed Godot.
- [ ] Run `npm test && npm run build && npm run lint`; expect success.
- [ ] Commit only the QA/test/readme changes with message `test: verify game-free browser journey`.

## Plan Self-Review

Tasks 1–2 implement the content and personality model, task 3 implements the interaction progression and removes games, task 4 implements final sign sharing, and task 5 verifies the requested constraints. No task creates a new project or alters existing Godot artifacts.
