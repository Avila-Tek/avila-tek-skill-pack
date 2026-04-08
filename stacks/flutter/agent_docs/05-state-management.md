# State Management

## Why Bloc

We use [flutter_bloc](https://pub.dev/packages/flutter_bloc) as our state management solution. Bloc enforces a strict unidirectional data flow:

```
UI → Event → Bloc → State → UI
```

This separation ensures:
- Business logic is testable in isolation from the UI.
- State transitions are explicit and traceable.
- The UI is a pure function of the state.

## Core Concepts

| Class | Role |
|---|---|
| `Bloc<Event, State>` | Receives events, emits states |
| `BlocProvider` | Creates and provides a Bloc to the widget tree |
| `BlocBuilder` | Rebuilds UI in response to state changes |
| `BlocListener` | Reacts to state changes with side effects (navigation, snackbars) |
| `BlocConsumer` | Combines `BlocBuilder` + `BlocListener` |
| `MultiBlocProvider` | Provides multiple Blocs at once |
| `MultiBlocListener` | Listens to multiple Blocs at once |
| `context.read<T>()` | Access a Bloc without subscribing |
| `context.watch<T>()` | Access a Bloc and subscribe to rebuilds |

## Where Blocs Live

Blocs are **created and provided by `Page` widgets**. They are **consumed by `View` and `Body` widgets**. See [Pages](./presentation/features/pages.md) and [Blocs](./presentation/blocs/blocs.md) for full rules.

## Dependency Rule

**Blocs may only depend on use cases** — never on repository interfaces or infrastructure directly. This ensures the Bloc stays decoupled from data-fetching details.

```dart
// ✅
class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc({required GetUserUseCase getUserUseCase})
      : _getUser = getUserUseCase, ...

// ❌
class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc({required IUserRepository userRepository})
      : _userRepository = userRepository, ...
```

## Bloc Isolation

**Blocs must not directly communicate with or depend on other Blocs.** Inter-Bloc communication must happen externally, via `BlocListener` in the widget tree or by using `context.read<OtherBloc>().add(...)` inside a listener.

```dart
// ✅ — Cross-Bloc communication via BlocListener
BlocListener<AuthBloc, AuthState>(
  listenWhen: (prev, curr) => curr.status == .authenticated,
  listener: (context, state) {
    context.read<ProfileBloc>().add(const ProfileLoadRequested());
  },
  child: ...,
)
```

## Handling `TaskEither` Results in Blocs

Use case methods return `TaskEither<E, T>`. Always `await` the `.run()` call and use `.fold` to emit success or failure states:

```dart
Future<void> _onSignInRequested(
  SignInRequested event,
  Emitter<LoginState> emit,
) async {
  emit(state.copyWith(status: .loading));

  final result = await _signIn.execute(
    email: event.email,
    password: event.password,
  ).run();

  result.fold(
    (error) => emit(state.copyWith(status: .failure, error: error)),
    (user)  => emit(state.copyWith(status: .success, user: user)),
  );
}
```

## Detailed Docs

- [Bloc Class Rules](./presentation/blocs/blocs.md)
- [Events](./presentation/blocs/events.md)
- [States](./presentation/blocs/states.md)
