# Epic Document — Canonical Template

Reference template for generating Epic documents. Use `[TO BE DEFINED]` for gaps, never skip a section.

---

## Document Header

```markdown
# E-<XXX> — <Epic Name>
```

---

## 0) References

```markdown
## 0) References

- **Dependencies:** [other epic IDs this epic depends on, e.g. "E-001 (auth must exist)"]
- **Related Docs:** [links to Spec Funcional, TDD, Figma, ADRs]
```

---

## 1) Objective

One paragraph: what problem it solves and what business outcome it generates. Audience: non-technical stakeholders.

```markdown
## 1) Objective

When this epic is delivered, [users/system] will be able to [capability]. This eliminates [current pain point] and enables [business outcome].
```

---

## 2) Scope

```markdown
## 2) Scope

**In scope:** [specific capabilities delivered]
**Out of scope:** [explicitly excluded adjacent features]
**Assumptions:** A1. [condition that must be true] / A2. [another condition]
```

---

## 3) Happy Path

Simple ASCII flow — maximum 8 steps.

```markdown
## 3) Happy Path

[Step 1] → [Step 2] → [Step 3] → [Step 4] → [Step 5]
```

Or numbered:
```markdown
1. User does X
2. System does Y
3. Result Z is produced
```

---

## 4) KPIs & Measurement

### Product Metrics (max 3)

Quantifiable KPIs tied to a real data source (PostHog, Datadog, DB query).

```markdown
### Product Metrics (max 3)

| KPI | Target | Source |
|-----|--------|--------|
| [metric name] | [e.g. >= 95%] | [PostHog event / Datadog / DB] |
```

### Logs / Events to Persist (max 5)

Key events to store and why.

```markdown
### Logs / Events to Persist (max 5)

| Event | What to store | Why |
|-------|---------------|-----|
| `event_name` | [fields: user_id, amount, ...] | [audit / debugging / analytics] |
```

---

## 5) User Stories

3–8 stories per epic. Each story is brief — detail goes in skill-4 (story generator).

### Story Format

```markdown
### HU-<epic>.<story> — <Story Title>

As a [role] I want [action] so that [benefit].

- [ ] Given [precondition], When [action], Then [expected result].
- [ ] Given [precondition], When [action], Then [expected result].
- [ ] Given [precondition], When [action], Then [expected result].
```

**Rules:**
- Max 3 acceptance criteria per story
- No technical notes per story (those go in skill-4)
- No telemetry per story (goes in skill-4)
- No per-story dependencies

### Example

```markdown
### HU-001.01 — Trigger reconciliation via cron job

As a system operator I want reconciliation to run automatically at 02:00 UTC so that merchants' records are reconciled without manual intervention.

- [ ] Given the cron is scheduled, When 02:00 UTC arrives, Then a reconciliation run is created for each merchant with status "pending".
- [ ] Given a merchant has a run "in_progress", When the cron fires, Then a new run is queued, not started.
- [ ] Given no merchants have connected processors, When the cron fires, Then no runs are created and a warning is logged.
```
