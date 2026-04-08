# Domain Layer

## Purpose

The domain layer is the **core of the application**. It contains all business rules, entities, and contracts. It has **no dependencies** on any other layer and no knowledge of Flutter, HTTP, or databases.

## Rules

- No Flutter imports (`package:flutter/...`).
- No infrastructure imports (no HTTP clients, no JSON libraries, no third-party data packages).
- No dependency on the application layer.
- All public APIs that can fail **must** return `Either<E, T>` or `TaskEither<E, T>` from `fpdart`.

## Components

| Component | Description |
|---|---|
| Entities | Immutable objects that represent core business concepts |
| Enums | Domain-level enumerations; no serialization logic |
| Errors | Typed failures specific to each domain concept |
| Repository Interfaces | Contracts the infrastructure layer must fulfill |
| Validators | Field-level validation rules expressed as typed objects |

## Folder Structure

```
domain/
├── entities/
│   ├── enums/
│   │   ├── user_status.dart
│   │   └── order_status.dart
│   ├── user.dart
│   └── order.dart
├── errors/
│   ├── user_error.dart
│   └── order_error.dart
├── repositories/
│   ├── i_user_repository.dart
│   └── i_order_repository.dart
└── validators/
    ├── email_field.dart
    └── password_field.dart
```

## Detailed Docs

- [Entities](./entities.md)
- [Enums](./enums.md)
- [Repository Interfaces](./repositories.md)
- [Validators](./validators.md)
- [Errors](../error-handling.md)
