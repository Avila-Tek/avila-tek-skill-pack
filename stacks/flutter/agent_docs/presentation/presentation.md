# Presentation Layer

## Purpose

The presentation layer contains everything the user sees and interacts with: Flutter widgets, routing, and Bloc-based state management.

It depends on:
- The **application layer** — to invoke use cases.
- The **domain layer** — to read entities and handle domain errors.

It **must not** depend on the infrastructure layer directly.

## Rules

- Blocs may only depend on **use cases** (not repository interfaces).
- No raw HTTP calls, JSON parsing, or direct data source access.
- All state changes go through Bloc events.
- Widget trees reflect state — they never drive logic.

## Components

| Component | Description |
|---|---|
| Page | `StatelessWidget` that provides Blocs to the tree. Entry point for a feature. |
| View | `StatelessWidget` that reads from Blocs and delegates to the Body. |
| Body | `StatelessWidget` (or `StatefulWidget`) that renders the actual UI. |
| Bloc | State management; receives events, emits states. |
| Events | Immutable actions that trigger Bloc state transitions. |
| States | Immutable snapshots of the Bloc's current state. |

## Feature Organization

Each feature (screen or flow) is self-contained in its own folder under `presentation/`:

```
presentation/
└── login/
    ├── bloc/
    │   ├── login_bloc.dart
    │   ├── login_event.dart
    │   ├── login_state.dart
    │   └── bloc.dart           # barrel
    ├── view/
    │   └── login_page.dart     # Page + View in the same file
    └── widgets/
        ├── login_body.dart
        ├── email_input.dart
        └── widgets.dart        # barrel
```

## Detailed Docs

- [Features](./features/features.md) — feature structure and naming
- [Pages](./features/pages.md) — the `Page` widget
- [Views](./features/view.md) — the `View` widget
- [Bodies](./features/body.md) — the `Body` widget
- [Blocs](./blocs/blocs.md) — Bloc class rules
- [Events](./blocs/events.md) — Event class rules
- [States](./blocs/states.md) — State class rules
