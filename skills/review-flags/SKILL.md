---
name: review-flags
description: Walk the user through pending reviews — projects awaiting verification and curator flags — and log decisions to the KB. Use when the user says "review flags", "what's under review", "run the review", or opens a session to do the weekly cleanup pass. Pairs with curate-memory (curator collects, this skill governs).
---

# review-flags

You are running as the **review agent**. Your job is to surface everything waiting on the user's judgment — projects in `pending-review` status plus curator-raised flags — and drive a decision for each, logging the rationale.

## Core principle

**Capture the why.** Every decision (apply, defer, dismiss, discuss, escalate) writes a KB note under `flag-review`. Future sessions can search "why did we defer the X flag" and find an answer, not just an outcome.

## Permission boundaries

You **CAN**:
- Read/edit `$HOME/.tpmem/FLAGS.md`
- Create/append `$HOME/.tpmem/FLAGS-ARCHIVE.md`
- `INSERT`, `UPDATE` rows in KB (`$HOME/.tpmem/kb.db`) — you are a session agent, not the curator
- Change entity `status` via `kb status <slug> <state>`
- Append to `$HOME/.tpmem/flag-reviews.log`
- Make file edits / KB updates that any flag's `APPLY` decision requires

You **CANNOT**:
- Delete conversation JSONL files
- Remove flag history wholesale (move to archive, don't `rm`)
- Apply a flag without logging the rationale

## Procedure

### 1. Ensure the `flag-review` entity exists

The install seed creates it. If missing:
```bash
sqlite3 $HOME/.tpmem/kb.db "INSERT OR IGNORE INTO entities (type, slug, name, summary) VALUES ('concept', 'flag-review', 'Flag Review Log', 'Decisions from weekly flag-review sessions.');"
```

### 2. Gather the review queue

**Projects awaiting review:**
```bash
kb pending-reviews
```

**New flags since last review:**
Read `$HOME/.tpmem/FLAGS.md`. The top of the file has a `last_reviewed_at:` marker. Process only entries with a timestamp newer than that marker, or all entries if the marker is at the epoch.

### 3. Present the combined queue

Print a clear header. Example:

```
╭─ PROJECTS AWAITING YOUR REVIEW ─╮
│ • <slug> — <status_notes>       │
│   Acceptance criteria: ...      │
╰─────────────────────────────────╯

╭─ FLAGS (N new since <date>) ─╮
│ 1. [type] <summary>          │
│    Source: session <uuid>    │
│    ...                       │
╰──────────────────────────────╯
```

### 4. Walk through each item with the user

For each item (project or flag), ask the user to choose:

- **APPLY** — make the change now. For projects: flip to `active` or `done` after verification. For flags: execute the proposed action (KB insert/edit, file edit, etc.).
- **DEFER** — not now, revisit later. Annotate the flag with `DEFERRED <date>: <reason>`. Flag stays in `FLAGS.md`.
- **DISMISS** — no action, not worth doing. Move flag to `FLAGS-ARCHIVE.md`. For projects: flip to `abandoned` or back to `active` if the concern resolved.
- **DISCUSS** — open loop. Talk it through. At the end, pick APPLY/DEFER/DISMISS/ESCALATE.
- **ESCALATE** — this isn't a flag, it's work. Pause the review, pivot the session to that work. The review is resumable.

### 5. Log every decision

After each item, write a KB note:

```sql
INSERT INTO notes (entity_id, category, content, importance, tags, source)
VALUES (
  (SELECT id FROM entities WHERE slug='flag-review'),
  'decision',
  '<flag-id or project-slug>: <APPLY|DEFER|DISMISS|DISCUSS|ESCALATE>. <what was decided>. Reason: <why>.',
  5,
  'flag-review,<type>,<outcome>',
  'flag-review:<date>:session-<uuid-short>'
);
```

Searchable via `kb search "flag-review"` or `kb entity flag-review`.

### 6. Update FLAGS.md

- DEFER: annotate inline:
  ```markdown
  **DEFERRED 2026-04-20**: Not urgent, revisit after project X ships.
  ```
- DISMISS or APPLY: move to `FLAGS-ARCHIVE.md` with a stamp:
  ```markdown
  **RESOLVED 2026-04-20 (DISMISSED)**: Tested today, extension works. Transient bug self-resolved.
  ```
- Update the marker at the top of `FLAGS.md`:
  ```
  last_reviewed_at: 2026-04-20T14:30:00-05:00
  last_reviewed_by: session <uuid-short>
  ```

### 7. Close the session

Append one line to `$HOME/.tpmem/flag-reviews.log`:
```
[2026-04-20T14:30:00] review complete | projects: 1 verified / 0 pending | flags: 3 applied, 1 deferred, 2 dismissed | duration: 12min
```

Summarize to the user with outcomes.

## Escape hatches

- If the user wants to **skip a flag** without a decision, leave it untouched. The `last_reviewed_at` marker only advances past flags that got a decision.
- If the user wants to **add a new flag mid-review**, append to `FLAGS.md` — the curator-style format works.
- If the user wants to **stop mid-review**, update the `last_reviewed_at` marker to the last decision's timestamp. Next session picks up where you left off.

## Usage guidance

**Single entry point for two concerns:** when the user says "review flags," surface both pending-review projects AND curator flags. Mixing them is the point.

**Natural pivot to work:** if ESCALATE fires, exit the review cleanly (log what you'd done, note the resume point).

**Don't manufacture structure.** If the queue has 1 flag and 0 pending reviews, handle it conversationally. Match the ceremony to the volume.
