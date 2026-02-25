#!/usr/bin/env bash
set -euo pipefail

VERSION="0.1.0"
PRIORS_MARKER="## Priors"
SHARED=false

# Parse args
for arg in "$@"; do
  case $arg in
    --shared) SHARED=true ;;
    --help|-h)
      echo "claude-priors v${VERSION} — Persistent agent memory for AI coding assistants"
      echo ""
      echo "Usage: curl -fsSL https://raw.githubusercontent.com/<org>/claude-priors/main/install.sh | sh"
      echo "   or: ./install.sh [--shared]"
      echo ""
      echo "Options:"
      echo "  --shared    Git-track priors (default: git-ignored)"
      exit 0
      ;;
  esac
done

echo ""
echo "claude-priors v${VERSION}"
echo "Initializing in: $(pwd)"
echo ""

# 1. Create .claude/priors/
if [ ! -d ".claude/priors" ]; then
  mkdir -p .claude/priors
  touch .claude/priors/.gitkeep
  echo "  Created .claude/priors/"
else
  echo "  .claude/priors/ already exists"
fi

# 2. Create SKILL.md
SKILL_DIR=".claude/skills/knowledge-extraction"
mkdir -p "$SKILL_DIR"

if [ ! -f "$SKILL_DIR/SKILL.md" ]; then
  cat > "$SKILL_DIR/SKILL.md" << 'SKILLEOF'
---
name: knowledge-extraction
description: Detailed instructions for the agent priors system — how to extract, format, store, consume, and manage priors files in .claude/priors/. Load this skill when you need to write new priors, reorganize existing priors, or understand the priors file format. The always-on bootstrap lives in CLAUDE.md; this skill provides the full reference.
---

# Knowledge Extraction — Priors System Reference

This skill is the detailed reference for the priors system. The always-on bootstrap in `CLAUDE.md` tells the agent to scan and use priors every session. This skill is loaded on demand when the agent needs to **write, format, or manage** priors.

## Skills vs Priors

- **Skills** (`.claude/skills/`) — Explicit, user-provided and user-maintained. **Never write agent-learned knowledge into these files.**
- **Priors** (`.claude/priors/`) — Implicit, agent-learned and agent-maintained. The agent's working memory persisted to disk.

## Agent Autonomy Over Priors

Priors are fully agent-managed. The agent has **unconditional permission** to create, edit, rewrite, merge, split, delete, and reorganize priors files and directory structure. No user confirmation needed. Optimize purely for agent utility: fast scanning, low token cost, high signal density.

## When to Extract

After completing a task, extract if the conversation contained:

1. **User correction** — User pointed out something wrong
2. **Unexpected discovery** — Something behaved differently than assumed
3. **Domain context the user provided** — System behavior, business logic, conventions not in code
4. **Multi-step debugging** — Root cause of a back-and-forth diagnosis
5. **Workaround or gotcha** — Non-obvious solution or edge case
6. **User-volunteered context** — User proactively provided info (strong non-derivable signal)

Do NOT extract when:
- Task completed smoothly on first attempt
- Knowledge already exists in skills or priors
- Insight is too one-time-specific to reuse

## Derivable vs Non-Derivable Context

- **Derivable** — Discoverable from codebase (schemas, file structure). Don't persist unless expensive to re-derive.
- **Non-derivable** — Exists only in user's head or external systems (timezone configs, business events, product behavior). Always persist.

When a user volunteers information unprompted, it's almost certainly non-derivable — they're telling you because they know you can't find it. Always capture it.

## Priors File Format

### Frontmatter (required)

Every priors file has YAML frontmatter for progressive disclosure — the agent scans frontmatter to decide relevance before loading the body.

```yaml
---
topic: <short topic name>
summary: <one-line description — used for relevance scanning without loading body>
entries: <count>
last_updated: <YYYY-MM-DD>
---
```

### Body

```markdown
# <Topic>

## <Section>

### <Fact title>
<!-- Learned: YYYY-MM-DD -->
<1-3 sentences: fact, consequence, correct approach. Max 5 lines.>
```

### Entry rules

- State the **fact**, not the discovery story
- Include **consequence** of getting it wrong
- Include the **correct approach**
- Max 5 lines per entry
- Code snippets only when they save more words than they cost
- Newest entries first within each section

## Where to Store

All priors: `<repo>/.claude/priors/`. Organize by **topic domain**:

```
.claude/priors/
├── data-analysis.md
├── schema.md
├── deployment.md
└── product.md
```

Decision tree:
1. `.claude/priors/` doesn't exist? Create it.
2. Relevant file exists? Append. If not, create with frontmatter.
3. Relevant `##` section exists? Append under it. If not, create one.
4. Update frontmatter (`entries`, `last_updated`) after every edit.

## Execution (Writing Priors)

1. Identify extractable lessons from conversation
2. Draft compact entries
3. Read target priors file (or create with frontmatter)
4. Append under appropriate section
5. Update frontmatter
6. Briefly confirm to user what was captured

Do this automatically at conversation end without being asked.

## Execution (Reading Priors)

1. List `.claude/priors/`
2. Read frontmatter only (first lines up to closing `---`)
3. Based on `topic` and `summary`, decide relevance to current task
4. Load full body only for relevant files

## Maintenance

Proactively maintain quality:
- **Merge** overlapping files
- **Split** files exceeding ~50 entries
- **Rewrite** verbose or unclear entries
- **Delete** outdated entries or entries now covered by explicit skills
- **Update frontmatter** after every change
SKILLEOF
  echo "  Created .claude/skills/knowledge-extraction/SKILL.md"
else
  echo "  SKILL.md already exists"
fi

# 3. Append bootstrap to CLAUDE.md or AGENTS.md
INSTRUCTION_FILE=""
if [ -f "CLAUDE.md" ]; then
  INSTRUCTION_FILE="CLAUDE.md"
elif [ -f "AGENTS.md" ]; then
  INSTRUCTION_FILE="AGENTS.md"
else
  INSTRUCTION_FILE="CLAUDE.md"
fi

BOOTSTRAP_TEXT='
## Priors

This project uses agent priors (`.claude/priors/`) — persistent knowledge the agent accumulates across sessions.

**Start of every task:** List `.claude/priors/` and read each file'\''s YAML frontmatter (`topic`, `summary`). Load full content only for files relevant to the current task.

**End of every conversation** where you were corrected, discovered something unexpected, or the user provided context you couldn'\''t derive from code: load the `knowledge-extraction` skill from `.claude/skills/` and extract priors.'

if [ -f "$INSTRUCTION_FILE" ]; then
  if grep -q "$PRIORS_MARKER" "$INSTRUCTION_FILE" 2>/dev/null; then
    echo "  $INSTRUCTION_FILE already has priors bootstrap"
  else
    printf '\n%s\n' "$BOOTSTRAP_TEXT" >> "$INSTRUCTION_FILE"
    echo "  Appended priors bootstrap to $INSTRUCTION_FILE"
  fi
else
  printf '%s\n' "$BOOTSTRAP_TEXT" > "$INSTRUCTION_FILE"
  echo "  Created $INSTRUCTION_FILE with priors bootstrap"
fi

# 4. Handle .gitignore
if [ "$SHARED" = false ]; then
  if [ -f ".gitignore" ]; then
    if grep -q ".claude/priors/" ".gitignore" 2>/dev/null; then
      echo "  .gitignore already excludes priors"
    else
      printf '\n# Agent priors (local knowledge)\n.claude/priors/\n' >> .gitignore
      echo "  Added .claude/priors/ to .gitignore"
    fi
  else
    printf '# Agent priors (local knowledge)\n.claude/priors/\n' > .gitignore
    echo "  Created .gitignore with priors exclusion"
  fi
else
  echo "  --shared: priors will be git-tracked"
fi

echo ""
echo "Done! Your agent will now learn from every conversation."
echo ""
