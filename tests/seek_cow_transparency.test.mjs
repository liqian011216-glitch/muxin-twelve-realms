import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const scene = await readFile(new URL('../games/seek_cow/seek_cow.tscn', import.meta.url), 'utf8');

test('寻牛牛素材会移除中灰色棋盘底色碎片', () => {
  assert.match(scene, /path="res:\/\/cow\/cow_run_sheet_v2\.png"/);
  assert.match(scene, /\[node name="CowSprite"[\s\S]*?hframes = 4/);
  assert.doesNotMatch(scene, /\[node name="CowSprite"[\s\S]*?material = SubResource/);
});
