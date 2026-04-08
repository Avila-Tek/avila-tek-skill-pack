# Repository Implementations

Repository implementations live in the infrastructure layer and fulfill the contracts defined by the domain's repository interfaces. They are responsible for fetching data from data sources, converting DTOs to entities, and **mapping all infrastructure exceptions to domain errors**.

## Naming

Repository implementations use the same base name as the interface **without** the `I` prefix:

```dart
// Domain interface
abstract interface class IUserRepository { ... }

// Infrastructure implementation
class UserRepository implements IUserRepository { ... }
```

## Constructor and Dependency Injection

The repository receives its data sources as named, required constructor parameters. Dependencies are stored as `final` private fields:

```dart
class UserRepository implements IUserRepository {
  UserRepository({
    required IUserApi userApi,
  }) : _userApi = userApi;

  final IUserApi _userApi;
}
```

> Repositories depend on **data source interfaces** (`IUserApi`), not on concrete implementations.

## Return Types

Repository implementations fulfill the `TaskEither<E, T>` (or `Either<E, T>`) contract defined by the domain interface. The repository is responsible for:

1. Calling the data source.
2. Converting the raw result to a DTO.
3. Converting the DTO to a domain entity.
4. Catching exceptions and returning the appropriate domain error as `Left`.

```dart
@override
TaskEither<UserError, User> getUserById(String id) =>
    TaskEither(() async {
      try {
        final map = await _userApi.getUser(id);
        return right(UserDto.fromMap(map).toEntity());
      } on NotFoundException {
        return left(UserNotFoundError(id));
      } on UnauthorizedException {
        return left(UserNetworkError.unauthorized);
      } catch (_) {
        return left(UserNetworkError.serverError);
      }
    });
```

## Exception to Error Mapping

Every exception thrown by a data source **must** be caught in the repository and converted to a domain error. Do not let raw exceptions propagate to the application or presentation layers.

Map exceptions to the most specific domain error available:

```dart
on NotFoundException  => left(UserNotFoundError(id))
on UnauthorizedException => left(UserNetworkError.unauthorized)
on TimeoutException   => left(UserNetworkError.timeout)
catch (_)             => left(UserNetworkError.serverError)
```

## Streams

When the domain interface declares a `Stream<T>`, the implementation wraps a `StreamController` (or `BehaviorSubject` from `rxdart`) and exposes the stream as a getter:

```dart
class UserRepository implements IUserRepository {
  UserRepository({required IUserApi userApi}) : _userApi = userApi;

  final IUserApi _userApi;
  final _currentUserController = BehaviorSubject<User?>();

  @override
  Stream<User?> get currentUserStream => _currentUserController.stream;

  // Call _currentUserController.add(...) whenever the user changes.

  void dispose() => _currentUserController.close();
}
```

## Public Attributes

If the domain interface exposes a getter attribute (e.g., a cached value), implement it by wrapping a private field:

```dart
User? _cachedUser;

@override
User? get cachedUser => _cachedUser;
```

## Complete Example

```dart
// infrastructure/repositories/user_repository.dart

import 'package:fpdart/fpdart.dart';
import '../../domain/entities/user.dart';
import '../../domain/errors/user_error.dart';
import '../../domain/repositories/i_user_repository.dart';
import '../data_sources/user/i_user_api.dart';
import '../dtos/user_dto.dart';

class UserRepository implements IUserRepository {
  UserRepository({required IUserApi userApi}) : _userApi = userApi;

  final IUserApi _userApi;

  @override
  TaskEither<UserError, User> getCurrentUser() =>
      TaskEither(() async {
        try {
          final map = await _userApi.getCurrentUser();
          return right(UserDto.fromMap(map).toEntity());
        } on UnauthorizedException {
          return left(UserNetworkError.unauthorized);
        } catch (_) {
          return left(UserNetworkError.serverError);
        }
      });

  @override
  TaskEither<UserError, User> getUserById(String id) =>
      TaskEither(() async {
        try {
          final map = await _userApi.getUser(id);
          return right(UserDto.fromMap(map).toEntity());
        } on NotFoundException {
          return left(UserNotFoundError(id));
        } on UnauthorizedException {
          return left(UserNetworkError.unauthorized);
        } catch (_) {
          return left(UserNetworkError.serverError);
        }
      });

  @override
  TaskEither<UserError, Unit> updateUser(User user) =>
      TaskEither(() async {
        try {
          await _userApi.updateUser(user.id, UserDto.fromEntity(user).toMap());
          return right(unit);
        } on UnauthorizedException {
          return left(UserNetworkError.unauthorized);
        } on ValidationException catch (e) {
          return left(UserValidationError(field: e.field, message: e.message));
        } catch (_) {
          return left(UserNetworkError.serverError);
        }
      });
}
```
