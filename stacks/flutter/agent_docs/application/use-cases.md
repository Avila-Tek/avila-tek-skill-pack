# Use Cases

A use case encapsulates **a single business operation** from the application's perspective. It is the only construct in the application layer and is the entry point that Blocs use to trigger business logic.

## Naming

Use case class names **must** begin with an action verb describing the operation, followed by a subject, and end with the `UseCase` suffix:

```dart
// ✅
class SignInUseCase { ... }
class GetUserUseCase { ... }
class UpdateUserProfileUseCase { ... }
class CreateOrderUseCase { ... }

// ❌
class LoginUseCase { ... }    // vague verb
class UserUseCase { ... }     // no verb
class GetUser { ... }         // missing UseCase suffix
```

## Constructor

Use cases receive their dependencies (domain repository interfaces) via the constructor using named, required parameters. Store dependencies as `final` private fields:

```dart
class SignInUseCase {
  SignInUseCase({
    required IUserRepository userRepository,
    required ISessionRepository sessionRepository,
  })  : _userRepository = userRepository,
        _sessionRepository = sessionRepository;

  final IUserRepository _userRepository;
  final ISessionRepository _sessionRepository;
}
```

> Use cases **must** depend on repository **interfaces** (`IUserRepository`), never on implementations (`UserRepository`).

## Execute Method

Each use case exposes **one public method** that performs the operation. Name it `execute` or use a descriptive verb. The method must return `Either<E, T>` or `TaskEither<E, T>`:

```dart
TaskEither<AuthError, User> execute({
  required String email,
  required String password,
});
```

### Naming the Execute Method

For simple use cases with a clear action, `execute` is sufficient. For use cases with multiple closely related sub-operations, a descriptive name is preferred:

```dart
// Simple: single action
class SignInUseCase {
  TaskEither<AuthError, User> execute({...}) { ... }
}

// Descriptive when context makes "execute" ambiguous
class OrderUseCase {
  TaskEither<OrderError, Order> create({...}) { ... }
  TaskEither<OrderError, Unit> cancel(String orderId) { ... }
}
```

> Avoid putting multiple unrelated operations in a single use case. If a use case grows to cover multiple responsibilities, split it.

## Return Types

| Operation type | Return type |
|---|---|
| Async, can fail | `TaskEither<E, T>` |
| Async, infallible | `Task<T>` |
| Sync, can fail | `Either<E, T>` |
| Sync, infallible | `T` directly |

The error type `E` **must** be a domain error defined in the domain layer. Use cases must **not** throw exceptions — all failures are expressed in the return type.

## Streams

If a use case needs to expose a stream of values, declare the stream as a getter that delegates to the repository:

```dart
class WatchCurrentUserUseCase {
  WatchCurrentUserUseCase({required IUserRepository userRepository})
      : _userRepository = userRepository;

  final IUserRepository _userRepository;

  /// Emits the current user whenever their profile changes.
  Stream<User?> get userStream => _userRepository.currentUserStream;
}
```

## Documentation

The class and its public method **must** be documented. Document parameters using `[paramName]` references and describe the success type and potential errors:

```dart
/// Signs the user into the application using email and password.
///
/// Returns the authenticated [User] on success.
///
/// Errors:
/// - [AuthError.invalidCredentials] if the email/password pair is incorrect.
/// - [AuthError.userNotFound] if no account exists for the given email.
/// - [AuthNetworkError.connectionFailed] if the device is offline.
class SignInUseCase {
  SignInUseCase({required IAuthRepository authRepository})
      : _authRepository = authRepository;

  final IAuthRepository _authRepository;

  /// Authenticates the user with [email] and [password].
  TaskEither<AuthError, User> execute({
    required String email,
    required String password,
  }) {
    return _authRepository.signIn(email: email, password: password);
  }
}
```

## Complete Examples

### Simple delegation

When the use case delegates directly to a repository method:

```dart
// application/use_cases/user/get_user_use_case.dart

class GetUserUseCase {
  GetUserUseCase({required IUserRepository userRepository})
      : _userRepository = userRepository;

  final IUserRepository _userRepository;

  TaskEither<UserError, User> execute(String userId) =>
      _userRepository.getUserById(userId);
}
```

### Orchestration across multiple repositories

When the use case composes multiple domain operations:

```dart
// application/use_cases/orders/create_order_use_case.dart

class CreateOrderUseCase {
  CreateOrderUseCase({
    required IOrderRepository orderRepository,
    required IInventoryRepository inventoryRepository,
  })  : _orderRepository = orderRepository,
        _inventoryRepository = inventoryRepository;

  final IOrderRepository _orderRepository;
  final IInventoryRepository _inventoryRepository;

  /// Creates an order after verifying stock availability for all [items].
  TaskEither<OrderError, Order> execute({
    required String userId,
    required List<OrderItem> items,
  }) =>
      _inventoryRepository
          .checkStock(items)
          .flatMap((_) => _orderRepository.createOrder(
                userId: userId,
                items: items,
              ));
}
```
