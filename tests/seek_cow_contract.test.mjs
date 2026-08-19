import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const root = new URL('../', import.meta.url);
const scene = await readFile(new URL('games/seek_cow/seek_cow.tscn', root), 'utf8');
const script = await readFile(new URL('scripts/seek_cow.gd', root), 'utf8');

test('寻牛人物和牛使用校准后的视觉比例', () => {
  assert.match(scene, /path="res:\/\/games\/jump\/assets\/player_walk_v2\.png"/);
  assert.match(scene, /path="res:\/\/cow\/cow_run_sheet_v2\.png"/);
  assert.match(scene, /\[node name="Seeker"[\s\S]*?scale = Vector2\(0\.12, 0\.12\)/);
  assert.match(scene, /\[node name="CowSprite"[\s\S]*?scale = Vector2\(0\.28, 0\.28\)/);
  assert.match(scene, /\[node name="CowSprite"[\s\S]*?hframes = 4/);
});

test('牛只在移动时播放走路帧，停下时回到站立帧', () => {
  assert.match(script, /var cow_velocity := Vector2\.ZERO/);
  assert.match(script, /if cow_velocity\.length_squared\(\) < 0\.0001/);
  assert.match(script, /cow_sprite\.rotation/);
  assert.match(script, /seeker\.rotation/);
});
