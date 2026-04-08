# Application Layer

## Purpose

The application layer **orchestrates domain logic**. It acts as the bridge between the domain (what the app knows) and the presentation layer (what the app shows). It has no knowledge of UI or external infrastructure.

## Rules

- Only depends on the **domain layer** (entities, errors, repository interfaces).
- Must **not** import Flutter, HTTP, or infrastructure packages.
- Must **not** access data sources directly — only through domain repository interfaces.
- All operations that can fail **must** return `Either<E, T>` or `TaskEither<E, T>`.
- Each use case has **a single responsibility** (one public method per use case class).

## Components

The application layer contains only **use cases**.

## Folder Structure

```
application/
└── use_cases/
    ├── user/
    │   ├── get_user_use_case.dart
    │   ├── sign_in_use_case.dart
    │   └── update_user_use_case.dart
    └── orders/
        ├── get_orders_use_case.dart
        └── create_order_use_case.dart
```

Use cases are grouped by **domain concept** (matching the domain folder names). Each file contains exactly one use case class.

## Detailed Docs

- [Use Cases](./use-cases.md)
