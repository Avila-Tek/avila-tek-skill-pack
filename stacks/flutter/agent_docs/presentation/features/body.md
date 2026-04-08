# Bodies

The `Body` widget is where the **actual UI is rendered**. It reads from the Bloc and builds the widget tree accordingly.

## Naming

Body classes **must** be named `[FeatureName]Body`:

```dart
class LoginBody extends StatelessWidget { ... }
class ProfileBody extends StatelessWidget { ... }
class OrderDetailBody extends StatelessWidget { ... }
```

## Extension

Bodies **should** extend `StatelessWidget` whenever possible.

Use `StatefulWidget` only when a mixin that requires it is needed (e.g., `TickerProviderStateMixin`, `AutomaticKeepAliveClientMixin`):

```dart
// ✅ Preferred
class LoginBody extends StatelessWidget { ... }

// ✅ Acceptable when a mixin requires it
class AnimatedFormBody extends StatefulWidget { ... }
class _AnimatedFormBodyState extends State<AnimatedFormBody>
    with TickerProviderStateMixin { ... }
```

## Constructor

The constructor **must** be `const`.

## Parameters

Bodies should have **minimal parameters**. The primary data source is the Bloc via `context.read` / `context.watch` / `BlocBuilder`. If parameters are necessary (e.g., a `TabController`, a `ScrollController`), declare them as `final`:

```dart
class ProfileBody extends StatelessWidget {
  const ProfileBody({super.key});
}

// When a controller is needed:
class TabbedBody extends StatefulWidget {
  const TabbedBody({super.key});
}

class _TabbedBodyState extends State<TabbedBody>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  ...
}
```

## Reading Bloc State

Use `BlocBuilder` to rebuild parts of the UI in response to state changes. Narrow rebuilds with `buildWhen`:

```dart
class LoginBody extends StatelessWidget {
  const LoginBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          BlocBuilder<LoginBloc, LoginState>(
            buildWhen: (previous, current) => previous.email != current.email,
            builder: (context, state) => EmailInput(field: state.email),
          ),
          BlocBuilder<LoginBloc, LoginState>(
            buildWhen: (previous, current) => previous.password != current.password,
            builder: (context, state) => PasswordInput(field: state.password),
          ),
          BlocBuilder<LoginBloc, LoginState>(
            buildWhen: (previous, current) => previous.status != current.status,
            builder: (context, state) => ElevatedButton(
              onPressed: state.isValid && state.status != .loading
                  ? () => context.read<LoginBloc>().add(const LoginSubmitted())
                  : null,
              child: state.status == .loading
                  ? const CircularProgressIndicator()
                  : const Text('Sign In'),
            ),
          ),
        ],
      ),
    );
  }
}
```

## Complete Example

```dart
// presentation/login/widgets/login_body.dart

class LoginBody extends StatelessWidget {
  const LoginBody({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Sign In',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            BlocBuilder<LoginBloc, LoginState>(
              buildWhen: (previous, current) => previous.email != current.email,
              builder: (context, state) => EmailInput(field: state.email),
            ),
            const SizedBox(height: 16),
            BlocBuilder<LoginBloc, LoginState>(
              buildWhen: (previous, current) => previous.password != current.password,
              builder: (context, state) => PasswordInput(field: state.password),
            ),
            const SizedBox(height: 32),
            BlocBuilder<LoginBloc, LoginState>(
              buildWhen: (previous, current) =>
                  previous.status != current.status || previous.isValid != current.isValid,
              builder: (context, state) => FilledButton(
                onPressed: state.isValid && state.status != .loading
                    ? () =>
                        context.read<LoginBloc>().add(const LoginSubmitted())
                    : null,
                child: state.status == .loading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Sign In'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```
