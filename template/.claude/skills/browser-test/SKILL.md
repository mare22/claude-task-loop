---
name: browser-test
description: >
  Verify a feature works in the browser using Playwright CLI.
  Use when a UI story needs browser verification, or when asked to "check in browser",
  "verify the UI", or "test in browser".
allowed-tools: Read, Bash, Glob, Grep
---

# Browser Test

## Prerequisites

1. Check Playwright CLI is available: `npx playwright --version`
2. Read `CLAUDE.md` for the project's dev server URL and viewport size
3. Check if the dev server is running. If not, start it using the command from CLAUDE.md

---

## Step 1 — Open Browser

```bash
playwright-cli open <DEV_SERVER_URL>
playwright-cli resize <VIEWPORT_WIDTH> <VIEWPORT_HEIGHT>
```

Use the dev server URL and viewport from CLAUDE.md.

---

## Step 2 — Navigate & Verify

1. Read the acceptance criteria for the current task (from `tasks/tasks.json` or the user's request)
2. Navigate to the relevant route
3. Take a snapshot to understand the current state:
   ```bash
   playwright-cli snapshot
   ```
4. Interact with the UI to verify each acceptance criterion:
   - Click buttons, fill forms, navigate between screens
   - Check that elements are visible and correct
   - Verify animations/transitions work

---

## Step 3 — Screenshot Evidence

Take screenshots as evidence:
```bash
playwright-cli screenshot --filename=/tmp/browser-test/feature-name.png
```

---

## Step 4 — Report

Report results:
- **PASS**: All acceptance criteria verified in browser
- **FAIL**: List which criteria failed and why

If FAIL, describe what needs to be fixed. Do NOT fix code in this skill — just report.

---

## Step 5 — Cleanup

```bash
playwright-cli close
```
