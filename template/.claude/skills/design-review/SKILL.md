---
name: design-review
description: >
  Automated visual design QA with closed-loop fixing.
  Use when the user runs /design-review, wants to audit UI/UX, check if the frontend
  looks correct, or says "screenshot and fix the design".
allowed-tools: Read, Edit, Bash, Glob, Grep, Write
---

# Design Review

## Prerequisites

Check that Playwright CLI is available:
```bash
npx playwright --version
```

If not installed — **stop immediately** and tell the user:
> Playwright CLI is not installed. Run `npm install -D @playwright/test && npx playwright install chromium` and then try again.

---

## Step 1 — Detect Project Type

Read `CLAUDE.md` to understand:
- **Framework** (React, Next.js, Vue, Expo, etc.)
- **Dev server URL** and port
- **Target viewport** (width x height)
- **Brand colors** and design system

---

## Step 2 — Gather Info

Ask the user for anything not already provided:
1. **URL** to review (default: dev server from CLAUDE.md) — or offer to start the dev server
2. **Routes/pages** to check (or default to `/`)
3. **Reference screenshots** — check `screenshots/reference/` for design targets
4. **Dark mode?** — check if the app has theme switching

---

## Step 3 — Screenshot

Use Playwright CLI to take screenshots at the project's target viewport:

```bash
playwright-cli open <DEV_SERVER_URL>
playwright-cli resize <VIEWPORT_WIDTH> <VIEWPORT_HEIGHT>
playwright-cli screenshot --filename=/tmp/design-review/iter-N/page-name.png
```

If reference screenshots exist in `screenshots/reference/`, compare against them.

Save screenshots to `/tmp/design-review/iter-N/` (where N is the iteration number).

---

## Step 4 — Audit

Look at the screenshots and act as a **harsh senior UI/UX engineer**. Compare against reference screenshots if available.

### HARD BLOCKERS — These are auto-fail, must fix before anything else

Check these FIRST. If ANY of these are present, the page is **BROKEN** and cannot pass:

1. **Content cut off or clipped** — ANY text, label, input, or UI element that is not fully visible within the viewport. This includes:
   - Labels cut off on the left/right edge
   - Text truncated without ellipsis
   - Form fields partially hidden or shifted off-screen
   - Buttons or interactive elements partially obscured

2. **Broken layout** — Elements stacked incorrectly, overlapping, or positioned outside the viewport:
   - Content shifted left/right leaving a visible gap on the opposite side
   - Elements overlapping and obscuring each other
   - Missing padding from screen edges (minimum 16px on left/right)
   - Scroll container not working (content below fold unreachable)

3. **Missing critical elements** — Expected UI elements not rendered:
   - Form fields that should exist but don't
   - Navigation elements (back button, tabs) missing
   - Empty areas where content should be
   - Blank white/black sections with no content

4. **Unreadable content**:
   - Text with insufficient contrast (invisible against background)
   - Text too small to read (below 12px equivalent)
   - Overlapping text that can't be parsed

5. **Non-functional interactions**:
   - Buttons that can't be tapped (overlapped, off-screen, too small)
   - Touch targets smaller than 44x44pt (mobile) or too small to click (web)
   - Forms that can't be submitted
   - Navigation that doesn't work

### Visual Design (check after hard blockers are clear)

- Does it match the reference screenshots for FUNCTIONALITY?
- Colors off-brand or inconsistent with the project's design system
- Spacing/alignment problems
- Typography inconsistencies (font size, weight, line height)
- Broken responsive layout at target viewport
- Anything that looks unpolished or unintentional

### Accessibility

- Contrast ratios — flag any text/background combination that fails WCAG AA
- Touch/click target sizes — flag interactive elements that are too small
- Font scaling — check that text is not clipped or overlapping

### Severity Classification
- **Critical**: Any HARD BLOCKER item — broken layout, content cut off, unreadable text, missing elements, non-functional interactions
- **Major**: Significant visual inconsistency, poor contrast, misaligned elements, wrong colors vs reference
- **Minor**: Small spacing issues, subtle inconsistencies, polish items

---

## Step 5 — Fix

Fix all Critical and Major issues directly in the code. No asking for permission.

**Priority order:**
1. Fix ALL hard blockers first (content cut off, broken layout, missing elements)
2. Then fix Major visual issues
3. Minor issues: fix if obvious, otherwise list them at the end

For Minor issues: fix them if obvious, otherwise list them at the end for the user.

---

## Step 6 — Loop

Re-screenshot after fixes into a new `/tmp/design-review/iter-N/` directory. Compare with the previous iteration.

Repeat Steps 4–6 until:
- All Critical and Major issues are resolved
- Or stuck on the same issue after 2 iterations → ask user for guidance

Maximum 5 iterations total. If issues remain after 5, report what's left.

---

## Step 7 — Report

Summarize:
- Total iterations taken
- Issues found (by severity) — highlight any HARD BLOCKERS that were found
- What was fixed (with before/after screenshot paths)
- How closely the result matches reference screenshots
- Any remaining Minor issues for the user to address
