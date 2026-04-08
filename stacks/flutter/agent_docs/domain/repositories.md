# Repository Interfaces

Repository interfaces define the **contract** for data access. They live in the domain layer and are implemented by the infrastructure layer. The domain has zero knowledge of how data is actually fetched or persisted.

## Naming

Repository interfaces **must** be prefixed with `I` and suffixed with `Repository`:

```dart
// ✅
abstract interface class IUserRepository { ... }
abstract interface class IOrderRepository { ... }

// ❌
abstract class UserRepository { ... }   // missing I prefix, not interface
abstract class UserRepo { ... }          // abbreviation
```

## Declaration

Use `abstract interface class` (not `abstract class`) to enforce that implementors provide all methods without inheriting any behavior:

```dart
abstract interface class IUserRepository {
  // ...
}
```

## Method Return Types

All repository methods that perform I/O **must** return `TaskEither<E, T>` where:
- `E` is the domain error type for this concept.
- `T` is the expected success value.

Synchronous operations that can fail must return `Either<E, T>`.

```dart
import 'package:fpdart/fpdart.dart';
import '../entities/user.dart';
import '../errors/user_error.dart';

abstract interface class IUserRepository {
  /// Fetches the user with the given [id].
  ///
  /// Returns [UserNotFoundError] if no user exists with that id.
  TaskEither<UserError, User> getUser(String id);

  /// Returns a list of all users.
  TaskEither<UserError, List<User>> getUsers();

  /// Persists [user] changes. Returns [Unit] on success.
  TaskEither<UserError, Unit> updateUser(User user);

  /// Deletes the user with the given [id].
  TaskEither<UserError, Unit> deleteUser(String id);
}
```

## Streams

When the repository needs to expose a real-time data stream, declare it as a getter returning `Stream<T>`:

```dart
abstract interface class IUserRepository {
  /// Emits the current authentication status whenever it changes.
  Stream<bool> get isAuthenticatedStream;

  /// Emits the currently signed-in user, or null if signed out.
  Stream<User?> get currentUserStream;
}
```

## Attributes

Repository interfaces **may** expose read-only attributes as getters. These represent cached or in-memory state that is always available synchronously:

```dart
abstract interface class ISessionRepository {
  /// The currently cached user, or null if no session is active.
  User? get cachedUser;
}
```

## Documentation

Every method and getter **must** be documented with:
- A one-line description of what the method does.
- `@param` / named `[paramName]` references for each parameter.
- The success type and what it represents.
- Which error(s) may be returned.

```dart
abstract interface class IOrderRepository {
  /// Creates a new order for the given [userId] with the provided [items].
  ///
  /// Returns the created [Order] with its server-assigned [Order.id].
  ///
  /// Errors:
  /// - [OrderError.insufficientStock] if any item is out of stock.
  /// - [OrderNetworkError.serverError] for unrecoverable server failures.
  TaskEither<OrderError, Order> createOrder({
    required String userId,
    required List<OrderItem> items,
  });
}
```

## Complete Example

```dart
// domain/repositories/i_user_repository.dart

import 'package:fpdart/fpdart.dart';
import '../entities/user.dart';
import '../errors/user_error.dart';

abstract interface class IUserRepository {
  /// Returns the currently authenticated user.
  ///
  /// Errors:
  /// - [UserNetworkError.unauthorized] if the session has expired.
  TaskEither<UserError, User> getCurrentUser();

  /// Fetches the user with the given [id].
  ///
  /// Errors:
  /// - [UserNotFoundError] if no user exists with that [id].
  /// - [UserNetworkError.serverError] for unrecoverable server failures.
  TaskEither<UserError, User> getUserById(String id);

  /// Updates the [user]'s profile information.
  ///
  /// Returns [Unit] on success.
  ///
  /// Errors:
  /// - [UserValidationError] if the data fails server-side validation.
  /// - [UserNetworkError.unauthorized] if the session has expired.
  TaskEither<UserError, Unit> updateUser(User user);

  /// Emits the latest [User] whenever the profile is updated remotely.
  Stream<User?> get currentUserStream;
}
```
