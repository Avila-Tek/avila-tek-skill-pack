# DTOs (Data Transfer Objects)

DTOs are infrastructure-layer objects responsible for **serialization and deserialization** of data from external sources. They are completely separate from domain entities — they do not extend or inherit from them.

## Core Rule: No Inheritance from Entities

> **DTOs must not extend or inherit from domain entities.**

This is a deliberate separation of concerns. A DTO's shape is dictated by the external API contract, while an entity's shape is dictated by business rules. The two can — and often do — differ.

```dart
// ✅ Correct — DTO is its own class
class UserDto {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final String status;        // raw string from API
  final int createdAtEpoch;   // Unix timestamp from API
  ...
}

// ❌ Wrong — DTO must not extend the entity
class UserDto extends User {
  ...
}
```

## Naming

DTOs **must** use the same base name as their corresponding entity, with a `Dto` suffix:

```dart
class UserDto { ... }       // corresponds to User entity
class OrderDto { ... }      // corresponds to Order entity
class OrderItemDto { ... }  // corresponds to OrderItem entity
```

## Attributes

- DTO attributes mirror the **external data schema**, not the domain model.
- Types follow external conventions: Unix timestamps as `int`, enum values as `String`, etc.
- DTO attributes are `final`.

```dart
class UserDto {
  const UserDto({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.status,
    required this.createdAtEpoch,
    this.avatarUrl,
  });

  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String status;          // raw API value — mapped by UserStatusDto
  final int createdAtEpoch;     // Unix timestamp in milliseconds
  final String? avatarUrl;

  /// The creation date as a [DateTime] object.
  DateTime get createdAt =>
      DateTime.fromMillisecondsSinceEpoch(createdAtEpoch, isUtc: true);
}
```

## Constructors

### `fromMap` / `fromJson`

Provide a `factory` constructor for deserialization. Use intermediate variables for readability and null-safe fallbacks:

```dart
factory UserDto.fromMap(Map<String, dynamic> map) {
  return UserDto(
    id: map['id'] as String? ?? '',
    email: map['email'] as String? ?? '',
    firstName: map['first_name'] as String? ?? '',
    lastName: map['last_name'] as String? ?? '',
    status: map['status'] as String? ?? '',
    createdAtEpoch: map['created_at'] as int? ?? 0,
    avatarUrl: map['avatar_url'] as String?,
  );
}

factory UserDto.fromJson(String source) =>
    UserDto.fromMap(jsonDecode(source) as Map<String, dynamic>);
```

### `empty` Constructor

Provide a `const` empty constructor for use in tests and default states:

```dart
const UserDto.empty()
    : id = '',
      email = '',
      firstName = '',
      lastName = '',
      status = '',
      createdAtEpoch = 0,
      avatarUrl = null;
```

## Serialization Methods

### `toMap`

```dart
Map<String, dynamic> toMap() {
  return {
    'id': id,
    'email': email,
    'first_name': firstName,
    'last_name': lastName,
    'status': status,
    'created_at': createdAtEpoch,
    if (avatarUrl != null) 'avatar_url': avatarUrl,
  };
}
```

### `toJson`

```dart
String toJson() => jsonEncode(toMap());
```

Omit `toJson` if the DTO is read-only (only ever deserialized, never sent back).

## Entity Conversion

DTOs **must** provide a `toEntity()` method that converts the DTO into the corresponding domain entity. If the conversion can be performed in reverse, also provide a `static fromEntity()` method.

```dart
// DTO → Entity
User toEntity() {
  return User(
    id: id,
    email: email,
    firstName: firstName,
    lastName: lastName,
    status: UserStatusDto.fromValue(status).toEntity(),
    avatarUrl: avatarUrl,
  );
}

// Entity → DTO
static UserDto fromEntity(User user) {
  return UserDto(
    id: user.id,
    email: user.email,
    firstName: user.firstName,
    lastName: user.lastName,
    status: UserStatusDto.fromEntity(user.status).value,
    createdAtEpoch: user.createdAt?.millisecondsSinceEpoch ?? 0,
    avatarUrl: user.avatarUrl,
  );
}
```

## DTO Enums

When an entity enum has a corresponding raw value in the external API, define a DTO enum in `infrastructure/dtos/enums/`. DTO enums are responsible for serialization and conversion; they **must not** be used in the domain or application layers.

```dart
// infrastructure/dtos/enums/user_status_dto.dart

enum UserStatusDto {
  active('active'),
  inactive('inactive'),
  suspended('suspended'),
  unknown('');

  const UserStatusDto(this.value);
  final String value;

  /// Returns the [UserStatusDto] for the given raw [value], defaulting to [unknown].
  static UserStatusDto fromValue(String value) =>
      UserStatusDto.values.firstWhere(
        (e) => e.value == value,
        orElse: () => .unknown,
      );

  /// Converts a domain [UserStatus] to its DTO equivalent.
  static UserStatusDto fromEntity(UserStatus status) => switch (status) {
        .active    => .active,
        .inactive  => .inactive,
        .suspended => .suspended,
        .unknown   => .unknown,
      };

  /// Converts this DTO value to the domain [UserStatus].
  UserStatus toEntity() => switch (this) {
        .active    => UserStatus.active,
        .inactive  => UserStatus.inactive,
        .suspended => UserStatus.suspended,
        .unknown   => UserStatus.unknown,
      };
}
```

## Complete Example

```dart
// infrastructure/dtos/user_dto.dart

import 'dart:convert';
import '../../domain/entities/user.dart';
import '../../domain/entities/enums/user_status.dart';
import 'enums/user_status_dto.dart';

class UserDto {
  const UserDto({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.status,
    required this.createdAtEpoch,
    this.avatarUrl,
  });

  const UserDto.empty()
      : id = '',
        email = '',
        firstName = '',
        lastName = '',
        status = '',
        createdAtEpoch = 0,
        avatarUrl = null;

  factory UserDto.fromMap(Map<String, dynamic> map) => UserDto(
        id: map['id'] as String? ?? '',
        email: map['email'] as String? ?? '',
        firstName: map['first_name'] as String? ?? '',
        lastName: map['last_name'] as String? ?? '',
        status: map['status'] as String? ?? '',
        createdAtEpoch: map['created_at'] as int? ?? 0,
        avatarUrl: map['avatar_url'] as String?,
      );

  factory UserDto.fromJson(String source) =>
      UserDto.fromMap(jsonDecode(source) as Map<String, dynamic>);

  static UserDto fromEntity(User user) => UserDto(
        id: user.id,
        email: user.email,
        firstName: user.firstName,
        lastName: user.lastName,
        status: UserStatusDto.fromEntity(user.status).value,
        createdAtEpoch: DateTime.now().millisecondsSinceEpoch,
        avatarUrl: user.avatarUrl,
      );

  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String status;
  final int createdAtEpoch;
  final String? avatarUrl;

  DateTime get createdAt =>
      DateTime.fromMillisecondsSinceEpoch(createdAtEpoch, isUtc: true);

  Map<String, dynamic> toMap() => {
        'id': id,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'status': status,
        'created_at': createdAtEpoch,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      };

  String toJson() => jsonEncode(toMap());

  User toEntity() => User(
        id: id,
        email: email,
        firstName: firstName,
        lastName: lastName,
        status: UserStatusDto.fromValue(status).toEntity(),
        avatarUrl: avatarUrl,
      );
}
```
