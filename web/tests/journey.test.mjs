import assert from "node:assert/strict";
import test from "node:test";

const { createJourneyState, recordChoice, recordGameResult, getSignArchetype, recordHeartAction } =
  await import("../app/journey.ts");
const { deriveSign, drawSign, SIGN_VARIANT_COUNT } = await import("../app/signs.ts");

test("心行以任运为主时映照任运签", () => {
  let totals = { hold: 0, observe: 0, harmonize: 0, release: 0 };
  totals = recordHeartAction(totals, "release", 3);
  totals = recordHeartAction(totals, "observe");

  assert.equal(deriveSign(totals).primary, "任运签");
});

test("心行以持绳为主时映照持绳签", () => {
  let totals = { hold: 0, observe: 0, harmonize: 0, release: 0 };
  totals = recordHeartAction(totals, "hold", 3);
  totals = recordHeartAction(totals, "harmonize");

  assert.equal(deriveSign(totals).primary, "持绳签");
});

test("心行在持绳与观照相近时写出回首的过渡", () => {
  let totals = { hold: 0, observe: 0, harmonize: 0, release: 0 };
  totals = recordHeartAction(totals, "hold", 3);
  totals = recordHeartAction(totals, "observe", 2);

  assert.equal(deriveSign(totals).transition, "持绳而能回首");
});

test("心行记入旅程时保留原来的旅程状态", () => {
  const journey = createJourneyState();
  const next = recordHeartAction(journey, "release", 2);

  assert.equal(journey.heartTotals.release, 0);
  assert.equal(next.heartTotals.release, 2);
});

test("既有旅程选择会累计心行并映照最终签", () => {
  let journey = createJourneyState();
  journey = recordChoice(journey, "let_go", "放手前行");
  journey = recordChoice(journey, "let_go", "随风而行");
  journey = recordChoice(journey, "wait", "停下观看");

  assert.deepEqual(journey.heartTotals, { hold: 0, observe: 1, harmonize: 0, release: 2 });
  assert.equal(drawSign(journey, 0).primary, "任运签");
});

test("空白心行不写过渡", () => {
  assert.equal(deriveSign({ hold: 0, observe: 0, harmonize: 0, release: 0 }).transition, null);
});

test("starts with an empty journey and complete label counters", () => {
  const state = createJourneyState();
  assert.deepEqual(state.counts, {
    chase: 0,
    wait: 0,
    look_back: 0,
    let_go: 0,
    control: 0,
    together: 0,
  });
  assert.deepEqual(state.choices, []);
  assert.deepEqual(state.gameResults, []);
});

test("records a chapter choice without mutating the previous state", () => {
  const state = createJourneyState();
  const next = recordChoice(state, "wait", "未牧·停下听风");
  assert.equal(state.counts.wait, 0);
  assert.equal(next.counts.wait, 1);
  assert.deepEqual(next.choices, ["未牧·停下听风"]);
  assert.equal(next.lastTag, "wait");
});

test("records game actions as behavior labels instead of scores", () => {
  const next = recordGameResult(createJourneyState(), {
    game: "bridge",
    actions: ["stop", "let_go"],
    result: "let_go",
  });
  assert.equal(next.counts.let_go, 1);
  assert.equal(next.gameResults.length, 1);
  assert.equal("score" in next.gameResults[0], false);
});

test("uses the final seal to resolve a tied archetype", () => {
  let state = createJourneyState();
  state = recordChoice(state, "chase", "追上");
  state = recordChoice(state, "look_back", "回望");
  state = { ...state, finalSeal: "path" };
  assert.equal(getSignArchetype(state), "look_back×chase");
});

test("draws different variants inside the same behavior archetype", () => {
  let state = createJourneyState();
  state = recordChoice(state, "wait", "停留");
  state = recordChoice(state, "let_go", "放手");
  const first = drawSign(state, 0);
  const second = drawSign(state, 0.99);
  assert.equal(first.archetype, second.archetype);
  assert.notEqual(first.id, second.id);
  assert.equal(SIGN_VARIANT_COUNT >= 60, true);
});
