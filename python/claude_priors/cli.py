"""CLI for claude-priors: bootstrap persistent agent memory into any repo."""

import argparse
import os
import re
import sys
from pathlib import Path

VERSION = "0.1.0"
PRIORS_MARKER = "## Priors"


def get_asset(name: str) -> str:
    """Read a bundled asset file."""
    # When installed as package, assets are in claude_priors/assets/
    pkg_dir = Path(__file__).parent
    asset_path = pkg_dir / "assets" / name
    if asset_path.exists():
        return asset_path.read_text()

    # Fallback: development layout
    repo_root = pkg_dir.parent.parent
    candidates = [
        repo_root / "skill" / name,
        repo_root / "bootstrap" / name,
    ]
    for candidate in candidates:
        if candidate.exists():
            return candidate.read_text()

    print(f"Error: Could not find asset '{name}'", file=sys.stderr)
    sys.exit(1)


def cmd_init(args):
    cwd = Path.cwd()
    shared = args.shared
    global_install = args.global_install

    print(f"\nclaude-priors v{VERSION}")
    print(f"Initializing in: {cwd}\n")

    # 1. Create .claude/priors/
    priors_dir = cwd / ".claude" / "priors"
    if not priors_dir.exists():
        priors_dir.mkdir(parents=True)
        (priors_dir / ".gitkeep").touch()
        print("  Created .claude/priors/")
    else:
        print("  .claude/priors/ already exists")

    # 2. Copy SKILL.md
    skill_content = get_asset("SKILL.md")

    if global_install:
        home = Path.home()
        skill_dir = home / ".claude" / "skills" / "knowledge-extraction"
    else:
        skill_dir = cwd / ".claude" / "skills" / "knowledge-extraction"

    skill_dir.mkdir(parents=True, exist_ok=True)
    skill_dest = skill_dir / "SKILL.md"

    if not skill_dest.exists():
        skill_dest.write_text(skill_content)
        label = "~/.claude/skills" if global_install else ".claude/skills"
        print(f"  Created {label}/knowledge-extraction/SKILL.md")
    else:
        existing = skill_dest.read_text()
        if existing == skill_content:
            print("  SKILL.md already up to date")
        else:
            skill_dest.write_text(skill_content)
            print(f"  Updated SKILL.md to v{VERSION}")

    # 3. Append bootstrap to CLAUDE.md or AGENTS.md
    bootstrap_content = get_asset("CLAUDE.md.snippet").strip()

    instruction_file = None
    for candidate in ["CLAUDE.md", "AGENTS.md"]:
        if (cwd / candidate).exists():
            instruction_file = candidate
            break

    if not instruction_file:
        instruction_file = "CLAUDE.md"

    instruction_path = cwd / instruction_file

    if instruction_path.exists():
        existing = instruction_path.read_text()
        if PRIORS_MARKER in existing:
            print(f"  {instruction_file} already has priors bootstrap")
        else:
            instruction_path.write_text(
                existing.rstrip() + "\n\n" + bootstrap_content + "\n"
            )
            print(f"  Appended priors bootstrap to {instruction_file}")
    else:
        instruction_path.write_text(bootstrap_content + "\n")
        print(f"  Created {instruction_file} with priors bootstrap")

    # 4. Handle .gitignore
    gitignore_path = cwd / ".gitignore"
    priors_glob = ".claude/priors/"

    if not shared:
        if gitignore_path.exists():
            gitignore = gitignore_path.read_text()
            if priors_glob not in gitignore:
                gitignore_path.write_text(
                    gitignore.rstrip()
                    + "\n\n# Agent priors (local knowledge)\n"
                    + priors_glob
                    + "\n"
                )
                print("  Added .claude/priors/ to .gitignore")
            else:
                print("  .gitignore already excludes priors")
        else:
            gitignore_path.write_text(
                "# Agent priors (local knowledge)\n" + priors_glob + "\n"
            )
            print("  Created .gitignore with priors exclusion")
    else:
        print("  --shared: priors will be git-tracked")

    print("\nDone! Your agent will now learn from every conversation.\n")


def cmd_status(args):
    cwd = Path.cwd()
    priors_dir = cwd / ".claude" / "priors"

    if not priors_dir.exists():
        print("No priors directory found. Run `claude-priors init` first.")
        return

    files = sorted(priors_dir.glob("*.md"))

    if not files:
        print(
            "Priors directory exists but is empty. "
            "The agent will start writing priors as it learns.\n"
        )
        return

    print(f"\nPriors: {priors_dir}\n")

    total_entries = 0

    for f in files:
        content = f.read_text()

        # Parse frontmatter
        topic = f.stem
        summary = ""
        entries = 0
        last_updated = ""

        fm_match = re.match(r"^---\n(.*?)\n---", content, re.DOTALL)
        if fm_match:
            fm = fm_match.group(1)
            for line in fm.split("\n"):
                if line.startswith("topic:"):
                    topic = line.split(":", 1)[1].strip()
                elif line.startswith("summary:"):
                    summary = line.split(":", 1)[1].strip()
                elif line.startswith("entries:"):
                    try:
                        entries = int(line.split(":", 1)[1].strip())
                    except ValueError:
                        pass
                elif line.startswith("last_updated:"):
                    last_updated = line.split(":", 1)[1].strip()

        total_entries += entries
        print(f"  {f.name}")
        print(
            f"    Topic: {topic} | Entries: {entries} | Updated: {last_updated or 'unknown'}"
        )
        if summary:
            print(f"    {summary}")
        print()

    print(f"Total: {len(files)} files, {total_entries} entries\n")


def main():
    parser = argparse.ArgumentParser(
        prog="claude-priors",
        description="Persistent agent memory for AI coding assistants",
    )
    parser.add_argument(
        "--version", action="version", version=f"claude-priors {VERSION}"
    )

    subparsers = parser.add_subparsers(dest="command")

    init_parser = subparsers.add_parser("init", help="Bootstrap priors in current directory")
    init_parser.add_argument(
        "--shared", action="store_true", help="Git-track priors (default: git-ignored)"
    )
    init_parser.add_argument(
        "--global",
        dest="global_install",
        action="store_true",
        help="Install skill to ~/.claude/skills/ instead of repo",
    )

    subparsers.add_parser("status", help="Show priors stats")

    args = parser.parse_args()

    if args.command == "init":
        cmd_init(args)
    elif args.command == "status":
        cmd_status(args)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
