-- ─────────────────────────────────────────────────────────────
-- Universal lessons — applicable to almost any Claude Code user on any project.
-- Seeded on install so the KB isn't empty (empty KB confuses agents).
-- Tagged 'tpmem-seed:universal' so they can be filtered out or removed later.
-- ─────────────────────────────────────────────────────────────

-- Dedicated entity for universal lessons so they're grouped
INSERT OR IGNORE INTO entities (type, slug, name, summary) VALUES
  ('concept', 'universal-lessons', 'Universal Lessons',
   'Cross-project lessons applicable to almost any development work. Seeded on tpmem install. Feel free to add your own, prune what doesn''t apply, or flag refinements.');

INSERT INTO notes (entity_id, category, content, importance, tags, source) VALUES
  ((SELECT id FROM entities WHERE slug='universal-lessons'), 'lesson',
   'Port-binding zombie processes: always verify the PID on a port matches the PID you started. A pre-session server process can hold a port while every subsequent "restart" appears to succeed (new PID spawns, exits silently when the port is taken). All your code fixes look deployed but aren''t — the old process is still serving. Pattern: `ss -lntp | grep :PORT` (or `lsof -i :PORT`), verify PID, cross-check against any pidfile. Kill the true holder before starting fresh. Applies to any long-running dev server.',
   7, 'debugging,ops,server-restart,port-binding',
   'tpmem-seed:universal'),

  ((SELECT id FROM entities WHERE slug='universal-lessons'), 'lesson',
   'SSE behind a reverse proxy is a buffering trap. If server-sent events go silent intermittently and clients need to refresh, check the proxy. Apache needs `flushpackets=on` on ProxyPass plus `disablereuse=on` on a dedicated Location block (default connection pool reuses backend TCP connections and drops SSE mid-stream). Nginx needs `proxy_buffering off` and `proxy_http_version 1.1`. Also disable gzip compression for the SSE endpoint — the compression layer buffers chunks waiting for enough bytes to compress, which breaks streaming. Always test SSE through the proxy, never just against the backend.',
   8, 'sse,reverse-proxy,apache,nginx,buffering',
   'tpmem-seed:universal'),

  ((SELECT id FROM entities WHERE slug='universal-lessons'), 'lesson',
   'Express behind a reverse proxy needs `app.set(''trust proxy'', 1)` or `true`. Without it: express-rate-limit buckets every request to 127.0.0.1 (all users share one limiter), X-Forwarded-For is set by the proxy but ignored by Express. Silent failure — nothing errors, but your IP-keyed logic all collapses to one bucket.',
   6, 'express,proxy,rate-limit',
   'tpmem-seed:universal'),

  ((SELECT id FROM entities WHERE slug='universal-lessons'), 'lesson',
   'Node HTTP server default timeouts can kill long SSE/WebSocket streams. `server.requestTimeout` defaults to 5 minutes — silent for regular requests, fatal for streams. Fix: `server.requestTimeout = 0` (disabled), bump `server.keepAliveTimeout` and `server.headersTimeout` to ~65-70s. Apply to any Node server serving long-lived connections.',
   6, 'nodejs,sse,timeouts,long-connections',
   'tpmem-seed:universal'),

  ((SELECT id FROM entities WHERE slug='universal-lessons'), 'lesson',
   'Transparency doesn''t launder shortcuts. When a skill or policy says "read in full" or "verify before", the rule fires hardest exactly when it''s inconvenient. Rationalizations to stop on: "already in KB" (doesn''t mean the file has nothing new), "diminishing returns" (can''t know before you read), "I''ll note it transparently in the audit log" (the audit log is for recording what you did, not confessing what you skipped). If the rule mattered enough to write down, it matters enough to follow at the cost of speed.',
   8, 'discipline,agent-behavior,curator,shortcuts',
   'tpmem-seed:universal'),

  ((SELECT id FROM entities WHERE slug='universal-lessons'), 'lesson',
   'Flavor-only config is data/code drift. If a config field declares a mechanic but the engine never reads it, you have a lie the system tells users. Tier descriptions promising effects that don''t exist. Feature flags that do nothing. Rule: if config declares X, the engine reads X OR tests fail on missing handler. Silent drop is worse than visible error.',
   6, 'config,data-code-drift,testing',
   'tpmem-seed:universal'),

  ((SELECT id FROM entities WHERE slug='universal-lessons'), 'lesson',
   'Ad-hoc `npm install` without `--save` is a time bomb. If you install a package directly on one machine without committing package.json, fresh clones won''t have it. The dep works where you tested, breaks on the next machine. Always `npm install --save` (or install at the level where package.json lives and commit the change) so the dependency travels with the code. Same pattern for `pip install` without updating requirements.txt.',
   6, 'npm,pip,dependencies,drift',
   'tpmem-seed:universal');
