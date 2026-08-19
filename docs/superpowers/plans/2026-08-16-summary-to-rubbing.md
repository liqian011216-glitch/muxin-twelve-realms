# Summary to Rubbing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the unchanged final cultural-introduction frame open the existing stone-rubbing game when the player clicks anywhere on it.

**Architecture:** Extend the frame hotspot model with a single non-frame action, `rubbing`, while preserving all existing numeric frame transitions. The page resolves a hotspot into either another frame or one full-canvas iframe, so entering rubbing unmounts the introduction canvas and cannot create duplicate game instances.

**Tech Stack:** React client component, TypeScript, Node test runner, existing Godot Web export.

## Global Constraints

- Keep `public/frames/15-summary.png` unchanged and add no visible button, label, or overlay.
- The whole final frame is the click target.
- Load `/games/godot/?game=stone` inside the current page, not a new window.
- Render only one rubbing iframe.
- Do not connect rubbing completion to the twelve realms in this task.
- Do not add a return control in this task.

---

### Task 1: Model the final-frame rubbing action

**Files:**
- Modify: `web/.worktrees/muxin-cover-step/app/frame-flow.ts`
- Modify: `web/.worktrees/muxin-cover-step/tests/frame-flow.test.mjs`

**Interfaces:**
- Consumes: existing `FRAME_SCREENS` and `getTargetIndex(screenIndex, hotspotId)`.
- Produces: `FrameAction = { type: "frame"; targetIndex: number } | { type: "rubbing" }` and `getHotspotAction(screenIndex, hotspotId): FrameAction`.

- [ ] **Step 1: Write the failing final-frame action tests**

Update the hotspot validation to accept exactly one destination type, replace the terminal-summary assertion, and add:

```js
test("the unchanged summary frame opens rubbing from its whole surface", () => {
  assert.deepEqual(flow.FRAME_SCREENS[15].hotspots, [{
    id: "enter-rubbing",
    label: "进入拓印",
    rect: { left: 0, top: 0, width: 100, height: 100 },
    action: "rubbing",
  }]);
  assert.deepEqual(flow.getHotspotAction(15, "enter-rubbing"), { type: "rubbing" });
  assert.throws(() => flow.getTargetIndex(15, "enter-rubbing"), /does not target a frame/);
});
```

- [ ] **Step 2: Run the focused test and verify RED**

Run: `node --test tests/frame-flow.test.mjs`

Expected: FAIL because the summary has no hotspot and `getHotspotAction` does not exist.

- [ ] **Step 3: Implement the action model minimally**

In `app/frame-flow.ts`, allow a hotspot to carry either `targetIndex` or `action: "rubbing"`, add the whole-page summary hotspot, and resolve it with:

```ts
export type FrameAction =
  | { type: "frame"; targetIndex: number }
  | { type: "rubbing" };

export function getHotspotAction(screenIndex: number, hotspotId: string): FrameAction {
  const hotspot = FRAME_SCREENS[screenIndex]?.hotspots.find((item) => item.id === hotspotId);
  if (!hotspot) throw new RangeError(`Unknown hotspot ${hotspotId} on screen ${screenIndex}`);
  return hotspot.action === "rubbing"
    ? { type: "rubbing" }
    : { type: "frame", targetIndex: hotspot.targetIndex };
}
```

Keep `getTargetIndex` as a compatibility wrapper and throw `Hotspot enter-rubbing does not target a frame` for the rubbing action.

- [ ] **Step 4: Run the focused test and verify GREEN**

Run: `node --test tests/frame-flow.test.mjs`

Expected: all frame-flow tests PASS.

- [ ] **Step 5: Commit the model and contract**

```bash
git add app/frame-flow.ts tests/frame-flow.test.mjs
git commit -m "feat: connect summary to rubbing action"
```

### Task 2: Render a single rubbing experience

**Files:**
- Modify: `web/.worktrees/muxin-cover-step/app/page.tsx`
- Modify: `web/.worktrees/muxin-cover-step/app/globals.css`
- Create: `web/.worktrees/muxin-cover-step/tests/summary-rubbing-page.test.mjs`
- Modify: `web/.worktrees/muxin-cover-step/scripts/test.mjs`

**Interfaces:**
- Consumes: `getHotspotAction(screenIndex, hotspotId): FrameAction`.
- Produces: page state `experience: "frames" | "rubbing"` and one iframe with title `石刻拓印`.

- [ ] **Step 1: Write the failing rendering contract**

Create `tests/summary-rubbing-page.test.mjs`:

```js
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

test("the page switches the final whole-frame action to one rubbing iframe", async () => {
  const page = await readFile(new URL("../app/page.tsx", import.meta.url), "utf8");
  assert.match(page, /getHotspotAction/);
  assert.match(page, /setExperience\("rubbing"\)/);
  assert.match(page, /experience === "rubbing"/);
  assert.equal((page.match(/<iframe/g) ?? []).length, 1);
  assert.match(page, /src="\/games\/godot\/\?game=stone"/);
  assert.match(page, /title="石刻拓印"/);
});

test("the rubbing iframe fills the established stage", async () => {
  const css = await readFile(new URL("../app/globals.css", import.meta.url), "utf8");
  assert.match(css, /\.rubbing-frame\s*\{[^}]*width:\s*100%[^}]*height:\s*100%[^}]*border:\s*0/s);
});
```

Add this test path to `scripts/test.mjs`.

- [ ] **Step 2: Run the focused test and verify RED**

Run: `node --test tests/summary-rubbing-page.test.mjs`

Expected: FAIL because page state and the iframe do not exist.

- [ ] **Step 3: Implement the single-state switch**

In `app/page.tsx`, add `experience` state, resolve clicks with `getHotspotAction`, set rubbing once for the rubbing action, and return:

```tsx
if (experience === "rubbing") {
  return (
    <main className="figma-stage rubbing-stage">
      <iframe
        className="rubbing-frame"
        src="/games/godot/?game=stone"
        title="石刻拓印"
        allow="autoplay; fullscreen"
      />
    </main>
  );
}
```

Add only the iframe sizing rule:

```css
.rubbing-frame {
  width: 100%;
  height: 100%;
  border: 0;
}
```

- [ ] **Step 4: Run the focused and complete tests**

Run: `node --test tests/summary-rubbing-page.test.mjs && npm test`

Expected: focused tests PASS, production build succeeds, and the complete suite passes.

- [ ] **Step 5: Commit the page transition**

```bash
git add app/page.tsx app/globals.css tests/summary-rubbing-page.test.mjs scripts/test.mjs
git commit -m "feat: enter rubbing from final introduction"
```

### Task 3: Browser acceptance

**Files:**
- Create: `.audit/step-reviews/07-summary-before-rubbing.jpg`
- Create: `.audit/step-reviews/07-rubbing-entered.jpg`

**Interfaces:**
- Consumes: the local server at `http://localhost:3000/`.
- Produces: two screenshots demonstrating an unchanged final frame and the entered rubbing scene.

- [ ] **Step 1: Open the local page and progress to frame 15**

Use the browser to click through the existing flow without changing any earlier choices or assets.

- [ ] **Step 2: Capture the unchanged final frame**

Save `.audit/step-reviews/07-summary-before-rubbing.jpg` and confirm it is the original `15-summary.png` without overlays.

- [ ] **Step 3: Click once anywhere on the final frame**

Confirm the URL remains on the current site and exactly one iframe loads `/games/godot/?game=stone`.

- [ ] **Step 4: Capture the entered rubbing scene**

Save `.audit/step-reviews/07-rubbing-entered.jpg` and confirm the initial state is `壹  清尘` at 0%.

- [ ] **Step 5: Run final verification**

Run: `npm test && git diff --check`

Expected: production build succeeds, all tests pass, and `git diff --check` prints no errors.
