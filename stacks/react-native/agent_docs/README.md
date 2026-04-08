# React Native + Expo Style Guide

Avila Tek builds React Native applications using **Clean Architecture** as the structural backbone. Every decision in this guide — from folder names to hook patterns — serves a single purpose: keeping business logic independent from frameworks, UI libraries, and infrastructure details.

The framework is a delivery mechanism. React Native, Expo, and NativeWind are tools that render your domain model; they do not define it. This guide enforces a strict boundary between what the application *is* (domain and application layers) and how it *delivers* that to users (infrastructure and presentation layers). Engineers who internalize this distinction write code that is testable in isolation, portable across platforms, and maintainable across years.

---

## Architecture at a Glance

| Layer | Responsibility | Allowed Dependencies |
|---|---|---|
| **Domain** | Entities, repository interfaces, domain errors, validators | None (pure TypeScript) |
| **Application** | Use cases, orchestration | Domain only |
| **Infrastructure** | Data sources, repository implementations, DTOs | Domain, external libraries |
| **Presentation** | Screens, components, hooks, navigation | Application, Domain (types), UI libraries |

---

## Library Stack

| Concern | Library |
|---|---|
| Framework | React Native + Expo |
| Navigation | Expo Router |
| Server state | @tanstack/react-query |
| UI state | Zustand |
| Validation | Zod |
| Styling | NativeWind |
| Testing | Vitest |

---

## Table of Contents

### Cross-Cutting Concerns

| # | Guide | Description |
|---|---|---|
| — | [README](./README.md) | This index |
| 01 | [Architecture](./01-architecture.md) | Clean Architecture layers, dependency rule, DI |
| 02 | [Folder Structure](./02-folder-structure.md) | `src/` tree, path aliases, barrel exports |
| 03 | [Naming Conventions](./03-naming-conventions.md) | Files, classes, hooks, schemas, DTOs |
| 04 | [Error Handling](./04-error-handling.md) | Result pattern, discriminated unions, no throws |
| 05 | [State Management](./05-state-management.md) | TanStack Query vs Zustand, decision matrix |
| 06 | [Authentication](./06-authentication.md) | better-auth + Expo, session management, OAuth, deep links |

### Domain Layer

| Guide | Description |
|---|---|
| [Domain Layer](./domain/domain.md) | Overview and constraints |
| [Entities](./domain/entities.md) | Readonly interfaces, factory patterns |
| [Enums](./domain/enums.md) | `const` object pattern, string literal unions |
| [Repository Interfaces](./domain/repositories.md) | Contracts, `I` prefix, Result returns |
| [Validators](./domain/validators.md) | Zod schemas, `.safeParse()`, naming |

### Application Layer

| Guide | Description |
|---|---|
| [Application Layer](./application/application.md) | Overview and constraints |
| [Use Cases](./application/use-cases.md) | `execute()` pattern, naming, orchestration |

### Infrastructure Layer

| Guide | Description |
|---|---|
| [Infrastructure Layer](./infrastructure/infrastructure.md) | Overview and constraints |
| [Data Sources](./infrastructure/data-sources.md) | REST, AsyncStorage, expo-secure-store |
| [DTOs](./infrastructure/dtos.md) | Zod validation, `toEntity()`, `fromEntity()` |
| [Repository Implementations](./infrastructure/repositories.md) | Implementing domain contracts |

### Presentation Layer

| Guide | Description |
|---|---|
| [Presentation Layer](./presentation/presentation.md) | Overview and constraints |
| [Features](./presentation/features/features.md) | Vertical slices, directory structure |
| [Screens](./presentation/features/screens.md) | Expo Router conventions, Screen vs View |
| [Components](./presentation/features/components.md) | Pure/presentational, NativeWind, props |
| [Hooks](./presentation/hooks/hooks.md) | TanStack Query wrappers, use case composition |

---

## Core Principles

**The Dependency Rule** — Source code dependencies must point inward. Domain knows nothing about Application; Application knows nothing about Infrastructure or Presentation.

**Explicit errors, no throws** — All expected failures are modeled as `Result<T, E>` types. `throw` is reserved for truly unrecoverable programmer errors.

**Two-store state model** — Server state lives in TanStack Query. Local UI state lives in Zustand. `useState` is for ephemeral, component-scoped interaction state only.

**Feature-first organization** — Code is organized by domain concept (feature), not by technical layer inside the `presentation/` directory. All screens, components, and hooks for "user profile" live together.

**No framework imports in domain or application** — The domain and application layers are pure TypeScript. They have no `import from 'react'`, no `import from 'expo-*'`, no HTTP clients.
