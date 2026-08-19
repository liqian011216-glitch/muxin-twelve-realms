import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const script = await readFile(new URL('../scripts/bridge.gd', import.meta.url), 'utf8');
const scene = await readFile(new URL('../games/bridge/bridge.tscn', import.meta.url), 'utf8');

test('独木桥使用左右点击修正而不是拖拽', () => {
  assert.match(script, /InputEventMouseButton/);
  assert.match(script, /player_lean -= CLICK_MAX_FORCE/);
  assert.match(script, /player_lean \+= CLICK_MAX_FORCE/);
  assert.doesNotMatch(script, /is_pulling/);
});

test('独木桥每轮归零计时并限制自动进度', () => {
  assert.match(script, /elapsed_seconds = 0\.0/);
  assert.match(script, /balance > 0\.25/);
});

test('独木桥失败重来不清空本局连续计时，成功时锁定用时', () => {
  assert.match(script, /func _reset_round\(reset_timer: bool = true\)/);
  assert.match(script, /if reset_timer:\n\t\telapsed_seconds = 0\.0/);
  assert.match(script, /_reset_round\(false\)/);
  assert.match(script, /result_score_label\.text = str\(int\(elapsed_seconds\)\)/);
});

test('独木桥人物倾斜和倒下使用平滑动画', () => {
  assert.match(script, /lerp_angle\(/);
  assert.match(script, /exp\(-6\.0 \* delta\)/);
  assert.match(script, /create_tween\(\)/);
  assert.match(script, /tween_property\(character, "rotation"/);
});

test('独木桥播放背影行走和倾倒精灵帧', () => {
  assert.match(script, /walk_sheet_v2\.png/);
  assert.match(script, /fall_sheet_v2\.png/);
  assert.match(script, /character\.hframes = 4/);
  assert.match(script, /character\.frame/);
});

test('独木桥使用较友好的入门难度', () => {
  assert.match(script, /const FALL_ANGLE := 0\.86/);
  assert.match(script, /const CLICK_MAX_FORCE := 0\.52/);
  assert.match(script, /balance > 0\.25/);
  assert.match(script, /randf_range\(-0\.55, 0\.55\)/);
});

test('独木桥提示和结算按钮与点击操作一致', () => {
  assert.match(script, /点击左右两侧，保持平衡/);
  assert.match(scene, /text = "继续牧心"/);
  assert.doesNotMatch(scene, /text = "再走一次"/);
  assert.doesNotMatch(scene, /name="RestartButton"/);
  assert.match(script, /godot:bridge-complete/);
});
