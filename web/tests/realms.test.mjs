import assert from "node:assert/strict";
import test from "node:test";

const { HEART_ACTIONS } = await import("../app/journey.ts");
const { REALMS } = await import("../app/realms.ts");

test("defines twelve ordered browser-native realms with weighted choices", () => {
  assert.equal(REALMS.length, 12);
  assert.deepEqual(REALMS.map((realm) => realm.id), Array.from({ length: 12 }, (_, index) => index + 1));

  for (const realm of REALMS) {
    assert.ok(realm.title);
    assert.ok(realm.image);
    assert.ok(realm.story);
    assert.ok(realm.choices.length >= 2);
    assert.equal("game" in realm, false);
    assert.equal(typeof realm.showProgress, "boolean");
    assert.equal(typeof realm.showHint, "boolean");
    assert.ok(realm.choices.every((choice) =>
      choice.label
      && choice.feedback
      && choice.tags.length
      && Object.keys(choice.weights).length >= 1
      && Object.keys(choice.weights).length <= 2
      && Object.entries(choice.weights).every(([action, weight]) => HEART_ACTIONS.includes(action) && weight > 0),
    ));
  }
});

test("realm interactions use the approved native sequence", () => {
  assert.deepEqual(
    REALMS.map((realm) => realm.interaction),
    ["drag", "observe", "choice", "choice", "observe", "choice", "choice", "observe", "observe", "autoplay", "autoplay", "imprint"],
  );
  assert.ok(REALMS.slice(9).every((realm) => !realm.showHint));
  assert.equal(REALMS[11].interaction, "imprint");
});

test("realm heart-action weights increase through later scenes", () => {
  const highestWeight = (realm) => Math.max(...realm.choices.flatMap((choice) => Object.values(choice.weights)));
  assert.ok(highestWeight(REALMS[5]) > highestWeight(REALMS[0]));
  assert.ok(highestWeight(REALMS[11]) > highestWeight(REALMS[5]));
});
