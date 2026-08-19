import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const scene = await readFile(new URL('../games/seek_cow/seek_cow.tscn', import.meta.url), 'utf8');
const main = await readFile(new URL('../main.tscn', import.meta.url), 'utf8');
const menu = await readFile(new URL('../scripts/menu.gd', import.meta.url), 'utf8');

test('寻牛统一使用初调名称和兼容字体的分隔线', () => {
  assert.match(scene, /text = "初调｜寻牛"/);
  assert.match(scene, /text = "第一境｜初调"/);
  assert.doesNotMatch(scene, /·/);
  assert.match(main, /text = "第一境｜初调｜寻牛"/);
  assert.match(menu, /第一境｜初调｜寻牛/);
  assert.doesNotMatch(menu, /·/);
});
