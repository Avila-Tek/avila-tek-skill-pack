# Features

A **feature** represents a single screen or user flow in the application. Each feature is a self-contained folder under `presentation/`.

## Naming

Feature folders **must** use `snake_case` and be named after the screen or flow they represent, in the singular:

```
presentation/
├── login/
├── profile/
├── order_detail/
├── settings/
└── home/
```

## Folder Structure

Every feature **must** follow this structure:

```
[feature_name]/
├── bloc/
│   ├── [feature_name]_bloc.dart
│   ├── [feature_name]_event.dart
│   ├── [feature_name]_state.dart
│   └── bloc.dart                    # barrel export
├── view/
│   └── [feature_name]_page.dart     # contains Page and View classes
└── widgets/
    ├── [feature_name]_body.dart
    ├── [other_widget].dart
    └── widgets.dart                 # barrel export
```

### `bloc/`

Contains the Bloc, Event, and State classes, plus a barrel `bloc.dart` file that exports all three.

### `view/`

Contains the `Page` class (and optionally the `View` class in the same file when the view is simple). The `Page` class is the entry point for navigation.

### `widgets/`

Contains the `Body` widget and any feature-specific widgets. Widgets that are shared across multiple features **must** be moved to a shared folder (e.g., `core/widgets/`). Includes a `widgets.dart` barrel export.

## Barrel Exports

### `bloc/bloc.dart`

```dart
// presentation/login/bloc/bloc.dart
export 'login_bloc.dart';
export 'login_event.dart';
export 'login_state.dart';
```

### `widgets/widgets.dart`

```dart
// presentation/login/widgets/widgets.dart
export 'login_body.dart';
export 'email_input.dart';
export 'password_input.dart';
```

## Reusable Widgets

Widgets that are used in **more than one feature** must be extracted to a shared location:

```
core/
└── widgets/
    ├── primary_button.dart
    ├── loading_overlay.dart
    └── widgets.dart
```

Never duplicate widgets across feature folders.
