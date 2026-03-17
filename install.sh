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
  echo "After installing, open Claude Code in your project and run /setup to configure it."
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

# .claude directory
mkdir -p "$TARGET/.claude/agents"
mkdir -p "$TARGET/.claude/hooks"
mkdir -p "$TARGET/.claude/skills/tasks"
mkdir -p "$TARGET/.claude/skills/loop-tasks"
mkdir -p "$TARGET/.claude/skills/browser-test"
mkdir -p "$TARGET/.claude/skills/design-review"
mkdir -p "$TARGET/.claude/skills/prd"
mkdir -p "$TARGET/.claude/skills/frontend-design"
mkdir -p "$TARGET/.claude/skills/playwright-cli"
mkdir -p "$TARGET/.claude/skills/setup"

cp "$TEMPLATE_DIR/.claude/agents/task-worker.md" "$TARGET/.claude/agents/"
cp "$TEMPLATE_DIR/.claude/hooks/notify-macos.sh" "$TARGET/.claude/hooks/"
chmod +x "$TARGET/.claude/hooks/notify-macos.sh"
cp "$TEMPLATE_DIR/.claude/skills/tasks/SKILL.md" "$TARGET/.claude/skills/tasks/"
cp "$TEMPLATE_DIR/.claude/skills/loop-tasks/SKILL.md" "$TARGET/.claude/skills/loop-tasks/"
cp "$TEMPLATE_DIR/.claude/skills/browser-test/SKILL.md" "$TARGET/.claude/skills/browser-test/"
cp "$TEMPLATE_DIR/.claude/skills/design-review/SKILL.md" "$TARGET/.claude/skills/design-review/"
cp "$TEMPLATE_DIR/.claude/skills/prd/SKILL.md" "$TARGET/.claude/skills/prd/"
cp "$TEMPLATE_DIR/.claude/skills/frontend-design/SKILL.md" "$TARGET/.claude/skills/frontend-design/"
cp "$TEMPLATE_DIR/.claude/skills/playwright-cli/SKILL.md" "$TARGET/.claude/skills/playwright-cli/"
cp "$TEMPLATE_DIR/.claude/skills/setup/SKILL.md" "$TARGET/.claude/skills/setup/"

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

echo ""
echo "Done! Installed:"
echo "  .claude/agents/task-worker.md"
echo "  .claude/hooks/notify-macos.sh"
echo "  .claude/skills/{tasks,loop-tasks,browser-test,design-review,prd,frontend-design,playwright-cli,setup}/"
echo "  tasks/board.html"
echo "  screenshots/{reference,tasks}/"
echo ""
echo "Next steps:"
echo "  1. cd $TARGET"
echo "  2. Open Claude Code"
echo "  3. Run /setup to configure for your project"
echo "  4. Run /prd to create a PRD"
echo "  5. Run /tasks add to add tasks"
echo "  6. Run /loop-tasks to start the autonomous loop"
