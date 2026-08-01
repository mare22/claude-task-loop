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
# Quality gate commands
# npm run typecheck
# npm run lint
# npm test
```

## Quality Gates

Every commit must pass all quality gate commands listed above.

In the task loop they run twice: `task-worker` must get them green before reporting DONE, and
the orchestrator re-runs them immediately before committing (a QA cycle can regress them).

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
1. Commit or stash any work in progress — **the loop requires a clean working tree**
2. Create a PRD: `/prd`
3. Add tasks: `/tasks add`
4. Run the loop: `/loop-tasks`
5. View progress: serve `tasks/board.html`

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

1. **`/prd`** — Generate a Product Requirements Document, then turn its user stories into tasks
2. **`/tasks add`** — Add tasks with title, description, tags, pipeline, acceptance criteria, priority
3. **`/loop-tasks`** — Orchestrator runs each task through its pipeline

### The three invariants

The whole system rests on these. Nothing in the loop may break them:

1. **Only `task-worker` modifies code.** Every QA agent is read-only and reports findings instead.
2. **Only the orchestrator commits.** One commit per task, after every agent approves.
3. **Only the orchestrator writes `tasks.json`.** Agents report back; it records.

Because the orchestrator owns the commit, `HEAD` never moves while a task is in flight — so
`git diff HEAD` is exactly "this task's work" for every QA agent on every rework cycle.

### How a task runs

```
preflight (clean working tree)
   ↓
task-worker         implements, runs quality gates, `git add` — no commit
   ↓
QA WAVE             read-only verifiers, run CONCURRENTLY in lanes
   ↓
collect ALL verdicts (no fail-fast — one cycle surfaces every problem)
   ↓
any REJECTED  → consolidated findings into notes → attempts++ → back to task-worker (max 3)
all APPROVED  → orchestrator runs quality gates → single commit → status: done
```

### Lanes — why the pipeline is fast

Verifiers are grouped by the shared resource they need, declared as a `**Lock:**` line in each
`.claude/agents/*.md`:

| Lock | Scheduling |
|---|---|
| `none` | own lane — fully parallel |
| `browser` | one shared lane (playwright-cli is a single global session) |
| `ios` / `android` | one shared lane per device |
| `ios+android` | runs after both device lanes drain |

**Wall-clock cost is the deepest lane, not the agent count.** Four verifiers often cost the same
as one. `/tasks add` quotes rounds when you pick a pipeline.

### Pipeline examples

```json
// Web UI — 2 rounds
"agents": ["task-worker", "code-review", "browser-test", "design-review"]

// Web UI with accessibility — 3 rounds
"agents": ["task-worker", "code-review", "browser-test", "accessibility-audit", "design-review"]

// Backend API — 1 round (all three verifiers run at once)
"agents": ["task-worker", "code-review", "security-review", "test-coverage"]

// Performance-critical feature — 1 round
"agents": ["task-worker", "code-review", "performance-check", "test-coverage"]

// Mobile, both platforms — 2 rounds
"agents": ["task-worker", "code-review", "ios-tester", "android-tester", "mobile-design-review"]

// Quick — 1 round
"agents": ["task-worker", "code-review"]

// Fastest — no QA
"agents": ["task-worker"]
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
