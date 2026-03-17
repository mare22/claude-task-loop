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
| `tags` | string[] | One or more of: `bug`, `feature`, `ui`, `task`. Tasks with `ui` tag trigger browser-test + design-review QA. |
| `status` | string | `todo`, `in-progress`, `done` |
| `priority` | number | Lower = higher priority. Mutable. |
| `acceptanceCriteria` | string[] | Checklist the task-worker must satisfy |
| `screenshots` | string[] | Paths to screenshots in `screenshots/tasks/`. Naming: `T-XXX-description.png` |
| `progress` | string | Filled by task-worker after completion |
| `test_plan` | string[] | Filled by task-worker after completion. Each step is one array element. |
| `notes` | string | Extra context, QA findings on rework |

### Tags

Use multiple tags when appropriate:
- `["bug", "ui"]` — bug fix that changes UI → triggers QA
- `["feature", "ui"]` — new feature with UI → triggers QA
- `["feature"]` — logic-only feature → no QA
- `["bug"]` — logic-only bug fix → no QA
- `["task"]` — chore, refactor, config → no QA

Any task with `"ui"` in its tags triggers browser-test + design-review after implementation.

---

## Commands

### `/tasks add`

1. Read `tasks/tasks.json`
2. Auto-generate next ID (find highest existing T-XXX number, increment by 1)
3. Ask the user for:
   - **title** (required)
   - **description** (required)
   - **tags** (required) — suggest based on description
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
4. Common updates: status, progress, priority, tags, acceptanceCriteria
5. Write updated JSON back

### `/tasks remove`

1. Read `tasks/tasks.json`
2. User specifies task(s) to remove by ID
3. Remove from array (IDs are never re-numbered)
4. Write updated JSON back

### `/tasks list`

1. Read `tasks/tasks.json`
2. Display tasks grouped by status: todo → in-progress → done
3. Show: ID, title, tags, priority, status

### `/tasks` (no subcommand)

Show a brief summary: total tasks, todo count, in-progress count, done count. Then ask what the user wants to do.

---

## Rules

- **Never lose data** — always read before writing
- **IDs are permanent** — once assigned, never re-numbered
- **Always include quality gates** — read CLAUDE.md for project-specific quality gate commands and append them to acceptanceCriteria if not already present
- **Support batch operations** — user can add/update/remove multiple tasks at once
- **Validate tags** — must be from: `bug`, `feature`, `ui`, `task`
