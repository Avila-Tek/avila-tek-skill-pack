# Events

Events represent **actions or intentions** that trigger a state change. They are dispatched from the UI (or from listeners) and processed by the Bloc.

## Class Structure

### Base Event Class

The base event class **must**:
- Be declared as `sealed`.
- Extend `Equatable`.
- Be named `[FeatureName]Event`.
- Have a `const` constructor.
- Override `props` with an empty list (sub-events override if needed).

```dart
sealed class LoginEvent extends Equatable {
  const LoginEvent();

  @override
  List<Object?> get props => [];
}
```

### Sub-Event Classes

Sub-events extend the base class and name themselves using a **past-tense verb** that describes the action. They may include the feature name if clarity demands it:

```dart
// ✅
class LoginEmailChanged extends LoginEvent { ... }
class LoginSubmitted extends LoginEvent { ... }
class LoginPasswordVisibilityToggled extends LoginEvent { ... }

// When including the feature name would make the name too long:
class DropdownValueSelected extends LoginEvent { ... }
```

## Constructors

Sub-event constructors **must** be `const`:

```dart
// ✅
class LoginSubmitted extends LoginEvent {
  const LoginSubmitted();
}
```

### Parameters

Use **named parameters** for events with more than one parameter:

```dart
class LoginCredentialsSubmitted extends LoginEvent {
  const LoginCredentialsSubmitted({
    required this.email,
    required this.password,
  });

  final String email;
  final String password;
}
```

For events with **exactly one parameter**, positional (unnamed) parameters are allowed, except when the parameter is `bool` (in which case named parameters are required for clarity):

```dart
class LoginEmailChanged extends LoginEvent {
  const LoginEmailChanged(this.email);

  final String email;
}

// For boolean parameters, use named parameters for clarity:
class LoginPasswordVisibilityToggled extends LoginEvent {
  const LoginPasswordVisibilityToggled({required this.isVisible});
  final bool isVisible;
}
```


## `props`

The `props` getter is defined in the base class as an empty list. Override it **only** in sub-classes that have properties:

```dart
sealed class LoginEvent extends Equatable {
  const LoginEvent();

  @override
  List<Object?> get props => [];
}

class LoginEmailChanged extends LoginEvent {
  const LoginEmailChanged(this.email);

  final String email;

  @override
  List<Object?> get props => [email];
}

// No need to override props in parameter-less events:
class LoginSubmitted extends LoginEvent {
  const LoginSubmitted();
}
```

## Dot Shorthands in Event Dispatches

When dispatching events, prefer dot shorthands for parameter-less events:

```dart
// ✅
context.read<LoginBloc>().add(const LoginSubmitted());

// For events with parameters:
context.read<LoginBloc>().add(LoginEmailChanged(value));
```

## Complete Example

```dart
// presentation/login/bloc/login_event.dart

sealed class LoginEvent extends Equatable {
  const LoginEvent();

  @override
  List<Object?> get props => [];
}

/// Fired when the user edits the email input field.
class LoginEmailChanged extends LoginEvent {
  const LoginEmailChanged(this.email);
  final String email;

  @override
  List<Object?> get props => [email];
}

/// Fired when the user edits the password input field.
class LoginPasswordChanged extends LoginEvent {
  const LoginPasswordChanged(this.password);
  final String password;

  @override
  List<Object?> get props => [password];
}

/// Fired when the user taps the password visibility toggle.
class LoginPasswordVisibilityToggled extends LoginEvent {
  const LoginPasswordVisibilityToggled();
}

/// Fired when the user taps the "Sign In" button.
class LoginSubmitted extends LoginEvent {
  const LoginSubmitted();
}
```
