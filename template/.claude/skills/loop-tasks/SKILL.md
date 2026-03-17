---
name: loop-tasks
description: >
  Run the task-worker agent repeatedly, spawning a fresh agent per task.
  For UI tasks, spawns browser-test and design-review QA agents after implementation.
  A task is "done" only when all agents approve.
  Use when the user runs /loop-tasks or says "start the loop", "run tasks", "build tasks".
user-invocable: true
allowed-tools: Read, Agent
---

# Loop Tasks — Orchestrator

## Overview

You are an **orchestrator**. You do NOT implement code yourself. You:
1. Read `tasks/tasks.json` and find the next `todo` task (lowest priority number)
2. Spawn a **task-worker** agent to implement it
3. For UI tasks: spawn **browser-test** and **design-review** QA agents
4. A task is **done** only when all agents approve
5. Loop until all tasks are done or you hit a blocker

---

## When to STOP and ask the user

Only stop when:
- **All tasks done** — nothing left to build
- **Agent hit a blocker** — something broken, can't proceed
- **QA failed 3 times** on the same task — needs human input

Do NOT stop for:
- Successful task completion — report and continue
- QA failures (attempts 1-2) — auto-retry

---

## Step 1 — Load State

**CRITICAL: Re-read `tasks/tasks.json` from disk EVERY iteration.** Never use cached data.

1. Read `tasks/tasks.json`
2. Find next task: `status: "todo"`, lowest `priority` number
3. If zero `todo` tasks → **"All tasks complete!"** → STOP

---

## Step 2 — Announce

```
Starting T-XXX: [Title]...
```

Immediately proceed — do NOT wait for confirmation.

---

## Step 3 — Spawn Task-Worker Agent

Spawn a **fresh** Agent (general-purpose) with this prompt:

```
You are a task worker. Follow the instructions in .claude/agents/task-worker.md exactly.

Read tasks/tasks.json, pick the highest priority "todo" task, implement it, run quality checks, commit if all pass, update tasks.json with status based on results.

For UI tasks (tags include "ui"), use playwright-cli for browser testing.
For UI work, use the /frontend-design skill for design guidance.

Read CLAUDE.md for project conventions before starting.

Output NEXT when done if more tasks remain, or COMPLETE if all tasks are done.
```

Wait for the agent to finish.

---

## Step 4 — QA Verification (UI tasks only)

**Skip this step if the task does NOT have `"ui"` in its tags.**

After task-worker finishes successfully, spawn **two QA agents sequentially**:

### QA Agent 1 — Browser Test (Functional)

Spawn a fresh Agent:

```
You are a QA engineer verifying a recently implemented task.
You do NOT fix code. You only TEST and REPORT.

## Task
- ID: [T-XXX]
- Title: [title]
- Acceptance Criteria:
  [list all criteria]

## Instructions
1. Read `.claude/skills/browser-test/SKILL.md` for the browser testing process
2. Read `CLAUDE.md` for project context (dev server URL, viewport size)
3. Open the app using playwright-cli at the configured dev server URL
4. Resize to the project's target viewport
5. Navigate to the relevant screen
6. Test EACH acceptance criterion
7. Take screenshots: `playwright-cli screenshot --filename=/tmp/qa/[ID]-functional.png`
8. `playwright-cli close`

## HARD BLOCKERS (auto-fail)
- Content cut off or clipped
- Labels/text not fully visible
- Elements shifted outside viewport
- Scroll not working
- Interactive elements unreachable
- Empty areas where content should be

## Report Format
RESULT: PASS or FAIL

ISSUES (if FAIL):
1. [Critical/Major/Minor] [Description]

VERIFIED:
- [x] [criterion that passed]
- [ ] [criterion that failed]
```

### QA Agent 2 — Design Review (Visual)

Spawn a fresh Agent:

```
You are a senior UI/UX designer reviewing a recently implemented task.
You do NOT fix code. You only REVIEW and REPORT.

## Task
- ID: [T-XXX]
- Title: [title]

## Instructions
1. Read `.claude/skills/design-review/SKILL.md` for the design QA checklist
2. Read `CLAUDE.md` for brand guidelines and viewport
3. Check reference screenshots in `screenshots/reference/` if they exist
4. Open the app using playwright-cli at the configured dev server URL
5. Resize to the project's target viewport
6. Navigate to the relevant screen
7. Take screenshot: `playwright-cli screenshot --filename=/tmp/qa/[ID]-design.png`
8. Audit: hard blockers, visual design, mobile conventions, accessibility
9. `playwright-cli close`

## Report Format
RESULT: PASS or FAIL

HARD_BLOCKERS (if any):
1. [Description]

DESIGN_ISSUES (if any):
1. [Major/Minor] [Description]

NOTES:
[Observations for the next agent]
```

---

## Step 5 — Process Results

### Definition of Done

A task is **done** when:
- **Non-UI task**: task-worker passes quality gates and commits
- **UI task**: task-worker passes quality gates AND browser-test PASS AND design-review PASS

### If all agents approve (or non-UI task passes):
1. Verify `status: "done"` in tasks.json (task-worker should have set this)
2. Report success, auto-continue to Step 1

### If any QA agent reports FAIL:
1. Read tasks.json, set `status: "todo"` for this task
2. Update the task's `notes` field with QA findings:
   ```
   "notes": "QA FAILED (attempt N) — [summary]. Issues: 1) [issue] 2) [issue]"
   ```
3. Write tasks.json
4. Report QA failure briefly
5. **Auto-continue** — loop picks this task up again since status is "todo"
6. The next task-worker gets the QA findings in the notes field

### Re-work limit:
Track QA failure count per task (count in notes). If a task fails QA **3 times**, STOP and ask the user.

---

## Step 6 — Report & Continue

### Success:
```
T-XXX [Title] — Done
  [one-line summary]
  QA: Functional PASS, Design PASS
  Files: [key files]

Starting T-YYY: [Next Title]...
```

### QA Failed (retry):
```
T-XXX [Title] — QA Failed (attempt N/3)
  Issues: [brief list]
  Re-dispatching...

Starting T-XXX: [Title] (fixing QA issues)...
```

### Blocked:
```
T-XXX [Title] — Blocked

Problem: [what went wrong]

Options:
1. Retry with a fresh agent
2. Skip this task and continue
3. I'll give you guidance

What do you want to do?
```

### QA Failed 3 times:
```
T-XXX [Title] — Failed QA 3 times

Persistent issues:
[list]

Options:
1. I'll look at it and give guidance
2. Skip this task for now
3. Retry one more time

What do you want to do?
```

---

## Rules

- **RE-READ tasks.json FROM DISK every iteration** — never use cached data
- **NEVER implement code yourself** — always use a fresh agent
- **RUN QA after every UI task** — any task with `"ui"` tag
- **QA agents are READ-ONLY** — they do NOT fix code, only test and report
- **Only task-worker changes code** — QA findings go back via notes field
- **AUTO-CONTINUE after success AND QA failure** — retry up to 3 times
- **STOP only when blocked, all done, or 3 QA failures**
- **Fresh agents every time** — never resume, always spawn new
- **Sequential execution** — one task at a time
