#!/bin/bash
set -e

# Claude Task Loop — Installer
# Usage: ./install.sh /path/to/your/project

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/template"

# Check argument
if [ -z "$1" ]; then
  echo "Usage: ./install.sh /path/to/your/project"
  echo ""
  echo "This installs the Claude Task Loop system into your project."
  echo "After installing, fill in CLAUDE.md with your project details."
  exit 1
fi

TARGET="$(cd "$1" 2>/dev/null && pwd)" || {
  echo "Error: Directory '$1' does not exist."
  exit 1
}

echo "Installing Claude Task Loop into: $TARGET"
echo ""

# Check for existing files
CONFLICTS=""
if [ -d "$TARGET/.claude/skills/tasks" ]; then CONFLICTS="$CONFLICTS  .claude/skills/tasks/\n"; fi
if [ -d "$TARGET/.claude/skills/loop-tasks" ]; then CONFLICTS="$CONFLICTS  .claude/skills/loop-tasks/\n"; fi
if [ -d "$TARGET/.claude/agents" ]; then CONFLICTS="$CONFLICTS  .claude/agents/\n"; fi
if [ -f "$TARGET/tasks/tasks.json" ]; then CONFLICTS="$CONFLICTS  tasks/tasks.json\n"; fi

if [ -n "$CONFLICTS" ]; then
  echo "Warning: These paths already exist and will be overwritten:"
  echo -e "$CONFLICTS"
  read -p "Continue? (y/N) " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
  fi
fi

# Copy template files
echo "Copying files..."

# .claude directory structure
mkdir -p "$TARGET/.claude/agents"
mkdir -p "$TARGET/.claude/hooks"
mkdir -p "$TARGET/.claude/skills"

# Agents and skills — copied wholesale so adding a new one needs no edit here
cp -R "$TEMPLATE_DIR/.claude/agents/." "$TARGET/.claude/agents/"
cp -R "$TEMPLATE_DIR/.claude/skills/." "$TARGET/.claude/skills/"

# Hooks
cp "$TEMPLATE_DIR/.claude/hooks/notify-macos.sh" "$TARGET/.claude/hooks/"
chmod +x "$TARGET/.claude/hooks/notify-macos.sh"

# Only copy settings.json if it doesn't exist (don't overwrite user's existing settings)
if [ ! -f "$TARGET/.claude/settings.json" ]; then
  cp "$TEMPLATE_DIR/.claude/settings.json" "$TARGET/.claude/"
  echo "  Created .claude/settings.json"
else
  echo "  Skipped .claude/settings.json (already exists)"
fi

# tasks directory
mkdir -p "$TARGET/tasks"
if [ ! -f "$TARGET/tasks/tasks.json" ]; then
  cp "$TEMPLATE_DIR/tasks/tasks.json" "$TARGET/tasks/"
  echo "  Created tasks/tasks.json"
else
  echo "  Skipped tasks/tasks.json (already exists)"
fi
cp "$TEMPLATE_DIR/tasks/board.html" "$TARGET/tasks/"

# screenshots directories
mkdir -p "$TARGET/screenshots/reference"
mkdir -p "$TARGET/screenshots/tasks"

# CLAUDE.md — only if it doesn't exist
if [ ! -f "$TARGET/CLAUDE.md" ]; then
  cp "$TEMPLATE_DIR/CLAUDE.md" "$TARGET/"
  echo "  Created CLAUDE.md"
else
  echo "  Skipped CLAUDE.md (already exists — you may want to merge manually)"
fi

AGENT_COUNT=$(find "$TARGET/.claude/agents" -name '*.md' | wc -l | tr -d ' ')
SKILL_LIST=$(find "$TARGET/.claude/skills" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort | paste -sd, -)

echo ""
echo "Done! Installed:"
echo ""
echo "  Agents ($AGENT_COUNT):"
find "$TARGET/.claude/agents" -name '*.md' | sort | sed "s|$TARGET/|    |"
echo ""
echo "  Skills:"
echo "    .claude/skills/{$SKILL_LIST}/"
echo ""
echo "  Other:"
echo "    tasks/board.html"
echo "    screenshots/{reference,tasks}/"
echo ""
echo "Next steps:"
echo "  1. cd $TARGET"
echo "  2. Edit CLAUDE.md — fill in tech stack, quality gates, dev server, viewport"
echo "  3. Commit or stash any uncommitted work — the loop needs a clean working tree"
echo "  4. Open Claude Code"
echo "  5. Run /prd to create a PRD"
echo "  6. Run /tasks add to add tasks"
echo "  7. Run /loop-tasks to start the autonomous loop"
