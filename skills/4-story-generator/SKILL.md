---
name: story-generator
description: >
  Generate fully detailed engineering Story documents (.md) from an Epic file. Use this skill whenever the user wants to
  write a story, create a story from an epic, develop a user story, expand an S-XXX into a full document, or turn an
  epic into implementation-ready stories. Triggers include phrases like "write story S-004", "create the story for
  S-001", "generate story from this epic", "expand this user story", "develop S-XXX", "write the stories for this
  epic", or any reference to producing an engineering story document from an epic. Also trigger when the user uploads
  or references an epic.md and asks to work on a specific story. Even if the user just says "write the story" or
  "next story" in a conversation where an epic is present, use this skill.
---

# Epic Story Writer

Transform Epic documents into fully detailed, engineering-ready Story files (.md) following a strict template and repo convention.

---

## Workflow

### Step 1 — Locate and read the Epic

The epic can come from:
- An uploaded file in `/mnt/user-data/uploads/`
- A file already in the conversation context (the user pasted it or it was loaded from a document block)
- A path the user provides (e.g., `docs/epics/E-002_authentication-and-registration/epic.md`)

If the epic content is already in the conversation context, use it directly — don't re-read the file.

### Step 2 — Auto-detect available stories

Scan the epic for user story references. Look for patterns like:
- `*(S-XXX)*` in the user stories section
- `S-XXX` references in the handoff/refinement section
- Numbered items in section 5 (User stories)

Present the detected stories to the user with their one-line description so they can pick one, unless they already specified which story they want.

### Step 3 — Gather inputs

You need three things:
1. **The Epic content** (from step 1)
2. **The Story ID** — e.g., S-004 (from user selection or explicit request)
3. **Optional additional context** — ask the user if they have extra context, clarifications, or constraints for this specific story. If they say no or don't provide any, proceed without it.

### Step 4 — Generate the Story

Follow the **Story Template** and **Generation Guidance** sections below.

**Priority rules when generating:**
1. User-provided context (HIGHEST — overrides everything)
2. Epic content (primary source of truth)
3. Logical inference (ONLY when necessary — never invent features outside the epic scope)

**Critical rules:**
- Write in English
- Do NOT invent features, endpoints, or behaviors not described in the epic
- Do NOT leave sections empty — every section must have substantive content
- Do NOT contradict epic rules, constraints, or business logic
- Maintain consistency with the epic's terminology, entity names, and security requirements
- Acceptance criteria must be testable (clear pass/fail)
- Edge cases should cover user errors, system failures, integration issues, and security scenarios
- Architecture section stays at logical/conceptual level — no code, no endpoint signatures
- If the epic has Open Questions relevant to this story, carry them forward

### Step 5 — Write the output file

**File naming convention:**
```
E-{epic_number}_S-{story_number}_{slug}.md
```
Where `{slug}` is a short snake_case name derived from the story's title (3-5 words max).

Examples:
- `E-002_S-001_manual_signup_verification.md`
- `E-002_S-004_first_access_onboarding.md`
- `E-015_S-003_qr_label_generation.md`

**Output location:**
Write the file to `/mnt/user-data/outputs/` and present it. If the user has specified a repo path, mention where it should go:
```
docs/epics/E-XXX_<epic_slug>/stories/E-XXX_S-XXX_<story_slug>.md
```

### Step 6 — Quality self-check

Before finishing, internally verify:
- [ ] The correct User Story (S-XXX) was developed — not a different one
- [ ] User-provided context was incorporated
- [ ] No contradictions with the epic's rules, scope, or constraints
- [ ] Acceptance criteria are testable with clear pass/fail conditions
- [ ] All 10 sections of the template are complete with substantive content
- [ ] Edge cases are realistic, not generic placeholders
- [ ] Architecture section is logical-level, not implementation-level
- [ ] Non-goals correctly exclude what's out of scope for *this story*
- [ ] Open questions are carried from the epic only if relevant to this story

### Output format

Return ONLY the story document. No preamble explanations. No "here's the story I generated" text. Just the document, then present the file.

---

## Story Template

Every generated story MUST follow this exact structure. Every section is mandatory and must contain substantive content — never leave a section empty or with placeholder text.

```
# Story E-{epic}_S-{story} — {Story Name}

## 0) Snapshot

* **Parent Epic:** E-{epic} — {Epic Name}
* **Status:** Draft
* **Owner:** Tech Lead / Architect
* **Related docs:**
  * `/docs/project_context.md`
  * `/docs/epics/{epic_folder}/epic.md`

---

## 1) User story

As a {user type}, I want {action}, so that {outcome}.

---

## 2) Minimum context

Where this story sits in the overall epic flow (what comes before, what comes after).
Preconditions that must be true before this story's work begins.
Dependencies on other stories, systems, or decisions.
Any user-provided context that affects understanding.
Key domain concepts the reader needs to know.

---

## 3) Acceptance criteria

Each criterion must be testable — a QA engineer should be able to read it and write a test.

Cover:
- Happy path success conditions
- Failure / error conditions
- Validation rules (field formats, required fields, length limits)
- Security constraints (auth, rate limits, session rules)
- Integration behavior (what happens when external calls succeed or fail)

Format:
- **AC-01:** Given [precondition], when [action], then [expected result].

---

## 4) Applicable business rules

Extract ONLY the rules relevant to this specific story from the epic.

Format:
- **BR-01:** {rule}

---

## 5) Edge cases

Cover: user errors, system failures, integration issues, security edge cases, data edge cases.

Format:
- **EC-01:** {scenario} → {expected behavior}

---

## 6) Architecture decisions

### Frontend components
UI behavior and component responsibilities at a conceptual level.
What screens, forms, or flows are involved? What state do they manage?
Do NOT specify framework-level details or component code.

### Backend services
Logical services, orchestration flows, and data operations.
What service handles what? What is the sequence of operations?
Do NOT define endpoint signatures, HTTP methods, or code.

### Infrastructure
External integrations, auth systems, third-party APIs, queues, or async processes.

---

## 7) Required data (inputs / outputs)

### Inputs
Explicit user inputs with: field name, type, required/optional, validation rules.

### System-generated / internal fields
System-managed data with: field name, how it's generated or derived, where it's stored.

### Outputs

#### Success
What the user sees or the system produces on successful completion.

#### Failure
Error states and user experience for each failure type.

---

## 8) Telemetry / expected logs

### Product telemetry
- `event_name` — when it fires, what it measures

### Security / audit logs
- `event_name` — trigger condition, what it records

### Recommended log attributes
Key fields to include in log entries.

---

## 9) Non-goals

What is explicitly OUT of scope for this story.
Be specific: "Do not implement X" is better than "X is out of scope".

---

## 10) Open questions

Include ONLY if the epic has open questions relevant to this story or the user introduced ambiguity.

Format:
- **OQ-X:** {question}
  - **Owner:** {who resolves it}
  - **Due stage:** {when it must be resolved}

If none: "No open questions for this story. All required decisions are resolved in the epic."
```

---

## Generation Guidance

### Extracting story content from the epic

Each story ID (S-XXX) appears in multiple places in the epic. Mine all of them:

1. **Section 5 (User stories)** — the one-liner that defines the story's intent
2. **Section 2 (Scope → In scope)** — detailed behaviors and rules that map to this story
3. **Section 6 (Scope boundaries and rules)** — business rules this story must enforce
4. **Section 3 (Epic overview)** — the primary workflow steps this story covers
5. **Section 7 (Dependencies)** — integrations and systems this story touches
6. **Section 8 (Risks and constraints)** — risks that affect this story
7. **Section 9 (Open questions)** — unresolved decisions relevant to this story
8. **Section 11 (Acceptance criteria)** — epic-level criteria that decompose into this story
9. **Section 12 (Handoff)** — additional grouping context for what this story covers

### Acceptance criteria depth

Epic-level acceptance criteria are broad. Story-level criteria must be granular:
- Break each epic criterion that applies to this story into specific, testable sub-criteria
- Add validation rules with exact formats, lengths, and allowed values
- Add failure criteria (what happens when things go wrong)
- Add security criteria extracted from the epic's security controls section

### Architecture section tone

This section describes *what* the system does, not *how* it's coded:
- "A service validates the input and calls the external API" — good
- "POST /api/v1/onboarding with body { ... }" — too specific, avoid
- "The frontend renders a form with conditional fields" — good
- "Use React Hook Form with Zod validation" — too specific, avoid

### Edge cases quality

Bad edge cases are generic ("what if the server is down"). Good edge cases are specific to the story's domain:
- "User submits the onboarding form with a `dniType` of `J` but leaves `legal_name` empty" — specific and testable
- "Canguro Azul returns a `client_code` for an `inactive` client during onboarding" — domain-aware
- "User navigates back after the `client_code` call succeeds but before the Business Account is created" — flow-aware

### User story rewriting

Rewrite the user story from the epic clearly and precisely. Do not copy it verbatim if it can be improved for clarity. The outcome should reflect real business or user value.

### Non-goals scoping

Pull from the epic's non-goals but narrow to what's relevant for *this specific story*. Also exclude work that belongs to adjacent stories in the same epic — this prevents scope creep during implementation.
