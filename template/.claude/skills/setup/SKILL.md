---
name: setup
description: >
  Configure the Claude Task Loop for this project. Asks questions about the project
  and adapts task-worker, quality gates, viewport, and CLAUDE.md accordingly.
  Use when the user says "set up task loop", "configure tasks", or runs /setup.
user-invocable: true
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Setup — Configure Claude Task Loop

## Overview

You configure the task loop system for this specific project. Ask questions, then adapt the configuration files.

---

## Step 1 — Ask Questions

Ask the user these questions (with lettered options for quick answers):

```
1. What type of project is this?
   A. React / Next.js web app
   B. React Native / Expo mobile app
   C. Vue / Nuxt web app
   D. Node.js backend / API
   E. Python project
   F. Other: [please specify]

2. What is your dev server URL and port?
   A. http://localhost:3000
   B. http://localhost:5173 (Vite)
   C. http://localhost:8080
   D. http://localhost:8081 (Expo)
   E. No dev server (backend only)
   F. Other: [please specify]

3. What viewport should browser tests use?
   A. 390x844 (iPhone 14 Pro — mobile-first)
   B. 1280x720 (Desktop)
   C. 1920x1080 (Full HD desktop)
   D. Both mobile (390x844) and desktop (1280x720)
   E. N/A — no UI
   F. Other: [please specify]

4. What are your quality gate commands? (comma-separated)
   Example: npm run typecheck, npm run lint, npm test
   Or: cargo check, cargo clippy, cargo test
   Or: python -m mypy ., python -m pytest

5. What is the project name? (for tasks.json and notifications)

6. Do you have reference screenshots to replicate?
   A. Yes — I'll add them to screenshots/reference/
   B. No — original design
   C. N/A — no UI

7. Any brand colors or design system? (optional)
   Describe or say "none" — e.g., "Blue (#3B82F6) primary, dark background (#0F172A)"
```

---

## Step 2 — Update Configuration

Based on answers, update these files:

### 1. `CLAUDE.md` — Update the placeholder sections:
- **Tech Stack**: Fill in framework, routing, state management, etc.
- **Commands**: Fill in quality gate commands
- **Dev Server**: URL and port
- **Viewport**: Target viewport size
- **Design**: Brand colors if provided
- **Quality Gates**: The exact commands to run

### 2. `.claude/hooks/notify-macos.sh` — Update project name:
```bash
# Change "My Project" to the actual project name
```

### 3. `tasks/tasks.json` — Update project name:
```json
{ "project": "Actual Project Name", "tasks": [] }
```

### 4. `.claude/settings.json` — Already configured, no changes needed unless the user wants custom hooks.

---

## Step 3 — Create Directories

```bash
mkdir -p screenshots/reference screenshots/tasks
```

---

## Step 4 — Verify

1. Confirm all files are updated
2. Show the user a summary of what was configured
3. Suggest next steps:
   - "Add reference screenshots to `screenshots/reference/` (if UI project)"
   - "Run `/prd` to create a PRD for your first feature"
   - "Run `/tasks add` to add tasks"
   - "Run `/loop-tasks` to start the autonomous loop"

---

## Rules

- Ask ALL questions before making changes
- Don't assume — let the user choose
- Keep CLAUDE.md concise — don't add unnecessary sections
- If the user says "no UI", remove/skip browser-test and design-review references from CLAUDE.md
