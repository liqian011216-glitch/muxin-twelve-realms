import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const root = new URL('../', import.meta.url);
const script = await readFile(new URL('scripts/jump_game.gd', root), 'utf8');
const scene = await readFile(new URL('games/jump/jump_game.tscn', root), 'utf8');

test('横向跳跃只在实际拾取莲花时更新提示', () => {
  assert.match(script, /var collected_this_frame := false/);
  assert.match(script, /collected_this_frame = true/);
  assert.match(script, /if collected_this_frame:/);
});

test('横向跳跃掉落后回到最近安全平台且计时和莲花保留', () => {
  assert.match(script, /func _respawn_from_fall\(\) -> void/);
  assert.match(script, /player\.position = last_safe_position/);
  assert.doesNotMatch(script, /func _show_failure/);
  assert.doesNotMatch(script.match(/func _respawn_from_fall[\s\S]*?(?=\nfunc )/)?.[0] ?? '', /collected = 0|elapsed_time = 0/);
});

test('横向跳跃自动向右奔跑并由整屏单击或双击控制跳跃', () => {
  assert.match(script, /const START_DELAY := 1\.2/);
  assert.match(script, /velocity\.x = move_toward\(velocity\.x, RUN_SPEED/);
  assert.match(script, /InputEventScreenTouch/);
  assert.match(script, /InputEventMouseButton/);
  assert.match(script, /jump_requested/);
  assert.match(script, /high_jump_requested/);
  assert.match(script, /const DOUBLE_TAP_WINDOW := 0\.5/);
  assert.match(script, /const HIGH_JUMP_SPEED := -860\.0/);
  assert.match(script, /event\.double_click/);
  assert.match(script, /if high_jump_pressed:\s*velocity\.y = HIGH_JUMP_SPEED/);
  assert.doesNotMatch(script, /jump_held|HELD_GRAVITY_SCALE|MAX_JUMP_HOLD/);
  assert.match(scene, /node name="LeftControl"[\s\S]*?visible = false/);
  assert.match(scene, /node name="RightControl"[\s\S]*?visible = false/);
  assert.match(scene, /node name="JumpControl"[\s\S]*?visible = false/);
});

test('横向跳跃使用 48 朵莲花和手机提示', () => {
  assert.match(script, /const LOTUS_COUNT := 48/);
  assert.match(scene, /轻触跳跃，双击跃得更高/);
  assert.match(scene, /莲花 0 \/ 48/);
});

test('横向跳跃不再包含青苔晕厥机制', () => {
  assert.doesNotMatch(script, /晕厥|青苔|stun_timer|green_zone|_build_green_zones/);
});

test('横向跳跃出生点取起始平台真实碰撞面', () => {
  assert.match(script, /const START_X := 120\.0/);
  assert.match(script, /var start_surface := _surface_y_any\(START_X\)/);
  assert.match(script, /player\.position = Vector2\(START_X, start_surface - 64\.0\)/);
});

test('横向跳跃只把同高度的平台中部记为安全重生点', () => {
  assert.match(script, /func _is_safe_checkpoint_position\(\) -> bool/);
  assert.match(script, /left_surface := _surface_y_near/);
  assert.match(script, /right_surface := _surface_y_near/);
  assert.match(script, /absf\(left_surface - foot_y\) < 10\.0/);
  assert.match(script, /respawn_delay = RESPAWN_DELAY/);
});

test('横向跳跃将碰撞图预加载进 Web 导出资源', () => {
  assert.match(script, /const COLLISION_MAP_TEXTURE := preload\(/);
  assert.match(script, /collision_map = COLLISION_MAP_TEXTURE\.get_image\(\)/);
});

test('横向跳跃仍允许桌面端使用空格键试玩', () => {
  assert.match(script, /func _input\(event: InputEvent\)/);
  assert.match(script, /KEY_SPACE/);
});

test('横向跳跃顶部信息与所有文案使用汇文明朝体', () => {
  assert.match(scene, /汇文明朝体GBK1\.001\/汇文明朝体\.otf/);
  assert.match(scene, /相忘｜莲花跳跃/);
  assert.match(scene, /用时 00:00/);
});

test('横向跳跃抵达彼岸后通知网页进入独照', () => {
  assert.match(script, /godot:lotus-complete/);
  assert.match(script, /window\.parent\.postMessage/);
});
