# Naming Conventions

## General Dart Rules

| Kind | Convention | Example |
|---|---|---|
| Files | `snake_case` | `user_repository.dart` |
| Classes / Enums / Typedefs | `PascalCase` | `UserRepository` |
| Variables / Parameters / Methods | `camelCase` | `currentUser`, `getUserById()` |
| Constants | `camelCase` | `defaultTimeout` |
| Private members | `_camelCase` | `_httpClient` |

## Layer-Specific Suffixes

Each construct has a required suffix that signals its role at a glance:

| Construct | Suffix | Example |
|---|---|---|
| Domain entity | *(none)* | `User`, `Order` |
| Domain error | `Error` | `UserError`, `OrderError` |
| Repository interface | `I` prefix + `Repository` | `IUserRepository` |
| Repository implementation | `Repository` | `UserRepository` |
| Use case | `UseCase` | `SignInUseCase`, `GetOrdersUseCase` |
| DTO | `Dto` | `UserDto`, `OrderDto` |
| Data source interface | `I` prefix + `Api` / `Service` / `DataSource` | `IUserApi`, `IAnalyticsService` |
| Data source implementation | Protocol prefix + base name | `UserApiRest`, `UserApiGraphQL` |
| Bloc | `Bloc` | `LoginBloc` |
| Bloc event base | `Event` | `LoginEvent` |
| Bloc state base | `State` | `LoginState` |
| Page widget | `Page` | `LoginPage` |
| View widget | `View` | `LoginView` |
| Body widget | `Body` | `LoginBody` |
| Field validator | `Field` | `EmailField`, `PasswordField` |
| Validation failure | `ValidationFailure` | `EmailValidationFailure` |
| Params object | `Params` | `ContractDetailParams` |
| Status enum (single-class Bloc) | `Status` | `LoginStatus` |

## File Naming

File names **must** match the primary class they contain, converted to `snake_case`:

```
UserRepository → user_repository.dart
IUserRepository → i_user_repository.dart
SignInUseCase → sign_in_use_case.dart
LoginBloc → login_bloc.dart
LoginEvent → login_event.dart
LoginState → login_state.dart
UserDto → user_dto.dart
```

## Enums

Domain enums are named in singular `PascalCase` with **no** `Enum` suffix:

```dart
// ✅
enum UserStatus { active, inactive, unknown }

// ❌
enum UserStatusEnum { active, inactive, unknown }
```

DTO-level enums that mirror a domain enum add a `Dto` suffix to distinguish them:

```dart
enum UserStatusDto { active, inactive, unknown }
```

## Repository Interfaces vs. Implementations

The `I` prefix makes it explicit whether a type is a contract or a concrete implementation:

```dart
// Domain — interface
abstract interface class IUserRepository { ... }

// Infrastructure — implementation
class UserRepository implements IUserRepository { ... }
```

## Use Cases

Use case names must begin with an action verb that describes what the use case does:

```dart
// ✅
class SignInUseCase { ... }
class GetOrdersUseCase { ... }
class UpdateUserProfileUseCase { ... }

// ❌
class LoginUseCase { ... }       // vague
class UserUseCase { ... }        // no verb
```

## Dart Dot Shorthands

Dart supports **static access shorthands** (dot shorthands) when the context type can be inferred. Prefer dot shorthands over fully qualified names whenever the type is unambiguous.

```dart
// ✅ Preferred
UserStatus get defaultStatus => .active;

void setStatus(UserStatus status) { ... }
setStatus(.active);

final UserStatus status = switch (currentStatus) {
  .active => .inactive,
  .inactive => .active,
  .unknown => .unknown,
};

// ❌ Verbose when type is clear
UserStatus get defaultStatus => UserStatus.active;
setStatus(UserStatus.active);
```

Dot shorthands work with:
- Enum values
- Static methods / constructors when the return type matches the context type

They do **not** work when the type cannot be inferred (e.g., `var x = .active`).
