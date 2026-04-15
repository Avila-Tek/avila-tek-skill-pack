---
stack: nextjs
label: "Next.js + React Query"
type: frontend
detection:
  package_json_deps:
    - "next"
---

# Stack: Next.js + React Query

## Summary

Next.js frontend with React Query for server state, `@repo/ui` design system, and feature-driven Clean Architecture. Contracts come from `packages/schemas/` (shared Zod schemas with the NestJS backend).

## Architecture Overview

```
src/
  app/                  ← Next.js App Router (thin composition — wiring only)
  context/              ← Client-side React context providers
  features/             ← Product features (vertical slices)
    <feature>/
      ui/
        pages/*.tsx       ← route-level screens
        layouts/*.tsx     ← shared layout wrappers
        widgets/*.tsx     ← self-contained sections (own loading/error/empty)
        components/*.tsx  ← reusable presentational pieces
        context/*.tsx     ← feature-scoped React context
        hooks/*.ts        ← custom hooks for this feature's UI
      application/
        queries/use*.query.ts       ← React Query reads
        mutations/use*.mutation.ts  ← React Query writes
        useCases/*.useCase.ts       ← flow orchestration
      domain/             ← Types, value objects, business rules (no React)
      infrastructure/     ← API clients, mappers, adapters
  shared/               ← Cross-cutting UI + utilities
  lib/                  ← App-level helpers (query client, env, config)
```

## Key Patterns

- **`@repo/ui` only** — no raw HTML elements with inline styles; use design system tokens
- **Zod schemas from `packages/schemas/`** — never hand-write type interfaces shared with backend
- **React Query for all server state** — no `useEffect` + `fetch`; no `useState` for async data
- **No logic in pages** — `app/` files wire routes to feature pages; zero business logic there
- **Layer boundaries are strict** — UI can call application; application can call domain + infra; never reverse
- **Server Components by default** — opt into `'use client'` only when needed (interactivity, hooks)
- **Accessibility first** — semantic HTML, ARIA where needed, keyboard nav, contrast ratios (WCAG AA)

## Standards Documents

Full standards live in `stacks/nextjs/agent_docs/`:

| File | Content |
|------|---------|
| `architecture.md` | Clean Architecture layers, folder structure, import rules |
| `code-standard.md` | Naming, component patterns, forbidden patterns |
| `component-structure.md` | Component anatomy, prop conventions, composition rules |
| `data-fetching.md` | React Query patterns, query keys, stale time, optimistic updates |
| `error-handling.md` | Error boundaries, query error states, toast notifications |
| `feature-flags.md` | How feature flags are declared and consumed |
| `forms.md` | React Hook Form + Zod validation patterns |
| `good-practices.md` | General frontend best practices for this repo |
| `import-boundaries.md` | Allowed cross-layer import directions |
| `observability.md` | Frontend logging, error tracking |
| `performance.md` | Core Web Vitals targets, lazy loading, bundle splitting |
| `routing.md` | App Router conventions, route groups, layouts |
| `shadcn.md` | Using and extending shadcn/ui components |
| `styling.md` | Tailwind usage, design tokens, responsive utilities |
| `testing.md` | Vitest, React Testing Library, testing server components |
| `authentication.md` | Auth flow, protected routes, session management |
| `layers/` | Deep-dives per layer: application, domain, infrastructure, server, ui |

## Required Reading by Task Type

After reading this file, Read the `agent_docs` files listed for your task type. Do not proceed until those Reads are complete.

| Task type | Read these files |
|-----------|-----------------|
| Any implementation | `agent_docs/architecture.md`, `agent_docs/code-standard.md`, `agent_docs/import-boundaries.md` |
| UI / components | Any implementation + `agent_docs/component-structure.md`, `agent_docs/styling.md`, `agent_docs/good-practices.md` |
| Data fetching | Any implementation + `agent_docs/data-fetching.md` |
| Forms | Any implementation + `agent_docs/forms.md` |
| Routing / pages | Any implementation + `agent_docs/routing.md` |
| Auth | Any implementation + `agent_docs/authentication.md` |
| Performance | Any implementation + `agent_docs/performance.md` |
| Testing | `agent_docs/testing.md` |
| Code review | `agent_docs/architecture.md`, `agent_docs/code-standard.md`, `agent_docs/import-boundaries.md` |
| Observability | Any implementation + `agent_docs/observability.md` |

## Specialized Skills

When working in a Next.js project, use these skills for stack-specific tasks:

| Task | Skill | Invoke when |
|------|-------|-------------|
| Building UI components, pages, layouts, or any user-facing interface | `frontend-ui-engineering` | "build this UI", "this component", "frontend patterns", "state management", or any time React/Next.js code is being written |
| Code review of a Next.js change | `code-review-and-quality` | Before merging — runs the Next.js Red Flags list as axis 6 |

The `frontend-ui-engineering` skill contains the full Next.js-specific patterns: feature-driven Clean Architecture, React Query, layer boundaries, `@repo/ui` design system, accessibility, and performance. It cross-references `stacks/nextjs/agent_docs/` for detailed standards.

## Testing Conventions

- Unit/integration: Vitest + React Testing Library
- Tests co-located: `*.test.tsx` next to component
- No testing implementation details — test behavior
- Coverage gate: 80% statements minimum
- E2E: Playwright in `e2e/` (separate from unit tests)

## Red Flags

- `useEffect` for data fetching (use React Query)
- Business logic in `app/` route files
- Importing from a higher layer (infra importing from ui)
- Raw `fetch()` calls outside `infrastructure/` adapters
- Inline styles or color values not from the design token
- Missing loading and error states in widgets
- `any` type without comment

## Verification Checklist

- [ ] `pnpm build` passes with no type errors
- [ ] `pnpm test` passes, coverage ≥ 80%
- [ ] No ESLint errors (`pnpm lint`)
- [ ] New pages have loading.tsx and error.tsx siblings
- [ ] All interactive elements are keyboard-accessible
- [ ] No raw `fetch()` outside `infrastructure/` layer
- [ ] Bundle size delta reviewed (`pnpm analyze`)
