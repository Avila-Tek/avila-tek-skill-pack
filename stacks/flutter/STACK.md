---
stack: flutter
label: "Flutter"
type: mobile
detection:
  files:
    - "pubspec.yaml"
  content_pattern: "flutter:"
---

# Stack: Flutter

## Summary

Flutter mobile (iOS + Android). Clean Architecture with four layers. BLoC / Cubit for state management (`flutter_bloc`). `fpdart` for functional error handling (`Either`, `TaskEither`). `mocktail` + `bloc_test` for testing. Firebase optional depending on project.

## Architecture Overview

```
lib/
  features/
    <feature>/
      domain/         ← Entities, Repository interfaces, Validators (pure Dart)
      application/    ← Use Cases — orchestration, TaskEither<Failure, T>
      infrastructure/ ← Repository implementations, Data Sources, DTOs
      presentation/   ← Pages, Views, Blocs, Widgets
        pages/        ← Creates BlocProvider, navigation entry points
        views/        ← BlocBuilder/BlocConsumer, layout
        blocs/        ← Events, States, Bloc class
  shared/             ← Cross-feature: theme, routes, DI, common widgets
```

## Key Patterns

- **BLoC unidirectional flow** — UI → Event → Bloc → State → UI; Blocs never talk to each other directly
- **Use cases in Blocs** — Blocs inject use cases (not repositories); repositories are infrastructure
- **TaskEither for async** — all async operations return `TaskEither<Failure, T>`; call `.run()` to execute
- **Sealed class failures** — domain failures are sealed classes; UI pattern-matches exhaustively
- **Pages create, Views consume** — `BlocProvider` only in Page widgets; Views only read via `context.read/watch`
- **Infrastructure translates exceptions** — data sources catch raw exceptions, map to domain `Failure` types
- **Test mirrors lib/** — test file path matches source path; `bloc_test` for Bloc, `mocktail` for mocks
- **No Flutter in domain** — domain has zero imports from `flutter/` packages

## Standards Documents

Standards live in `stacks/flutter/agent_docs/`:

| File | Content |
|------|---------|
| `00-index.md` | Full index — reading order and overview |
| `01-architecture.md` | Clean Architecture layers, dependency rules |
| `02-folder-structure.md` | Feature-driven folder layout |
| `03-naming-conventions.md` | File, class, and widget naming rules |
| `04-error-handling.md` | Either/Failure patterns, user-facing errors |
| `05-state-management.md` | BLoC/Cubit patterns, state types |
| `06-testing.md` | Unit, widget, integration tests; mockito |
| `07-observability.md` | Logging, crash reporting, analytics |
| `08-ci-cd.md` | GitHub Actions, Fastlane, code signing |
| `09-firebase.md` | Firebase integration patterns |
| `10-deep-links.md` | Deep link handling, routing |
| `11-practical-patterns.md` | Reusable patterns and anti-patterns |
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
| `presentation/features/pages.md` | Page widgets |
| `presentation/features/view.md` | View widgets |
| `presentation/features/body.md` | Body widget patterns |
| `presentation/blocs/blocs.md` | BLoC definitions |
| `presentation/blocs/states.md` | State definitions |
| `presentation/blocs/events.md` | Event definitions |

## Testing Conventions

- Domain tests: pure Dart, zero mocks — test entities and validators directly
- Application tests: `blocTest<MyBloc, MyState>()` with mocked use cases (`mocktail`)
- Infrastructure tests: DTO mapping and repository error translation
- Presentation tests: `testWidgets` with `MockBloc` — test rendering, not business logic
- Integration tests: critical user flows end-to-end (sparingly)

## Red Flags

- Bloc calling a repository directly (should call a use case)
- `throw Exception(...)` for an expected failure (use `Left(Failure(...))`)
- Business logic inside a Widget's `build()` method
- Flutter package imports inside the `domain/` layer
- `TaskEither` without `.run()` — forgetting to execute the lazy computation
- Cross-Bloc dependency via direct reference (use `BlocListener` for cross-Bloc communication)

## Verification Checklist

- [ ] `flutter build apk --debug` (or `--release`) passes without errors
- [ ] `flutter analyze` passes with no issues
- [ ] `flutter test` passes; all BLoC state transitions covered
- [ ] No `flutter/` package imports in `domain/` layer
- [ ] All async fallible operations return `TaskEither` (not raw `Future<T>`)
- [ ] `BlocProvider` only in Page widgets (not in View or Body)
