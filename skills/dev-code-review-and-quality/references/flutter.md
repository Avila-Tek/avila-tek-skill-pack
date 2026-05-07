# Flutter — Code Review Reference

## Architecture Red Flags

These are blocking findings in a code review:

- Domain layer importing infrastructure packages (`dio`, `hive`, `shared_preferences`, any `flutter_*` package) — domain must be pure Dart with no external dependencies
- BLoC directly making HTTP calls or importing a data source — BLoC depends on use cases, not on infrastructure
- Repository implementation in the domain layer — repositories are defined as abstractions in domain, implemented in infrastructure
- `SharedPreferences` used for auth tokens or sensitive data — use `flutter_secure_storage` instead
- `TaskEither` missing on async use cases that can fail — all I/O that can fail must return `TaskEither<Failure, T>`
- Missing loading state in a BLoC — every async event must emit at least `loading → success/failure`
- Page creating state directly (not via BLoC or provider) — Pages create context; Views consume state

## Layer Boundaries

```
Presentation (BLoC + Widgets)
      ↓ depends on
Application (Use Cases)
      ↓ depends on
Domain (Entities, Repositories interface, Failures)
      ↑ implements
Infrastructure (Repository impls, DTOs, HTTP clients)
```

**Pages create, Views consume.** A `Page` sets up `BlocProvider` and `RepositoryProvider`. A `View`/`Body` widget reads state from the bloc with `BlocBuilder` or `BlocListener`. Views never call `context.read<XBloc>().add(...)` — that belongs in the parent `Page` or in a handler.

## BLoC Patterns

- Every event has a corresponding `on<Event>` handler in the BLoC constructor
- States are `sealed` classes — all possible states are exhaustive and compile-time checked
- `emit()` called with loading state before async work begins
- Failures use sealed `Failure` classes — never raw exceptions bubbled to the UI
- `blocTest` tests must verify the full state sequence including loading

## Error Handling

Use `TaskEither` from `fpdart` for operations that can fail. Never throw from infrastructure:

```dart
// ✅ Use case returns TaskEither
Future<Either<Failure, User>> execute(String email, String password) =>
    _authRepo.signIn(email, password).run();

// ❌ Throwing exceptions that cross layer boundaries
Future<User> execute(String email, String password) async {
    return await _authRepo.signIn(email, password); // throws on failure
}
```

Repositories map infrastructure exceptions to sealed `Failure` types — HTTP exceptions, `DioException`, `FormatException` never reach the application layer.

## State Management

`UserBloc` at the root tree is the single source of truth for authentication state. Any BLoC that needs the current user reads it from the `UserBloc` state — never re-fetches from storage independently.

Token management is centralized in `HttpHeadersInjector` — never scattered across individual HTTP calls.

## Code Standards

- No `print()` or `debugPrint()` in production code — use a structured logger
- No `dynamic` type without a comment explaining why
- `const` constructors used wherever possible
- Widget `Key` parameters provided on list items and test-accessible widgets
- `dispose()` called on controllers, streams, and subscriptions

## Verification Checklist

- [ ] `flutter analyze` — no analyzer warnings or errors
- [ ] `flutter test` — all tests pass
- [ ] No infrastructure imports in `domain/` or `application/` layers
- [ ] No direct HTTP calls inside a BLoC
- [ ] Sensitive data stored in `flutter_secure_storage`, not `SharedPreferences`
- [ ] All async use cases return `TaskEither<Failure, T>`
- [ ] All BLoC async events emit loading state before async work
- [ ] Pages create context; Views consume it
- [ ] States are `sealed` classes
- [ ] No `print()` in changed files
- [ ] Release builds use `--obfuscate --split-debug-info`
