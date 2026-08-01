---
name: loop-tasks
description: >
  Run the autonomous task loop. For each task: task-worker implements (uncommitted), then all QA
  agents verify in parallel waves, then the orchestrator commits. Use when the user runs /loop-tasks
  or says "start the loop", "run tasks", "build tasks".
user-invocable: true
---

# Loop Tasks — Orchestrator

## Overview

You are an **orchestrator**. You do NOT implement code yourself.

Three invariants govern the whole system. Never break them:

1. **Only `task-worker` modifies code.** Every other agent is read-only.
2. **Only you (the orchestrator) commit.** One commit per task, after every agent approves.
3. **Only you write `tasks/tasks.json`.** Agents report back to you; you record it.

Because you own the commit, `HEAD` never moves while a task is in flight. That makes
`git diff HEAD` exactly equal to "the work for this task" — for every QA agent, on every
rework cycle, with no bookkeeping. Do not break this by committing early.

### The cycle

```
preflight (clean tree) → task-worker (edits + stages, no commit)
                              ↓
                    QA WAVE — agents run in parallel lanes
                              ↓
                    collect ALL verdicts (no fail-fast)
                              ↓
   any REJECTED → consolidate → attempts++ → back to task-worker
   all APPROVED → run quality gates → commit → status: done
```

---

## Step 0 — Preflight

Run once, before the first task:

```bash
git rev-parse --git-dir            # must be a git repo
git status --porcelain             # must be EMPTY
```

- **Not a git repo** → STOP. Tell the user the loop needs git (it reviews the working-tree diff).
- **Dirty working tree** → it depends on why:
  - If `tasks.json` has a task in `in-progress` or `blocked`, this is an **interrupted run**.
    The dirty tree is that task's own uncommitted work. Say so, and resume it in Step 1.
  - Otherwise it is the user's own work → STOP. Show `git status --short` and ask them to commit
    or stash first. A dirty tree would be reviewed as if it were the task's work, and swept into
    the task's commit.

---

## Step 1 — Load State

**Re-read `tasks/tasks.json` from disk EVERY iteration.** Never use cached data — you may have
been restarted or compacted since the last write.

1. Read `tasks/tasks.json`
2. **Resume before you start anything new.** If a task is already `in-progress` or `blocked` and
   the working tree is dirty, a previous run was interrupted mid-task. Pick that task up again —
   its uncommitted work is still in the tree, and its `base_sha` is still valid. Do not start a
   different task while another task's changes are sitting in the working tree.
3. Otherwise find the next task: `status: "todo"`, lowest `priority` number
4. If zero `todo` tasks → **"All tasks complete!"** → STOP
5. If the task's `agents` array is missing or empty, default to `["task-worker"]`
6. Read the task's `attempts` field (default `0`). If it is already `>= 3`, this task previously
   exhausted its retries — go to **Blocked / Exhausted** in Step 6.

Record the starting commit:

```bash
git rev-parse HEAD
```

Write it to the task's `base_sha` and set `status: "in-progress"`. This is your record of what
the task built on, and your check that task-worker did not commit behind your back.

---

## Step 2 — Announce

```
T-XXX [Title] — attempt N/3
  Lanes: [static: code-review, security-review, test-coverage] [browser: browser-test → design-review]
```

Proceed immediately — do NOT wait for confirmation.

---

## Step 3 — Run task-worker

Spawn a **fresh** agent (`subagent_type: task-worker`, or a general-purpose agent instructed to
follow `.claude/agents/task-worker.md` exactly):

```
Implement task [T-XXX] from tasks/tasks.json.

- ID: [T-XXX]
- Title: [title]
- Description: [description]
- Acceptance Criteria:
  [list every criterion]
- Notes: [the notes field — on a rework pass this contains the consolidated QA findings]

Rules you must not break:
- Do NOT run `git commit`. Stage your work with `git add` and stop there. The orchestrator commits.
- Do NOT write to tasks/tasks.json. Report back to me instead; I record it.
- Run every quality gate command from CLAUDE.md and get them passing before you report DONE.

Read CLAUDE.md for project conventions first. For UI work, use the /frontend-design skill.

Report DONE with a summary + test plan, or BLOCKED with the reason.
```

### Verify the work actually happened

Do not trust the DONE signal. Check:

```bash
git rev-parse HEAD                 # compare to base_sha
git status --porcelain             # must be NON-empty
```

- **HEAD moved** — task-worker committed despite the rule. Undo it without losing the work:
  ```bash
  git reset --soft <base_sha>
  ```
  Log it and carry on.
- **Working tree is clean** — task-worker changed nothing. This is a false DONE. Treat it as a
  REJECTED verdict with the reason "no changes were made" and go to Step 5.
- **BLOCKED** → Step 6.

Record task-worker's summary and test plan into the task's `log` and `test_plan` fields.

---

## Step 4 — Run the QA Wave

The remaining entries in the task's `agents` array are QA agents. They are all read-only, so
most of them can run **at the same time**. What stops them is not read/write — it is **shared
singleton resources**.

### Lanes

Read the `**Lock:**` line near the top of each `.claude/agents/{name}.md`. Absent → `none`.

| Lock | Meaning | Scheduling |
|---|---|---|
| `none` | No shared resource | Every such agent gets its own lane — all fully parallel |
| `browser` | Drives `playwright-cli` | ALL browser agents share ONE lane, run in array order |
| `ios` | Drives the iOS simulator | One shared lane |
| `android` | Drives the Android emulator | One shared lane |
| `ios+android` | Needs both devices | Runs in a final round, after both device lanes drain |

**Why `browser` is one lane:** `playwright-cli` is a single global session — `open` and `close`
take no session id. Two agents driving it concurrently will close each other's browser mid-test
and produce flaky false rejections.

### Execution — rounds

Run the lanes as rounds. **Every spawn in a round goes in a SINGLE message with multiple Agent
tool calls** — that is what makes them run concurrently. One call per message is sequential and
defeats the entire design.

- **Round 1:** every `none`-lock agent, plus the *first* agent of each locked lane.
- **Round 2:** the *second* agent of each locked lane (if any).
- **Round N:** continue until every lane is drained.
- **Final round:** any multi-lock agent (`ios+android`).

Worked example — `["task-worker", "code-review", "security-review", "test-coverage", "browser-test", "accessibility-audit", "design-review"]`:

```
Round 1 (one message, 4 concurrent):  code-review │ security-review │ test-coverage │ browser-test
Round 2 (one message, 1 agent):       accessibility-audit
Round 3 (one message, 1 agent):       design-review
```

Six QA agents in three rounds instead of six.

### The prompt for each QA agent

```
You are a read-only QA agent. Follow .claude/agents/{AGENT_NAME}.md exactly.

## Task
- ID: [T-XXX]
- Title: [title]
- Acceptance Criteria:
  [list every criterion]

## Where the work is
task-worker's changes are STAGED BUT UNCOMMITTED. Review the working tree:
  git status --porcelain     — every file touched, including new untracked files
  git diff HEAD              — the full diff for this task
Do NOT use `git diff HEAD~1` — HEAD is the commit BEFORE this task started.

## Context
Read CLAUDE.md for project context (dev server URL, viewport, brand colors).
Check screenshots/reference/ for design targets if they exist.

## Rules
- You are READ-ONLY. Do not edit, create, or delete any file. Do not run git commit,
  git add, git checkout, git stash, or git reset. task-worker fixes what you find.
- Do not write to tasks/tasks.json. Report to me; I record it.
- Report every issue with file:line and a concrete suggested fix — task-worker gets ALL
  findings from ALL agents at once and fixes them in a single pass. Be complete.

Output APPROVED, REJECTED, or BLOCKED with details.
```

### Collecting verdicts

**Do NOT stop the wave on the first REJECTED.** Let every agent finish and collect all of
them. Surfacing every problem in one cycle is the point — it is what lets task-worker fix
everything in one rework pass instead of one problem per pass.

The one exception: if an agent returns **BLOCKED** because its environment is broken (no
browser, no simulator), skip the rest of *that lane* — the agents behind it share the same
broken resource. Other lanes keep running.

After the wave, append one `log` entry per agent with its verdict and a one-line summary.

---

## Step 5 — Decide

### Any REJECTED

1. Consolidate **every** rejection from **every** agent into the task's `notes`:
   ```
   QA FAILED (attempt N/3)

   [code-review] REJECTED
     1. api/boards.ts:42 — N+1 query in index(); use eager loading
   [browser-test] REJECTED
     1. Submit button does nothing — POST /api/boards returns 500
   [design-review] REJECTED
     1. [Critical] Card title clipped at 320px — needs min-width or truncation
   ```
2. Set `status: "todo"`, increment `attempts`, write `tasks/tasks.json`
3. If `attempts >= 3` → Step 6 (Exhausted)
4. Otherwise re-read `tasks/tasks.json`, set this task back to `in-progress`, and go to
   **Step 3** — task-worker reads the consolidated notes and fixes everything in one pass. The
   working tree still holds the previous changes, so it builds on them rather than starting over.

   Retry at Step 3, **not** Step 1. Step 1 re-selects by priority, and if a higher-priority task
   was added while this one was running you would switch tasks with uncommitted work still in
   the tree. Keep `base_sha` — nothing has been committed, so it is still correct.

`attempts` lives in `tasks.json`, not in your context. Read it from disk each cycle — if this
session restarts or compacts, the count survives.

### All APPROVED — commit

You are the only committer. Run the project's quality gates yourself first — a QA cycle can
regress them, and this is the last gate before the work is permanent:

```bash
# every quality gate command from CLAUDE.md
```

If a gate fails, treat it as a REJECTED verdict (reason: which gate, and its output) and go
back to Step 3. Do not commit failing code.

If they pass, commit in two steps — **the code first, the task record second**:

**1. The work commit.** Exclude `tasks/tasks.json`; the task record isn't final yet (it can't
hold its own commit SHA) and mixing it in would leave the tree dirty afterwards.

```bash
git add -A -- ':!tasks/tasks.json'
git commit -m "$(cat <<'EOF'
feat(T-XXX): Task Title

[one-line summary of what was implemented]

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
git rev-parse HEAD          # this is commit_sha
```

Use `fix(T-XXX)` for tasks tagged `bug`, `feat(T-XXX)` otherwise.

**2. The bookkeeping commit.** Now update `tasks/tasks.json`: `status: "done"`, `commit_sha` set
to the SHA above, `attempts` reset to `0`, `notes` cleared, final `log` entry appended. Then:

```bash
git add tasks/tasks.json
git commit -m "chore(T-XXX): update task record"
```

**Verify the tree is clean again** (`git status --porcelain` empty) before starting the next
task — that is Step 0's precondition restored. If anything is still dirty, something wrote
outside the task scope; stop and show the user.

---

## Step 6 — Stop conditions

Stop and ask the user ONLY for these. Everything else auto-continues.

### Blocked

```
T-XXX [Title] — Blocked by [agent]

Problem: [what went wrong]

Uncommitted work is still in the working tree.

Options:
1. Retry with a fresh agent
2. Skip this task (status: "skipped") — I'll `git stash` the partial work first
3. Give me guidance

What do you want to do?
```

Set `status: "blocked"` in `tasks.json` so the board shows it while you wait.

### Exhausted (attempts >= 3)

```
T-XXX [Title] — Failed 3 times

Persistent issues:
[the notes field]

Options:
1. Give me guidance and I'll retry (resets attempts)
2. Skip this task (status: "skipped")
3. Retry once more anyway

What do you want to do?
```

### Skipping

If the user skips a task, the working tree still holds partial work — it must not leak into
the next task. Stash it, then set `status: "skipped"`:

```bash
git stash push -u -m "T-XXX skipped"
```

Tell the user how to get it back (`git stash list` / `git stash pop`).

---

## Step 7 — Report & Continue

```
T-XXX [Title] — Done ✓  (attempt 2/3, commit a1b2c3d)
  [one-line summary]
  Round 1: code-review ✓  security-review ✓  test-coverage ✓  browser-test ✓
  Round 2: accessibility-audit ✓
  Round 3: design-review ✓
  Files: [key files]

T-YYY [Next Title] — attempt 1/3
```

Go back to Step 1.

---

## Rules

- **NEVER implement code yourself** — always spawn task-worker
- **NEVER let a QA agent modify code** — they are read-only; task-worker fixes everything
- **NEVER commit before every agent approves** — one commit per task, made by you
- **NEVER let an agent write tasks.json** — you are the single writer
- **RE-READ tasks.json FROM DISK every iteration** — `attempts` and `notes` live there, not in your context
- **BATCH each round into ONE message** — multiple Agent calls in one message run concurrently; separate messages do not
- **COLLECT ALL VERDICTS** — never fail-fast; one cycle should surface every problem
- **RESPECT THE LOCKS** — two agents sharing a browser or a simulator will corrupt each other
- **VERIFY, DON'T TRUST** — check the tree changed before believing DONE; run the gates before committing
- **The agents array is the source of truth** — never hardcode which agents run
