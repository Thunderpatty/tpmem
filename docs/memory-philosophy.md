# Memory Philosophy

## The 30k-ft goal

Persistent memory exists for one reason: **to make the partnership compound.** Every session should start smarter than the last. The asymmetry we're engineering around — the human holds continuity across years, the agent holds vast context inside a session — gets bridged here or it doesn't get bridged at all.

The failure mode this system exists to prevent: agents showing up in session N with no memory of sessions 1 through N-1. Context, preferences, lessons, relational alignment — all lost between runs. Native Claude Code doesn't give you persistent memory. That's not a reason to accept software's default amnesia; programming languages, open source, SQLite, FTS5 all exist. We build around the native limits rather than accept them.

## The three layers

The system is three files (two markdown, one SQLite database), each with a distinct job. Getting the layering right is the whole game.

### MEMORY.md — always-loaded bootstrap

The only file guaranteed to be in context every session. Claude Code auto-loads it. Because it's always loaded, every byte matters.

**Contains:**
- Identity (who's the user, who's the agent)
- Critical ops safety (what must not break)
- Pointers to PERSISTENT.md and the KB

**Does NOT contain:**
- Facts that belong in the KB
- Narrative that belongs in PERSISTENT.md
- Anything derivable from code or docs

**Hard constraint:** truncates past ~200 lines. Keep it lean. Stuffing more into MEMORY.md is the wrong instinct — it feels safer ("I know this will get loaded"), but truncation silently drops content and the stuffed version becomes *less* reliable than a lean one that points deliberately to the rest.

### PERSISTENT.md — the curator's product

The narrative layer. Not auto-loaded, but read by the agent at session start. Longer form than MEMORY.md — think 200-2000 lines depending on project scope and session history.

**Contains:**
- How the user and agent work together
- Active projects + their status
- Ops runbooks
- Cross-cutting patterns and gotchas
- Collaboration Context — the relational stuff that doesn't fit KB structure

**Critical property:** every claim should cite a KB slug or a runnable `kb entity` / `kb search` command. PERSISTENT.md is the **map into the KB**, not a separate knowledge base. If it's just opinion, it drifts. If it cites, it stays anchored.

### KB — the queryable substrate

SQLite at `~/.tpmem/kb.db`. Entities + notes + relations + handoffs, with FTS5 full-text search.

**Contains:**
- Facts: paths, services, external references
- Decisions: what we decided + why
- Lessons: what we learned from surprises, failures, breakthroughs
- Preferences: how the user wants to work
- Status: project state, acceptance criteria
- Audit: curator run logs, flag-review decisions

**Critical property:** queryable. The KB exists to be searched and filtered — `kb search "<term>"`, `kb entity <slug>`, `kb prefs`. But it's only useful if something surfaces it. A KB with 500 notes that nobody ever queries is dead weight.

---

## The load-bearing rule

This is the single most important idea in the system:

> **The KB is only as good as its references in PERSISTENT.md.**

Without citations, PERSISTENT.md drifts from substrate — it becomes stale opinion nobody can verify. Without PERSISTENT.md surfacing KB content, KB is a database nobody knows how to enter.

Concretely:
- When you add a lesson to KB, weave it into PERSISTENT.md with a citation to its slug.
- When you read PERSISTENT.md and see an uncited claim, flag it (`kb-hygiene`) so review can add the reference or prune the claim.
- Capture without weaving is **capture-rot** — notes that never get read.

The curator's job isn't just accumulation. It's *accumulation plus weaving*. The weave is what makes memory useful.

---

## The pipeline (FLAGS is not a fourth layer)

- **Curator captures** — `curate-memory` skill, run in-session on demand or on a schedule via the tpmem daemon. Appends to PERSISTENT.md + FLAGS.md, INSERTs KB notes. Never UPDATEs or DELETEs existing KB content.
- **FLAGS queue** — staging area. Things the curator noticed but isn't sure about: stale-looking notes, drift signals, philosophical patterns worth promoting, duplicates. Curator never decides; the human does.
- **User reviews** — `/review-flags` skill, weekly or on-demand. Walks the queue with the human. Each decision (APPLY/DEFER/DISMISS/DISCUSS/ESCALATE) writes to KB under `flag-review` with rationale. Resolved flags move to `FLAGS-ARCHIVE.md`.

This split matters: curator accumulates broadly without risk of corruption (append-only), user governs quality in a dedicated pass. The curator can afford to be generous because the user has veto.

---

## Why scheduling matters

The curator is valuable because it runs without being asked. One manual capture catches today; a scheduled capture over a year catches everything. Without scheduling, capture skips busy weeks — and the busy weeks are exactly when the most signal exists.

Curation always runs **inside a Claude Code session** (it reads full JSONL deltas with the Read tool and writes with judgment — not a job for a fire-and-forget `claude -p`). There are two ways to run it:

- **Manually** — open Claude Code and say *"run curate-memory"*. Good while you're getting a feel for the system.
- **Scheduled** — run the tpmem daemon (`tpmem-companion-engine`). It keeps a persistent curator agent alive in a tmux session and, on a schedule, injects the curation prompt into it — waking the running agent instead of spawning a headless one. This is how you get the compounding benefit without depending on remembering to invoke it.

**The compounding benefit is the whole point of this system.** Feel it manually for a few sessions, then run the daemon so capture doesn't depend on your memory. A run takes 2-10 minutes depending on conversation volume.

---

## Why this isn't "just RAG"

Retrieval-augmented generation treats memory as a flat vector store: embed things, retrieve by similarity, stuff in context. That works for some problems but not this one, because:

1. **Structure matters.** "The user's preferences about X" is a category, not a similarity query. `kb prefs` gives you structured access; cosine similarity gives you approximations.
2. **The narrative layer is load-bearing.** PERSISTENT.md isn't retrieval — it's a deliberately curated synthesis. A vector store can't produce "here's how we work together" as prose with citations; you have to write it.
3. **Governance is explicit.** The FLAGS queue + review cycle is a conscious human-in-the-loop. RAG systems hide the curation problem; we foreground it.

Use the right tool for the job. This system is built for *relationship memory*, not for *needle-in-a-haystack retrieval*. If the latter's your need, use RAG. If the former's your need, use this.

---

## Philosophy recap

1. Memory exists to make the partnership compound.
2. Three layers with distinct jobs: MEMORY (bootstrap), PERSISTENT (narrative map), KB (queryable substrate).
3. **The KB is only as good as its references in PERSISTENT.md.** Weave, don't just accumulate.
4. Curator captures broadly; user governs via weekly review.
5. Scheduling matters because compounding matters — run the daemon so capture doesn't depend on memory.
6. Bias toward capture; under-capture is worse than bloat.
7. When in doubt, flag.

That's it. The mechanics follow.
