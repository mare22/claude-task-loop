---
name: tasks
description: >
  Manage the task database in tasks/tasks.json.
  Use when the user runs /tasks, says "add a task", "update task", "remove task",
  or wants to see/manage the task list.
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Bash, AskUserQuestion
---

# Tasks — Task Manager

## Task Schema

```json
{
  "project": "Project Name",
  "tasks": [
    {
      "id": "T-001",
      "title": "Task title",
      "description": "User story or description",
      "tags": ["feature", "ui"],
      "status": "todo",
      "priority": 1,
      "agents": ["task-worker", "code-review", "browser-test", "design-review"],
      "acceptanceCriteria": ["Criterion 1", "Quality gates pass"],
      "attempts": 0,
      "base_sha": "",
      "commit_sha": "",
      "log": [],
      "test_plan": [],
      "screenshots": [],
      "notes": ""
    }
  ]
}
```

### Fields

| Field | Type | Written by | Description |
|-------|------|-----------|-------------|
| `id` | string | /tasks | Auto-generated: T-001, T-002, … Never reused. |
| `title` | string | /tasks | Short task title |
| `description` | string | /tasks | Full description or user story |
| `tags` | string[] | /tasks | One or more of: `bug`, `feature`, `ui`, `task` |
| `status` | string | orchestrator | `todo`, `in-progress`, `done`, `blocked`, `skipped` |
| `priority` | number | /tasks | Lower = higher priority. Mutable. |
| `agents` | string[] | /tasks | The pipeline. First element must always be `task-worker`. |
| `acceptanceCriteria` | string[] | /tasks | Checklist task-worker must satisfy |
| `attempts` | number | orchestrator | Failed QA cycles for this task. Loop stops at 3. **Lives on disk so the count survives a restart.** |
| `base_sha` | string | orchestrator | Commit the task started from. QA agents review `git diff HEAD` against it. |
| `commit_sha` | string | orchestrator | The single commit produced when the task passed |
| `log` | string[] | orchestrator | Timestamped activity entries, one per element |
| `test_plan` | string[] | orchestrator | Manual verification steps, one per element |
| `screenshots` | string[] | /tasks | Paths in `screenshots/tasks/`. Naming: `T-XXX-description.png` |
| `notes` | string | /tasks, orchestrator | Extra context, plus consolidated QA findings on rework |

> **Single-writer rule.** During a loop run, **only the orchestrator writes `tasks.json`**.
> task-worker and every QA agent report back to it instead. This is what makes the parallel QA
> wave safe — concurrent agents appending to the same file would lose each other's writes.

### Tags

- `bug` — bug fix
- `feature` — new feature
- `ui` — has UI changes
- `task` — chore, refactor, config

Combine tags: `["feature", "ui"]`, `["bug", "ui"]`, etc.

---

## Choosing the pipeline

The `agents` array is the most consequential field on a task — it decides how thoroughly the
work is verified and how long it takes. **Always ask the user. Never pick silently.**

### How the pipeline actually runs

`task-worker` implements first, alone. Every agent after it is a **read-only** verifier, and the
orchestrator runs them **concurrently** — grouped into lanes by which shared resource they need:

- Agents with `**Lock:** none` each get their own lane — fully parallel
- All `browser` agents share one lane (playwright-cli is a single global session)
- `ios` and `android` are separate lanes; `ios+android` agents run after both drain

So wall-clock cost is **the deepest lane, not the number of agents**. Four verifiers can cost the
same as one. Quote rounds, not agent counts, when the user is choosing.

### Preset catalog

| Preset | `agents` | Rounds |
|---|---|---|
| **Full QA** | `task-worker, code-review, security-review, test-coverage, browser-test, accessibility-audit, design-review` | 3 |
| **Web UI** | `task-worker, code-review, browser-test, design-review` | 2 |
| **Web UI + a11y** | `task-worker, code-review, browser-test, accessibility-audit, design-review` | 3 |
| **Backend / API** | `task-worker, code-review, security-review, test-coverage` | 1 |
| **Performance** | `task-worker, code-review, performance-check, test-coverage` | 1 |
| **Mobile (both)** | `task-worker, code-review, ios-tester, android-tester, mobile-design-review` | 2 |
| **Mobile (iOS)** | `task-worker, code-review, ios-tester, mobile-design-review` | 2 |
| **Mobile (Android)** | `task-worker, code-review, android-tester, mobile-design-review` | 2 |
| **Quick** | `task-worker, code-review` | 1 |
| **Fastest** | `task-worker` | 0 |

### How to ask

Use **AskUserQuestion** with header `Pipeline`. Offer **4 options**, chosen from the catalog by
the task's tags and description, ordered thorough → fast, with your recommendation first and
marked `(Recommended)`. "Other" is added automatically for a custom chain.

Put the round count and what it buys in each option's description:

- tags include `ui` + web project → **Web UI (Recommended)**, Web UI + a11y, Full QA, Quick
- tags include `ui` + mobile project → **Mobile (both) (Recommended)**, Mobile (iOS), Mobile (Android), Quick
- API / auth / payments / data in the description → **Backend / API (Recommended)**, Full QA, Quick, Fastest
- tag `task` (chore, config, refactor) → **Quick (Recommended)**, Backend / API, Fastest, Web UI
- tag `bug`, no UI → **Quick (Recommended)**, Backend / API, Full QA, Fastest

Example option text:

> **Web UI (Recommended)** — code-review + browser-test → design-review. 2 rounds. Catches logic
> bugs, broken interactions, and visual defects.
>
> **Quick** — code-review only. 1 round. Fastest useful check; no browser verification.

When adding several tasks at once, ask **once** for a default, apply the per-task suggestion from
the rules above where a task clearly differs, then show the resulting table and let the user
adjust before writing.

### Available agents

Each name maps to `.claude/agents/{name}.md`.

| Agent | Lock | What it does |
|---|---|---|
| `task-worker` | none | **Required, always first.** The only agent that modifies code. |
| `code-review` | none | Correctness, data integrity, maintainability |
| `security-review` | none | OWASP Top 10 vulnerability scan |
| `test-coverage` | none | Runs the suite; checks new code has meaningful tests |
| `performance-check` | browser | N+1 queries, unbounded ops, memory leaks, render cost |
| `browser-test` | browser | Playwright functional testing (web) |
| `accessibility-audit` | browser | WCAG 2.2 AA compliance (web) |
| `design-review` | browser | Visual design audit (web) |
| `ios-tester` | ios | Maestro functional testing (iOS simulator) |
| `android-tester` | android | Maestro functional testing (Android emulator) |
| `mobile-design-review` | ios+android | Mobile visual design audit |

To add your own: create `.claude/agents/{name}.md`, declare a `**Lock:**` line, and have it
output `APPROVED` / `REJECTED` / `BLOCKED`. It must be read-only — only `task-worker` writes code.

---

## Commands

### `/tasks add`

1. Read `tasks/tasks.json`
2. Auto-generate the next ID (highest existing `T-XXX` + 1)
3. Ask the user for:
   - **title** (required)
   - **description** (required)
   - **tags** (required) — suggest based on the description
   - **agents** (required) — **always ask, using the AskUserQuestion flow above**
   - **acceptanceCriteria** (required) — always append the project's quality gate criteria from `CLAUDE.md`
   - **priority** (optional, default: next available)
   - **notes** (optional)
   - **screenshots** — if the user supplied screenshots in the conversation, copy them to
     `screenshots/tasks/T-XXX-description.png` with `cp`, then add the relative paths
4. Set `status: "todo"`, `attempts: 0`, `base_sha: ""`, `commit_sha: ""`, `log: []`, `test_plan: []`
5. Write the updated JSON back
6. Supports batch — the user can add multiple tasks at once

### `/tasks update`

1. Read `tasks/tasks.json`
2. The user specifies a task by ID (e.g. T-003)
3. Update only the specified fields
4. Common updates: status, priority, tags, agents, acceptanceCriteria
5. Write the updated JSON back

Resetting a stuck task: set `status: "todo"` and `attempts: 0`, and clear `notes`.

### `/tasks remove`

1. Read `tasks/tasks.json`
2. The user specifies task(s) by ID
3. Remove from the array (IDs are never re-numbered)
4. Write the updated JSON back

### `/tasks list`

1. Read `tasks/tasks.json`
2. Display grouped by status: todo → in-progress → blocked → done → skipped
3. Show: ID, title, tags, priority, pipeline, attempts, status

### `/tasks` (no subcommand)

Show a brief summary: total, todo, in-progress, blocked, done, skipped. Flag any task with
`attempts >= 3`. Then ask what the user wants to do.

---

## Rules

- **Never lose data** — always read before writing
- **IDs are permanent** — once assigned, never re-numbered
- **Always ask which pipeline** — never assign the `agents` array silently
- **Always include quality gates** — read `CLAUDE.md` and append its gate commands to `acceptanceCriteria`
- **Support batch operations** — add/update/remove multiple tasks at once
- **Validate tags** — must be from: `bug`, `feature`, `ui`, `task`
- **Validate agents** — first element must be `task-worker`; every other name must exist as
  `.claude/agents/{name}.md`
- **Don't hand-edit `tasks.json` while a loop is running** — the orchestrator is the single writer
