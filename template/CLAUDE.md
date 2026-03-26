# Project Name

## Project Overview

<!-- Fill in your project details -->

## Tech Stack

<!-- e.g.: -->
<!-- - **Framework**: React / Next.js / Expo / Vue / etc. -->
<!-- - **Language**: TypeScript -->
<!-- - **Testing**: Jest / Vitest / Pytest / etc. -->

## Commands

```bash
# Quality gate commands — filled by /setup
# npm run typecheck
# npm run lint
# npm test
```

## Quality Gates

Every commit must pass all quality gate commands listed above.

## Project Structure

```
app/                  # Application source code
tasks/                # Task database for autonomous agent loop
  tasks.json          # Task definitions (managed via /tasks skill)
  board.html          # Visual task board (serve with: npx serve tasks/)
screenshots/
  reference/          # Reference screenshots for design targets
  tasks/              # Task-related screenshots
.claude/skills/       # Claude Code skills
.claude/agents/       # Agent definitions
```

## Development Workflow

### For UI features:
1. Check reference screenshots in `screenshots/reference/` (if available)
2. **Use `/frontend-design` skill** for design guidance
3. Run quality gate commands

### For logic/state features:
1. Write a failing test first
2. Implement until the test passes
3. Run quality gate commands

### Autonomous mode (Task Loop):
1. Create a PRD: `/prd`
2. Add tasks: `/tasks add`
3. Run the loop: `/loop-tasks`
4. View progress: serve `tasks/board.html`

## Browser Verification

<!-- Fill in your project details -->
<!-- Dev server: http://localhost:3000 -->
<!-- Viewport: 1280x720 -->

```bash
playwright-cli open http://localhost:3000
playwright-cli resize 1280 720
playwright-cli snapshot
playwright-cli screenshot --filename=/tmp/verify.png
playwright-cli close
```

## Task System

Tasks are managed in `tasks/tasks.json`. The autonomous loop works as follows:

1. **`/prd`** — Generate a Product Requirements Document
2. **`/tasks add`** — Add tasks with title, description, tags, agents, acceptance criteria, priority
3. **`/loop-tasks`** — Orchestrator runs the agent chain for each task:
   - Reads the task's `agents` array (e.g. `["task-worker", "browser-test", "design-review"]`)
   - Spawns each agent sequentially — task-worker implements, then QA agents verify
   - Task is **done** only when ALL agents in the chain approve
   - If any agent rejects → task goes back to `"todo"` with findings in notes → full chain restarts
   - Up to 3 chain retries before asking the user

### Agent chain examples

```json
// Web UI task — full QA
"agents": ["task-worker", "browser-test", "design-review"]

// Backend/logic task — no QA
"agents": ["task-worker"]

// Mobile task (future)
"agents": ["task-worker", "ios-tester", "android-tester", "mobile-design-review"]
```

### Task tags
- `bug` — bug fix
- `feature` — new feature
- `ui` — has UI changes
- `task` — chore, refactor, config

Combine tags: `["bug", "ui"]` for a bug with UI changes.

## Task Board

View your tasks visually by serving the board:

```bash
npx serve tasks/
# or
python3 -m http.server 9090 -d tasks
```

Then open `http://localhost:3000/board.html` (or port 9090). The board auto-refreshes every 5 seconds.

## Decision Making

- **Interactive mode**: Ask the user when you need input on design decisions, ambiguous requirements, or business logic.
- **Task loop (autonomous) mode**: Agents cannot ask questions. Make best judgment from reference screenshots and task description. If genuinely stuck, output BLOCKED and the orchestrator will ask the user.

## Setup

Fill in the sections above marked with `<!-- Filled by ... -->` with your project's details: tech stack, quality gate commands, dev server URL, and viewport size.
