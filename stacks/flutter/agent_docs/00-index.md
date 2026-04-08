# Flutter Development Guidelines

This document is the entry point for the Flutter coding guidelines used across our projects. These rules exist to ensure **consistency**, **maintainability**, and **scalability** in every codebase.

## Philosophy

These guidelines are grounded in:

- **Domain-Driven Design (DDD)** — model software around real business concepts.
- **Clean Architecture** — separate concerns into layers with strict dependency rules.
- **Explicit over implicit** — code should be readable without needing to trace through layers of abstraction.

## Architecture at a Glance

We follow a **four-layer architecture**:

| Layer            | Responsibility                                              |
| ---------------- | ----------------------------------------------------------- |
| `domain`         | Core business rules, entities, errors, repository contracts |
| `application`    | Orchestration of domain logic (use cases)                   |
| `infrastructure` | External world: APIs, databases, local storage              |
| `presentation`   | UI, state management (Bloc), routing                        |

See [Architecture](./01-architecture.md) for the full explanation and dependency rules.

## Table of Contents

### Cross-Cutting Concerns
- [Architecture](./01-architecture.md) — Layer diagram, DDD concepts, dependency rules
- [Folder Structure](./02-folder-structure.md) — Project layout and file organization
- [Naming Conventions](./03-naming-conventions.md) — Files, classes, variables, suffixes
- [Error Handling](./04-error-handling.md) — `Either`, `TaskEither`, domain errors
- [State Management](./05-state-management.md) — Bloc overview and usage rules
- [Testing](./06-testing.md) — Domain, BLoC, infrastructure, widget, and integration tests
- [Observability](./07-observability.md) — Error categorization, Sentry integration, Loki logging
- [CI/CD](./08-ci-cd.md) — Codemagic setup, Firebase App Distribution, TestFlight
- [Firebase](./09-firebase.md) — Push notifications, analytics, remote config, in-app messaging
- [Deep Links](./10-deep-links.md) — Android/iOS configuration, DeepLinkBloc, testing
- [Practical Patterns](./11-practical-patterns.md) — HTTP headers, user session, token refresh, quick actions

### Domain Layer
- [Overview](./domain/domain.md)
- [Entities](./domain/entities.md)
- [Enums](./domain/enums.md)
- [Repository Interfaces](./domain/repositories.md)
- [Validators](./domain/validators.md)

### Application Layer
- [Overview](./application/application.md)
- [Use Cases](./application/use-cases.md)

### Infrastructure Layer
- [Overview](./infrastructure/infrastructure.md)
- [Data Sources](./infrastructure/data-sources.md)
- [DTOs](./infrastructure/dtos.md)
- [Repository Implementations](./infrastructure/repositories.md)

### Presentation Layer
- [Overview](./presentation/presentation.md)
- **Features**
  - [Feature Structure](./presentation/features/features.md)
  - [Pages](./presentation/features/pages.md)
  - [Views](./presentation/features/view.md)
  - [Bodies](./presentation/features/body.md)
- **Blocs**
  - [Bloc Overview](./presentation/blocs/blocs.md)
  - [Events](./presentation/blocs/events.md)
  - [States](./presentation/blocs/states.md)
