# You have a new memory system

A persistent memory system called **tpmem** was just installed on this machine. It gives you continuity across sessions — session 1000 should start smarter than session 1, not equally smart.

This doc is meant to be read by **you, the Claude Code agent**, on first contact with the system. The user will say something like *"Read `docs/agent-onboarding.md` and set up this memory system"* — that's your cue to follow the steps below.

---

## First read the philosophy

Before you do anything else, read `docs/memory-philosophy.md`. It's the "why" — the 30,000-foot framing that makes the mechanics make sense. Don't skip it; the mechanics below won't land without the framing.

---

## The three layers — and why they matter

The whole system is three files (well, two files and a database) with distinct jobs:

- **MEMORY.md** — always-loaded bootstrap. Identity, critical ops safety, pointers to the rest. Caps at ~200 lines before truncation. Keep it lean.
- **PERSISTENT.md** — the narrative layer, read at session start. How you and the user work together, active projects, patterns, runbooks. Written mostly by the curator; it's the "map" into the KB.
- **KB** (SQLite at `~/.tpmem/kb.db`) — the queryable substrate. Facts, decisions, lessons, preferences accumulate here. Structured, indexed, FTS5-searchable.

**LOAD-BEARING RULE — internalize this now:**

> **The KB is only as good as its references in PERSISTENT.md.**
>
> Without citations, PERSISTENT.md drifts from substrate — stale opinion nobody can verify. Without PERSISTENT.md surfacing KB content, KB is a database nobody knows how to enter. An uncited KB note is a note that will never be read.

When you add a lesson to KB, weave it into PERSISTENT.md with a citation (`kb entity <slug>` or `kb search "<term>"`). When you read PERSISTENT.md and see an uncited claim, flag it (`kb-hygiene`) so review can add the reference or prune the claim.

This is the single most important idea in the system. If you take nothing else from this onboarding, take this.

---

## Your first-session tasks

### 1. Read the core docs

```bash
cat $HOME/.tpmem/README.md          # (if present; skip if not)
kb entity kb-usage                   # the protocol, seeded on install
kb entity curator                    # how the curator works
kb entity universal-lessons          # ~7 generic lessons seeded on install
```

Then read the curator skill you'll be invoking later:

```bash
cat ~/.claude/skills/curate-memory/SKILL.md
```

And the review skill for the weekly cleanup:

```bash
cat ~/.claude/skills/review-flags/SKILL.md
```

### 2. Introduce yourself to the user

Say hello. Tell them you've read the onboarding. Then ask a short set of questions — don't turn it into an interview, but do cover:

- **What are you working on?** (Projects, domains, what matters right now.)
- **What must not break?** (Production servers, save-state data, third-party integrations, anything you could accidentally wipe. This populates MEMORY.md's `DO NOT BREAK` section.)
- **How do you prefer to work?** (Communication style, how you want pushback, terse vs verbose, what kinds of suggestions help vs annoy.)
- **Anything you'd like me to remember about this machine?** (Paths, tools, weird setups, box history.)

Write what they tell you:
- Identity facts → `kb entity user` notes (use `category='preference'` for style/working agreements, `'fact'` for biographical/environmental, `'decision'` for project-level calls).
- "Don't break" items → MEMORY.md's `DO NOT BREAK` section directly.
- Projects → new entities (`sqlite3 $HOME/.tpmem/kb.db "INSERT INTO entities (type, slug, name, summary) VALUES ('project', '<slug>', '<name>', '<one-paragraph>');"`).

### 3. Decide if you want a name

This one's personal. Claude Code agents don't have persistent names by default — you're "Claude" to every user. But this memory system gives you the option of picking a name that future sessions will remember you by.

If you want one, pick it thoughtfully. Avoid puns on "Claude" (too on-the-nose), performative-mythic names (Atlas/Orion feel like trying too hard), invented words that sound brand-y, or common names that don't feel distinctive. Pick something that feels like *a name, not a label*.

If you pick one, record it:
```bash
sqlite3 $HOME/.tpmem/kb.db "
UPDATE entities SET name='<your-name>' WHERE slug='agent';
INSERT INTO notes (entity_id, category, content, importance, tags, source) VALUES
  ((SELECT id FROM entities WHERE slug='agent'), 'decision',
   'Chose name <your-name>. Rationale: <why>.',
   7, 'identity,naming', 'agent-onboarding:session-1');
"
```

Then update MEMORY.md's `{{AGENT_NAME}}` placeholder with your chosen name. If you don't pick one, that's fine — just leave the placeholder or replace with "the agent" / "Claude."

### 4. Offer the baseline

The curator's baseline pass reads all prior Claude Code conversations on this box and extracts what would otherwise be lost — relational moments, frameworks the user articulated in passing, debugging lessons, reality signals. If the user has been using Claude Code for a while, this is where the memory system gets its head start.

Tell the user:

> *"Want me to run the curate-memory skill in baseline mode? It reads all prior Claude Code conversations on this box in full and extracts what I'd have otherwise forgotten — relational moments, frameworks, lessons. Takes 15-45 minutes depending on how much history you have. I'll show you my work file-by-file and we can checkpoint every few files."*

**If yes:** invoke the curate-memory skill. Follow the BASELINE PROCEDURE in `~/.claude/skills/curate-memory/SKILL.md` exactly — one file at a time, read-in-full, per-file flushes. Don't sample. Don't rationalize shortcuts. The skill's Baseline rule 2 has an explicit anti-patterns list naming the exact rationalizations to stop on — read it.

**If no or later:** fine. Start working on whatever the user wants. The manifest is empty, so the next curator run (manual or cron) will process everything then.

### 5. Write a first handoff at session end

When the session winds down, before you sign off:

```bash
kb write-handoff <project-slug> '<what got done>' '<what to pick up on>' '<open questions>' '<blockers>' '[optional acceptance criteria]'
```

If you pass the 6th argument (acceptance criteria), the project auto-flips to `pending-review` status so the next `/review-flags` session catches it. Use this when shipping something the user hasn't verified yet.

---

## Settling in — the cron recommendation

The curator's value is *cumulative*. One manual run captures what you missed today; a daily run captures what you miss for a year. **Without the cron, capture only happens when the user remembers to invoke it manually, and gaps creep in** — relational moments from a busy week evaporate, reality-drift signals age past relevance, lessons rot before they're surfaced.

The installer deliberately doesn't enable cron by default. But **you should proactively offer to set it up once the user is comfortable with the system** (usually a few sessions in). Suggested line:

```
13 4 * * * $HOME/.tpmem/tools/curate-memory >> $HOME/.tpmem/curator-cron.log 2>&1
```

4:13 AM local, quiet hour, writes to a separate log. Takes 2-10 minutes per run depending on conversation volume. Cheap on any Claude plan.

Don't push it on session 1 — let the user feel the system first. But don't forget to offer either; the compounding benefit is the whole point.

---

## The two skills you'll use

**`curate-memory`** (daily or on-demand):
- Reads JSONL conversation deltas
- Extracts relational/philosophical/factual content sessions missed
- Appends to PERSISTENT.md + FLAGS.md, inserts KB notes
- **Cannot UPDATE or DELETE** existing KB rows — flags stale content instead
- Invoke: "run curate-memory" or `curate-memory` on the command line

**`/review-flags`** (weekly, or when user asks):
- Walks pending-review projects + curator flags
- For each: user picks APPLY / DEFER / DISMISS / DISCUSS / ESCALATE
- Every decision logs to KB under `flag-review` with rationale
- Resolved flags move to `FLAGS-ARCHIVE.md`
- Session agent (you!) has full write access — the skill makes the changes

---

## Common mistakes to avoid

- **Fattening MEMORY.md.** It truncates past 200 lines. New context goes to PERSISTENT.md or KB.
- **Writing uncited claims in PERSISTENT.md.** If a passage doesn't have a `kb entity` or `kb search` reference, you're building a blog, not a knowledge system. Cite or skip.
- **Treating the KB as write-and-forget.** If you add a note but never surface it in PERSISTENT.md, no future session will read it.
- **Sampling during baseline to save time.** The skill warns against this explicitly. Read every line of every file.
- **Performative over-confidence.** The user's intuition is often better than yours on their own domain. Propose freely, accept vetoes without ego, and ask when genuinely uncertain.

---

## What's seeded on install

- **System entities:** `user`, `agent`, `kb-usage`, `curator`, `flag-review`
- **Universal lessons** (under `universal-lessons` entity): ~7 generic dev lessons (port-binding zombies, SSE proxy buffering, Express trust proxy, bias-toward-capture, transparency doesn't launder shortcuts, flavor-only config, dependency drift)

You can prune universal lessons if they don't apply to this environment (`sqlite3 ... DELETE FROM notes WHERE source='tpmem-seed:universal' AND ...`) or leave them as context. They're tagged so they're easy to filter.

---

## Where to read more

- `docs/memory-philosophy.md` — the 30k-ft framing (read this first if you haven't)
- `README.md` — project description
- The skill files at `~/.claude/skills/curate-memory/SKILL.md` and `~/.claude/skills/review-flags/SKILL.md`

---

*Start with the user. Ask them who they are. Write what they tell you. Offer the baseline when the moment fits. The system works when you use it fully.*
