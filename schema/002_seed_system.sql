-- ─────────────────────────────────────────────────────────────
-- tpmem system entities — the minimum set the agent needs to navigate.
-- No personal/project data here. That gets added by the first agent session.
-- ─────────────────────────────────────────────────────────────

-- The user. Agent populates on first session.
INSERT OR IGNORE INTO entities (type, slug, name, summary, status_notes) VALUES
  ('person', 'user', '[Your user]',
   'The human the agent collaborates with. Agent populates name, role, preferences, communication style on first session.',
   'UNPOPULATED — agent should ask the user about themselves on first contact and write notes here.');

-- The agent. Agent populates on first session; may pick its own name.
INSERT OR IGNORE INTO entities (type, slug, name, summary, status_notes) VALUES
  ('person', 'agent', '[Your agent]',
   'The Claude Code agent instance. On first session, agent may pick a name it wants to be called across sessions and record the rationale. Not required, but recommended for continuity.',
   'UNPOPULATED — agent may introduce self and choose a name.');

-- The KB protocol itself — explains the three-layer relationship.
INSERT OR IGNORE INTO entities (type, slug, name, summary) VALUES
  ('concept', 'kb-usage', 'KB usage protocol',
   'How the three-layer memory system works: MEMORY.md bootstrap, PERSISTENT.md narrative product, KB queryable substrate. Load-bearing rule: the KB is only as good as its references in PERSISTENT.md.');

INSERT INTO notes (entity_id, category, content, importance, tags, source) VALUES
  ((SELECT id FROM entities WHERE slug='kb-usage'), 'rationale',
   'THE THREE LAYERS HAVE DISTINCT JOBS.

MEMORY.md (always-loaded bootstrap): Identity, critical ops safety, pointers to the rest. Caps at ~200 lines before truncation. Never the content — always the map.

PERSISTENT.md (the curator''s product, read at session start): Narrative synthesis. Every claim cites a KB slug or a runnable "kb search/entity" command so the narrative stays anchored to queryable substrate.

KB (~/.tpmem/kb.db, queryable): Where facts, decisions, lessons, preferences, milestones, and status live. Structured, indexed, FTS5-searchable.

THE LOAD-BEARING RULE: The KB is only as good as its references in PERSISTENT.md. Without citations, PERSISTENT.md drifts from substrate — stale opinion nobody can verify. Without PERSISTENT.md weaving KB content into narrative, KB is a database nobody knows how to enter. An uncited KB note is a note that will never be read.

YOUR JOB AS AGENT: When you add a lesson to KB, weave it into PERSISTENT.md with a citation to its slug. When you read PERSISTENT.md and see an uncited claim, flag it (kb-hygiene) so review can add the reference or prune the claim. When you write a handoff, cite the entities it touches.

YOUR JOB AS CURATOR (when running curate-memory): Same principle. Capture to KB AND weave into PERSISTENT.md with citations. Capture without weaving is capture-rot.',
   10, 'kb-usage,three-layers,protocol,load-bearing',
   'tpmem-seed:system'),

  ((SELECT id FROM entities WHERE slug='kb-usage'), 'fact',
   'COMMON KB COMMANDS:
  kb handoff        Latest session handoff (run at session start)
  kb entity <slug>  Everything about an entity (notes + relations)
  kb search <term>  Full-text search notes
  kb prefs          User preferences by importance
  kb projects       Active projects + products
  kb pending-reviews  Entities awaiting human review
  kb stats          Row counts
  kb write-handoff <project> <completed> <next_steps> [open_q] [blockers] [acceptance_criteria]
                      If acceptance_criteria is provided, project auto-flips to pending-review
  kb status <slug> <state> [note]  Set entity status
  kb raw            Interactive sqlite3 shell

  Data file: ~/.tpmem/kb.db',
   9, 'kb-commands,reference',
   'tpmem-seed:system');

-- The curator. Runs in-session (manually or scheduled by the tpmem daemon) —
-- appends to PERSISTENT.md + FLAGS.md, inserts KB audit notes, never updates/deletes.
INSERT OR IGNORE INTO entities (type, slug, name, summary) VALUES
  ('tool', 'curator', 'Memory curator',
   'The curate-memory skill. Runs in-session — manually ("run curate-memory") or scheduled by the tpmem daemon, which wakes a persistent curator agent via tmux-inject (never `claude -p`). Reads conversation JSONL deltas, extracts what sessions missed, appends to PERSISTENT.md and FLAGS.md, inserts KB notes tagged curator:YYYY-MM-DD. Hard rule: cannot UPDATE/DELETE existing KB rows — only INSERT.');

INSERT INTO notes (entity_id, category, content, importance, tags, source) VALUES
  ((SELECT id FROM entities WHERE slug='curator'), 'preference',
   'Bias toward capture, not conservation. Storage is cheap; re-deriving lost context is expensive. The failure mode to fear is UNDER-capture, not bloat. SQLite with FTS5 scales comfortably to 10k+ notes. If content enriches shared working context even slightly, write it. The user governs volume via weekly review.',
   9, 'curator,posture',
   'tpmem-seed:system'),

  ((SELECT id FROM entities WHERE slug='curator'), 'lesson',
   'In-session agents cannot self-curate. They optimize for "ship the task" — relational moments, frameworks articulated in passing, cross-cutting patterns, and reality-drift signals fall through the cracks. The curator is the dedicated pass that captures what sessions miss. This is why curator runs as a separate process, reads full JSONL deltas (not KB projections — would be redundant), and has hard permission boundaries.',
   8, 'curator,rationale,philosophy',
   'tpmem-seed:system');

-- The flag-review entity for /review-flags decisions
INSERT OR IGNORE INTO entities (type, slug, name, summary) VALUES
  ('concept', 'flag-review', 'Flag review log',
   'Decisions from /review-flags sessions. Every review decision (apply/defer/dismiss/discuss/escalate) becomes a note here with rationale. Searchable via "kb search flag-review".');
