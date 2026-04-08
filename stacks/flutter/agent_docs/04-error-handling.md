# Error Handling

## Core Principle

Every operation that can fail **must** make that possibility explicit in its return type. We use `fpdart`'s functional types to represent success and failure without relying on exceptions for control flow.

## Domain Errors

Each domain concept defines its **own discrete set of errors**. Errors are declared in `domain/errors/[concept]_error.dart`.

Errors may be:
- **Sealed classes** — when errors need to carry data.
- **Enums** — when errors are simple labels.
- **A mix**: a `sealed class` as the base, with sub-types that are either enums or classes.

```dart
// domain/errors/user_error.dart

/// Errors that can occur in user-related operations.
sealed class UserError {
  const UserError();
}

/// Network-level errors when communicating with the user service.
enum UserNetworkError implements UserError {
  connectionFailed,
  timeout,
  unauthorized,
  serverError,
}

/// The requested user was not found.
class UserNotFoundError extends UserError {
  final String userId;
  const UserNotFoundError(this.userId);
}

/// Validation failed when updating the user.
class UserValidationError extends UserError {
  final String field;
  final String message;
  const UserValidationError({required this.field, required this.message});
}
```

## fpdart Types

We use [fpdart](https://pub.dev/packages/fpdart) for functional error handling. Choose the appropriate type based on whether the operation is synchronous or asynchronous.

### `Either<E, T>`

Use for **synchronous** operations that can fail.

- `Left<E, T>(error)` — the failure path.
- `Right<E, T>(value)` — the success path.

```dart
// E = error type (Left), T = success type (Right)
Either<UserError, User> parseUser(Map<String, dynamic> json) {
  try {
    return right(User.fromJson(json));
  } catch (_) {
    return left(const UserValidationError(field: 'json', message: 'Invalid format'));
  }
}
```

### `TaskEither<E, T>`

Use for **asynchronous** operations that can fail. `TaskEither` is a lazy wrapper around `Future<Either<E, T>>` — call `.run()` to execute it.

```dart
// Repository interface method signature
TaskEither<UserError, User> getUser(String id);

// Usage in a use case
final result = await getUserRepository.getUser(id).run();
result.fold(
  (error) => handleError(error),
  (user) => handleSuccess(user),
);
```

### `Task<T>`

Use for **asynchronous** operations that **cannot** fail (i.e., errors are handled internally or the operation is infallible).

```dart
Task<void> logEvent(String name) =>
    Task(() async => analytics.log(name));
```

### `IO<T>`

Use for **synchronous** operations with **side effects** that cannot fail.

```dart
IO<DateTime> getCurrentTime() => IO(() => DateTime.now());
```

### `IOEither<E, T>`

Use for **synchronous** operations with **side effects** that can fail.

```dart
IOEither<CacheError, User> readFromCache(String key) =>
    IOEither(() => Either.tryCatch(
      () => cache.read(key),
      (_, __) => const CacheError.notFound(),
    ));
```

## Summary: When to Use Which

| Scenario | Type |
|---|---|
| Sync operation, can fail | `Either<E, T>` |
| Async operation, can fail | `TaskEither<E, T>` |
| Async operation, cannot fail | `Task<T>` |
| Sync side effect, cannot fail | `IO<T>` |
| Sync side effect, can fail | `IOEither<E, T>` |

In practice, **most repository and use case methods return `TaskEither<E, T>`** because they involve async I/O.

## Consuming Results

### `fold` / `match`

Use `.fold` to handle both branches:

```dart
final result = await signInUseCase.execute(email, password).run();

result.fold(
  (error) => emit(state.copyWith(status: .failure, error: error)),
  (user)  => emit(state.copyWith(status: .success, user: user)),
);
```

### `getOrElse`

Use when you have a sensible default for the failure case:

```dart
final user = result.getOrElse((_) => User.empty());
```

### `map` / `flatMap`

Use to transform or chain operations without breaking out of the functional context:

```dart
TaskEither<UserError, String> getUserName(String id) =>
    getUserRepository
        .getUser(id)
        .map((user) => user.fullName);
```

## Pattern Matching on Errors

Because domain errors use `sealed class` or are `enum` types, exhaustive pattern matching is enforced by the compiler:

```dart
result.fold(
  (error) => switch (error) {
    UserNotFoundError(:final userId) =>
        showSnackBar('User $userId not found'),
    UserNetworkError.unauthorized =>
        navigateTo(LoginPage.path),
    UserNetworkError.timeout ||
    UserNetworkError.connectionFailed =>
        showSnackBar('Network error. Please retry.'),
    UserNetworkError.serverError =>
        showSnackBar('Server error.'),
    UserValidationError(:final message) =>
        showSnackBar(message),
  },
  (user) => ...,
);
```

## Infrastructure: Exception to Error Mapping

The infrastructure layer is responsible for **catching exceptions** and mapping them to domain errors. Neither the application layer nor the presentation layer should handle raw exceptions from external sources.

```dart
// infrastructure/repositories/user_repository.dart
@override
TaskEither<UserError, User> getUser(String id) =>
    TaskEither(() async {
      try {
        final dto = await _userApi.getUser(id);
        return right(dto.toEntity());
      } on NotFoundException {
        return left(UserNotFoundError(id));
      } on UnauthorizedException {
        return left(UserNetworkError.unauthorized);
      } catch (_) {
        return left(UserNetworkError.serverError);
      }
    });
```
