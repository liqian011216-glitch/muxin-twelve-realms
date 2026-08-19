import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

test("build output serves the first approved Figma frame", async () => {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}`);
  const { default: worker } = await import(workerUrl.href);
  const response = await worker.fetch(new Request("http://localhost/", { headers: { accept: "text/html" } }), { ASSETS: { fetch: async () => new Response("Not found", { status: 404 }) } }, { waitUntil() {}, passThroughOnException() {} });
  assert.equal(response.status, 200);
  const html = await response.text();
  assert.match(html, /\/frames\/00-cover\.png/);
  assert.match(html, /问心，开始旅程/);
  assert.match(html, /data-loaded="true"/, "the initial frame remains visible without client JavaScript");
});

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

test("replaces and hides a changed frame image until its load event", async () => {
  const [page, css] = await Promise.all([
    readFile(new URL("../app/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/globals.css", import.meta.url), "utf8"),
  ]);
  assert.match(page, /key=\{screen\.image\}/, "screen changes must replace the image element");
  assert.match(page, /setLoadedImage\(null\)/, "navigation must close the visibility gate");
  assert.match(page, /onLoad=\{\(\)\s*=>\s*setLoadedImage\(screen\.image\)\}/, "only image load opens the gate");
  assert.match(page, /loadedImage\s*===\s*screen\.image/, "the gate must be tied to the current src");
  assert.match(page, /imageLoaded\s*&&\s*screen\.hotspots\.map/, "new hotspots wait for their visual frame");
  assert.match(css, /\.figma-frame-image\[data-loaded=["']false["']\]\s*\{[^}]*visibility:\s*hidden/s);
  assert.match(css, /\.figma-canvas\s*\{[^}]*background:\s*#000/s, "the loading canvas must be black");
});

test("uses the exact viewport scale and centering formulas", async () => {
  const css = await readFile(new URL("../app/globals.css", import.meta.url), "utf8");
  assert.match(css, /\.figma-stage\s*\{[^}]*display:\s*grid[^}]*place-items:\s*center/s);
  assert.match(css, /\.figma-canvas\s*\{[^}]*width:\s*min\(100vw,\s*calc\(100svh\s*\*\s*1066\s*\/\s*600\)\)/s);
  assert.match(css, /\.figma-canvas\s*\{[^}]*height:\s*min\(100svh,\s*calc\(100vw\s*\*\s*600\s*\/\s*1066\)\)/s);
});

test("metadata describes the sixteen-screen contemplative narrative", async () => {
  const layout = await readFile(new URL("../app/layout.tsx", import.meta.url), "utf8");
  assert.doesNotMatch(layout, /拓印|寻牛互动/);
  assert.match(layout, /16\s*幅画面/);
  assert.match(layout, /观照心念/);
});
