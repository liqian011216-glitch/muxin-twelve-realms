import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { inflateSync } from "node:zlib";

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

const crcTable = Array.from({ length: 256 }, (_, byte) => {
  let crc = byte;
  for (let bit = 0; bit < 8; bit += 1) {
    crc = (crc & 1) === 1 ? 0xedb88320 ^ (crc >>> 1) : crc >>> 1;
  }
  return crc >>> 0;
});

function crc32(bytes) {
  let crc = 0xffffffff;
  for (const byte of bytes) crc = crcTable[(crc ^ byte) & 0xff] ^ (crc >>> 8);
  return (crc ^ 0xffffffff) >>> 0;
}

function decodeRgb8Png(bytes, image) {
  const signature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  assert.deepEqual(bytes.subarray(0, 8), signature, `${image} signature`);

  const chunks = [];
  let offset = 8;
  while (offset < bytes.length) {
    assert.ok(offset + 12 <= bytes.length, `${image} truncated chunk header`);
    const length = bytes.readUInt32BE(offset);
    const type = bytes.toString("ascii", offset + 4, offset + 8);
    const dataStart = offset + 8;
    const dataEnd = dataStart + length;
    assert.ok(dataEnd + 4 <= bytes.length, `${image} truncated ${type} chunk`);
    const expectedCrc = bytes.readUInt32BE(dataEnd);
    const actualCrc = crc32(bytes.subarray(offset + 4, dataEnd));
    assert.equal(actualCrc, expectedCrc, `${image} invalid ${type} CRC`);
    chunks.push({ type, data: bytes.subarray(dataStart, dataEnd) });
    offset = dataEnd + 4;
    if (type === "IEND") break;
  }

  assert.equal(offset, bytes.length, `${image} has data after IEND`);
  assert.equal(chunks[0]?.type, "IHDR", `${image} first chunk`);
  assert.equal(chunks.at(-1)?.type, "IEND", `${image} final chunk`);
  assert.equal(chunks.filter(({ type }) => type === "IHDR").length, 1, `${image} IHDR count`);
  assert.equal(chunks.filter(({ type }) => type === "IEND").length, 1, `${image} IEND count`);

  const ihdr = chunks[0].data;
  assert.equal(ihdr.length, 13, `${image} IHDR length`);
  assert.equal(ihdr.readUInt32BE(0), 1066, `${image} width`);
  assert.equal(ihdr.readUInt32BE(4), 600, `${image} height`);
  assert.deepEqual([...ihdr.subarray(8)], [8, 2, 0, 0, 0], `${image} RGB8 encoding`);

  const idat = chunks.filter(({ type }) => type === "IDAT").map(({ data }) => data);
  assert.ok(idat.length > 0, `${image} requires IDAT data`);
  const scanlines = inflateSync(Buffer.concat(idat));
  const rowLength = 1 + 1066 * 3;
  assert.equal(scanlines.length, rowLength * 600, `${image} decoded scanline length`);
  for (let row = 0; row < 600; row += 1) {
    assert.ok(scanlines[row * rowLength] <= 4, `${image} row ${row} filter`);
  }
}

test("all approved local frame exports are complete decodable 1066 by 600 PNGs", async () => {
  for (const screen of flow.FRAME_SCREENS) {
    const bytes = await readFile(new URL(`../public${screen.image}`, import.meta.url));
    decodeRgb8Png(bytes, screen.image);
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

test("defines the complete expected transition graph and opening choice values", () => {
  const expected = [
    [{ id: "start", targetIndex: 1 }],
    [{ id: "continue", targetIndex: 2 }],
    [
      { id: "untrained", targetIndex: 3, choice: "untrained" },
      { id: "restrained", targetIndex: 3, choice: "restrained" },
      { id: "free", targetIndex: 3, choice: "free" },
    ],
    [{ id: "enter", targetIndex: 4 }],
    [{ id: "preview-next", targetIndex: 5 }, { id: "previous", targetIndex: 3 }, { id: "next", targetIndex: 5 }],
    [{ id: "preview-previous", targetIndex: 4 }, { id: "preview-next", targetIndex: 6 }, { id: "previous", targetIndex: 4 }, { id: "next", targetIndex: 6 }],
    [{ id: "preview-previous", targetIndex: 5 }, { id: "preview-next", targetIndex: 7 }, { id: "previous", targetIndex: 5 }, { id: "next", targetIndex: 7 }],
    [{ id: "preview-previous", targetIndex: 6 }, { id: "preview-next", targetIndex: 8 }, { id: "previous", targetIndex: 6 }, { id: "next", targetIndex: 8 }],
    [{ id: "preview-previous", targetIndex: 7 }, { id: "preview-next", targetIndex: 9 }, { id: "previous", targetIndex: 7 }, { id: "next", targetIndex: 9 }],
    [{ id: "preview-previous", targetIndex: 8 }, { id: "preview-next", targetIndex: 10 }, { id: "previous", targetIndex: 8 }, { id: "next", targetIndex: 10 }],
    [{ id: "preview-previous", targetIndex: 9 }, { id: "preview-next", targetIndex: 11 }, { id: "previous", targetIndex: 9 }, { id: "next", targetIndex: 11 }],
    [{ id: "preview-previous", targetIndex: 10 }, { id: "preview-next", targetIndex: 12 }, { id: "previous", targetIndex: 10 }, { id: "next", targetIndex: 12 }],
    [{ id: "preview-previous", targetIndex: 11 }, { id: "preview-next", targetIndex: 13 }, { id: "previous", targetIndex: 11 }, { id: "next", targetIndex: 13 }],
    [{ id: "preview-previous", targetIndex: 12 }, { id: "preview-next", targetIndex: 14 }, { id: "previous", targetIndex: 12 }, { id: "next", targetIndex: 14 }],
    [{ id: "preview-previous", targetIndex: 13 }, { id: "previous", targetIndex: 13 }, { id: "next", targetIndex: 15 }],
    [],
  ];

  assert.deepEqual(
    flow.FRAME_SCREENS.map((screen) => screen.hotspots.map(({ id, targetIndex, choice }) => ({
      id,
      targetIndex,
      ...(choice === undefined ? {} : { choice }),
    }))),
    expected,
  );
});

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

test("side preview hotspots stay outside each central artwork boundary", () => {
  const centralArtwork = {
    4: { left: 0, right: 71.3 },
    5: { left: 30, right: 70.3 },
    6: { left: 35.2, right: 65.9 },
    7: { left: 31.6, right: 67.4 },
    8: { left: 22.6, right: 83 },
    9: { left: 31.3, right: 69.3 },
    10: { left: 24.9, right: 77.1 },
    11: { left: 26.5, right: 74.9 },
    12: { left: 15.4, right: 85.7 },
    13: { left: 35.2, right: 64.5 },
    14: { left: 36.2, right: 100 },
  };

  for (const [index, boundaries] of Object.entries(centralArtwork)) {
    for (const hotspot of flow.FRAME_SCREENS[Number(index)].hotspots) {
      if (hotspot.id === "preview-previous") assert.ok(hotspot.rect.left + hotspot.rect.width <= boundaries.left, `${index} left preview overlaps central artwork`);
      if (hotspot.id === "preview-next") assert.ok(hotspot.rect.left >= boundaries.right, `${index} right preview overlaps central artwork`);
    }
  }
});

test("the summary is terminal and rejects further navigation", () => {
  assert.deepEqual(flow.FRAME_SCREENS[15].hotspots, []);
  assert.throws(() => flow.getTargetIndex(15, "next"), /Unknown hotspot next on screen 15/);
});

test("the project test runner includes the frame-flow contract", async () => {
  const runner = await readFile(new URL("../scripts/test.mjs", import.meta.url), "utf8");
  assert.match(runner, /tests\/frame-flow\.test\.mjs/);
});
