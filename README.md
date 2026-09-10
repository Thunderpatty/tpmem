# tpmem — persistent memory for Claude Code agents

Drop-in memory system that gives Claude Code agents continuity across sessions. Session 1000 starts smarter than session 1, not equally smart.

## What it is

Three layers + a curator + a review workflow.

- **MEMORY.md** — always-loaded bootstrap (≤200 lines). Identity, critical ops safety, pointers to the rest.
- **PERSISTENT.md** — narrative layer read at session start. How the agent and user work together, active projects, patterns. Mostly written by the curator. Every claim cites a KB slug.
- **KB** — SQLite at `~/.tpmem/kb.db`. Entities, notes, relations, handoffs, FTS5 full-text search. Queryable via a `kb` CLI helper.
- **FLAGS** — staging queue where the curator parks "uncertain" items. User processes weekly via the `/review-flags` skill.
- **Curator** — `curate-memory` skill that reads conversation JSONL deltas, extracts what sessions missed (relational moments, frameworks, lessons, reality-drift), appends to PERSISTENT.md + FLAGS.md, INSERTs KB notes. Runs in-session: on demand ("run curate-memory"), or scheduled by the tpmem daemon, which wakes a persistent curator agent via tmux-inject (never a headless `claude -p`).

## Load-bearing rule

> **The KB is only as good as its references in PERSISTENT.md.**

Capture without weaving is capture-rot. When the curator adds a lesson to KB, it also weaves the reference into PERSISTENT.md. Uncited narrative drifts; unsurfaced KB notes rot. The two stay tied or the system fails.

## Install

```bash
git clone https://github.com/Thunderpatty/tpmem.git
cd tpmem
bash install.sh
```

The installer:
1. Checks prereqs (`sqlite3`, `jq`, `git`, `claude`).
2. Prints the pitch, asks to continue.
3. Creates `~/.tpmem/` (db, tools, backups).
4. Applies schema, seeds system entities + 7 universal dev lessons.
5. Installs `curate-memory` + `review-flags` skills to `~/.claude/skills/`.
6. Drops MEMORY.md + PERSISTENT.md + FLAGS.md templates in your Claude Code project memory dir.
7. Installs the `kb`, `kb-note`, and `curate-memory` tools and adds `~/.tpmem/tools/` to PATH.

## After install

Open a Claude Code session. Tell your agent:

> *"Read `<cloned-tpmem-dir>/docs/agent-onboarding.md` and set up this memory system."*

Your agent will:
1. Read the onboarding doc + memory philosophy doc.
2. Introduce itself. Ask who you are, what you're working on, what must not break.
3. Decide if it wants to pick a name for itself (continuity across sessions).
4. Offer to run the **baseline** — curator reads all prior Claude Code conversations on this machine and extracts durable signal.
5. Start working. Use `kb handoff` at session end.

## Why not RAG

Retrieval-augmented generation is great for needle-in-a-haystack lookup. This system is built for **relationship memory** — the narrative and structured substrate of how a specific agent and specific human work together. Different problem, different tool. See `docs/memory-philosophy.md` for the longer answer.

## Directory layout (after install)

```
~/.tpmem/
├─ kb.db                         # SQLite substrate
├─ FLAGS.md                      # Curator review queue
├─ FLAGS-ARCHIVE.md              # Resolved flags
├─ conversation-manifest.json    # Delta tracking for curator
├─ curator-cron.log              # Run log
├─ curator-audit.log
├─ migrations/                   # Schema SQL
├─ persistent-backups/           # PERSISTENT.md snapshots (keeps last 7)
└─ tools/
   ├─ kb                         # CLI helper (read/query + handoffs + status)
   ├─ kb-note                    # Validated KB note writer (readback-verified)
   └─ curate-memory              # PERSISTENT.md snapshot helper

~/.claude/skills/
├─ curate-memory/SKILL.md
└─ review-flags/SKILL.md

~/.claude/projects/-home-<user>/memory/
├─ MEMORY.md                     # Always-loaded bootstrap
└─ PERSISTENT.md                 # Narrative layer
```

## Commands

```bash
kb handoff                        # Latest session handoff (run at session start)
kb entity <slug>                  # Everything about an entity
kb search <term>                  # Full-text search
kb prefs                          # User preferences by importance
kb projects                       # Active projects + products
kb pending-reviews                # Entities awaiting user review
kb context <slug|topic>           # Compact entity view (fuzzy): top notes + one-hop relations
kb stats                          # Row counts
kb write-handoff <project> <completed> <next_steps> [open_q] [blockers] [acceptance_criteria]

# Validated KB writes (named flags, category-checked, readback-verified):
kb-note <slug> --cat <category> --content "..." [--imp 1-10] [--tags a,b] [--source who]
echo "long content" | kb-note <slug> --cat fact --stdin

curate-memory                     # Snapshot PERSISTENT.md (keep last 7). Curation runs in-session — see below.
```

Curation runs **in-session**, not from a headless `claude -p`:
- *"run curate-memory"* — invoke the capture skill in your live Claude Code session.
- For automatic scheduling, run the tpmem daemon (`tpmem-companion-engine`): it keeps a persistent curator agent alive and injects the curation prompt into its tmux session on a schedule.
- *"review flags"* or *"/review-flags"* — walk the user through the pending queue.

## Philosophy

See `docs/memory-philosophy.md` for the longer version. Short version:

1. Memory exists to make the partnership compound.
2. Three layers with distinct jobs: MEMORY (bootstrap), PERSISTENT (narrative map), KB (queryable substrate).
3. **The KB is only as good as its references in PERSISTENT.md.** Weave, don't just accumulate.
4. Curator captures broadly; user governs via weekly review.
5. Scheduling matters because compounding matters — run the daemon so capture doesn't depend on memory.
6. Bias toward capture; under-capture is worse than bloat.
7. When in doubt, flag.

## Origin

This was built originally at the [Hopeful](https://hopefulai.com) lab as an internal system for one user + one agent. Extracted into a generic kit because the architecture seemed worth sharing. Scrubbed of project-specific data; only universal dev lessons seeded.

## License

MIT. See `LICENSE`.

## Uninstall

```bash
# Remove the tpmem directory
rm -rf ~/.tpmem

# Remove the skills
rm -rf ~/.claude/skills/curate-memory ~/.claude/skills/review-flags

# Remove the memory files (careful — your agent's accumulated context is in these)
rm ~/.claude/projects/-home-$USER/memory/MEMORY.md
rm ~/.claude/projects/-home-$USER/memory/PERSISTENT.md

# Remove the PATH line from your shell rc
# (edit ~/.bashrc or ~/.zshrc and delete the "tpmem — persistent memory tools" block)

# If you set up scheduled curation via the tpmem daemon (tpmem-companion-engine),
# stop/uninstall that separately per its own instructions.
```
