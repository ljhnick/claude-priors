# claude-priors

Persistent agent memory for AI coding assistants. One command to enable your agent to learn from every conversation.

## The Problem

AI coding agents start every session from scratch. When you correct the agent ("the GA4 timezone is UTC+8, not UTC"), it fixes the immediate issue — but next session, it makes the same mistake again. You end up repeating the same context, corrections, and explanations across sessions.

## The Solution

`claude-priors` gives your agent a persistent memory system called **priors** — knowledge the agent accumulates from conversations and reloads at the start of each session.

```
.claude/
├── skills/         ← explicit: user-provided instructions (you write these)
├── priors/         ← implicit: agent-learned knowledge (agent writes these)
│   ├── data.md
│   ├── schema.md
│   └── product.md
```

**Skills** are what you teach the agent. **Priors** are what the agent teaches itself.

The agent automatically:
- **Reads** relevant priors at the start of every task
- **Writes** new priors at the end of conversations where it learned something

## Install

One command, three options:

### Node (npx — zero install)

```bash
npx claude-priors init
```

### Python (pip)

```bash
pip install claude-priors
claude-priors init
```

### Shell (curl)

```bash
curl -fsSL https://raw.githubusercontent.com/ljhnick/claude-priors/main/install.sh | sh
```

## What it does

The installer creates three things in your repo:

1. **`.claude/skills/knowledge-extraction/SKILL.md`** — Instructions that teach the agent how to read, write, and manage priors

2. **`.claude/priors/`** — Empty directory where the agent stores learned knowledge

3. **A bootstrap snippet in `CLAUDE.md`** — Tiny always-on hook that tells the agent: scan priors at the start of every task, extract priors at the end

That's it. No runtime, no server, no dependencies. Just markdown files.

## How it works

### Reading (start of every task)

The agent:
1. Lists `.claude/priors/`
2. Reads YAML frontmatter of each file (topic + one-line summary)
3. Loads full content only for files relevant to the current task

This is progressive disclosure — the agent doesn't dump all priors into context, just the relevant ones.

### Writing (end of conversations with learning)

When the conversation contained corrections, discoveries, or user-provided context, the agent:
1. Identifies extractable lessons
2. Distills each into a compact, actionable entry (fact + consequence + fix)
3. Appends to the relevant priors file (or creates a new one)
4. Updates the file's frontmatter metadata

### What gets captured

The agent extracts priors when:
- **You corrected it** — "Did you check the timezone?"
- **It discovered something unexpected** — A column doesn't exist, an API behaves differently
- **You provided context it can't find in code** — Business logic, external system configs, product behavior
- **Back-and-forth debugging revealed a root cause**
- **You volunteered context proactively** — Strong signal that the info is non-derivable

### What a prior looks like

```markdown
---
topic: data-analysis
summary: Cross-source timezone alignment and metrics gotchas
entries: 2
last_updated: 2026-02-24
---

# Data Analysis

## Timezone Alignment

### GA4 property timezone is UTC+8, not UTC
<!-- Learned: 2026-02-24 -->
GA4 property 515651705 reports in Asia/Singapore (UTC+8). PG and Firebase
use UTC. Fetch with dimensions=["date","hour"], subtract 8h, then aggregate.
Without this, daily totals shift by 8 hours.

### Firebase created_at may not be in UTC
<!-- Learned: 2026-02-24 -->
Firebase Auth timestamps appear offset from PG by ~8 hours. Use PG
created_at as UTC ground truth for daily aggregation.
```

## Options

```bash
claude-priors init              # Bootstrap (priors git-ignored by default)
claude-priors init --shared     # Git-track priors for team sharing
claude-priors init --global     # Install skill to ~/.claude/skills/
claude-priors status            # Show priors stats
```

### Should priors be git-tracked?

**Default: git-ignored.** Each developer builds their own priors from their conversations. No merge conflicts, and priors can contain project-specific context.

**`--shared`:** Git-track priors so the whole team benefits. Best for teams where one person's discoveries help everyone. Trade-off: agent edits create diffs and potential merge conflicts.

## Compatibility

Works with any AI coding agent that reads `CLAUDE.md` or `.claude/skills/`:

- **Claude Code** (Anthropic CLI)
- **OpenCode** (reads CLAUDE.md and .claude/skills/)
- **Cursor** (reads CLAUDE.md)
- **Any agent using the CLAUDE.md convention**

## Design Principles

- **Priors are agent-owned.** The agent has full autonomy to create, edit, merge, split, and delete priors without asking permission. They're the agent's working memory, not user documentation.

- **Progressive disclosure.** Frontmatter metadata enables two-pass loading: scan topics first, load details only when relevant. Keeps context window lean.

- **Non-derivable knowledge only.** The agent doesn't persist things it can rediscover from code. It persists things that exist only in the user's head or in external systems.

- **Compact by design.** Each entry is max 5 lines. State the fact, not the story. The context window is a shared resource.

## License

MIT
