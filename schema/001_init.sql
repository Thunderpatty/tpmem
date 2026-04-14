-- ─────────────────────────────────────────────────────────────
-- tpmem KB — v1 schema
-- Persistent memory substrate for Claude Code agents.
-- ─────────────────────────────────────────────────────────────

PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;

-- ENTITIES: people, projects, products, decisions, tools, files, concepts
CREATE TABLE IF NOT EXISTS entities (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    type        TEXT NOT NULL,          -- person | project | product | decision | tool | file | concept | reference
    slug        TEXT UNIQUE NOT NULL,   -- short identifier
    name        TEXT,                   -- human-readable name
    summary     TEXT,                   -- one-paragraph overview
    status      TEXT DEFAULT 'active',  -- active | pending-review | blocked | done | abandoned | archived | deprecated
    status_updated_at DATETIME,
    status_notes TEXT,
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at  DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_entities_type ON entities(type);
CREATE INDEX IF NOT EXISTS idx_entities_status ON entities(status);

-- NOTES: decisions, preferences, lessons, facts, todos, audit entries attached to entities
CREATE TABLE IF NOT EXISTS notes (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    entity_id    INTEGER REFERENCES entities(id) ON DELETE CASCADE,
    category     TEXT NOT NULL,         -- decision | preference | lesson | fact | todo | rationale | risk | milestone | audit | status
    content      TEXT NOT NULL,
    importance   INTEGER DEFAULT 5,     -- 1-10; higher = surface first
    tags         TEXT,                  -- comma-separated
    expires_at   DATETIME,              -- optional auto-purge for ephemeral notes
    source       TEXT,                  -- where this came from
    created_at   DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at   DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_notes_entity ON notes(entity_id);
CREATE INDEX IF NOT EXISTS idx_notes_category ON notes(category);
CREATE INDEX IF NOT EXISTS idx_notes_importance ON notes(importance DESC);
CREATE INDEX IF NOT EXISTS idx_notes_expires ON notes(expires_at) WHERE expires_at IS NOT NULL;

-- RELATIONS: how entities connect
CREATE TABLE IF NOT EXISTS relations (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    from_id     INTEGER NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
    to_id       INTEGER NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
    relation    TEXT NOT NULL,         -- works_on | makes | depends_on | conflicts_with | part_of | replaces | inspired_by
    context     TEXT,
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(from_id, to_id, relation)
);

CREATE INDEX IF NOT EXISTS idx_relations_from ON relations(from_id);
CREATE INDEX IF NOT EXISTS idx_relations_to ON relations(to_id);

-- HANDOFFS: session bookmarks — what was done, next steps, open questions
CREATE TABLE IF NOT EXISTS handoffs (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    session_end     DATETIME DEFAULT CURRENT_TIMESTAMP,
    session_start   DATETIME,
    project_slug    TEXT,
    completed       TEXT,
    next_steps      TEXT,
    open_questions  TEXT,
    blockers        TEXT,
    notes           TEXT,
    acceptance_criteria TEXT               -- if set, project flips to pending-review
);

CREATE INDEX IF NOT EXISTS idx_handoffs_session_end ON handoffs(session_end DESC);
CREATE INDEX IF NOT EXISTS idx_handoffs_project ON handoffs(project_slug);

-- FULL TEXT SEARCH over notes
CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(
    content,
    tags,
    content='notes',
    content_rowid='id'
);

CREATE TRIGGER IF NOT EXISTS notes_fts_insert AFTER INSERT ON notes BEGIN
    INSERT INTO notes_fts(rowid, content, tags) VALUES (new.id, new.content, new.tags);
END;

CREATE TRIGGER IF NOT EXISTS notes_fts_delete AFTER DELETE ON notes BEGIN
    INSERT INTO notes_fts(notes_fts, rowid, content, tags) VALUES ('delete', old.id, old.content, old.tags);
END;

CREATE TRIGGER IF NOT EXISTS notes_fts_update AFTER UPDATE ON notes BEGIN
    INSERT INTO notes_fts(notes_fts, rowid, content, tags) VALUES ('delete', old.id, old.content, old.tags);
    INSERT INTO notes_fts(rowid, content, tags) VALUES (new.id, new.content, new.tags);
END;

CREATE TRIGGER IF NOT EXISTS entities_updated AFTER UPDATE ON entities
    BEGIN UPDATE entities SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id; END;

CREATE TRIGGER IF NOT EXISTS notes_updated AFTER UPDATE ON notes
    BEGIN UPDATE notes SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id; END;
