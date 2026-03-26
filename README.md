# Claude Task Loop

An autonomous task execution system for [Claude Code](https://claude.ai/claude-code). Define tasks with custom agent chains, and Claude agents will implement and verify them one by one.

## What It Does

```
/prd          → Generate a Product Requirements Document
/tasks add    → Add tasks with acceptance criteria and agent chains
/loop-tasks   → Autonomous loop: for each task, run the agent chain
```

The system spawns fresh Claude agents for each task in a configurable chain:

1. **task-worker** — picks the next task, implements it, runs quality gates, commits
2. **QA/verification agents** — run after task-worker, verify the work (configurable per task)

Available QA agents:
- **browser-test** — functional verification via Playwright (web)
- **design-review** — visual QA with auto-fixing (web)
- More can be added (e.g., `ios-tester`, `android-tester`, `mobile-design-review`)

A task is "done" only when **every agent in the chain approves**. If any agent rejects, the full chain restarts — task-worker reads the rejection notes and fixes the issues. Up to 3 retries before asking the user.

## Install

```bash
git clone https://github.com/anthropics/claude-task-loop.git
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

Add tasks with title, description, tags, agent chain, and acceptance criteria. Tasks are stored in `tasks/tasks.json`.

**The `agents` array controls which agents process each task:**

```json
// Web UI task — full QA pipeline
"agents": ["task-worker", "browser-test", "design-review"]

// Backend/logic task — no QA needed
"agents": ["task-worker"]

// Mobile task (when you add mobile agents)
"agents": ["task-worker", "ios-tester", "android-tester", "mobile-design-review"]
```

**Tags describe the task type:**
- `bug` — bug fix
- `feature` — new feature
- `ui` — has UI changes
- `task` — chore, refactor, config

### 3. Run the Loop

```
/loop-tasks
```

The orchestrator processes tasks sequentially:
- Picks highest priority `todo` task
- Runs the task's agent chain: spawns each agent one by one
- task-worker implements → QA agents verify → all must approve
- If any agent rejects → full chain restarts (task-worker fixes, all agents re-verify)
- Reports results, auto-continues to next task
- Stops when all done, blocked, or chain fails 3 times

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
/frontend-design — Design guidance for UI work
```

## What Gets Installed

```
your-project/
├── .claude/
│   ├── agents/
│   │   ├── task-worker.md       # Agent: implements one task per session
│   │   ├── browser-test.md      # Agent: Playwright functional QA (web)
│   │   └── design-review.md     # Agent: visual design QA with auto-fix (web)
│   ├── hooks/
│   │   └── notify-macos.sh      # macOS notification when Claude needs input
│   ├── settings.json            # Hook configuration
│   └── skills/
│       ├── tasks/SKILL.md       # /tasks — manage task database
│       ├── loop-tasks/SKILL.md  # /loop-tasks — autonomous orchestrator
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
todo → in-progress → [quality gates] → commit → agent chain
                                                    ↓
                                          task-worker → agent2 → agent3 → ... → done
                                                    ↓ (if any agent rejects)
                                          back to todo (with notes) → retry chain
```

### Agent Chain

Each task has an `agents` array that defines its processing pipeline:

1. **task-worker** (always first) — implements the code, runs quality gates, commits
2. **QA agents** (rest of the chain) — each verifies the work and outputs APPROVED or REJECTED

The chain runs sequentially. If any agent rejects:
- Task goes back to `"todo"` with rejection details in `notes`
- Full chain restarts — task-worker reads the notes and fixes the issues
- All agents re-verify (because a fix might break something else)
- Maximum 3 full chain retries before asking the user

### Adding Custom Agents

To add a new agent to the system:

1. Create `.claude/agents/{agent-name}.md` with instructions
2. The agent must output **APPROVED** or **REJECTED** at the end
3. Add the agent name to task `agents` arrays: `["task-worker", "your-agent"]`

### Quality Gates

Every task must pass the project's quality gates before committing. These are configured during `/setup` (e.g., typecheck, lint, test).

### Re-work Loop

If any agent rejects, the task goes back to `todo` with detailed findings in the `notes` field. The next task-worker reads those notes and fixes the specific issues (doesn't rebuild from scratch). Maximum 3 retries before asking the user.

## Requirements

- [Claude Code](https://claude.ai/claude-code) CLI
- macOS (for notification hook — optional, works without it on other OS)
- For web QA agents: [Playwright CLI](https://www.npmjs.com/package/@anthropic-ai/playwright-cli) (`npm install -g @anthropic-ai/playwright-cli`)

## License

MIT
