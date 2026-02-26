#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const PRIORS_MARKER = '## Priors';
const VERSION = '0.1.2';

// Resolve paths to bundled assets (works both locally and via npx)
const PKG_ROOT = path.resolve(__dirname, '..');
const SKILL_SRC = path.resolve(PKG_ROOT, '..', 'skill', 'SKILL.md');
const BOOTSTRAP_SRC = path.resolve(PKG_ROOT, '..', 'bootstrap', 'CLAUDE.md.snippet');

// Fallback: when installed as npm package, skill/ and bootstrap/ are siblings to bin/
const SKILL_SRC_ALT = path.resolve(PKG_ROOT, 'skill', 'SKILL.md');
const BOOTSTRAP_SRC_ALT = path.resolve(PKG_ROOT, 'bootstrap', 'CLAUDE.md.snippet');

function resolveAsset(primary, fallback) {
  if (fs.existsSync(primary)) return primary;
  if (fs.existsSync(fallback)) return fallback;
  return null;
}

function readAsset(primary, fallback) {
  const resolved = resolveAsset(primary, fallback);
  if (!resolved) {
    console.error(`Error: Could not find asset. Looked in:\n  ${primary}\n  ${fallback}`);
    process.exit(1);
  }
  return fs.readFileSync(resolved, 'utf8');
}

function printUsage() {
  console.log(`
claude-priors v${VERSION} — Persistent agent memory for AI coding assistants

Usage:
  claude-priors init [options]    Bootstrap priors in current directory
  claude-priors status            Show priors stats
  claude-priors help              Show this help

Options:
  --global    Install skill to ~/.claude/skills/ instead of repo
  `);
}

function init(args) {
  const cwd = process.cwd();
  const global = args.includes('--global');

  console.log(`\nclaude-priors v${VERSION}`);
  console.log(`Initializing in: ${cwd}\n`);

  // 1. Create .claude/priors/
  const priorsDir = path.join(cwd, '.claude', 'priors');
  if (!fs.existsSync(priorsDir)) {
    fs.mkdirSync(priorsDir, { recursive: true });
    fs.writeFileSync(path.join(priorsDir, '.gitkeep'), '');
    console.log('  Created .claude/priors/');
  } else {
    console.log('  .claude/priors/ already exists');
  }

  // 2. Copy SKILL.md
  const skillContent = readAsset(SKILL_SRC, SKILL_SRC_ALT);
  let skillDir;
  if (global) {
    skillDir = path.join(
      process.env.HOME || process.env.USERPROFILE,
      '.claude', 'skills', 'knowledge-extraction'
    );
  } else {
    skillDir = path.join(cwd, '.claude', 'skills', 'knowledge-extraction');
  }

  if (!fs.existsSync(skillDir)) {
    fs.mkdirSync(skillDir, { recursive: true });
  }

  const skillDest = path.join(skillDir, 'SKILL.md');
  if (!fs.existsSync(skillDest)) {
    fs.writeFileSync(skillDest, skillContent);
    console.log(`  Created ${global ? '~/.claude/skills' : '.claude/skills'}/knowledge-extraction/SKILL.md`);
  } else {
    // Check version
    const existing = fs.readFileSync(skillDest, 'utf8');
    if (existing === skillContent) {
      console.log(`  SKILL.md already up to date`);
    } else {
      fs.writeFileSync(skillDest, skillContent);
      console.log(`  Updated SKILL.md to v${VERSION}`);
    }
  }

  // 3. Append bootstrap to CLAUDE.md (or AGENTS.md)
  const bootstrapContent = readAsset(BOOTSTRAP_SRC, BOOTSTRAP_SRC_ALT);

  // Detect which instruction file exists
  let instructionFile = null;
  const candidates = ['CLAUDE.md', 'AGENTS.md'];
  for (const candidate of candidates) {
    if (fs.existsSync(path.join(cwd, candidate))) {
      instructionFile = candidate;
      break;
    }
  }

  if (!instructionFile) {
    instructionFile = 'CLAUDE.md';
  }

  const instructionPath = path.join(cwd, instructionFile);

  if (fs.existsSync(instructionPath)) {
    const existing = fs.readFileSync(instructionPath, 'utf8');
    if (existing.includes(PRIORS_MARKER)) {
      console.log(`  ${instructionFile} already has priors bootstrap`);
    } else {
      fs.writeFileSync(instructionPath, existing.trimEnd() + '\n\n' + bootstrapContent.trim() + '\n');
      console.log(`  Appended priors bootstrap to ${instructionFile}`);
    }
  } else {
    fs.writeFileSync(instructionPath, bootstrapContent.trim() + '\n');
    console.log(`  Created ${instructionFile} with priors bootstrap`);
  }

  console.log('\nDone! Your agent will now learn from every conversation.\n');
}

function status() {
  const cwd = process.cwd();
  const priorsDir = path.join(cwd, '.claude', 'priors');

  if (!fs.existsSync(priorsDir)) {
    console.log('No priors directory found. Run `claude-priors init` first.');
    return;
  }

  const files = fs.readdirSync(priorsDir).filter(f => f.endsWith('.md'));

  if (files.length === 0) {
    console.log('Priors directory exists but is empty. The agent will start writing priors as it learns.\n');
    return;
  }

  console.log(`\nPriors: ${priorsDir}\n`);

  let totalEntries = 0;

  for (const file of files) {
    const content = fs.readFileSync(path.join(priorsDir, file), 'utf8');

    // Parse frontmatter
    const fmMatch = content.match(/^---\n([\s\S]*?)\n---/);
    let topic = file.replace('.md', '');
    let summary = '';
    let entries = 0;
    let lastUpdated = '';

    if (fmMatch) {
      const fm = fmMatch[1];
      const topicMatch = fm.match(/topic:\s*(.+)/);
      const summaryMatch = fm.match(/summary:\s*(.+)/);
      const entriesMatch = fm.match(/entries:\s*(\d+)/);
      const dateMatch = fm.match(/last_updated:\s*(.+)/);

      if (topicMatch) topic = topicMatch[1].trim();
      if (summaryMatch) summary = summaryMatch[1].trim();
      if (entriesMatch) entries = parseInt(entriesMatch[1]);
      if (dateMatch) lastUpdated = dateMatch[1].trim();
    }

    totalEntries += entries;
    console.log(`  ${file}`);
    console.log(`    Topic: ${topic} | Entries: ${entries} | Updated: ${lastUpdated || 'unknown'}`);
    if (summary) console.log(`    ${summary}`);
    console.log();
  }

  console.log(`Total: ${files.length} files, ${totalEntries} entries\n`);
}

// --- Main ---
const args = process.argv.slice(2);
const command = args[0];

switch (command) {
  case 'init':
    init(args.slice(1));
    break;
  case 'status':
    status();
    break;
  case 'help':
  case '--help':
  case '-h':
  case undefined:
    printUsage();
    break;
  default:
    console.error(`Unknown command: ${command}`);
    printUsage();
    process.exit(1);
}
