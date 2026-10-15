import { dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { runGodotCheck } from '../scripts/godot-check.mjs'

const root = dirname(dirname(fileURLToPath(import.meta.url)))
const suites = { progress: '[PROGRESS_PASS]', bot: '[BOT] end state=' }
const suite = process.argv[2]
if (process.argv.length !== 3 || !Object.hasOwn(suites, suite)) {
  throw new Error('Usage: node tools/run-native-test.mjs progress|bot')
}
runGodotCheck(process.env.GODOT_BIN || 'godot',
  ['--headless', '--audio-driver', 'Dummy', '--path', root, '--script', `test/${suite}.gd`],
  suites[suite], root, 300_000)
