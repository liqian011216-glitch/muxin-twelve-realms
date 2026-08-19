# Local Figma 16-Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current mixed template experience with a fixed-ratio, keyboard-accessible 16-screen website that displays every approved 1066 × 600 local Figma export in order.

**Architecture:** A typed screen registry maps the 16 approved Figma node IDs to the existing local frame images and normalized hotspot rectangles. A single client-side frame viewer renders the selected image inside a fixed 1066:600 canvas, overlays semantic buttons, and moves through the registry without reflowing the design. Existing narrative and game modules remain on disk but are no longer part of the active page flow.

**Tech Stack:** Next.js 16, React 19, TypeScript, CSS, Node test runner, Vinext/Vite

## Global Constraints

- Use only `web/public/frames/00-cover.png` through `web/public/frames/15-summary.png` as the visual layer for the 16 approved screens.
- Every approved frame is exactly 1066 × 600 pixels.
- Scale the complete canvas uniformly with `min(viewport width / 1066, viewport height / 600)`; center it; never crop or reflow it.
- Keep interactive regions as semantic HTML buttons with accessible labels and visible keyboard focus.
- Do not introduce responsive rearrangement, new narrative copy, new screens, authentication, persistence, or unrelated Godot changes.
- The final screen is terminal because the approved local export contains no visible restart or continuation control.

---

## File Structure

- Create `web/app/frame-flow.ts`: authoritative frame/node/hotspot registry plus pure navigation helpers.
- Create `web/tests/frame-flow.test.mjs`: registry completeness, PNG dimension, hotspot target, and navigation tests.
- Modify `web/app/page.tsx`: replace the mixed journey/template UI with one data-driven fixed-frame viewer.
- Modify `web/app/globals.css`: retain only fixed canvas, image, hotspot, focus, and loading styles needed by the active page.
- Modify `web/tests/rendered-html.test.mjs`: verify the built page serves the approved first frame and the source uses the complete registry.
- Modify `web/scripts/test.mjs`: include the new frame-flow test in the project test command.

---

### Task 1: Define and validate the 16-screen frame registry

**Files:**
- Create: `web/app/frame-flow.ts`
- Create: `web/tests/frame-flow.test.mjs`

**Interfaces:**
- Produces: `FRAME_WIDTH = 1066`, `FRAME_HEIGHT = 600`.
- Produces: `FrameHotspot`, with `id`, `label`, normalized `rect`, `targetIndex`, and optional `choice`.
- Produces: `FrameScreen`, with `index`, `nodeId`, `image`, `alt`, and `hotspots`.
- Produces: `FRAME_SCREENS`, the ordered immutable list consumed by `app/page.tsx`.
- Produces: `getTargetIndex(screenIndex, hotspotId): number`, used by the viewer to validate and perform navigation.

- [ ] **Step 1: Write the failing registry tests**

Create `web/tests/frame-flow.test.mjs` with tests that import the future registry, assert all 16 mappings, parse every PNG IHDR, and validate every hotspot target:

```js
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const flow = await import("../app/frame-flow.ts");
const expectedNodes = [
  "2:2", "3:36", "3:41", "3:64", "4:165", "7:217", "13:20", "29:58",
  "15:40", "29:76", "29:94", "29:130", "29:112", "29:148", "29:166", "29:304",
];

test("maps the sixteen approved Figma nodes to sixteen local frames", () => {
  assert.equal(flow.FRAME_WIDTH, 1066);
  assert.equal(flow.FRAME_HEIGHT, 600);
  assert.equal(flow.FRAME_SCREENS.length, 16);
  assert.deepEqual(flow.FRAME_SCREENS.map((screen) => screen.nodeId), expectedNodes);
  assert.deepEqual(
    flow.FRAME_SCREENS.map((screen) => screen.image),
    Array.from({ length: 16 }, (_, index) => {
      const names = ["cover", "intro", "choice", "stone-intro", "untrained", "first-taming", "restrained", "turning-back", "tamed", "unforced", "forgotten", "solitary", "both-gone", "meditation", "mind-moon", "summary"];
      return `/frames/${String(index).padStart(2, "0")}-${names[index]}.png`;
    }),
  );
});

test("all approved local frame exports are 1066 by 600 PNGs", async () => {
  for (const screen of flow.FRAME_SCREENS) {
    const bytes = await readFile(new URL(`../public${screen.image}`, import.meta.url));
    assert.equal(bytes.toString("ascii", 1, 4), "PNG");
    assert.equal(bytes.readUInt32BE(16), 1066, screen.image);
    assert.equal(bytes.readUInt32BE(20), 600, screen.image);
  }
});

test("all hotspot rectangles and targets are valid", () => {
  for (const screen of flow.FRAME_SCREENS) {
    for (const hotspot of screen.hotspots) {
      assert.ok(hotspot.rect.left >= 0 && hotspot.rect.top >= 0);
      assert.ok(hotspot.rect.width > 0 && hotspot.rect.height > 0);
      assert.ok(hotspot.rect.left + hotspot.rect.width <= 100);
      assert.ok(hotspot.rect.top + hotspot.rect.height <= 100);
      assert.ok(hotspot.targetIndex >= 0 && hotspot.targetIndex < 16);
      assert.equal(flow.getTargetIndex(screen.index, hotspot.id), hotspot.targetIndex);
    }
  }
  assert.equal(flow.FRAME_SCREENS[15].hotspots.length, 0);
});
```

- [ ] **Step 2: Run the registry tests and verify RED**

Run:

```bash
cd web
node --test tests/frame-flow.test.mjs
```

Expected: FAIL with `ERR_MODULE_NOT_FOUND` for `app/frame-flow.ts`.

- [ ] **Step 3: Implement the minimal registry and navigation helper**

Create `web/app/frame-flow.ts`. Use normalized percentage rectangles so they scale with the image:

```ts
export const FRAME_WIDTH = 1066;
export const FRAME_HEIGHT = 600;

export type FrameRect = { left: number; top: number; width: number; height: number };
export type FrameHotspot = {
  id: string;
  label: string;
  rect: FrameRect;
  targetIndex: number;
  choice?: "untrained" | "restrained" | "free";
};
export type FrameScreen = {
  index: number;
  nodeId: string;
  image: string;
  alt: string;
  hotspots: readonly FrameHotspot[];
};

const whole: FrameRect = { left: 0, top: 0, width: 100, height: 100 };
const previous: FrameRect = { left: 88.2, top: 86.8, width: 4.2, height: 9.2 };
const next: FrameRect = { left: 92.5, top: 86.8, width: 4.2, height: 9.2 };

const nodeIds = [
  "2:2", "3:36", "3:41", "3:64", "4:165", "7:217", "13:20", "29:58",
  "15:40", "29:76", "29:94", "29:130", "29:112", "29:148", "29:166", "29:304",
] as const;
const names = [
  "cover", "intro", "choice", "stone-intro", "untrained", "first-taming", "restrained", "turning-back",
  "tamed", "unforced", "forgotten", "solitary", "both-gone", "meditation", "mind-moon", "summary",
] as const;
const labels = [
  "牧牛十二境封面", "你所见之牛亦是你所观之心", "问心选择", "千年前有人将这份心境刻于石上",
  "未牧", "初调", "受制", "回首", "驯服", "任运", "相忘", "独照", "双泯", "禅定", "心月图", "一轮心月映照牧心十二境",
] as const;

function realmHotspots(index: number): readonly FrameHotspot[] {
  return [
    { id: "previous", label: "上一境", rect: previous, targetIndex: index - 1 },
    { id: "next", label: index === 14 ? "开启牧心十二境总结" : "下一境", rect: next, targetIndex: index + 1 },
  ];
}

export const FRAME_SCREENS: readonly FrameScreen[] = names.map((name, index) => ({
  index,
  nodeId: nodeIds[index],
  image: `/frames/${String(index).padStart(2, "0")}-${name}.png`,
  alt: labels[index],
  hotspots: index === 0
    ? [{ id: "start", label: "问心，开始旅程", rect: { left: 17.5, top: 70, width: 21, height: 12 }, targetIndex: 1 }]
    : index === 1
      ? [{ id: "continue", label: "继续问心", rect: whole, targetIndex: 2 }]
      : index === 2
        ? [
            { id: "untrained", label: "选择未牧之牛", rect: { left: 9.5, top: 31, width: 25, height: 57 }, targetIndex: 3, choice: "untrained" },
            { id: "restrained", label: "选择受制之牛", rect: { left: 37.5, top: 31, width: 25, height: 57 }, targetIndex: 3, choice: "restrained" },
            { id: "free", label: "选择自在之牛", rect: { left: 65, top: 31, width: 25, height: 57 }, targetIndex: 3, choice: "free" },
          ]
        : index === 3
          ? [{ id: "enter", label: "循迹入境", rect: whole, targetIndex: 4 }]
          : index >= 4 && index <= 14
            ? realmHotspots(index)
            : [],
}));

export function getTargetIndex(screenIndex: number, hotspotId: string): number {
  const hotspot = FRAME_SCREENS[screenIndex]?.hotspots.find((item) => item.id === hotspotId);
  if (!hotspot) throw new RangeError(`Unknown hotspot ${hotspotId} on screen ${screenIndex}`);
  return hotspot.targetIndex;
}
```

- [ ] **Step 4: Run the registry tests and verify GREEN**

Run `node --test tests/frame-flow.test.mjs` from `web`.

Expected: 3 tests PASS.

- [ ] **Step 5: Commit the registry**

```bash
git add web/app/frame-flow.ts web/tests/frame-flow.test.mjs
git commit -m "feat: define local Figma frame flow"
```

---

### Task 2: Render the fixed-ratio frame viewer and semantic hotspots

**Files:**
- Modify: `web/app/page.tsx`
- Modify: `web/app/globals.css`
- Modify: `web/tests/rendered-html.test.mjs`

**Interfaces:**
- Consumes: `FRAME_SCREENS` and `getTargetIndex` from `app/frame-flow.ts`; registry tests consume the fixed width and height constants.
- Produces: the default `Home` component with `screenIndex` and `openingChoice` client state.
- Produces: `.figma-stage`, `.figma-canvas`, `.figma-frame-image`, and `.figma-hotspot` CSS contracts.

- [ ] **Step 1: Replace the source assertions with failing viewer assertions**

In `web/tests/rendered-html.test.mjs`, replace the old mixed-flow source assertions with:

```js
test("uses the complete local Figma frame registry instead of the generic realm template", async () => {
  const [page, css, { FRAME_SCREENS }] = await Promise.all([
    readFile(new URL("../app/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/globals.css", import.meta.url), "utf8"),
    import("../app/frame-flow.ts"),
  ]);
  assert.match(page, /FRAME_SCREENS/);
  assert.match(page, /figma-hotspot/);
  assert.match(page, /openingChoice/);
  assert.doesNotMatch(page, /RealmPage|OpeningRubbing|MiniGame|SignPage/);
  assert.equal(FRAME_SCREENS.at(-1)?.image, "/frames/15-summary.png");
  assert.match(css, /aspect-ratio:\s*1066\s*\/\s*600/);
});
```

Update the built-output test to assert the first approved image is served:

```js
assert.match(html, /\/frames\/00-cover\.png/);
assert.match(html, /问心，开始旅程/);
```

- [ ] **Step 2: Run the rendered HTML test and verify RED**

Run:

```bash
node --test tests/rendered-html.test.mjs
```

Expected: FAIL because the old `page.tsx` still contains `RealmPage`, `OpeningRubbing`, `MiniGame`, and `SignPage`.

- [ ] **Step 3: Replace `app/page.tsx` with the registry-driven viewer**

Use the following structure:

```tsx
"use client";

import { useState } from "react";
import { FRAME_SCREENS, getTargetIndex } from "./frame-flow";

type OpeningChoice = "untrained" | "restrained" | "free" | null;

export default function Home() {
  const [screenIndex, setScreenIndex] = useState(0);
  const [openingChoice, setOpeningChoice] = useState<OpeningChoice>(null);
  const screen = FRAME_SCREENS[screenIndex];

  const activate = (hotspotId: string, choice?: Exclude<OpeningChoice, null>) => {
    if (choice) setOpeningChoice(choice);
    setScreenIndex(getTargetIndex(screenIndex, hotspotId));
  };

  return (
    <main className="figma-stage" data-screen-index={screenIndex} data-opening-choice={openingChoice ?? ""}>
      <section
        className="figma-canvas"
        aria-label={`${screen.alt}，第 ${screenIndex + 1} 页，共 ${FRAME_SCREENS.length} 页`}
      >
        <img className="figma-frame-image" src={screen.image} alt={screen.alt} draggable={false} />
        {screen.hotspots.map((hotspot) => (
          <button
            key={hotspot.id}
            type="button"
            className="figma-hotspot"
            aria-label={hotspot.label}
            onClick={() => activate(hotspot.id, hotspot.choice)}
            style={{
              left: `${hotspot.rect.left}%`,
              top: `${hotspot.rect.top}%`,
              width: `${hotspot.rect.width}%`,
              height: `${hotspot.rect.height}%`,
            }}
          />
        ))}
      </section>
    </main>
  );
}
```

- [ ] **Step 4: Replace active layout CSS with fixed uniform scaling**

Rewrite `web/app/globals.css` so the active page uses the exact image aspect ratio and does not reflow:

```css
* { box-sizing: border-box; }
html, body { margin: 0; width: 100%; height: 100%; overflow: hidden; background: #000; }
body { font-family: serif; }
.figma-stage {
  width: 100vw;
  height: 100svh;
  display: grid;
  place-items: center;
  overflow: hidden;
  background: #000;
}
.figma-canvas {
  position: relative;
  width: min(100vw, calc(100svh * 1066 / 600));
  aspect-ratio: 1066 / 600;
  overflow: hidden;
  background: #f7f1e6;
}
.figma-frame-image {
  display: block;
  width: 100%;
  height: 100%;
  object-fit: fill;
  user-select: none;
  pointer-events: none;
}
.figma-hotspot {
  position: absolute;
  z-index: 1;
  margin: 0;
  padding: 0;
  border: 0;
  background: transparent;
  cursor: pointer;
}
.figma-hotspot:focus-visible {
  outline: 2px solid #b56c49;
  outline-offset: -2px;
  background: rgb(255 255 255 / 8%);
}
```

- [ ] **Step 5: Build and run the rendered HTML test to verify GREEN**

Run `node node_modules/vinext/dist/cli.js build`, then `node --test tests/rendered-html.test.mjs` from `web`.

Expected: build succeeds and both rendered HTML tests PASS.

- [ ] **Step 6: Commit the viewer**

```bash
git add web/app/page.tsx web/app/globals.css web/tests/rendered-html.test.mjs
git commit -m "feat: render all sixteen Figma frame exports"
```

---

### Task 3: Integrate the new tests and verify the complete flow

**Files:**
- Modify: `web/scripts/test.mjs`
- Verify: `web/app/frame-flow.ts`
- Verify: `web/app/page.tsx`
- Verify: `web/app/globals.css`

**Interfaces:**
- Consumes: all code and tests from Tasks 1 and 2.
- Produces: one project test command that builds and runs frame-flow, journey, realms, and rendered-output regression tests.

- [ ] **Step 1: Write the failing project test-runner assertion**

Add this source assertion to `web/tests/frame-flow.test.mjs`:

```js
test("the project test runner includes the frame-flow contract", async () => {
  const runner = await readFile(new URL("../scripts/test.mjs", import.meta.url), "utf8");
  assert.match(runner, /tests\/frame-flow\.test\.mjs/);
});
```

- [ ] **Step 2: Run the assertion and verify RED**

Run `node --test tests/frame-flow.test.mjs`.

Expected: the new test FAILS because `scripts/test.mjs` does not yet list `tests/frame-flow.test.mjs`.

- [ ] **Step 3: Add the frame-flow test to the project test runner**

Change the final line of `web/scripts/test.mjs` to:

```js
run(["--test", "tests/frame-flow.test.mjs", "tests/journey.test.mjs", "tests/realms.test.mjs", "tests/rendered-html.test.mjs"]);
```

- [ ] **Step 4: Run the complete automated suite**

Run:

```bash
node scripts/test.mjs
```

Expected: Vinext production build succeeds and every Node test passes with no warnings or unhandled errors.

- [ ] **Step 5: Perform browser flow verification at the approved ratio**

With the existing development server running at `http://localhost:3000/`, verify:

1. The initial screen is exactly `00-cover.png` with no crop or reflow.
2. Start advances to `01-intro.png`; continuing advances to `02-choice.png`.
3. Each of the three choice regions advances to `03-stone-intro.png` and updates `data-opening-choice`.
4. The whole stone-intro screen advances to `04-untrained.png`.
5. The right arrow advances through frames 04–14; the left arrow moves back one frame.
6. The right arrow on `14-mind-moon.png` opens `15-summary.png`.
7. `15-summary.png` has no invisible click target.
8. Resize the browser to wider and taller aspect ratios; the 1066:600 canvas remains centered, uniformly scaled, and fully visible with black letterboxing.

- [ ] **Step 6: Compare screenshots to the exact local sources**

Capture the browser canvas at 1066 × 600 for screens 0, 2, 4, 10, 14, and 15. Compare each capture to its matching file under `web/public/frames/`. Because the image is the entire visual layer, any pixel difference inside the canvas indicates unintended browser styling, cropping, or overlay visibility and must be fixed before completion.

- [ ] **Step 7: Commit test integration**

```bash
git add web/scripts/test.mjs web/tests/frame-flow.test.mjs
git commit -m "test: verify sixteen-screen Figma flow"
```

---

## Final Verification

- [ ] `node scripts/test.mjs` completes successfully from `web`.
- [ ] Exactly 16 ordered screen registry entries exist.
- [ ] Every referenced PNG exists and is 1066 × 600.
- [ ] Active `page.tsx` contains no generic realm, rubbing, game, or sign templates.
- [ ] All interactive regions work with mouse and keyboard.
- [ ] The final summary screen has no invented continuation behavior.
- [ ] The local development preview remains running and shows the new implementation through hot reload.
