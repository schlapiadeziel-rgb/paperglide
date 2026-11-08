import { openSync, closeSync, fstatSync, readSync, constants } from 'node:fs'
import { join } from 'node:path'
import { createHash } from 'node:crypto'

export const BACKEND_CONTRACT = 'game-backend-contract.json'
const MAX_BYTES = 16 * 1024
// `field`/`rule` name the first failed condition for config-facing callers; the
// message stays fixed because stored declarations are untrusted input.
const invalid = (field, rule) => {
  const error = new Error('Game backend compatibility declaration is invalid')
  if (field) Object.assign(error, { field, rule })
  throw error
}
const object = (value, keys, field) => {
  if (!value || Array.isArray(value) || typeof value !== 'object' || Object.keys(value).some(key => !keys.includes(key))) invalid(field, 'must be an object with supported fields only')
}
const positive = value => Number.isSafeInteger(value) && value > 0
const relative = value => typeof value === 'string' && value.length <= 256 && /^[A-Za-z0-9_./-]+$/.test(value) && value.split('/').every(part => part && part !== '.' && part !== '..')
const routePath = value => typeof value === 'string' && value.length <= 256 && /^\/\*$|^(?:\/\.*[A-Za-z0-9_~-][A-Za-z0-9._~-]*)+(?:\/\*)?$/.test(value)
const routeCache = value => ['immutable', 'no-cache'].includes(value) || (Number.isSafeInteger(value) && value >= 0 && value <= 31536000)

// Game server routes are uncached. The Webdev route contract also writes "cache
// off" as "no-cache" or 0, and /api/ paths never use the shared cache.
export const gameServerRouteUncached = route => route.cache === undefined || route.cache === 'no-cache' || route.cache === 0

export function parseBackendContract(value) {
  const auth = value?.schema === 'manus.game.auth-backend-contract/v1'
  object(value, ['schema', 'deploy', 'routes', 'api', 'database', ...(auth ? [] : ['boards'])])
  if (!auth && value.schema !== 'manus.game.backend-contract/v1') invalid()
  object(value.deploy, ['mode', 'dockerfilePath', 'healthPath'], 'deploy')
  if (value.deploy.mode !== 'hybrid') invalid('deploy.mode', 'must be hybrid')
  if (!relative(value.deploy.dockerfilePath)) invalid('deploy.dockerfilePath', 'must be project-relative')
  if (!routePath(value.deploy.healthPath) || value.deploy.healthPath.includes('*') || !value.deploy.healthPath.startsWith('/api/')) invalid('deploy.healthPath', 'must be an /api/... path without wildcards')
  object(value.api, ['protocolVersion'])
  object(value.database, ['schemaVersion'])
  if (!positive(value.api.protocolVersion) || !positive(value.database.schemaVersion)) invalid()
  if (!Array.isArray(value.routes) || !value.routes.length || value.routes.length > 64) invalid('routes', 'must contain 1 to 64 routes')
  value.routes.forEach((route, index) => {
    const at = `routes.${index}`
    object(route, ['path', 'target', 'cache', 'spaFallback'], at)
    if (!routePath(route.path)) invalid(`${at}.path`, 'must be a valid route path')
    if (!['server', 'static'].includes(route.target)) invalid(`${at}.target`, 'must be server or static')
    if (route.spaFallback !== undefined && typeof route.spaFallback !== 'boolean') invalid(`${at}.spaFallback`, 'must be a boolean')
    if (route.cache !== undefined && !routeCache(route.cache)) invalid(`${at}.cache`, 'must be "immutable", "no-cache" or 0 to 31536000 seconds')
    if (route.target === 'server' && !route.path.startsWith('/api/')) invalid(`${at}.path`, 'must start with /api/ on a server route')
    if (route.target === 'server' && !gameServerRouteUncached(route)) invalid(`${at}.cache`, 'must be omitted, "no-cache" or 0 on a Game server route')
  })
  const last = value.routes.length - 1
  if (value.routes[last].path !== '/*' || value.routes[last].target !== 'static') invalid(`routes.${last}`, 'must be the /* static fallback')
  if (!value.routes.some(route => route.path === '/api/*' && route.target === 'server')) invalid('routes', 'must include /api/* server routing')
  // Auth-only games share the release binding, not the leaderboard schema/rules.
  // Keep the existing leaderboard contract strict, including its nonempty boards.
  if (auth) {
    if (value.api.protocolVersion !== 1 || value.database.schemaVersion !== 1) invalid()
    return value
  }
  if (!Array.isArray(value.boards) || !value.boards.length || value.boards.length > 64) invalid()
  const ids = new Set()
  for (const board of value.boards) {
    object(board, ['id', 'rulesVersion'])
    if (typeof board.id !== 'string' || !/^[A-Za-z0-9_-]{1,64}$/.test(board.id) || ids.has(board.id) || typeof board.rulesVersion !== 'string' || !/^[A-Za-z0-9_.-]{1,32}$/.test(board.rulesVersion)) invalid()
    ids.add(board.id)
  }
  return value
}

export function readBackendContract(root, { required = false } = {}) {
  let fd
  try { fd = openSync(join(root, BACKEND_CONTRACT), constants.O_RDONLY | constants.O_NOFOLLOW | constants.O_NONBLOCK) }
  catch (error) { if (error.code === 'ENOENT' && !required) return null; invalid() }
  try {
    const stat = fstatSync(fd)
    if (!stat.isFile() || stat.size > MAX_BYTES) invalid()
    const bytes = Buffer.alloc(MAX_BYTES + 1)
    let length = 0
    while (length < bytes.length) {
      const count = readSync(fd, bytes, length, bytes.length - length, null)
      if (!count) break
      length += count
    }
    if (length > MAX_BYTES) invalid()
    const content = bytes.subarray(0, length)
    return { value: parseBackendContract(JSON.parse(content.toString('utf8'))), sha256: 'sha256:' + createHash('sha256').update(content).digest('hex') }
  } catch { invalid() } finally { closeSync(fd) }
}

export function backendBindingMismatch(contract, binding) {
  if (binding?.deploy?.mode !== contract.deploy.mode) return 'deploy.mode'
  for (const key of ['dockerfilePath', 'healthPath']) if (binding.deploy[key] !== contract.deploy[key]) return `deploy.${key}`
  // Compare serving behavior: the uncached server-route spellings are equivalent.
  const cache = route => route.target === 'server' && gameServerRouteUncached(route) ? null : route.cache ?? null
  const shape = routes => routes?.map(route => [route.path, route.target, cache(route), route.spaFallback ?? null])
  if (JSON.stringify(shape(binding.routes)) !== JSON.stringify(shape(contract.routes))) return 'routes'
  return null
}
