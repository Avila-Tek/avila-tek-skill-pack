# Folder Structure

## Project Layout

```
lib/
├── app/                          # App entry point, routing, theme
│   ├── app.dart
│   └── router.dart
├── core/                         # Cross-cutting utilities
│   ├── extensions/
│   └── utils/
├── domain/                       # Domain layer
│   ├── entities/
│   │   ├── enums/
│   │   │   ├── user_status.dart
│   │   │   └── order_status.dart
│   │   ├── user.dart
│   │   └── order.dart
│   ├── errors/
│   │   ├── user_error.dart
│   │   └── order_error.dart
│   ├── repositories/
│   │   ├── i_user_repository.dart
│   │   └── i_order_repository.dart
│   └── validators/
│       ├── email_field.dart
│       └── password_field.dart
├── application/                  # Application layer
│   └── use_cases/
│       ├── user/
│       │   ├── get_user.dart
│       │   ├── update_user.dart
│       │   └── sign_in.dart
│       └── orders/
│           ├── get_orders.dart
│           └── create_order.dart
├── infrastructure/               # Infrastructure layer
│   ├── data_sources/
│   │   ├── user/
│   │   │   ├── i_user_api.dart
│   │   │   └── user_api_rest.dart
│   │   └── orders/
│   │       ├── i_orders_api.dart
│   │       └── orders_api_rest.dart
│   ├── dtos/
│   │   ├── enums/
│   │   │   ├── user_status_dto.dart
│   │   │   └── order_status_dto.dart
│   │   ├── user_dto.dart
│   │   └── order_dto.dart
│   └── repositories/
│       ├── user_repository.dart
│       └── order_repository.dart
└── presentation/                 # Presentation layer
    ├── login/
    │   ├── bloc/
    │   │   ├── login_bloc.dart
    │   │   ├── login_event.dart
    │   │   ├── login_state.dart
    │   │   └── bloc.dart
    │   ├── view/
    │   │   └── login_page.dart
    │   └── widgets/
    │       ├── login_body.dart
    │       └── widgets.dart
    ├── profile/
    │   └── ...
    └── home/
        └── ...
```

## Layer Folder Rules

### `domain/`
- `entities/` — one file per entity, `snake_case.dart`.
- `entities/enums/` — domain-level enums (no serialization logic).
- `errors/` — one file per domain concept, named `[concept]_error.dart`.
- `repositories/` — one abstract interface per file, prefixed with `i_`.
- `validators/` — field validators; one file per validated field.

### `application/`
- `use_cases/[domain]/` — use cases grouped by domain concept.
- One file per use case, named after the action: `get_user.dart`, `sign_in.dart`, `create_order.dart`.

### `infrastructure/`
- `data_sources/[domain]/` — interface + implementations grouped by domain concept.
- `dtos/` — flat list of DTO files (one per entity).
- `dtos/enums/` — DTO-level enums with serialization logic.
- `repositories/` — one implementation file per domain repository interface.

### `presentation/`
- One folder per **feature** (screen or flow), named in `snake_case`.
- Each feature contains `bloc/`, `view/`, and `widgets/` sub-folders.
- The `view/` folder contains the `Page` widget; the `widgets/` folder contains everything else.

## Barrel Files

Each folder that exposes multiple files **must** include a barrel export file named after the folder or `[name].dart`:

```dart
// presentation/login/bloc/bloc.dart
export 'login_bloc.dart';
export 'login_event.dart';
export 'login_state.dart';

// presentation/login/widgets/widgets.dart
export 'login_body.dart';
export 'email_input.dart';
export 'password_input.dart';
```

Top-level layer barrel files (e.g., `domain/domain.dart`) are optional but recommended for large codebases.
