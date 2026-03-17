# Claude Task Loop

An autonomous task execution system for [Claude Code](https://claude.ai/claude-code). Define tasks, and Claude agents will implement them one by one — with automatic QA for UI tasks.

## What It Does

```
/prd          → Generate a Product Requirements Document
/tasks add    → Add tasks with acceptance criteria
/loop-tasks   → Autonomous loop: implement → QA → commit → next task
```

The system spawns fresh Claude agents for each task:

1. **task-worker** — picks the next task, implements it, runs quality gates, commits
2. **browser-test** — (UI tasks only) functional verification via Playwright
3. **design-review** — (UI tasks only) visual QA with auto-fixing

A task is "done" only when all agents approve. If QA fails, the task goes back to todo with findings — the next worker reads those notes and fixes the issues. Up to 3 retries before asking the user.

## Install

```bash
git clone https://github.com/YOUR_USERNAME/claude-task-loop.git
cd claude-task-loop
./install.sh /path/to/your/project
```

This copies the skills, agents, and task database into your project.

## Setup

After installing, open Claude Code in your project and run:

```
/setup
```

Claude will ask you about your:
- Tech stack (React, Vue, Expo, Python, etc.)
- Dev server URL and port
- Target viewport (mobile, desktop, or both)
- Quality gate commands (typecheck, lint, test)
- Project name
- Design system / brand colors

It then configures everything in `CLAUDE.md` and the task system files.

## Usage

### 1. Create a PRD

```
/prd
```

Describe your feature. Claude asks clarifying questions, then generates a structured PRD saved to `tasks/prd-[name].md`.

### 2. Add Tasks

```
/tasks add
```

Add tasks with title, description, tags, and acceptance criteria. Tasks are stored in `tasks/tasks.json`.

**Tags control behavior:**
- `bug` — bug fix
- `feature` — new feature
- `ui` — has UI changes (triggers browser-test + design-review QA)
- `task` — chore, refactor, config

Combine tags: `["feature", "ui"]` triggers QA, `["bug"]` does not.

### 3. Run the Loop

```
/loop-tasks
```

The orchestrator processes tasks sequentially:
- Picks highest priority `todo` task
- Spawns a task-worker agent
- For UI tasks: spawns QA agents after implementation
- Reports results, auto-continues to next task
- Stops when all done, blocked, or QA fails 3 times

### 4. View Progress

Serve the task board:

```bash
npx serve tasks/
# or
python3 -m http.server 9090 -d tasks
```

Open `http://localhost:3000/board.html` — a live Kanban board that auto-refreshes every 5 seconds.

### 5. Other Commands

```
/tasks list      — View all tasks grouped by status
/tasks update    — Update task fields
/tasks remove    — Remove tasks
/tasks           — Summary stats
/design-review   — Manual visual QA audit
/browser-test    — Manual browser verification
/frontend-design — Design guidance for UI work
```

## What Gets Installed

```
your-project/
├── .claude/
│   ├── agents/
│   │   └── task-worker.md       # Agent: implements one task per session
│   ├── hooks/
│   │   └── notify-macos.sh      # macOS notification when Claude needs input
│   ├── settings.json            # Hook configuration
│   └── skills/
│       ├── tasks/SKILL.md       # /tasks — manage task database
│       ├── loop-tasks/SKILL.md  # /loop-tasks — autonomous orchestrator
│       ├── browser-test/SKILL.md# /browser-test — Playwright functional QA
│       ├── design-review/SKILL.md# /design-review — visual QA with auto-fix
│       ├── prd/SKILL.md         # /prd — PRD generator
│       ├── frontend-design/SKILL.md # /frontend-design — design guidance
│       ├── playwright-cli/SKILL.md  # /playwright-cli — browser automation
│       └── setup/SKILL.md       # /setup — project configuration wizard
├── tasks/
│   ├── tasks.json               # Task database
│   └── board.html               # Visual task board
├── screenshots/
│   ├── reference/               # Design reference screenshots
│   └── tasks/                   # Task-related screenshots
└── CLAUDE.md                    # Project instructions (configured by /setup)
```

## How It Works

### Task Lifecycle

```
todo → in-progress → [quality gates] → commit → done
                                          ↓ (UI tasks)
                                     browser-test → design-review
                                          ↓ (if QA fails)
                                     back to todo (with notes)
```

### Quality Gates

Every task must pass the project's quality gates before committing. These are configured during `/setup` (e.g., typecheck, lint, test).

### QA for UI Tasks

Any task tagged with `"ui"` gets two QA passes after implementation:

1. **Browser Test** — Opens the app in Playwright, tests each acceptance criterion, reports PASS/FAIL
2. **Design Review** — Screenshots the UI, audits for hard blockers (clipped content, broken layout, missing elements), fixes Critical/Major issues

Hard blockers that auto-fail QA:
- Content cut off or clipped
- Broken layout (overlapping, off-screen elements)
- Missing critical elements
- Unreadable content (low contrast, tiny text)
- Non-functional interactions (unreachable buttons)

### Re-work Loop

If QA fails, the task goes back to `todo` with detailed findings in the `notes` field. The next task-worker reads those notes and fixes the specific issues (doesn't rebuild from scratch). Maximum 3 retries before asking the user.

## Requirements

- [Claude Code](https://claude.ai/claude-code) CLI
- macOS (for notification hook — optional, works without it on other OS)
- For UI QA: [Playwright CLI](https://www.npmjs.com/package/@anthropic-ai/playwright-cli) (`npm install -g @anthropic-ai/playwright-cli`)

## License

MIT
