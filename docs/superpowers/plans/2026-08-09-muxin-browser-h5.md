# 牧心十二境浏览器 H5 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a 16:9 browser narrative of the twelve realms that progressively reduces interaction and concludes with a shareable Zen personality sign.

**Architecture:** Use a Vite + React + TypeScript single-page app. A data-driven twelve-scene configuration feeds a scene renderer; a pure scoring module accumulates `hold / observe / harmonize / release` values and a result module turns them into a principal sign and optional transition sign. Local storage persists the current journey, while the UI remains fully playable with mouse, keyboard, or touch.

**Tech Stack:** Vite, React, TypeScript, CSS, Vitest, React Testing Library, Playwright.

## Global Constraints

- Use the existing 12 PNG files in `审查版_H5制作包/` as the only required first-version visual assets.
- Render a 16:9 horizontal stage without document scrolling; target desktop browsers and exhibition touch screens.
- Journey duration must be 7–9 minutes; no failure, score, ranking, account, personal-data collection, or game-engine dependency.
- Reduce visible controls from realm 8 and remove explicit interaction hints from realm 10 onward.
- Present results as “禅意人格签” that reflect this journey only; never phrase them as clinical or fixed personality conclusions.
- Implement the four internal heart-actions exactly as `hold`, `observe`, `harmonize`, and `release`.

---

## File Structure

| Path | Responsibility |
|---|---|
| `package.json`, `vite.config.ts`, `tsconfig.json` | Browser application and test tooling |
| `src/domain/types.ts` | Shared scene, action, result, and persisted-state types |
| `src/domain/scoring.ts` | Pure scoring, tie handling, and result derivation |
| `src/domain/scoring.test.ts` | Unit coverage for main and transition signs |
| `src/content/scenes.ts` | All twelve scene copy, choices, action weights, and interaction modes |
| `src/state/useJourney.ts` | Scene progression, local persistence, and completion state |
| `src/state/useJourney.test.tsx` | State restoration and progression coverage |
| `src/components/Stage.tsx` | Fixed-ratio scene frame, input adapters, and progressive UI removal |
| `src/components/ChoiceInk.tsx` | Three-option ink-text choice control |
| `src/components/ResultSign.tsx` | Principal / transition sign presentation and restart/save actions |
| `src/App.tsx`, `src/styles.css` | App composition and visual system |
| `e2e/journey.spec.ts` | End-to-end completion and result-variation checks |

## Task 1: Bootstrap the app and stage assets

**Files:**
- Create: `package.json`, `vite.config.ts`, `tsconfig.json`, `index.html`
- Create: `src/main.tsx`, `src/App.tsx`, `src/styles.css`, `src/vite-env.d.ts`
- Create: `public/scenes/01_未牧.png` through `public/scenes/12_心月图.png`

**Interfaces:**
- Produces a runnable `npm run dev` app and `npm test` command for later tasks.

- [ ] **Step 1: Create the Vite React TypeScript project and copy the 12 approved assets**

```bash
npm create vite@latest . -- --template react-ts
npm install
mkdir -p public/scenes
cp 审查版_H5制作包/01_未牧.png public/scenes/
cp 审查版_H5制作包/02_初调.png public/scenes/
cp 审查版_H5制作包/03_受制.png public/scenes/
cp 审查版_H5制作包/04_回首.png public/scenes/
cp 审查版_H5制作包/05_驯服.png public/scenes/
cp 审查版_H5制作包/06_无碍.png public/scenes/
cp 审查版_H5制作包/07_任运.png public/scenes/
cp 审查版_H5制作包/08_相忘.png public/scenes/
cp 审查版_H5制作包/09_独照_吹笛替换版.png public/scenes/09_独照.png
cp 审查版_H5制作包/10_双忘.png public/scenes/
cp 审查版_H5制作包/11_禅定.png public/scenes/
cp 审查版_H5制作包/12_心月图.png public/scenes/
```

- [ ] **Step 2: Add testing dependencies and scripts**

```bash
npm install -D vitest jsdom @testing-library/react @testing-library/jest-dom @testing-library/user-event playwright
npx playwright install chromium
```

Set scripts to `dev: vite`, `build: tsc -b && vite build`, `test: vitest run`, and `test:e2e: playwright test`.

- [ ] **Step 3: Implement the fixed-ratio shell**

```tsx
export default function App() {
  return <main className="app-shell"><section className="stage-shell" aria-label="牧心十二境" /></main>
}
```

```css
.app-shell { min-height: 100vh; display: grid; place-items: center; overflow: hidden; background: #191814; }
.stage-shell { width: min(100vw, calc(100vh * 16 / 9)); aspect-ratio: 16 / 9; position: relative; overflow: hidden; background: #f6f1e5; }
```

- [ ] **Step 4: Run build and inspect the stage**

Run: `npm run build`

Expected: exit code 0; the rendered app has no document scroll bar at 1440×900.

- [ ] **Step 5: Commit**

```bash
git add package.json package-lock.json vite.config.ts tsconfig.json index.html src public/scenes
git commit -m "chore: bootstrap muxin browser h5"
```

## Task 2: Define domain types and testable personality-sign scoring

**Files:**
- Create: `src/domain/types.ts`, `src/domain/scoring.ts`, `src/domain/scoring.test.ts`

**Interfaces:**
- Produces `HeartAction`, `HeartTotals`, `JourneyResult`, `emptyTotals()`, `recordAction()`, and `deriveResult()`.
- Consumed by `scenes.ts`, `useJourney.ts`, and `ResultSign.tsx`.

- [ ] **Step 1: Write failing scoring tests**

```ts
import { deriveResult, emptyTotals, recordAction } from './scoring';

it('derives 持绳签 from hold-dominant actions', () => {
  const totals = recordAction(emptyTotals(), { hold: 5 });
  expect(deriveResult(totals).primary.key).toBe('hold');
});

it('adds a transition phrase when the two leading actions are close', () => {
  const result = deriveResult({ hold: 5, observe: 4, harmonize: 0, release: 0 });
  expect(result.transition).toBe('持绳而能回首');
});
```

- [ ] **Step 2: Run the unit test to verify it fails**

Run: `npm test -- src/domain/scoring.test.ts`

Expected: FAIL because `./scoring` does not exist.

- [ ] **Step 3: Implement stable types and scoring**

```ts
export type HeartAction = 'hold' | 'observe' | 'harmonize' | 'release';
export type HeartTotals = Record<HeartAction, number>;
export type ActionWeights = Partial<Record<HeartAction, number>>;

export function emptyTotals(): HeartTotals {
  return { hold: 0, observe: 0, harmonize: 0, release: 0 };
}
export function recordAction(totals: HeartTotals, weights: ActionWeights): HeartTotals {
  return { ...totals, ...Object.fromEntries(Object.entries(weights).map(([key, value]) => [key, totals[key as HeartAction] + (value ?? 0)])) } as HeartTotals;
}
```

Define sign copy for `持绳签`, `观照签`, `同行签`, and `任运签`. Sort ties using the fixed order `release`, `harmonize`, `observe`, `hold`; emit a transition only when the runner-up is within one point and a configured phrase exists.

- [ ] **Step 4: Run the test suite**

Run: `npm test -- src/domain/scoring.test.ts`

Expected: PASS, including main-sign, tie, and transition-sign test cases.

- [ ] **Step 5: Commit**

```bash
git add src/domain
git commit -m "feat: add heart-action scoring"
```

## Task 3: Encode the twelve realms as content configuration

**Files:**
- Create: `src/content/scenes.ts`, `src/content/scenes.test.ts`
- Modify: `src/domain/types.ts`

**Interfaces:**
- Consumes `ActionWeights` and `HeartAction` from `src/domain/types.ts`.
- Produces `SCENES: SceneDefinition[]` with exactly 12 ordered items and `getScene(id: number)`.

- [ ] **Step 1: Write failing content tests**

```ts
import { SCENES } from './scenes';

it('contains all twelve ordered realms', () => {
  expect(SCENES.map((scene) => scene.id)).toEqual([1,2,3,4,5,6,7,8,9,10,11,12]);
});
it('removes hints from 双忘 onward', () => {
  expect(SCENES.slice(9).every((scene) => scene.showHint === false)).toBe(true);
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `npm test -- src/content/scenes.test.ts`

Expected: FAIL because the scene configuration is absent.

- [ ] **Step 3: Add the scene schema and all 12 content records**

```ts
export type InteractionKind = 'intro' | 'drag' | 'choice' | 'observe' | 'autoplay' | 'imprint';
export interface SceneDefinition {
  id: number; title: string; image: string; copy: string; interaction: InteractionKind;
  choices?: Array<{ id: string; label: string; weights: ActionWeights }>;
  showProgress: boolean; showHint: boolean;
}
```

Encode the approved actions: drag at 未牧; distance observation at 初调; choices at 受制、无碍、任运; back-look at 回首; listening at 相忘; slow following at 独照; autoplay at 双忘、禅定; and `牛 / 来路 / 空白` imprint choices at 心月图. Use these exact choice IDs: `tighten`, `release`, `untie` (受制); `forward`, `look-back`, `wait` (回首); `hold-rope`, `hang-rope`, `let-go` (无碍); `choose-path`, `follow`, `watch` (任运); and `cow`, `road`, `empty` (心月图). Add `observe` to the 初调 completion action. Give later scenes higher action weights than early scenes.

- [ ] **Step 4: Run content tests**

Run: `npm test -- src/content/scenes.test.ts`

Expected: PASS; count is 12 and UI hints are disabled for scenes 10–12.

- [ ] **Step 5: Commit**

```bash
git add src/content
git commit -m "feat: add twelve-realm narrative content"
```

## Task 4: Implement journey state, persistence, and recovery

**Files:**
- Create: `src/state/useJourney.ts`, `src/state/useJourney.test.tsx`

**Interfaces:**
- Consumes `SCENES`, `recordAction`, `emptyTotals`, `deriveResult`.
- Produces `useJourney(): { scene, index, totals, choose(weights), continue(), restart(), result }`.

- [ ] **Step 1: Write failing hook tests**

```tsx
it('persists the next realm and totals after a choice', () => {
  const { result } = renderHook(() => useJourney());
  act(() => result.current.choose({ observe: 2 }));
  expect(result.current.index).toBe(1);
  expect(JSON.parse(localStorage.getItem('muxin-journey-v1')!).totals.observe).toBe(2);
});

it('restarts by clearing persisted state', () => {
  const { result } = renderHook(() => useJourney());
  act(() => result.current.restart());
  expect(localStorage.getItem('muxin-journey-v1')).toBeNull();
});
```

- [ ] **Step 2: Run hook tests to verify they fail**

Run: `npm test -- src/state/useJourney.test.tsx`

Expected: FAIL because the hook is absent.

- [ ] **Step 3: Implement versioned local state**

```ts
const STORAGE_KEY = 'muxin-journey-v1';
type PersistedJourney = { index: number; totals: HeartTotals };
```

On initialization, parse only a valid object with an index in `0..11`; otherwise start from scene 1. After `choose()` and `continue()`, persist the new state. Expose `result` only after scene 12 is completed. Make `restart()` remove the storage key and restore the initial state.

- [ ] **Step 4: Run hook tests**

Run: `npm test -- src/state/useJourney.test.tsx`

Expected: PASS for persistence, corrupt-storage fallback, and restart.

- [ ] **Step 5: Commit**

```bash
git add src/state
git commit -m "feat: add resumable journey state"
```

## Task 5: Build the progressive stage and input interactions

**Files:**
- Create: `src/components/Stage.tsx`, `src/components/ChoiceInk.tsx`, `src/components/Stage.test.tsx`
- Modify: `src/App.tsx`, `src/styles.css`

**Interfaces:**
- Consumes `SceneDefinition` and `useJourney()`.
- Produces the visual scene, keyboard/touch/mouse input, controls, progress, and accessible labels.

- [ ] **Step 1: Write failing stage tests**

```tsx
it('renders ink choices and records the selected action', async () => {
  render(<Stage scene={choiceScene} onChoose={onChoose} onContinue={vi.fn()} />);
  await userEvent.click(screen.getByRole('button', { name: '松一点' }));
  expect(onChoose).toHaveBeenCalledWith({ harmonize: 2, release: 1 });
});
it('does not render an explicit hint when showHint is false', () => {
  render(<Stage scene={{ ...choiceScene, showHint: false }} onChoose={vi.fn()} onContinue={vi.fn()} />);
  expect(screen.queryByText(/轻触|拖动|停留/)).not.toBeInTheDocument();
});
```

- [ ] **Step 2: Run component tests to verify they fail**

Run: `npm test -- src/components/Stage.test.tsx`

Expected: FAIL because `Stage` is absent.

- [ ] **Step 3: Implement the renderer and input adapters**

```tsx
<section className="stage" data-testid="stage">
<img className="scene-image" src={scene.image} alt={`${scene.title} 场景`} />
{scene.showProgress && <p className="scene-progress">第 {scene.id} 境</p>}
{scene.choices && <ChoiceInk choices={scene.choices} onChoose={onChoose} />}
</section>
```

Give each ink choice `data-testid={`choice-${choice.id}`}` and every non-choice advance control `data-testid="scene-continue"`. For `drag`, handle pointer down/move/up and keyboard arrows; for `observe`, use a 2-second dwell timer with a visible but unobtrusive focus ring; for `autoplay`, continue after 4 seconds and provide an accessible “继续” button that is visually hidden only when the interaction is intentionally absent. Respect `prefers-reduced-motion` by replacing movement with opacity fades.

- [ ] **Step 4: Compose the app and verify the visual progression**

Run: `npm run dev`

Expected: scene 1 fills the 16:9 stage; scenes 8–9 have diminished chrome; scenes 10–11 show no visible hint or progress; all core actions work with mouse, touch, and keyboard.

- [ ] **Step 5: Run component tests**

Run: `npm test -- src/components/Stage.test.tsx`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add src/components src/App.tsx src/styles.css
git commit -m "feat: render progressive twelve-realm stage"
```

## Task 6: Render, save, and restart the Zen personality sign

**Files:**
- Create: `src/components/ResultSign.tsx`, `src/components/ResultSign.test.tsx`
- Modify: `src/App.tsx`, `src/styles.css`

**Interfaces:**
- Consumes `JourneyResult` from `deriveResult()`.
- Produces the principal sign, optional transition line, image-save action, and restart action.

- [ ] **Step 1: Write failing result tests**

```tsx
it('shows the result as a journey reflection, not a diagnosis', () => {
  render(<ResultSign result={holdResult} onRestart={vi.fn()} />);
  expect(screen.getByText('你此刻所持的一签')).toBeInTheDocument();
  expect(screen.getByText('持绳签')).toBeInTheDocument();
  expect(screen.getByText('它不定义你，只映照你走过的这一程。')).toBeInTheDocument();
});
```

- [ ] **Step 2: Run result tests to verify they fail**

Run: `npm test -- src/components/ResultSign.test.tsx`

Expected: FAIL because `ResultSign` is absent.

- [ ] **Step 3: Implement sign composition and export fallback**

```tsx
<section className="result-sign" aria-label="禅意人格签">
  <p>你此刻所持的一签</p><h1>{result.primary.name}</h1>
  <p>{result.transition}</p><p>{result.primary.reflection}</p>
  <button onClick={saveSign}>保存此签</button><button onClick={onRestart}>再游一程</button>
</section>
```

Use the browser Web Share API when available. Otherwise create a downloadable SVG string containing only the sign text and a simple seal circle, then download it as `牧心十二境-<sign-key>.svg`; this avoids canvas image-origin restrictions. On failure, show a copyable title and reflection instead of suppressing the result.

- [ ] **Step 4: Run result tests**

Run: `npm test -- src/components/ResultSign.test.tsx`

Expected: PASS; principal name, transition phrase, reflection statement, save fallback, and restart are covered.

- [ ] **Step 5: Commit**

```bash
git add src/components/ResultSign.tsx src/components/ResultSign.test.tsx src/App.tsx src/styles.css
git commit -m "feat: add zen personality sign result"
```

## Task 7: Complete user-path QA and production build verification

**Files:**
- Create: `playwright.config.ts`, `e2e/journey.spec.ts`, `README.md`

**Interfaces:**
- Consumes the running Vite app.
- Produces repeatable completion, variation, and horizontal-layout checks.

- [ ] **Step 1: Write the failing end-to-end journey tests**

```ts
async function completeHoldPath(page: Page) {
  await page.goto('/');
  await page.locator('[data-testid="stage"]').hover({ position: { x: 120, y: 420 } });
  await page.mouse.down(); await page.mouse.move(1320, 420, { steps: 8 }); await page.mouse.up();
  await page.waitForTimeout(2100);
  await page.getByTestId('choice-observe').click();
  await page.getByTestId('choice-tighten').click();
  await page.getByTestId('choice-forward').click();
  await page.getByTestId('scene-continue').click();
  await page.getByTestId('choice-hold-rope').click();
  await page.getByTestId('choice-choose-path').click();
  await page.getByTestId('scene-continue').click();
  await page.getByTestId('scene-continue').click();
  await page.waitForTimeout(4100);
  await page.waitForTimeout(4100);
  await page.getByTestId('choice-cow').click();
}

test('a complete journey reaches a sign without page scrolling', async ({ page }) => {
  await completeHoldPath(page);
  await expect(page.getByText('你此刻所持的一签')).toBeVisible();
  expect(await page.evaluate(() => document.documentElement.scrollHeight <= window.innerHeight)).toBeTruthy();
});
```

- [ ] **Step 2: Run E2E test to verify the new harness fails before configuration exists**

Run: `npm run test:e2e -- e2e/journey.spec.ts`

Expected: FAIL because `playwright.config.ts` has not been created yet.

- [ ] **Step 3: Add Playwright configuration, complete the release-path test, and document local use**

Create `playwright.config.ts` with `webServer.command: 'npm run dev -- --host 127.0.0.1'`, `webServer.url: 'http://127.0.0.1:5173'`, and desktop projects at 1440×900 and 1920×1080. Add a release-oriented helper that selects `choice-observe`, `choice-release`, `choice-look-back`, `choice-let-go`, `choice-follow`, and `choice-empty`; assert its result heading is `任运签` and differs from the hold path's `持绳签`. Document `npm install`, `npm run dev`, `npm test`, `npm run test:e2e`, and `npm run build` in `README.md`.

- [ ] **Step 4: Run all verification commands**

Run: `npm test && npm run test:e2e && npm run build`

Expected: all commands exit 0; both result paths finish; no vertical scroll at 1440×900 and 1920×1080.

- [ ] **Step 5: Commit**

```bash
git add playwright.config.ts e2e README.md
git commit -m "test: verify complete browser journey"
```

## Plan Self-Review

- Spec coverage: tasks 1 and 5 implement the horizontal browser stage, tasks 2–4 implement behavior tracking and persistent flow, task 6 implements the four Zen personality signs and saving, and task 7 verifies completion, result variation, and no-scroll constraints.
- Placeholder scan: no deferred implementation steps or unspecified tests remain.
- Type consistency: `HeartAction`, `HeartTotals`, `ActionWeights`, `SceneDefinition`, `JourneyResult`, `recordAction()`, `deriveResult()`, and `useJourney()` are defined before their consuming tasks.
