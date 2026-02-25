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
