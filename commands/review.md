---
description: Conduct a five-axis code review — correctness, readability, architecture, security, performance
---

## Chaining Rules

Apply automatically — no need to ask the user:

| Type | Skill | When |
|------|-------|------|
| Conditional | `dev-security-and-hardening` | Review finds issues related to auth, authz, user input, secrets, or external APIs |
| Conditional | `dev-performance-optimization` | Review finds N+1 queries, missing indexes, large bundle size, or Core Web Vitals regressions |

Invoke the agent-skills:code-review-and-quality skill.

Review the current changes (staged or recent commits) across all five axes:

1. **Correctness** — Does it match the spec? Edge cases handled? Tests adequate?
2. **Readability** — Clear names? Straightforward logic? Well-organized?
3. **Architecture** — Follows existing patterns? Clean boundaries? Right abstraction level?
4. **Security** — Input validated? Secrets safe? Auth checked? (Use security-and-hardening skill)
5. **Performance** — No N+1 queries? No unbounded ops? (Use performance-optimization skill)

Categorize findings as Critical, Important, or Suggestion.
Output a structured review with specific file:line references and fix recommendations.
