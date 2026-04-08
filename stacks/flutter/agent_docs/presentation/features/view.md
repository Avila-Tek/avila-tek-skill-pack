# Views

The `View` widget sits between the `Page` and the `Body`. Its responsibilities are:

1. Listening to Bloc state changes and triggering side effects (navigation, snackbars, dialogs).
2. Delegating rendering to the `Body`.

It has **no parameters** beyond `super.key`, and does **no** direct rendering of business content.

## Naming

View classes **must** be named `[FeatureName]View`:

```dart
class LoginView extends StatelessWidget { ... }
class ProfileView extends StatelessWidget { ... }
```

## Extension

The `View` class **must** extend `StatelessWidget`:

```dart
class LoginView extends StatelessWidget {
  const LoginView({super.key});
  ...
}
```

## Constructor

The constructor **must** be `const` and accept **no** parameters beyond `super.key`.

## `build` Method

The `build` method **must** return either:
- The feature's `Body` widget directly, if no listeners are needed.
- A `BlocListener` wrapping the `Body`.
- A `MultiBlocListener` wrapping the `Body`.

No other root widget is allowed.

### No Listeners

```dart
@override
Widget build(BuildContext context) => const LoginBody();
```

### Single `BlocListener`

Each `BlocListener` **must** listen to **one single property** of the state at a time (singularity principle). Use `listenWhen` to filter to the exact property:

```dart
@override
Widget build(BuildContext context) {
  return BlocListener<LoginBloc, LoginState>(
    listenWhen: (prev, curr) => prev.status != curr.status,
    listener: (context, state) {
      if (state.status == .success) {
        Navigator.of(context).pushReplacementNamed(HomePage.path);
      }
      if (state.status == .failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.errorMessage ?? 'An error occurred')),
        );
      }
    },
    child: const LoginBody(),
  );
}
```

### Multiple `BlocListener`s

When multiple state properties need to trigger side effects, use `MultiBlocListener`:

```dart
@override
Widget build(BuildContext context) {
  return MultiBlocListener(
    listeners: [
      BlocListener<LoginBloc, LoginState>(
        listenWhen: (prev, curr) => prev.status != curr.status,
        listener: (context, state) {
          if (state.status == .success) {
            Navigator.of(context).pushReplacementNamed(HomePage.path);
          }
        },
      ),
      BlocListener<LoginBloc, LoginState>(
        listenWhen: (prev, curr) => prev.errorMessage != curr.errorMessage,
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!)),
            );
          }
        },
      ),
    ],
    child: const LoginBody(),
  );
}
```

### Inter-Bloc Communication

When a state change in one Bloc should trigger an event in another, do it inside a listener:

```dart
BlocListener<AuthBloc, AuthState>(
  listenWhen: (prev, curr) => prev.status != curr.status,
  listener: (context, state) {
    if (state.status == .authenticated) {
      context.read<ProfileBloc>().add(const ProfileLoadRequested());
    }
  },
  child: ...,
)
```

## Responsive Layouts

When a feature must support both phone and tablet layouts, use `LayoutBuilder` in the `View` to render the appropriate `Body`:

```dart
@override
Widget build(BuildContext context) {
  return BlocListener<ProfileBloc, ProfileState>(
    listenWhen: ...,
    listener: ...,
    child: LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 600) {
          return const ProfileBodyTablet();
        }
        return const ProfileBody();
      },
    ),
  );
}
```

## Complete Example

```dart
// presentation/login/view/login_page.dart  (View section)

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<LoginBloc, LoginState>(
      listenWhen: (prev, curr) => prev.status != curr.status,
      listener: (context, state) {
        switch (state.status) {
          case .success:
            Navigator.of(context).pushReplacementNamed(HomePage.path);
          case .failure:
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sign in failed. Please try again.')),
            );
          default:
            break;
        }
      },
      child: const LoginBody(),
    );
  }
}
```
