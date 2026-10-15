import { existsSync, mkdirSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { runGodotCheck } from '../scripts/godot-check.mjs'

const root = dirname(dirname(fileURLToPath(import.meta.url)))
if (process.argv.length > 4) throw new Error('Usage: npm run capture -- [output-directory] [comma-separated-shots]')
const output = resolve(process.argv[2] || resolve(root, 'game-captures', new Date().toISOString().replaceAll(':', '-')))
const shots = process.argv[3] || 'title,start,combat,town,canyon,outpost,boss'
mkdirSync(output, { recursive: true })
for (const shot of shots.split(',')) {
  if (!/^[a-z]+$/.test(shot)) throw new Error('Invalid capture name')
  if (existsSync(resolve(output, `${shot}.png`))) throw new Error(`Capture already exists: ${shot}.png; use a fresh output directory`)
}
runGodotCheck(process.env.GODOT_BIN || 'godot',
  ['--audio-driver', 'Dummy', '--path', root, '--script', 'test/capture.gd', '--', output, shots],
  '[capture]', root, 300_000)
console.log(`Screenshots: ${output}`)
