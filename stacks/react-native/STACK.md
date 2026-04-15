---
stack: react-native
label: "React Native"
type: mobile
detection:
  package_json_deps:
    - "react-native"
---

# Stack: React Native

## Summary

React Native with Expo (bare workflow or managed). Clean Architecture with four layers. TypeScript throughout. TanStack Query for server state, Zustand for UI state. Expo Router for navigation. Axios for HTTP, AsyncStorage for local persistence.

## Architecture Overview

```
src/
  presentation/      ← Screens, Components, Hooks, Expo Router — UI only
    features/
      <feature>/
        screens/     ← Screen components (navigation entry points)
        components/  ← Feature-specific UI components
        hooks/       ← Custom hooks (unwrap Results, expose typed state)
  application/       ← Use Cases — pure TypeScript, orchestration only
  domain/            ← Entities, Repository interfaces, Errors, Validators
  infrastructure/    ← Data Sources (Axios, AsyncStorage), Repo implementations, DTOs
```

## Key Patterns

- **Clean Architecture** — dependency rule: inward only; presentation never imports infrastructure
- **Result<T, E> pattern** — discriminated unions `{ success: true; data: T } | { success: false; error: E }` — never throw for expected failures
- **Two-store state** — TanStack Query for server state, Zustand for UI state; never mix concerns
- **Fat hooks, not fat screens** — business logic lives in custom hooks; screens are thin layout wrappers
- **Use cases own orchestration** — use cases call domain interfaces; never import `axios` or `AsyncStorage` directly
- **Domain errors as discriminated unions** — error types in `SCREAMING_SNAKE_CASE`, one union per domain concept
- **Query key hierarchy** — TanStack Query keys structured as arrays `[entity, scope, id]` for precise invalidation

## Standards Documents

Standards live in `stacks/react-native/agent_docs/`:

| File | Content |
|------|---------|
| `README.md` | Architecture overview — Clean Architecture layers |
| `01-architecture.md` | Hexagonal layers, dependency rules |
| `02-folder-structure.md` | Feature-driven folder layout |
| `03-naming-conventions.md` | File, component, and hook naming rules |
| `04-error-handling.md` | Error boundaries, safe wrappers, user feedback |
| `05-state-management.md` | Local vs server state, React Query patterns |
| `06-authentication.md` | Auth flow, token storage, session management |
| `application/application.md` | Application layer overview |
| `application/use-cases.md` | Use-case patterns and orchestration |
| `domain/domain.md` | Domain layer overview |
| `domain/entities.md` | Entity definitions |
| `domain/enums.md` | Domain enums |
| `domain/repositories.md` | Repository interfaces (ports) |
| `domain/validators.md` | Domain validation rules |
| `infrastructure/infrastructure.md` | Infrastructure layer overview |
| `infrastructure/data-sources.md` | API clients, local DB access |
| `infrastructure/repositories.md` | Repository implementations |
| `infrastructure/dtos.md` | DTO definitions and transforms |
| `presentation/presentation.md` | Presentation layer overview |
| `presentation/features/features.md` | Feature slice structure |
| `presentation/features/screens.md` | Screen components |
| `presentation/features/components.md` | Reusable UI components |
| `presentation/hooks/hooks.md` | Custom hooks patterns |

## Required Reading by Task Type

After reading this file, Read the `agent_docs` files listed for your task type. Do not proceed until those Reads are complete.

| Task type | Read these files |
|-----------|-----------------|
| Any implementation | `agent_docs/01-architecture.md`, `agent_docs/02-folder-structure.md`, `agent_docs/03-naming-conventions.md` |
| Presentation / UI | Any implementation + `agent_docs/presentation/presentation.md`, `agent_docs/presentation/features/features.md`, `agent_docs/presentation/features/components.md` |
| Screens | Any implementation + `agent_docs/presentation/features/screens.md` |
| Custom hooks | Any implementation + `agent_docs/presentation/hooks/hooks.md` |
| State management | Any implementation + `agent_docs/05-state-management.md` |
| Application / Use Cases | Any implementation + `agent_docs/application/application.md`, `agent_docs/application/use-cases.md` |
| Domain model | Any implementation + `agent_docs/domain/domain.md`, `agent_docs/domain/entities.md` |
| Infrastructure | Any implementation + `agent_docs/infrastructure/infrastructure.md`, `agent_docs/infrastructure/data-sources.md` |
| Error handling | Any implementation + `agent_docs/04-error-handling.md` |
| Auth | Any implementation + `agent_docs/06-authentication.md` |
| Code review | `agent_docs/01-architecture.md`, `agent_docs/02-folder-structure.md`, `agent_docs/03-naming-conventions.md` |

## Testing Conventions

- Domain tests: pure TypeScript logic, no mocks
- Application tests: use case inputs/outputs with mocked repository interfaces
- Infrastructure tests: DTO mapping correctness
- Presentation tests: React Testing Library for hooks and components
- Test files co-located: `*.test.ts` / `*.test.tsx` next to source

## Red Flags

- Business logic inside a Screen component (belongs in a hook or use case)
- Domain file importing from `infrastructure/` or third-party HTTP/storage libraries
- `useState` used to hold data fetched from an API (use TanStack Query)
- Zustand store with async actions that call APIs (use TanStack Query mutations)
- `throw new Error(...)` for an expected failure case (use `Result<T, E>`)
- Prop-drilling server data through multiple component levels

## Verification Checklist

- [ ] `npx expo export` (or `npx expo build`) completes without errors
- [ ] `tsc --noEmit` passes with no type errors
- [ ] No domain file imports from `infrastructure/` or third-party HTTP/storage libraries
- [ ] Server state managed by TanStack Query (not `useState` + `useEffect`)
- [ ] Expected errors return `Result` types, not thrown exceptions
- [ ] New screens registered in Expo Router with correct layout
