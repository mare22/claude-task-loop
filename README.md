# Claude Task Loop

An autonomous task execution system for [Claude Code](https://claude.ai/claude-code). Define tasks with custom agent chains, and Claude agents will implement and verify them one by one.

## What It Does

```
/prd          → Generate a Product Requirements Document
/tasks add    → Add tasks with acceptance criteria and agent chains
/loop-tasks   → Autonomous loop: for each task, run the agent chain
```

Each task defines an **agent chain** — a sequence of specialized agents that process the task:

```
task-worker → code-review → browser-test → design-review → done!
     ↑                                          |
     └──── rejection notes ─────────────────────┘
```

The first agent (`task-worker`) implements the code. The remaining agents verify the work. A task is "done" only when **every agent in the chain approves**. If any agent rejects, task-worker reads the rejection notes and fixes the issues, then the full chain runs again.

---

## Agents

### task-worker (required, always first)

Implements the task: reads acceptance criteria, writes code, runs quality gates (lint, typecheck, test), commits. For re-work, reads QA rejection notes and fixes specific issues.

### code-review

Senior code reviewer. Checks the diff for correctness, security vulnerabilities, data integrity, performance issues, and maintainability. Verifies acceptance criteria are actually met by the code. Read-only — reports APPROVED/REJECTED with file paths and line numbers.

### browser-test

Functional QA via Playwright. Opens the app in a browser, navigates to the relevant screen, and tests each acceptance criterion interactively — clicking buttons, filling forms, checking visibility. Screenshots evidence. Read-only — reports APPROVED/REJECTED.

### design-review

Visual design QA. Screenshots the UI and audits for hard blockers (clipped content, broken layout, missing elements, unreadable text). **Has write access** — fixes Critical and Major issues directly in code, re-screenshots, and loops up to 5 iterations. Reports APPROVED/REJECTED.

### accessibility-audit

WCAG 2.2 AA compliance audit. Uses Playwright's accessibility snapshot to check keyboard navigation, screen reader compatibility, color contrast (4.5:1 minimum), touch targets (44x44px minimum), semantic HTML, ARIA roles, and form accessibility. Read-only — reports APPROVED/REJECTED.

### security-review

Security engineer. Audits changed code for OWASP Top 10 vulnerabilities: injection (SQL, XSS, command), broken auth, secrets exposure, missing input validation, insecure crypto, path traversal, and data leaks. Follows data flow from user input to dangerous sinks. Read-only — reports APPROVED/REJECTED.

### performance-check

Performance engineer. Reviews code for unbounded queries, N+1 patterns, memory leaks, blocking operations, unnecessary re-renders, bundle bloat, and missing pagination. Optionally does a runtime check via Playwright if a dev server is available. Read-only — reports APPROVED/REJECTED.

### test-coverage

Test quality engineer. Runs the test suite, checks that new code has tests, verifies tests assert meaningful behavior (not no-ops), checks edge cases and error paths. Rejects if tests fail, new logic has no tests, or tests don't actually test anything. Read-only — reports APPROVED/REJECTED.

### ios-tester

iOS functional QA via Maestro. Launches the app on an iOS simulator, interacts with the UI (tap, scroll, type, swipe), and verifies each acceptance criterion. Checks for crashes, frozen UI, broken navigation, safe area violations, and data loss. Outputs BLOCKED if Maestro or simulator is not available. Read-only — reports APPROVED/REJECTED/BLOCKED.

### android-tester

Android functional QA via Maestro. Launches the app on an Android emulator, interacts with the UI, and verifies each acceptance criterion. Checks for crashes, ANR, broken navigation, keyboard issues, edge-to-edge violations, and data loss. Tests Android back button at every screen. Outputs BLOCKED if Maestro or emulator is not available. Read-only — reports APPROVED/REJECTED/BLOCKED.

### mobile-design-review

Mobile visual design QA. Takes native screenshots (`xcrun simctl io` for iOS, `adb screencap` for Android) and audits for safe area violations, clipped content, broken layout, platform convention violations, and visual inconsistencies. **Has write access** — fixes Critical and Major issues directly in code, re-screenshots, and loops up to 5 iterations. Checks iOS-specific patterns (SF Symbols, Dynamic Type, navigation style) and Android-specific patterns (Material Design 3, edge-to-edge, elevation). Reports APPROVED/REJECTED/BLOCKED.

---

## Agent Chain Examples

The `agents` array in each task defines which agents process it, in order. Mix and match based on what the task needs:

```jsonc
// Simple backend task — just code review
"agents": ["task-worker", "code-review"]

// Backend with security concerns (auth, payments, API)
"agents": ["task-worker", "code-review", "security-review", "test-coverage"]

// Web UI feature — full visual QA pipeline
"agents": ["task-worker", "code-review", "browser-test", "design-review"]

// Web UI with accessibility requirements
"agents": ["task-worker", "code-review", "browser-test", "accessibility-audit", "design-review"]

// Performance-critical feature
"agents": ["task-worker", "code-review", "performance-check", "test-coverage"]

// Full web pipeline — everything
"agents": ["task-worker", "code-review", "security-review", "test-coverage", "browser-test", "accessibility-audit", "performance-check", "design-review"]

// Backend-only task — no QA needed
"agents": ["task-worker"]

// Mobile app — iOS only
"agents": ["task-worker", "code-review", "ios-tester", "mobile-design-review"]

// Mobile app — Android only
"agents": ["task-worker", "code-review", "android-tester", "mobile-design-review"]

// Mobile app — both platforms
"agents": ["task-worker", "code-review", "ios-tester", "android-tester", "mobile-design-review"]

// Mobile app — full pipeline with security
"agents": ["task-worker", "code-review", "security-review", "test-coverage", "ios-tester", "android-tester", "mobile-design-review"]
```

### Recommended chains by project type

| Project Type | Recommended Chain |
|---|---|
| **Web app (UI)** | `task-worker → code-review → browser-test → design-review` |
| **Web app (accessible)** | `task-worker → code-review → browser-test → accessibility-audit → design-review` |
| **REST API** | `task-worker → code-review → security-review → test-coverage` |
| **CLI tool** | `task-worker → code-review → test-coverage` |
| **Library/SDK** | `task-worker → code-review → test-coverage → performance-check` |
| **Auth/payments** | `task-worker → code-review → security-review → test-coverage` |
| **Data pipeline** | `task-worker → code-review → performance-check → test-coverage` |
| **Mobile app (iOS)** | `task-worker → code-review → ios-tester → mobile-design-review` |
| **Mobile app (Android)** | `task-worker → code-review → android-tester → mobile-design-review` |
| **Mobile app (both)** | `task-worker → code-review → ios-tester → android-tester → mobile-design-review` |
| **Quick fix/chore** | `task-worker → code-review` |
| **Spike/prototype** | `task-worker` |

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

Describe your feature. Claude asks clarifying questions, then generates a structured PRD saved to `tasks/prd-[name].md`.

### 2. Add Tasks

```
/tasks add
```

Add tasks with title, description, tags, agent chain, and acceptance criteria. Tasks are stored in `tasks/tasks.json`.

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
  "progress": "",
  "test_plan": [],
  "screenshots": [],
  "notes": ""
}
```

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

Open `http://localhost:3000/board.html` (or `http://localhost:9090/board.html`) — a live Kanban board that auto-refreshes every 5 seconds.

The board shows 4 columns: **Todo**, **In Progress**, **Done**, **Skipped**. Each card displays the task ID, title, tags, priority, and agent chain. Click a card to see full details: description, agent chain, acceptance criteria, progress, test plan, screenshots, and notes.

> **Note:** The board requires a local HTTP server — opening `board.html` directly as a file won't work because it fetches `tasks.json` via HTTP.

### 5. Other Commands

```
/tasks list      — View all tasks grouped by status
/tasks update    — Update task fields (including agents)
/tasks remove    — Remove tasks
/tasks           — Summary stats
/frontend-design — Design guidance for UI work
```

---

## How It Works

### Task Lifecycle

```
todo → in-progress → [task-worker: implement + quality gates + commit]
                          ↓
                     [agent 2: verify] → [agent 3: verify] → ... → done
                          ↓ (if any rejects)
                     back to todo (with notes) → full chain restarts
```

### Agent Chain Execution

Each task has an `agents` array that defines its pipeline:

1. **task-worker** (always first) — implements the code, runs quality gates, commits
2. **Remaining agents** — each verifies the work and outputs APPROVED or REJECTED

The chain runs sequentially. Wait for each agent to finish before spawning the next.

### Rejection & Retry

When any agent rejects:
1. Task status goes back to `"todo"`
2. Rejection details are written to the task's `notes` field
3. The full chain restarts — task-worker reads the notes and fixes the issues
4. ALL agents re-verify (because a fix might break something else)
5. Maximum **3 full chain retries** before asking the user

### Adding Custom Agents

To add a new agent:

1. Create `.claude/agents/{agent-name}.md` with instructions
2. The agent must output **APPROVED** or **REJECTED** at the end
3. Include specific issue descriptions in REJECTED output so task-worker can fix them
4. Add the agent name to task `agents` arrays

Example: to add a `lighthouse-audit` agent for web performance scoring, create `.claude/agents/lighthouse-audit.md` and add it to your tasks: `["task-worker", "code-review", "lighthouse-audit"]`.

---

## What Gets Installed

```
your-project/
├── .claude/
│   ├── agents/
│   │   ├── task-worker.md          # Implements one task per session
│   │   ├── code-review.md          # Code correctness, security, maintainability
│   │   ├── browser-test.md         # Playwright functional QA (web)
│   │   ├── design-review.md        # Visual design QA with auto-fix (web)
│   │   ├── accessibility-audit.md  # WCAG 2.2 AA compliance (web)
│   │   ├── security-review.md      # OWASP Top 10 vulnerability scan
│   │   ├── performance-check.md    # Performance anti-patterns
│   │   ├── test-coverage.md        # Test quality verification
│   │   ├── ios-tester.md           # Maestro functional QA (iOS)
│   │   ├── android-tester.md       # Maestro functional QA (Android)
│   │   └── mobile-design-review.md # Mobile visual design QA with auto-fix
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
- macOS (for notification hook — optional, works without it on other OS)
- For web QA agents: [Playwright CLI](https://www.npmjs.com/package/@anthropic-ai/playwright-cli) (`npm install -g @anthropic-ai/playwright-cli`)
- For mobile QA agents: [Maestro](https://maestro.mobile.dev/) (`curl -Ls "https://get.maestro.mobile.dev" | bash`)
- For iOS testing: Xcode with iOS Simulator
- For Android testing: Android Studio with emulator (or physical device via `adb`)

## License

MIT
