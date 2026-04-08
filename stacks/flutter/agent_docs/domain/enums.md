# Enums

Domain enums represent a **finite set of named values** within a business concept. They live in `domain/entities/enums/` and contain no serialization logic.

## Naming

### Class Name

Enum classes **must** use a singular noun in `PascalCase`. Do **not** add an `Enum` suffix.

```dart
// ✅
enum UserStatus { ... }
enum OrderStatus { ... }
enum PrivacyType { ... }

// ❌
enum UserStatusEnum { ... }
enum OrderStatusEnum { ... }
```

### Values

Enum values **must** be in `camelCase`:

```dart
enum UserStatus {
  active,
  inactive,
  suspended,
  unknown,
}
```

## Unknown / Null Value

Every enum **must** include a value representing the **absence of a valid value**. Name it `unknown` (preferred) or `none`:

```dart
enum OrderStatus {
  pending,
  processing,
  shipped,
  delivered,
  cancelled,
  unknown, // absence of a known value
}
```

This prevents null-safety issues when deserializing unrecognized values from external sources.

## Dot Shorthands

Prefer dot shorthands when the context type is known:

```dart
// ✅
UserStatus get defaultStatus => .unknown;

void setStatus(UserStatus s) { ... }
setStatus(.active);

return switch (status) {
  .active   => 'Active',
  .inactive => 'Inactive',
  .unknown  => 'Unknown',
  _         => 'Other',
};

// ❌ Verbose when type is clear
UserStatus get defaultStatus => UserStatus.unknown;
setStatus(UserStatus.active);
```

## Getters

Enums **may** define getters for convenience checks. Prefer simple boolean getters:

```dart
enum UserStatus {
  active,
  inactive,
  suspended,
  unknown;

  bool get isActive    => this == .active;
  bool get isInactive  => this == .inactive;
  bool get isSuspended => this == .suspended;
  bool get isUnknown   => this == .unknown;
}
```

## No Serialization in Domain Enums

Domain enums **must not** contain JSON keys, HTTP values, or any serialization logic. If a domain enum needs to be serialized, create a corresponding [DTO enum](../infrastructure/dtos.md) in the infrastructure layer.

```dart
// ❌ Not allowed in domain enums
enum UserStatus {
  active('active'),
  inactive('inactive');

  const UserStatus(this.value);
  final String value; // serialization concerns belong in infrastructure
}
```

## Complete Example

```dart
// domain/entities/enums/notification_type.dart

/// The category of a push notification.
enum NotificationType {
  message,
  orderUpdate,
  promotion,
  systemAlert,
  unknown;

  bool get isMessage     => this == .message;
  bool get isOrderUpdate => this == .orderUpdate;
  bool get isPromotion   => this == .promotion;
  bool get isSystemAlert => this == .systemAlert;
  bool get isUnknown     => this == .unknown;
}
```
