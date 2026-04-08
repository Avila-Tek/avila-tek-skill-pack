# Blocs

A `Bloc` holds the state of a single feature and defines how that state changes in response to events.

## Naming

Bloc classes **must** be named `[FeatureName]Bloc`:

```dart
class LoginBloc extends Bloc<LoginEvent, LoginState> { ... }
class ProfileBloc extends Bloc<ProfileEvent, ProfileState> { ... }
```

## Extension

All Blocs **must** extend `Bloc<Event, State>` from `flutter_bloc`:

```dart
class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc({required SignInUseCase signInUseCase})
      : _signIn = signInUseCase,
        super(const LoginState()) {
    on<LoginEmailChanged>(_onEmailChanged);
    on<LoginPasswordChanged>(_onPasswordChanged);
    on<LoginSubmitted>(_onSubmitted);
  }
  ...
}
```

## Constructor

### Dependencies

Blocs **must** only depend on **use cases** — never on repository interfaces or data sources:

```dart
// ✅
LoginBloc({
  required SignInUseCase signInUseCase,
  required GetRemoteConfigUseCase remoteConfigUseCase,
})

// ❌
LoginBloc({required IUserRepository userRepository})
```

Dependencies are stored as `final` private fields and assigned via initializer lists:

```dart
LoginBloc({required SignInUseCase signInUseCase})
    : _signIn = signInUseCase,
      super(const LoginState());

final SignInUseCase _signIn;
```

### Initial State

The `super(...)` call in the constructor receives the initial state. Use `const` if the state allows it.

### Event Registration

Register all event handlers inside the constructor body using `on<EventType>(_handlerMethod)`:

```dart
LoginBloc({...}) : ... {
  on<LoginEmailChanged>(_onEmailChanged);
  on<LoginPasswordChanged>(_onPasswordChanged);
  on<LoginSubmitted>(_onSubmitted);
}
```

## Event Handlers

### Naming

Handler methods **must** be named `_on[EventName]` (private, verb-matching the event name):

```dart
void _onEmailChanged(LoginEmailChanged event, Emitter<LoginState> emit) { ... }
Future<void> _onSubmitted(LoginSubmitted event, Emitter<LoginState> emit) async { ... }
```

### Handling `TaskEither` Results

Use `.run()` to execute the `TaskEither` and `.fold` to handle the two branches:

```dart
Future<void> _onSubmitted(
  LoginSubmitted event,
  Emitter<LoginState> emit,
) async {
  emit(state.copyWith(status: .loading));

  final result = await _signIn
      .execute(email: state.email.value, password: state.password.value)
      .run();

  result.fold(
    (error) => emit(state.copyWith(status: .failure, error: error)),
    (user)  => emit(state.copyWith(status: .success, user: user)),
  );
}
```

### Synchronous Handlers

For synchronous state updates (e.g., form field changes):

```dart
void _onEmailChanged(
  LoginEmailChanged event,
  Emitter<LoginState> emit,
) {
  emit(state.copyWith(email: EmailField.dirty(event.email)));
}
```

## Bloc Isolation

**Blocs must not depend on other Blocs.** Inter-Bloc communication must happen externally via `BlocListener` in the widget tree:

```dart
// ✅ — In View widget
BlocListener<AuthBloc, AuthState>(
  listenWhen: (prev, curr) => prev.status != curr.status,
  listener: (context, state) {
    if (state.status == .authenticated) {
      context.read<DashboardBloc>().add(const DashboardLoadRequested());
    }
  },
  child: ...,
)

// ❌ — Inside a Bloc
class DashboardBloc {
  DashboardBloc({required AuthBloc authBloc}) // NEVER inject another Bloc
}
```

## Stream Subscriptions

When a Bloc needs to react to a stream (e.g., from a use case or repository), store the subscription in a private field and cancel it in `close()`:

```dart
class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  NotificationsBloc({required WatchNotificationsUseCase watchNotifications})
      : super(const NotificationsState()) {
    on<NotificationsReceived>(_onReceived);
    _subscription = watchNotifications.stream.listen(
      (notification) => add(NotificationsReceived(notification)),
    );
  }

  late final StreamSubscription<Notification> _subscription;

  void _onReceived(
    NotificationsReceived event,
    Emitter<NotificationsState> emit,
  ) {
    emit(state.copyWith(
      notifications: [event.notification, ...state.notifications],
    ));
  }

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
```

## Complete Example

```dart
// presentation/login/bloc/login_bloc.dart

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc({required SignInUseCase signInUseCase})
      : _signIn = signInUseCase,
        super(const LoginState()) {
    on<LoginEmailChanged>(_onEmailChanged);
    on<LoginPasswordChanged>(_onPasswordChanged);
    on<LoginSubmitted>(_onSubmitted);
  }

  final SignInUseCase _signIn;

  void _onEmailChanged(
    LoginEmailChanged event,
    Emitter<LoginState> emit,
  ) {
    emit(state.copyWith(email: EmailField.dirty(event.email)));
  }

  void _onPasswordChanged(
    LoginPasswordChanged event,
    Emitter<LoginState> emit,
  ) {
    emit(state.copyWith(password: PasswordField.dirty(event.password)));
  }

  Future<void> _onSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    if (!state.isValid) return;
    emit(state.copyWith(status: .loading));

    final result = await _signIn
        .execute(email: state.email.value, password: state.password.value)
        .run();

    result.fold(
      (error) => emit(state.copyWith(status: .failure, error: error)),
      (user)  => emit(state.copyWith(status: .success, user: user)),
    );
  }
}
```
