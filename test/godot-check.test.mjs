import assert from 'node:assert/strict'
import test from 'node:test'
import { runGodotCheck } from '../scripts/godot-check.mjs'

const run = (code) => runGodotCheck(process.execPath, ['-e', code], '[PASS]', process.cwd())

test('requires an explicit success marker', () => {
  assert.throws(() => run('process.exit(0)'), /Godot check failed/)
})
test('rejects script errors even with a zero exit and success marker', () => {
  assert.throws(() => run('console.log("[PASS]"); console.error("SCRIPT ERROR: parse failed")'), /Godot check failed/)
})
test('rejects unsuccessful process exit', () => {
  assert.throws(() => run('console.log("[PASS]"); process.exit(1)'), /Godot check failed/)
})
test('accepts an explicit pass with no errors', () => {
  assert.doesNotThrow(() => run('console.log("[PASS]")'))
})
