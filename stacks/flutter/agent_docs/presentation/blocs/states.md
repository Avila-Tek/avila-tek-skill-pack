# States

A state is an **immutable snapshot** of a feature's current data. The Bloc emits new states to reflect changes driven by events.

There are two accepted patterns for structuring states. Choose the one that best fits the feature's complexity.

---

## Pattern 1 — Single Class with Status Enum

Use this pattern for most features. It is simple, concise, and works well when the feature has one primary loading/success/failure lifecycle.

### Status Enum

The status enum **must**:
- Be named `[FeatureName]Status`.
- Contain at least `loading`, `success`, and `failure` values.
- Optionally include `initial` when the feature has a pre-load state.
- Define boolean getters for UI convenience.

```dart
enum LoginStatus {
  initial,
  loading,
  success,
  failure;

  bool get isInitial  => this == .initial;
  bool get isLoading  => this == .loading;
  bool get isSuccess  => this == .success;
  bool get isFailure  => this == .failure;
}
```

### State Class

The state class **must**:
- Be named `[FeatureName]State`.
- Extend `Equatable`.
- Have a `const` constructor with named, optional parameters and sensible defaults.
- List all state-affecting fields in `props`.
- Implement `copyWith`.

```dart
class LoginState extends Equatable {
  const LoginState({
    this.email = const EmailField.pure(''),
    this.password = const PasswordField.pure(''),
    this.status = LoginStatus.initial,
    this.error,
  });

  final EmailField email;
  final PasswordField password;
  final LoginStatus status;
  final AuthError? error;

  bool get isValid => email.isValid && password.isValid;

  LoginState copyWith({
    EmailField? email,
    PasswordField? password,
    LoginStatus? status,
    AuthError? error,
  }) {
    return LoginState(
      email: email ?? this.email,
      password: password ?? this.password,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [email, password, status, error];
}
```

---

## Pattern 2 — Sealed Class with Subclasses

Use this pattern when the feature has **distinctly different state shapes** that cannot be expressed cleanly with a single class (e.g., a list screen that can be empty, populated, or in an error state with different data).

### Base State Class

The base class **must**:
- Be declared as `sealed`.
- Extend `Equatable`.
- Be named `[FeatureName]State`.
- Have a `const` constructor.
- Define `props` (empty list or shared properties).

```dart
sealed class OrderListState extends Equatable {
  const OrderListState();

  @override
  List<Object?> get props => [];
}
```

### Sub-State Classes

Sub-state classes extend the base and describe specific states:

```dart
class OrderListInitial extends OrderListState {
  const OrderListInitial();
}

class OrderListLoading extends OrderListState {
  const OrderListLoading();
}

class OrderListSuccess extends OrderListState {
  const OrderListSuccess({required this.orders});

  final List<Order> orders;

  @override
  List<Object?> get props => [orders];
}

class OrderListFailure extends OrderListState {
  const OrderListFailure({required this.error});

  final OrderError error;

  @override
  List<Object?> get props => [error];
}
```

### Consuming Sealed States

Exhaustive pattern matching with `switch` ensures all states are handled:

```dart
BlocBuilder<OrderListBloc, OrderListState>(
  builder: (context, state) => switch (state) {
    OrderListInitial() => const SizedBox.shrink(),
    OrderListLoading() => const CircularProgressIndicator(),
    OrderListSuccess(:final orders) => OrdersListView(orders: orders),
    OrderListFailure(:final error) => ErrorView(error: error),
  },
)
```

---

## Clearing Errors on Retry

When using the single-class pattern, clearing the error field on retry prevents stale errors from re-displaying. Since `copyWith` uses `??`, introduce a sentinel to allow explicit nulling:

```dart
LoginState copyWith({
  LoginStatus? status,
  AuthError? error,
  bool clearError = false,
}) {
  return LoginState(
    status: status ?? this.status,
    error: clearError ? null : (error ?? this.error),
  );
}

// Usage in Bloc:
emit(state.copyWith(status: .loading, clearError: true));
```

---

## Dot Shorthands in State Checks

Prefer dot shorthands when checking or emitting statuses:

```dart
// ✅
emit(state.copyWith(status: .loading));
if (state.status == .failure) { ... }

// ❌ Verbose
emit(state.copyWith(status: LoginStatus.loading));
if (state.status == LoginStatus.failure) { ... }
```

---

## Complete Example (Single-Class Pattern)

```dart
// presentation/login/bloc/login_state.dart

enum LoginStatus {
  initial,
  loading,
  success,
  failure;

  bool get isInitial  => this == .initial;
  bool get isLoading  => this == .loading;
  bool get isSuccess  => this == .success;
  bool get isFailure  => this == .failure;
}

class LoginState extends Equatable {
  const LoginState({
    this.email = const EmailField.pure(''),
    this.password = const PasswordField.pure(''),
    this.passwordVisible = false,
    this.status = LoginStatus.initial,
    this.error,
  });

  final EmailField email;
  final PasswordField password;
  final bool passwordVisible;
  final LoginStatus status;

  /// Non-null when [status] is [LoginStatus.failure].
  final AuthError? error;

  bool get isValid => email.isValid && password.isValid;

  LoginState copyWith({
    EmailField? email,
    PasswordField? password,
    bool? passwordVisible,
    LoginStatus? status,
    AuthError? error,
    bool clearError = false,
  }) {
    return LoginState(
      email: email ?? this.email,
      password: password ?? this.password,
      passwordVisible: passwordVisible ?? this.passwordVisible,
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [email, password, passwordVisible, status, error];
}
```
