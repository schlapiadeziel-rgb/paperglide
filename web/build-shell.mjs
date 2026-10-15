import { readFileSync, writeFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const directory = dirname(fileURLToPath(import.meta.url))
const template = readFileSync(resolve(directory, 'loading.template.html'), 'utf8')
const fonts = readFileSync(resolve(directory, 'manus-fonts.css'), 'utf8')
if (template.split('{{MANUS_FONTS}}').length !== 2) throw new Error('Expected one loader font insertion point')
const html = template.replace('{{MANUS_FONTS}}', () => fonts)
for (const token of ['$GODOT_CONFIG', '$GODOT_URL', '$GODOT_PROJECT_NAME']) {
  if (!html.includes(token)) throw new Error('Missing Godot shell token: ' + token)
}
const args = process.argv.slice(2)
if (args.length === 1 && args[0] === '--stdout') process.stdout.write(html)
else if (args.length === 1 && args[0] === '--check') console.log('Web shell verified')
else if (args.length === 2 && args[0] === '--output') writeFileSync(resolve(args[1]), html)
else throw new Error('Use --check, --stdout or --output <path>')
