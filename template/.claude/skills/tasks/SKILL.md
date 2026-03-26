---
name: tasks
description: >
  Manage the task database in tasks/tasks.json.
  Use when the user runs /tasks, says "add a task", "update task", "remove task",
  or wants to see/manage the task list.
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Bash
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
      "agents": ["task-worker", "browser-test", "design-review"],
      "acceptanceCriteria": ["Criterion 1", "Quality gates pass"],
      "progress": "",
      "test_plan": [],
      "screenshots": [],
      "notes": ""
    }
  ]
}
```

### Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Auto-generated: T-001, T-002, etc. Never reused. |
| `title` | string | Short task title |
| `description` | string | Full description or user story |
| `tags` | string[] | One or more of: `bug`, `feature`, `ui`, `task`. |
| `status` | string | `todo`, `in-progress`, `done` |
| `priority` | number | Lower = higher priority. Mutable. |
| `agents` | string[] | Agent chain for this task. First must always be `task-worker`. Remaining agents run sequentially as QA/verification. Examples: `["task-worker"]`, `["task-worker", "browser-test", "design-review"]`, `["task-worker", "ios-tester", "android-tester"]`. Each agent name maps to `.claude/agents/{name}.md`. |
| `acceptanceCriteria` | string[] | Checklist the task-worker must satisfy |
| `screenshots` | string[] | Paths to screenshots in `screenshots/tasks/`. Naming: `T-XXX-description.png` |
| `progress` | string | Filled by task-worker after completion |
| `test_plan` | string[] | Filled by task-worker after completion. Each step is one array element. |
| `notes` | string | Extra context, QA findings on rework |

### Tags

- `bug` — bug fix
- `feature` — new feature
- `ui` — has UI changes
- `task` — chore, refactor, config

Combine tags: `["feature", "ui"]`, `["bug", "ui"]`, etc.

### Agents

The `agents` array defines which agents process this task, in order:

1. **`task-worker`** (required, always first) — implements the code, runs quality gates, commits
2. **QA/verification agents** (optional) — run after task-worker, verify the work

Available agents (maps to `.claude/agents/{name}.md`):
- `code-review` — Code correctness, security, maintainability review
- `browser-test` — Playwright-based functional testing (web)
- `design-review` — Visual design audit with auto-fixing (web)
- `accessibility-audit` — WCAG 2.2 AA compliance audit (web)
- `security-review` — OWASP Top 10 vulnerability scan
- `performance-check` — Performance anti-patterns detection
- `test-coverage` — Test quality and coverage verification
- More can be added (e.g., `ios-tester`, `android-tester`, `mobile-design-review`)

If `agents` is omitted or set to `["task-worker"]`, no QA agents run.

---

## Commands

### `/tasks add`

1. Read `tasks/tasks.json`
2. Auto-generate next ID (find highest existing T-XXX number, increment by 1)
3. Ask the user for:
   - **title** (required)
   - **description** (required)
   - **tags** (required) — suggest based on description
   - **agents** (required) — suggest based on tags and task type. Default: `["task-worker", "code-review"]`. For UI web tasks suggest: `["task-worker", "code-review", "browser-test", "design-review"]`. For API/auth tasks suggest: `["task-worker", "code-review", "security-review", "test-coverage"]`
   - **acceptanceCriteria** (required) — always append the project's quality gate criteria (from CLAUDE.md) as final criteria
   - **priority** (optional, default: next available)
   - **notes** (optional)
   - **screenshots** — if the user provided screenshots in the conversation, copy them to `screenshots/tasks/T-XXX-description.png` using Bash (`cp`), then add the relative paths to the `screenshots` array
4. Set `status: "todo"`, `progress: ""`, `test_plan: []`
5. Write updated JSON back
6. Supports batch: user can add multiple tasks at once

### `/tasks update`

1. Read `tasks/tasks.json`
2. User specifies task by ID (e.g., T-003)
3. Update only the specified fields
4. Common updates: status, progress, priority, tags, agents, acceptanceCriteria
5. Write updated JSON back

### `/tasks remove`

1. Read `tasks/tasks.json`
2. User specifies task(s) to remove by ID
3. Remove from array (IDs are never re-numbered)
4. Write updated JSON back

### `/tasks list`

1. Read `tasks/tasks.json`
2. Display tasks grouped by status: todo → in-progress → done
3. Show: ID, title, tags, priority, agents, status

### `/tasks` (no subcommand)

Show a brief summary: total tasks, todo count, in-progress count, done count. Then ask what the user wants to do.

---

## Rules

- **Never lose data** — always read before writing
- **IDs are permanent** — once assigned, never re-numbered
- **Always include quality gates** — read CLAUDE.md for project-specific quality gate commands and append them to acceptanceCriteria if not already present
- **Support batch operations** — user can add/update/remove multiple tasks at once
- **Validate tags** — must be from: `bug`, `feature`, `ui`, `task`
- **Validate agents** — first element must always be `task-worker`
