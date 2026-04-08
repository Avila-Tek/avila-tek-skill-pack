# Architecture

## Overview

We follow a **four-layer architecture** inspired by Clean Architecture and Domain-Driven Design. The layers are:

1. **Domain** — the heart of the application; contains business rules and is completely framework-agnostic.
2. **Application** — orchestrates domain logic; contains use cases.
3. **Infrastructure** — implements the domain's repository contracts; talks to external systems (APIs, databases, local storage).
4. **Presentation** — Flutter UI, routing, and Bloc-based state management.

## Layer Diagram

```
┌─────────────────────────────────────┐
│           Presentation              │  Flutter widgets, Blocs
│  (depends on: application, domain)  │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│           Application               │  Use Cases
│       (depends on: domain)          │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│             Domain                  │  Entities, Errors, Repository interfaces
│         (no dependencies)           │
└──────────────▲──────────────────────┘
               │
┌──────────────┴──────────────────────┐
│          Infrastructure             │  Repository impls, Data sources, DTOs
│       (depends on: domain)          │
└─────────────────────────────────────┘
```

> **The Dependency Rule:** source code dependencies can only point inward. Nothing in the domain knows about the application, infrastructure, or presentation layers.

## Key DDD Concepts

### Domain
A **domain** is a sphere of knowledge and activity. In practice, it maps to a feature or business concept (e.g., `user`, `orders`, `notifications`). Each domain:

- Defines its own **entities** and **enums**.
- Defines its own **errors** (`UserError`, `OrderError`, etc.).
- Exposes **repository interfaces** that the infrastructure layer must implement.
- May define **validators** for field-level business rules.

### Bounded Context
A bounded context is the boundary within which a domain model applies. Terms and concepts may mean different things in different contexts. In our codebase, each top-level domain folder (e.g., `user/`, `orders/`) represents its own bounded context.

### Entity
An entity is an object that has a **distinct identity** that persists over time. Entities are defined in the domain layer, are immutable, and have no serialization logic.

### Repository (Interface)
A repository interface is a **contract** defined in the domain layer that describes how to fetch and persist entities. The domain layer has no knowledge of how the repository is implemented.

### Use Case
A use case (also called an interactor) represents a **single business operation**. It lives in the **application layer**, depends only on domain interfaces, and returns a typed result or an error.

## Layer Responsibilities

### Domain
- Define entities, enums, and errors.
- Define repository interfaces (abstract).
- Define field validators.
- **No Flutter imports. No HTTP imports. No JSON serialization.**

### Application
- Implement use cases that orchestrate domain logic.
- Inject domain repository interfaces (not implementations).
- Return `Either<E, T>` or `TaskEither<E, T>` results.
- **No Flutter imports. No direct data-source access.**

### Infrastructure
- Implement repository interfaces from the domain.
- Define DTOs (Data Transfer Objects) for serialization.
- Define data sources (APIs, databases, shared preferences).
- Map infrastructure exceptions to domain errors.
- **No business logic. No UI concerns.**

### Presentation
- Render widgets based on Bloc states.
- Dispatch Bloc events in response to user actions.
- Inject use cases into Blocs (not repositories directly).
- **No direct infrastructure access. No raw HTTP calls.**

## Dependency Injection

Dependencies flow inward via constructor injection. A Bloc receives use cases; a use case receives repository interfaces; a repository implementation receives data sources.

```dart
// Composition root (e.g., BlocProvider in Page)
BlocProvider(
  create: (context) => LoginBloc(
    signInUseCase: context.read<SignInUseCase>(),
  ),
)
```

Use a service locator (e.g., `get_it`) or Flutter's `InheritedWidget`/`Provider` at the composition root to wire dependencies. The domain and application layers must never reference the DI container.
