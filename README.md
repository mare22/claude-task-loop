# Claude Task Loop

An autonomous task execution system for [Claude Code](https://claude.ai/claude-code). Define tasks with a verification pipeline, and Claude agents will implement and verify them one by one.

## What It Does

```
/prd          → Generate a PRD, then turn its user stories into tasks
/tasks add    → Add tasks with acceptance criteria and a verification pipeline
/loop-tasks   → Autonomous loop: implement, verify in parallel, commit
```

```
task-worker ──> ┌─ code-review ──────┐
  implements    ├─ security-review ──┤  read-only verifiers,
  (uncommitted) ├─ test-coverage ────┤  running CONCURRENTLY
                └─ browser-test → design-review
                          ↓
                  all approved? ──> orchestrator commits
                          │
                  any rejected? ──> consolidated findings ──> back to task-worker
```

---

## The three invariants

Everything else follows from these:

1. **Only `task-worker` modifies code.** Every verifier is read-only and reports findings instead of fixing them.
2. **Only the orchestrator commits.** One commit per task, made after every agent approves.
3. **Only the orchestrator writes `tasks.json`.** Agents report back; it records.

They buy three things that matter:

- **A correct review base.** Because the orchestrator owns the commit, `HEAD` never moves while a task is in flight — so `git diff HEAD` is exactly "this task's work" for every verifier, on every rework cycle. No agent ever reviews a partial diff.
- **Safe parallelism.** Read-only verifiers can't conflict with each other, so they run at the same time. A single writer for `tasks.json` means no lost updates.
- **A clean history.** One commit per task, and nothing lands until every check has passed.

---

## Lanes — why more verification isn't much slower

Verifiers are grouped by the **shared resource** they need, not by what they check. Each agent declares a `**Lock:**` line in its `.claude/agents/*.md`:

| Lock | Scheduling |
|---|---|
| `none` | Own lane — fully parallel |
| `browser` | One shared lane — `playwright-cli` is a single global session, so two agents driving it would close each other's browser mid-test |
| `ios` / `android` | One shared lane per device |
| `ios+android` | Runs after both device lanes drain |

The orchestrator runs lanes as rounds, spawning every agent in a round concurrently.

**Wall-clock cost is the deepest lane, not the number of agents.** Three static verifiers cost the same as one. That is why the pipeline picker quotes *rounds*:

| Preset | Agents after task-worker | Rounds |
|---|---|---|
| **Full QA** | code-review, security-review, test-coverage, browser-test, accessibility-audit, design-review | 3 |
| **Web UI** | code-review, browser-test, design-review | 2 |
| **Web UI + a11y** | code-review, browser-test, accessibility-audit, design-review | 3 |
| **Backend / API** | code-review, security-review, test-coverage | 1 |
| **Performance** | code-review, performance-check, test-coverage | 1 |
| **Mobile (both)** | code-review, ios-tester, android-tester, mobile-design-review | 2 |
| **Quick** | code-review | 1 |
| **Fastest** | — | 0 |

`/tasks add` and `/prd` **always ask** which pipeline to use, offering presets tailored to the task's tags.

### Collect-all, never fail-fast

The loop does not stop the wave at the first rejection. Every verifier finishes and all findings are consolidated into one list for `task-worker`. Three problems get fixed in one cycle instead of three.

---

## Agents

### task-worker (required, always first)

The **only** agent that modifies code. Reads acceptance criteria, writes code, runs the project's quality gates, and stages its work with `git add`. Never commits. On rework it reads the consolidated findings from every verifier that rejected and fixes them all in one pass, building on the uncommitted work already in the tree.

### code-review — `Lock: none`

Senior code reviewer. Checks the working-tree diff for correctness, data integrity, and maintainability, and verifies the acceptance criteria are actually met by the code. Reports blockers with file paths and line numbers.

### security-review — `Lock: none`

Security engineer. Audits the diff for OWASP Top 10 vulnerabilities: injection (SQL, XSS, command), broken auth, secrets exposure, missing input validation, insecure crypto, path traversal, and data leaks. Follows data flow from user input to dangerous sinks.

### test-coverage — `Lock: none`

Test quality engineer. Runs the test suite, checks that new code has tests, verifies tests assert meaningful behavior (not no-ops), and checks edge cases and error paths.

> If your test suite binds the dev-server port or shares its database, change this agent's lock to `browser` so it serializes against `browser-test` instead of racing it.

### performance-check — `Lock: browser`

Performance engineer. Reviews the diff for unbounded queries, N+1 patterns, memory leaks, blocking operations, unnecessary re-renders, bundle bloat, and missing pagination. Optionally does a runtime check via Playwright — which is why it takes the browser lock.

### browser-test — `Lock: browser`

Functional QA via Playwright. Opens the app, navigates to the relevant screen, and tests each acceptance criterion interactively — clicking buttons, filling forms, checking visibility. Screenshots evidence.

### accessibility-audit — `Lock: browser`

WCAG 2.2 AA compliance audit. Uses Playwright's accessibility snapshot to check keyboard navigation, screen reader compatibility, color contrast (4.5:1 minimum), touch targets (44x44px minimum), semantic HTML, ARIA roles, and form accessibility.

### design-review — `Lock: browser`

Visual design QA. Screenshots the UI and audits for clipped content, broken layout, missing elements, unreadable text, and off-brand styling. Traces every Critical/Major issue back to a **file:line with a suggested fix** so `task-worker` can fix it in a single cycle. Rejects on Critical/Major only — never on Minor polish.

### ios-tester — `Lock: ios`

iOS functional QA via Maestro. Launches the app on an iOS simulator, interacts with the UI (tap, scroll, type, swipe), and verifies each acceptance criterion. Checks for crashes, frozen UI, broken navigation, safe area violations, and data loss.

### android-tester — `Lock: android`

Android functional QA via Maestro. Launches the app on an Android emulator, interacts with the UI, and verifies each acceptance criterion. Checks for crashes, ANR, broken navigation, keyboard issues, edge-to-edge violations, and data loss. Tests the Android back button at every screen.

### mobile-design-review — `Lock: ios+android`

Mobile visual design QA. Takes native screenshots (`xcrun simctl io` for iOS, `adb screencap` for Android) and audits for safe area violations, clipped content, broken layout, and platform convention violations — iOS patterns (SF Symbols, Dynamic Type, navigation style) and Android patterns (Material Design 3, edge-to-edge, elevation). Needs both devices, so it runs after both device lanes finish.

---

### Recommended pipelines by project type

| Project Type | Pipeline | Rounds |
|---|---|---|
| **Web app (UI)** | code-review, browser-test, design-review | 2 |
| **Web app (accessible)** | code-review, browser-test, accessibility-audit, design-review | 3 |
| **REST API** | code-review, security-review, test-coverage | 1 |
| **CLI tool** | code-review, test-coverage | 1 |
| **Library/SDK** | code-review, test-coverage, performance-check | 1 |
| **Auth/payments** | code-review, security-review, test-coverage | 1 |
| **Data pipeline** | code-review, performance-check, test-coverage | 1 |
| **Mobile app (iOS)** | code-review, ios-tester, mobile-design-review | 2 |
| **Mobile app (both)** | code-review, ios-tester, android-tester, mobile-design-review | 2 |
| **Quick fix/chore** | code-review | 1 |
| **Spike/prototype** | — | 0 |

(`task-worker` is implied as the first entry in every pipeline.)

---

## Install

```bash
git clone https://github.com/mare22/claude-task-loop.git
cd claude-task-loop
./install.sh /path/to/your/project
```

This copies the skills, agents, and task database into your project.

## Setup

After installing, open `CLAUDE.md` in your project and fill in the marked sections:
- Tech stack (framework, language, testing)
- Quality gate commands (typecheck, lint, test)
- Dev server URL and port
- Target viewport (width x height)

---

## Usage

### 1. Create a PRD

```
/prd
```

Describe your feature. Claude asks clarifying questions, generates a structured PRD saved to `tasks/prd-[name].md`, then offers to turn its user stories into tasks — asking which pipeline to use and ordering priorities by dependency.

### 2. Add Tasks

```
/tasks add
```

Add tasks with title, description, tags, pipeline, and acceptance criteria. Stored in `tasks/tasks.json`.

Example task:

```json
{
  "id": "T-001",
  "title": "Add user login page",
  "description": "Create a login page with email/password form",
  "tags": ["feature", "ui"],
  "status": "todo",
  "priority": 1,
  "agents": ["task-worker", "code-review", "browser-test", "accessibility-audit", "design-review"],
  "acceptanceCriteria": [
    "Login form with email and password fields",
    "Form validation with error messages",
    "Submit button sends POST to /api/auth/login",
    "Redirect to /dashboard on success",
    "Show error message on invalid credentials",
    "npm run lint passes",
    "npm run typecheck passes"
  ],
  "attempts": 0,
  "base_sha": "",
  "commit_sha": "",
  "log": [],
  "test_plan": [],
  "screenshots": [],
  "notes": ""
}
```

### 3. Run the Loop

```
/loop-tasks
```

**Requires a clean working tree** — the verifiers review uncommitted changes, so pre-existing edits would be reviewed as if they were the task's work. The orchestrator checks this before starting.

For each task it:
- Picks the highest-priority `todo` task and records `base_sha`
- Runs `task-worker`, then verifies the tree actually changed
- Runs the QA wave in concurrent lanes and collects **all** verdicts
- On rejection: consolidates every finding into `notes`, increments `attempts`, retries (max 3)
- On approval: re-runs the quality gates, makes one commit, marks the task done
- Stops only when all tasks are done, an agent is blocked, or a task hits 3 failed cycles

### 4. View Progress

```bash
npx serve tasks/
# or
python3 -m http.server 9090 -d tasks
```

Open `http://localhost:3000/board.html` (or `http://localhost:9090/board.html`) — a live Kanban board that auto-refreshes every 5 seconds.

Five columns: **Todo**, **In Progress**, **Blocked**, **Done**, **Skipped**. Cards show ID, title, tags, priority, pipeline, and a failure counter once a task has been rejected. Click a card for the full detail: description, pipeline, acceptance criteria, activity log, test plan, screenshots, notes, and the resulting commit SHA.

> **Note:** The board requires a local HTTP server — opening `board.html` directly as a file won't work because it fetches `tasks.json` via HTTP.

### 5. Other Commands

```
/tasks list      — View all tasks grouped by status
/tasks update    — Update task fields (including the pipeline)
/tasks remove    — Remove tasks
/tasks           — Summary stats
/frontend-design — Design guidance for UI work
```

---

## How It Works

### Task Lifecycle

```
todo → in-progress → [task-worker: implement + quality gates + git add]
                          ↓
                     [QA wave: all verifiers, concurrent, read-only]
                          ↓
                     any rejected? → todo (consolidated notes, attempts++) → repeat
                     all approved? → [orchestrator: quality gates + commit] → done
```

### Rejection & Retry

When any verifier rejects:

1. **Every** rejection from **every** verifier is consolidated into the task's `notes`
2. Status returns to `todo` and `attempts` is incremented
3. `task-worker` reads the full findings list and fixes everything in one pass — the previous work is still in the working tree, uncommitted, so it builds on it rather than starting over
4. The full wave re-verifies (a fix can break something else)
5. After **3** failed cycles the loop stops and asks you

`attempts` lives in `tasks.json`, not in the orchestrator's context — so the count survives a session restart or compaction, and a permanently-failing task can't loop forever.

### State on Disk

Everything the loop needs to resume is in `tasks/tasks.json`:

| Field | Meaning |
|---|---|
| `attempts` | Failed QA cycles so far (stops at 3) |
| `base_sha` | Commit the task started from |
| `commit_sha` | The single commit produced when it passed |
| `log` | Structured activity timeline (see below) |
| `notes` | Consolidated QA findings on rework |

### The activity log

Each `log` entry is an object, so the board can group a run by cycle and colour it by outcome:

```json
{ "ts": "2026-08-01 14:36", "cycle": 1, "agent": "code-review", "result": "REJECTED",
  "summary": "2 blockers: N+1 query in BoardController.index(); missing null check on due_date" }
```

`result` is one of `DONE` · `APPROVED` · `REJECTED` · `BLOCKED` · `COMMITTED` · `INFO`, and
`summary` is one line under ~140 characters. The board renders these as a timeline grouped by
cycle, so a task that took three attempts reads as three labelled blocks rather than one long
list. Full detail stays in `notes` — that's what `task-worker` reads; the log is for you.

### Adding Custom Agents

1. Create `.claude/agents/{agent-name}.md`
2. Add frontmatter with `name`, `description`, and `tools: Read, Grep, Glob, Bash` (no `Write`/`Edit` — verifiers are read-only)
3. Declare a `**Lock:**` line — `none`, `browser`, `ios`, `android`, or `ios+android`
4. Output **APPROVED**, **REJECTED**, or **BLOCKED**, with specific file:line findings and a suggested fix so `task-worker` can act on them
5. Add the agent name to task `agents` arrays

The orchestrator reads the lock and schedules your agent automatically — a new `browser` agent joins the browser lane, a new `none` agent runs fully parallel.

---

## What Gets Installed

```
your-project/
├── .claude/
│   ├── agents/
│   │   ├── task-worker.md          # Implements one task — the only writer
│   │   ├── code-review.md          # Correctness, data integrity, maintainability
│   │   ├── security-review.md      # OWASP Top 10 vulnerability scan
│   │   ├── test-coverage.md        # Test quality verification
│   │   ├── performance-check.md    # Performance anti-patterns
│   │   ├── browser-test.md         # Playwright functional QA (web)
│   │   ├── accessibility-audit.md  # WCAG 2.2 AA compliance (web)
│   │   ├── design-review.md        # Visual design audit (web)
│   │   ├── ios-tester.md           # Maestro functional QA (iOS)
│   │   ├── android-tester.md       # Maestro functional QA (Android)
│   │   └── mobile-design-review.md # Mobile visual design audit
│   ├── hooks/
│   │   └── notify-macos.sh         # macOS notification when Claude needs input
│   ├── settings.json               # Hook configuration
│   └── skills/
│       ├── tasks/SKILL.md          # /tasks — manage task database
│       ├── loop-tasks/SKILL.md     # /loop-tasks — autonomous orchestrator
│       ├── prd/SKILL.md            # /prd — PRD generator
│       ├── frontend-design/SKILL.md # /frontend-design — design guidance
│       └── playwright-cli/SKILL.md  # /playwright-cli — browser automation
├── tasks/
│   ├── tasks.json                  # Task database
│   └── board.html                  # Visual task board
├── screenshots/
│   ├── reference/                  # Design reference screenshots
│   └── tasks/                      # Task-related screenshots
└── CLAUDE.md                       # Project instructions
```

## Requirements

- [Claude Code](https://claude.ai/claude-code) CLI
- A git repository with a clean working tree when the loop starts
- macOS (for the notification hook — optional, works without it on other OS)
- For web QA agents: [Playwright CLI](https://www.npmjs.com/package/@anthropic-ai/playwright-cli) (`npm install -g @anthropic-ai/playwright-cli`)
- For mobile QA agents: [Maestro](https://maestro.mobile.dev/) (`curl -Ls "https://get.maestro.mobile.dev" | bash`)
- For iOS testing: Xcode with iOS Simulator
- For Android testing: Android Studio with emulator (or physical device via `adb`)

## License

MIT
