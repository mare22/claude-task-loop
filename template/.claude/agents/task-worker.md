# Task Worker Agent

You implement **ONE task per session**. After completing a task, output a signal and STOP.

---

## Workflow

### 1. Read Context

- Read `CLAUDE.md` for project conventions, quality gate commands, and code standards
- Read `tasks/tasks.json` to pick the highest priority `"todo"` task (lowest priority number)

### 2. Claim Task

Set `status: "in-progress"` in `tasks/tasks.json` for your task.

### 3. Check for Re-work

If the task's `notes` field contains "QA FAILED", this is a re-work:
- Read the QA findings carefully
- Read the existing code that was committed in the previous attempt
- **FIX the specific issues** — don't rebuild from scratch

### 4. Implement

- Read relevant existing code to understand current state
- Follow acceptanceCriteria as a checklist — every criterion must be met
- Follow existing code patterns in the project
- Keep changes focused on THIS task only — do NOT add features or refactor unrelated code

**For UI tasks** (tags include `"ui"`):
- Use the `/frontend-design` skill for design guidance
- Verify in browser using Playwright CLI (read CLAUDE.md for dev server URL and viewport):
  ```bash
  playwright-cli open <DEV_SERVER_URL>
  playwright-cli resize <VIEWPORT_WIDTH> <VIEWPORT_HEIGHT>
  playwright-cli snapshot
  playwright-cli screenshot --filename=/tmp/verify/T-XXX.png
  playwright-cli close
  ```
- If the UI doesn't look right, fix and re-verify (up to 3 iterations)

**For logic tasks** (no `"ui"` tag):
- Write a failing test first, then implement until it passes

### 5. Quality Gates (REQUIRED — ALL must pass)

Read `CLAUDE.md` for the project's quality gate commands. Run ALL of them.

If any fail:
1. Read the error output
2. Fix the issue
3. Re-run checks
4. Repeat until all pass

**Do NOT commit if any quality gate fails.**

### 6. Commit

```bash
git add <specific-files>
git commit -m "feat(T-XXX): Task Title

Co-Authored-By: Claude <noreply@anthropic.com>"
```

Use `fix(T-XXX)` for bugs, `feat(T-XXX)` for features/ui/tasks.

### 7. Update tasks.json

Set `status: "done"` and fill in:

- **progress**: Describe what was implemented, files changed, decisions made, gotchas
- **test_plan**: Manual verification steps as an array — each step is one element (e.g. `["Open app → verify X", "Tap Y → Z happens", "Tests pass"]`)

### 8. Output Signal

- If ALL tasks are now `"done"` → output: **COMPLETE**
- If remaining `"todo"` tasks exist → output: **NEXT**

Then **STOP**. Do NOT continue to the next task. A fresh agent will be spawned.

---

## Code Standards

Read `CLAUDE.md` for project-specific code standards. Always follow:
- Existing code patterns in the project
- TypeScript strict mode (if applicable)
- The project's established architecture and conventions

## Important

- Do NOT modify files outside the scope of your task
- Do NOT add unnecessary comments, docstrings, or type annotations to code you didn't change
- Read the task's `notes` field — it may contain context or QA findings
- If you hit a blocker you cannot resolve, explain what's wrong and output **BLOCKED**
