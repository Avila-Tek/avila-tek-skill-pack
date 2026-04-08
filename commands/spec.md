---
name: spec
description: Start spec-driven development — write a structured specification before writing code
---

Invoke the agent-skills:spec-driven-development skill.

## Mode Detection (silent — do not announce)

Before doing anything, check if a story file exists for the current task:

1. Look for a `.md` file at `docs/epics/E-XXX_slug/stories/E-XXX_S-YYY_slug/E-XXX_S-YYY_slug.md`
2. If found → run **Story-Driven Mode** (see below)
3. If not found → run **Standard Mode**

## Standard Mode (no story file)

Ask clarifying questions about:
1. The objective and target users
2. Core features and acceptance criteria
3. Tech stack preferences and constraints
4. Known boundaries (what to always do, ask first about, and never do)

Generate a structured spec covering all six core areas: objective, commands, project structure, code style, testing strategy, and boundaries.

**Output:** Save as `SPEC.md` in the project root (or wherever the user specifies). Confirm before writing.

## Story-Driven Mode (story file exists)

1. Read the story file completely (Block A + Block B)
2. Map story sections to spec sections:
   - User Story → Objective
   - Acceptance Criteria → Success Criteria
   - Ranked Tasks → base for Tasks
   - Technical Scope (API, DB, auth, config) → Tech Stack + Boundaries
   - Business Rules → Boundary constraints
3. Ask only about gaps the story does not cover (e.g. build commands, test framework, code style)
4. Do NOT ask about scope, ACs, or technical boundaries already defined in the story

**Output:** Save as `spec.md` inside the story folder:
`docs/epics/E-XXX_slug/stories/E-XXX_S-YYY_slug/spec.md`
