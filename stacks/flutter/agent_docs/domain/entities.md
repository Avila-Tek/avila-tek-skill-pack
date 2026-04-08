# Entities

Entities are the **core objects of the domain**. They represent business concepts with a distinct identity and are fully independent of serialization or UI concerns.

## Naming

Entity classes **must** use a clear, singular noun in `PascalCase`. Do **not** add `Entity` or `Model` as a suffix.

```dart
// ✅
class User { ... }
class Order { ... }
class ProductVariant { ... }

// ❌
class UserEntity { ... }
class UserModel { ... }
```

## Equatable

All entities **must** extend `Equatable` to enable value-based equality. Override `props` to list every attribute that participates in the equality check.

```dart
import 'package:equatable/equatable.dart';

class User extends Equatable {
  const User({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
  });

  final String id;
  final String email;
  final String firstName;
  final String lastName;

  /// Null when the user has not uploaded a profile picture.
  final String? avatarUrl;

  @override
  List<Object?> get props => [id, email, firstName, lastName, avatarUrl];
}
```

## Constructors

### Primary Constructor

The primary constructor **must** be `const` whenever all fields allow it.

### `empty()` Constructor

Every entity **must** provide a named `empty()` constructor that returns a valid instance with default or empty values. This is used for initializing Bloc states, testing, and form scaffolding.

```dart
const User.empty()
    : id = '',
      email = '',
      firstName = '',
      lastName = '',
      avatarUrl = null;
```

## Attributes

- All attributes **must** be `final` (entities are immutable).
- Nullable attributes **must** include a documentation comment explaining when they are `null`.
- Constructor parameters for required attributes **must** use `required`.
- Optional attributes may have a default value.

## Methods

### `copyWith`

Entities **must not** have setters. To create a modified copy, provide a `copyWith` method using the null-coalescing operator (`??`):

```dart
User copyWith({
  String? id,
  String? email,
  String? firstName,
  String? lastName,
  String? avatarUrl,
}) {
  return User(
    id: id ?? this.id,
    email: email ?? this.email,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    avatarUrl: avatarUrl ?? this.avatarUrl,
  );
}
```

### Computed Getters

Getters for derived values are allowed:

```dart
String get fullName => '$firstName $lastName';
bool get hasAvatar => avatarUrl != null;
```

### No Serialization

Entities **must not** contain `fromJson`, `toJson`, `fromMap`, or `toMap` methods. Serialization is the responsibility of [DTOs](../infrastructure/dtos.md) in the infrastructure layer.

## Complete Example

```dart
import 'package:equatable/equatable.dart';
import '../entities/enums/user_status.dart';

/// Represents a registered user in the system.
class User extends Equatable {
  const User({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.status,
    this.avatarUrl,
  });

  /// Creates an empty [User] for use as a default state value.
  const User.empty()
      : id = '',
        email = '',
        firstName = '',
        lastName = '',
        status = UserStatus.unknown,
        avatarUrl = null;

  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final UserStatus status;

  /// Null when the user has not uploaded a profile picture.
  final String? avatarUrl;

  String get fullName => '$firstName $lastName';
  bool get isActive => status == .active;

  User copyWith({
    String? id,
    String? email,
    String? firstName,
    String? lastName,
    UserStatus? status,
    String? avatarUrl,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      status: status ?? this.status,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  @override
  List<Object?> get props => [id, email, firstName, lastName, status, avatarUrl];
}
```
