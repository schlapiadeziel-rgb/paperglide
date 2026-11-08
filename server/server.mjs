import { readBackendContract } from './backend-contract.mjs';
import http from 'node:http';
import { createLeaderboardService } from './service.mjs';
import { createLeaderboardRest, send } from './rest.mjs';
import mysql from 'mysql2/promise';
import { createRequestDatabase, databaseStream, DATABASE_CONCURRENCY } from './request-database.mjs';

import { assertDatabaseEnvironment, assertDatabaseReady, databaseName, PROTOCOL_VERSION, SCHEMA_VERSION } from './deployment-contract.mjs';

// This server belongs to the generated game, never to Addon Server.
const backendContract = readBackendContract(process.cwd(), { required: true }).value;
if (backendContract.api.protocolVersion !== PROTOCOL_VERSION || backendContract.database.schemaVersion !== SCHEMA_VERSION || backendContract.deploy.healthPath !== '/api/health') throw new Error('backend_contract_incompatible');
const namespace = 'production';
const readonly = process.env.GAME_LEADERBOARD_READ_ONLY === '1';
if (!process.env.DATABASE_URL) throw new Error('Project DATABASE_URL is required');
databaseName(process.env.DATABASE_URL);
const pool = mysql.createPool({ uri: process.env.DATABASE_URL, stream: databaseStream(process.env.DATABASE_URL), connectionLimit: DATABASE_CONCURRENCY, waitForConnections: false, connectTimeout: 3000, timezone: 'Z', dateStrings: true });
const db = createRequestDatabase(pool);
const handle = createLeaderboardRest(createLeaderboardService(db, namespace), {
  readonly,
  check: () => assertDatabaseEnvironment(db, namespace),
  async ready() {
    await assertDatabaseReady(db, namespace, backendContract);
    return { status: 'ok', namespace, readonly, protocolVersion: PROTOCOL_VERSION, schemaVersion: SCHEMA_VERSION };
  },
});
const server = http.createServer((req, res) => {
  // Startup probes must bypass database readiness and its admission limit.
  if (req.method === 'GET' && req.url?.split('?')[0] === '/api/health') return send(res, 200, { status: 'ok' });
  db.run(req, res, () => handle(req, res)).catch((error) => {
    if (res.destroyed || res.writableEnded) return;
    send(res, error.status || 503, { error: error.code && error.status ? error.code : 'leaderboard_unavailable' });
    // Stop a slow unfinished upload after returning the bounded failure response.
    if (!req.complete) res.once('finish', () => req.destroy());
  });
});
server.requestTimeout = 15_000;
server.headersTimeout = 10_000;
server.listen(Number(process.env.PORT || 8080), process.env.HOST || '0.0.0.0', () => {
  const address = server.address();
  if (typeof address === 'object') process.send?.({ type: 'ready', port: address.port });
});
for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => server.close(() => pool.end().finally(() => process.exit(0))));
