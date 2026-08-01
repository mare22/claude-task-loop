---
name: prd
description: "Generate a Product Requirements Document (PRD) for a new feature. Use when planning a feature, starting a new project, or when asked to create a PRD. Triggers on: create a prd, write prd for, plan this feature, requirements for, spec out."
user-invocable: true
---

# PRD Generator

Create detailed Product Requirements Documents that are clear, actionable, and suitable for implementation.

---

## The Job

1. Receive a feature description from the user
2. Ask 3-5 essential clarifying questions (with lettered options)
3. Generate a structured PRD based on answers
4. Save to `tasks/prd-[feature-name].md`
5. Offer to turn the PRD's user stories into tasks in `tasks/tasks.json`

**Important:** Do NOT start implementing. Create the PRD, and optionally the task list.

---

## Step 1: Clarifying Questions

Ask only critical questions where the initial prompt is ambiguous. Focus on:

- **Problem/Goal:** What problem does this solve?
- **Core Functionality:** What are the key actions?
- **Scope/Boundaries:** What should it NOT do?
- **Success Criteria:** How do we know it's done?

### Format Questions Like This:

```
1. What is the primary goal of this feature?
   A. Improve user onboarding experience
   B. Increase user retention
   C. Reduce support burden
   D. Other: [please specify]

2. Who is the target user?
   A. New users only
   B. Existing users only
   C. All users
   D. Admin users only

3. What is the scope?
   A. Minimal viable version
   B. Full-featured implementation
   C. Just the backend/API
   D. Just the UI
```

This lets users respond with "1A, 2C, 3B" for quick iteration.

---

## Step 2: PRD Structure

Generate the PRD with these sections:

### 1. Introduction/Overview
Brief description of the feature and the problem it solves.

### 2. Goals
Specific, measurable objectives (bullet list).

### 3. User Stories
Each story needs:
- **Title:** Short descriptive name
- **Description:** "As a [user], I want [feature] so that [benefit]"
- **Acceptance Criteria:** Verifiable checklist of what "done" means

Each story should be small enough to implement in one focused session.

**Format:**
```markdown
### US-001: [Title]
**Description:** As a [user], I want [feature] so that [benefit].

**Acceptance Criteria:**
- [ ] Specific verifiable criterion
- [ ] Another criterion
- [ ] Quality gates pass
- [ ] **[UI stories only]** Verify in browser
```

**Important:**
- Acceptance criteria must be verifiable, not vague. "Works correctly" is bad. "Button shows confirmation dialog before deleting" is good.
- **For any story with UI changes:** Always include "Verify in browser" as acceptance criteria.

### 4. Functional Requirements
Numbered list of specific functionalities:
- "FR-1: The system must allow users to..."
- "FR-2: When a user clicks X, the system must..."

Be explicit and unambiguous.

### 5. Non-Goals (Out of Scope)
What this feature will NOT include. Critical for managing scope.

### 6. Design Considerations (Optional)
- UI/UX requirements
- Link to mockups if available
- Relevant existing components to reuse

### 7. Technical Considerations (Optional)
- Known constraints or dependencies
- Integration points with existing systems
- Performance requirements

### 8. Success Metrics
How will success be measured?

### 9. Open Questions
Remaining questions or areas needing clarification.

---

## Step 3: Turn the PRD into Tasks

After saving the PRD, ask whether to generate tasks from it. If yes, follow
`.claude/skills/tasks/SKILL.md` for the schema and write to `tasks/tasks.json`.

Each **user story becomes one task**: `US-001` → `T-001`, with the story's acceptance criteria
carried over verbatim plus the project's quality gates from `CLAUDE.md`.

### Ask which pipeline — always

The `agents` array decides how thoroughly each task is verified and how long it takes.
**Never assign it silently.**

Ask with **AskUserQuestion**, header `Pipeline`, offering 4 presets from
`.claude/skills/tasks/SKILL.md` ordered thorough → fast, recommendation first. Quote **rounds**,
not agent count — the orchestrator runs read-only verifiers concurrently in lanes, so four
verifiers often cost the same wall-clock as one.

For a PRD, ask **once for the batch default**, then:

1. Apply the batch default to every task
2. Override individual tasks where the story clearly differs — a UI story in an otherwise
   backend PRD gets the web pipeline, a config chore gets `Quick`
3. Show the result as a table and let the user adjust before writing

```
T-001  Login form                 feature, ui   Web UI          2 rounds
T-002  POST /api/auth/login       feature       Backend / API   1 round
T-003  Session cookie config      task          Quick           1 round

Pipelines look right, or adjust any?
```

Then write all tasks in one go with `status: "todo"`, `attempts: 0`, `base_sha: ""`,
`commit_sha: ""`, `log: []`, `test_plan: []`.

Order `priority` by dependency — if `T-002`'s API is needed by `T-001`'s UI, give the API the
lower number. The loop runs strictly in priority order, so this is how you express sequencing.

Finish by telling the user to run `/loop-tasks`.

---

## Writing for Junior Developers

The PRD reader may be a junior developer or AI agent. Therefore:

- Be explicit and unambiguous
- Avoid jargon or explain it
- Provide enough detail to understand purpose and core logic
- Number requirements for easy reference
- Use concrete examples where helpful

---

## Output

- **Format:** Markdown (`.md`)
- **Location:** `tasks/`
- **Filename:** `prd-[feature-name].md` (kebab-case)

---

## Checklist

Before saving the PRD:

- [ ] Asked clarifying questions with lettered options
- [ ] Incorporated user's answers
- [ ] User stories are small and specific
- [ ] Functional requirements are numbered and unambiguous
- [ ] Non-goals section defines clear boundaries
- [ ] Saved to `tasks/prd-[feature-name].md`
- [ ] Offered to generate tasks — and if accepted, **asked which pipeline** rather than guessing
- [ ] Task priorities ordered by dependency
