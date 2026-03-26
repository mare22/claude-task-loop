---
name: loop-tasks
description: >
  Run the autonomous task loop. For each task, spawns agents in chain (from the task's agents array)
  one by one. A task is "done" only when every agent in the chain approves.
  Use when the user runs /loop-tasks or says "start the loop", "run tasks", "build tasks".
user-invocable: true
allowed-tools: Read, Edit, Agent
---

# Loop Tasks — Orchestrator

## Overview

You are an **orchestrator**. You do NOT implement code yourself. You:
1. Read `tasks/tasks.json` and find the next `todo` task (lowest priority number)
2. Run the task's **agent chain** — spawn each agent one by one, in order
3. A task is **done** only when ALL agents in the chain output APPROVED (or NEXT/COMPLETE for task-worker)
4. If any agent outputs REJECTED, restart the chain from task-worker
5. Loop until all tasks are done or you hit a blocker

---

## When to STOP and ask the user

Only stop when:
- **All tasks done** — nothing left to build
- **Agent hit a blocker** — something broken, can't proceed
- **Chain failed 3 times** on the same task — needs human input

Do NOT stop for:
- Successful task completion — report and continue
- Chain failures (attempts 1-2) — auto-retry

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
Agent chain: task-worker → browser-test → design-review
```

Immediately proceed — do NOT wait for confirmation.

---

## Step 3 — Run Agent Chain

The task's `agents` array defines the chain. Example: `["task-worker", "browser-test", "design-review"]`

**For each agent in the chain, spawn it sequentially. Wait for each to finish before spawning the next.**

### Agent 1: task-worker (always first)

Spawn a **fresh** Agent (general-purpose) with this prompt:

```
You are a task worker. Follow the instructions in .claude/agents/task-worker.md exactly.

Read tasks/tasks.json, pick the highest priority "todo" task, implement it, run quality checks, commit if all pass, update tasks.json with status based on results.

For UI work, use the /frontend-design skill for design guidance.

Read CLAUDE.md for project conventions before starting.

Output NEXT when done if more tasks remain, or COMPLETE if all tasks are done.
```

Wait for the agent to finish.

- If output contains **BLOCKED** → STOP and ask the user (see Step 5)
- If output contains **NEXT** or **COMPLETE** → task-worker approved, continue to next agent in chain

### Remaining agents (QA/verification)

For each subsequent agent in the chain (index 1, 2, 3, ...), spawn a **fresh** Agent with this prompt:

```
You are a QA/verification agent. Follow the instructions in .claude/agents/{AGENT_NAME}.md exactly.

## Task
- ID: [T-XXX]
- Title: [title]
- Acceptance Criteria:
  [list all criteria from the task]

## Context
Read CLAUDE.md for project context (dev server URL, viewport, brand colors, etc.).
Check screenshots/reference/ for design targets if they exist.

Follow your agent instructions and output APPROVED, REJECTED, or BLOCKED with details.
```

Wait for the agent to finish.

- If output contains **APPROVED** → this agent passed, continue to next agent in chain
- If output contains **REJECTED** → chain failed, go to Step 4 (Handle Rejection)
- If output contains **BLOCKED** → environment issue, STOP and ask the user (see Step 5 — Blocked)

---

## Step 4 — Handle Rejection

When any agent in the chain outputs REJECTED:

1. Read `tasks/tasks.json`
2. Set `status: "todo"` for this task
3. Update the task's `notes` field with the rejection findings:
   ```
   "notes": "QA FAILED (attempt N/3) by [agent-name] — [summary]. Issues: 1) [issue] 2) [issue]"
   ```
4. Write `tasks/tasks.json`
5. Increment the chain failure count for this task
6. If failure count reaches **3** → STOP and ask the user (see Step 5)
7. Otherwise, **auto-retry** — go back to Step 1 (the task is "todo" again, task-worker will read the notes and fix the issues, then the FULL chain runs again from the beginning)

**Important:** The full chain restarts from task-worker on every retry. This ensures:
- task-worker reads the rejection notes and fixes the specific issues
- ALL agents re-verify (a design fix might break functionality)

---

## Step 5 — Report & Continue

### Success (all agents approved):

```
T-XXX [Title] — Done ✓
  [one-line summary]
  Chain: task-worker ✓ → browser-test ✓ → design-review ✓
  Files: [key files]

Starting T-YYY: [Next Title]...
```

Go back to Step 1.

### Chain Failed (retry):

```
T-XXX [Title] — Rejected by [agent-name] (attempt N/3)
  Issues: [brief list]
  Re-dispatching full chain...

Starting T-XXX: [Title] (fixing [agent-name] issues)...
```

Go back to Step 1.

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

### Chain Failed 3 times:

```
T-XXX [Title] — Failed 3 times

Last rejection by: [agent-name]
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
- **NEVER implement code yourself** — always spawn fresh agents
- **RUN THE FULL AGENT CHAIN** — every agent in the task's `agents` array, sequentially
- **RESTART FROM task-worker on rejection** — full chain re-runs after task-worker fixes
- **AUTO-CONTINUE after success AND chain failure** — retry up to 3 times
- **STOP only when blocked, all done, or 3 chain failures**
- **Fresh agents every time** — never resume, always spawn new
- **Sequential execution** — one task at a time, one agent at a time
- **The agents array is the source of truth** — do NOT hardcode which agents to run
