#!/usr/bin/env bash
# tpmem — persistent memory for Claude Code agents
# Install script. Run from the cloned repo root: bash install.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TPMEM_DIR="${HOME}/.tpmem"
CLAUDE_PROJECT_DIR="${HOME}/.claude/projects/-home-${USER}"
CLAUDE_SKILLS_DIR="${HOME}/.claude/skills"
CLAUDE_MEMORY_DIR="${CLAUDE_PROJECT_DIR}/memory"

# ─── Pitch + prompt ────────────────────────────────────────────
cat <<'EOF'
╭──────────────────────────────────────────────────────────────────╮
│  tpmem — persistent memory for Claude Code agents                │
│                                                                  │
│  Gives your agent continuity across sessions via:                │
│    • MEMORY.md — always-loaded bootstrap (<200 lines)            │
│    • PERSISTENT.md — narrative layer, how you work together      │
│    • KB (SQLite) — queryable structured facts                    │
│    • FLAGS queue + weekly review workflow                        │
│    • curator skill that captures what sessions miss              │
│                                                                  │
│  Load-bearing rule: the KB is only as good as its references     │
│  in PERSISTENT.md. Curator captures; user governs weekly.        │
│                                                                  │
│  This installer will:                                            │
│    1. Create ~/.tpmem/ (db, tools, backups)                      │
│    2. Apply schema, seed system entities + universal lessons     │
│    3. Install 2 skills to ~/.claude/skills/                      │
│    4. Place MEMORY.md + PERSISTENT.md + FLAGS.md templates       │
│       in your Claude Code project memory dir                     │
│    5. Add ~/.tpmem/tools/ to PATH via your shell rc              │
│    6. Offer to set up a daily curator cron (default: off)        │
│                                                                  │
│  After install, open a Claude Code session and say:              │
│    "Read <this-repo>/docs/agent-onboarding.md and set up         │
│     this memory system."                                         │
│                                                                  │
│  Your agent will read the onboarding doc, introduce itself,      │
│  ask you about yourself and your work, and offer to run the      │
│  baseline (read all prior Claude Code conversations for          │
│  durable signal).                                                │
╰──────────────────────────────────────────────────────────────────╯

EOF

read -r -p "Continue with install? [y/N] " yn
case "$yn" in
  [Yy]*) ;;
  *) echo "Aborted."; exit 0 ;;
esac

# ─── Prereq check ──────────────────────────────────────────────
echo ""
echo "→ Checking prerequisites..."

missing=()
for cmd in sqlite3 jq git; do
  command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
done

if command -v claude >/dev/null 2>&1; then
  echo "  ✓ claude CLI found"
else
  echo "  ⚠ claude CLI not found in PATH"
  echo "    Not strictly required for install, but needed for the curator wrapper."
  echo "    Install Claude Code: https://claude.com/claude-code"
fi

if [ ${#missing[@]} -gt 0 ]; then
  echo ""
  echo "✗ Missing prerequisites: ${missing[*]}"
  echo "  Install with your package manager, e.g.:"
  echo "    Debian/Ubuntu:  sudo apt install ${missing[*]}"
  echo "    macOS (brew):   brew install ${missing[*]}"
  exit 1
fi

if [ ! -d "$CLAUDE_PROJECT_DIR" ]; then
  echo ""
  echo "⚠ Claude Code project dir not found: $CLAUDE_PROJECT_DIR"
  echo "  Creating it now — but note: Claude Code typically creates this on first run."
  echo "  If your project dir is at a non-standard path, edit this script (CLAUDE_PROJECT_DIR)."
  mkdir -p "$CLAUDE_PROJECT_DIR"
fi

echo "  ✓ Prereqs OK"

# ─── Install dirs ──────────────────────────────────────────────
echo ""
echo "→ Creating directories..."

mkdir -p "${TPMEM_DIR}"/{migrations,tools,persistent-backups}
mkdir -p "${CLAUDE_SKILLS_DIR}"/{curate-memory,review-flags}
mkdir -p "${CLAUDE_MEMORY_DIR}"

echo "  ✓ ${TPMEM_DIR}/"
echo "  ✓ ${CLAUDE_SKILLS_DIR}/"
echo "  ✓ ${CLAUDE_MEMORY_DIR}/"

# ─── Apply schema ──────────────────────────────────────────────
echo ""
echo "→ Initializing KB..."

DB="${TPMEM_DIR}/kb.db"
if [ -f "$DB" ]; then
  echo "  ⚠ ${DB} already exists. Skipping schema + seed (use --force to reinitialize)."
  if [[ "${1:-}" == "--force" ]]; then
    echo "  → --force specified, reinitializing."
    rm -f "$DB"
  fi
fi

if [ ! -f "$DB" ]; then
  sqlite3 "$DB" < "${REPO_DIR}/schema/001_init.sql"
  sqlite3 "$DB" < "${REPO_DIR}/schema/002_seed_system.sql"
  sqlite3 "$DB" < "${REPO_DIR}/examples/universal-seeds.sql"
  cp "${REPO_DIR}/schema/"*.sql "${TPMEM_DIR}/migrations/"
  cp "${REPO_DIR}/examples/universal-seeds.sql" "${TPMEM_DIR}/migrations/"
  echo "  ✓ KB initialized at ${DB}"
fi

# ─── Install tools ─────────────────────────────────────────────
echo ""
echo "→ Installing tools..."

install -m 0755 "${REPO_DIR}/tools/kb" "${TPMEM_DIR}/tools/kb"
install -m 0755 "${REPO_DIR}/tools/curate-memory" "${TPMEM_DIR}/tools/curate-memory"
echo "  ✓ kb → ${TPMEM_DIR}/tools/kb"
echo "  ✓ curate-memory → ${TPMEM_DIR}/tools/curate-memory"

# Add to PATH via shell rc (idempotent)
SHELL_RC=""
if [[ -n "${BASH_VERSION:-}" ]] || [[ "$SHELL" =~ bash ]]; then
  SHELL_RC="${HOME}/.bashrc"
elif [[ -n "${ZSH_VERSION:-}" ]] || [[ "$SHELL" =~ zsh ]]; then
  SHELL_RC="${HOME}/.zshrc"
fi

if [ -n "$SHELL_RC" ] && [ -f "$SHELL_RC" ]; then
  if ! grep -q 'tpmem/tools' "$SHELL_RC"; then
    echo '' >> "$SHELL_RC"
    echo '# tpmem — persistent memory tools' >> "$SHELL_RC"
    echo 'export PATH="$HOME/.tpmem/tools:$PATH"' >> "$SHELL_RC"
    echo "  ✓ Added ~/.tpmem/tools to PATH in $SHELL_RC (restart shell or source to activate)"
  else
    echo "  ✓ ~/.tpmem/tools already in PATH ($SHELL_RC)"
  fi
else
  echo "  ⚠ Could not auto-detect shell rc. Add manually:"
  echo '    export PATH="$HOME/.tpmem/tools:$PATH"'
fi

# ─── Install skills ────────────────────────────────────────────
echo ""
echo "→ Installing Claude Code skills..."

install -m 0644 "${REPO_DIR}/skills/curate-memory/SKILL.md" "${CLAUDE_SKILLS_DIR}/curate-memory/SKILL.md"
install -m 0644 "${REPO_DIR}/skills/review-flags/SKILL.md" "${CLAUDE_SKILLS_DIR}/review-flags/SKILL.md"
echo "  ✓ curate-memory skill installed"
echo "  ✓ review-flags skill installed"

# ─── Install templates ─────────────────────────────────────────
echo ""
echo "→ Installing memory templates..."

# Placeholder substitution: leave {{AGENT_NAME}} + {{USER_NAME}} for the agent to fill,
# but resolve {{USER}} and {{HOME}} to real values.
subst() {
  local src="$1"
  local dst="$2"
  sed \
    -e "s|{{HOME}}|${HOME}|g" \
    -e "s|{{USER}}|${USER}|g" \
    "$src" > "$dst"
}

MEMORY_FILE="${CLAUDE_MEMORY_DIR}/MEMORY.md"
PERSISTENT_FILE="${CLAUDE_MEMORY_DIR}/PERSISTENT.md"
FLAGS_FILE="${TPMEM_DIR}/FLAGS.md"
FLAGS_ARCHIVE_FILE="${TPMEM_DIR}/FLAGS-ARCHIVE.md"

for pair in \
  "${REPO_DIR}/templates/MEMORY.md.template:${MEMORY_FILE}" \
  "${REPO_DIR}/templates/PERSISTENT.md.template:${PERSISTENT_FILE}" \
  "${REPO_DIR}/templates/FLAGS.md.template:${FLAGS_FILE}" \
  "${REPO_DIR}/templates/FLAGS-ARCHIVE.md.template:${FLAGS_ARCHIVE_FILE}" \
  ; do
  src="${pair%%:*}"
  dst="${pair##*:}"
  if [ -f "$dst" ]; then
    echo "  ⚠ ${dst} exists, leaving untouched. (Delete it and rerun to regenerate.)"
  else
    subst "$src" "$dst"
    echo "  ✓ ${dst}"
  fi
done

# ─── Manifest ──────────────────────────────────────────────────
MANIFEST="${TPMEM_DIR}/conversation-manifest.json"
if [ ! -f "$MANIFEST" ]; then
  cat > "$MANIFEST" <<EOF
{
  "schema_version": 1,
  "notes": "Tracks Claude Code session JSONL files. Owned exclusively by curate-memory skill. Byte-length comparison assumes append-only JSONL. If a file shrinks, treat as anomaly and re-read in full.",
  "last_run": null,
  "conversations": {}
}
EOF
  echo "  ✓ Empty conversation manifest created at ${MANIFEST}"
fi

# ─── Cron offer ────────────────────────────────────────────────
echo ""
echo "→ Daily curator cron (recommended for maximum cumulative effect)"
echo ""
echo "  The curator's value compounds. One manual run captures what you missed today;"
echo "  a daily run captures what you miss for a year. Without the cron, capture only"
echo "  happens when you remember to invoke it manually, and gaps creep in."
echo ""
echo "  We DEFAULT TO OFF so you can feel the system manually first. STRONGLY"
echo "  RECOMMENDED to enable it once you're comfortable (a few sessions in)."
echo "  Your agent can help you set it up later when you're ready."
echo ""
read -r -p "  Install daily cron now? [y/N] " cron_yn
case "$cron_yn" in
  [Yy]*)
    CRON_LINE="13 4 * * * ${TPMEM_DIR}/tools/curate-memory >> ${TPMEM_DIR}/curator-cron.log 2>&1"
    if crontab -l 2>/dev/null | grep -q 'tpmem/tools/curate-memory'; then
      echo "  ✓ Cron already installed."
    else
      (crontab -l 2>/dev/null; echo "$CRON_LINE") | crontab -
      echo "  ✓ Cron installed: runs daily at 04:13 local time."
    fi
    ;;
  *)
    echo "  → Skipped. To add later:"
    echo "      crontab -e"
    echo "    and add:"
    echo "      13 4 * * * ${TPMEM_DIR}/tools/curate-memory >> ${TPMEM_DIR}/curator-cron.log 2>&1"
    ;;
esac

# ─── Done ──────────────────────────────────────────────────────
cat <<EOF

╭──────────────────────────────────────────────────────────────────╮
│  ✓ tpmem installed                                               │
│                                                                  │
│  Next steps:                                                     │
│    1. Restart your shell (or source ${SHELL_RC##*/})                 │
│       to pick up the PATH change.                                │
│    2. Open a Claude Code session.                                │
│    3. Tell your agent:                                           │
│                                                                  │
│       "Read ${REPO_DIR}/docs/agent-onboarding.md           │
│        and set up this memory system."                           │
│                                                                  │
│  Your agent will read the onboarding, introduce itself, ask      │
│  about you and your work, and offer to run the baseline.         │
│                                                                  │
│  Cron: ${cron_yn:-N} (recommended once you're comfortable)                    │
│                                                                  │
│  Verify: kb stats                                                │
│                                                                  │
╰──────────────────────────────────────────────────────────────────╯

EOF
