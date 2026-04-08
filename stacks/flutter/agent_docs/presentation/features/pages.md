# Pages

The `Page` widget is the **entry point** for a feature. It is the first widget created when navigating to a screen. Its sole responsibilities are:

1. Providing Blocs to the widget tree via `BlocProvider` / `MultiBlocProvider`.
2. Declaring the feature's route.
3. Wrapping in `PopScope` when back-navigation must be prevented.

## Naming

Page classes **must** be named `[FeatureName]Page` in `PascalCase`:

```dart
class LoginPage extends StatelessWidget { ... }
class ProfilePage extends StatelessWidget { ... }
class OrderDetailPage extends StatelessWidget { ... }
```

## Extension

The `Page` class **must** extend `StatelessWidget`:

```dart
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});
  ...
}
```

## Constructor

The constructor **must** be `const`.

### Params Object

When a page requires parameters (e.g., an ID or a flag), declare a separate `Params` class in the same file:

```dart
class OrderDetailParams {
  const OrderDetailParams({
    required this.orderId,
    this.showReviewPrompt = false,
  });

  final String orderId;
  final bool showReviewPrompt;
}

class OrderDetailPage extends StatelessWidget {
  const OrderDetailPage({required this.params, super.key});

  final OrderDetailParams params;
  ...
}
```

### Query Params

For deep-link or URL-driven parameters, add a `fromQueryParams` factory to the `Params` class:

```dart
factory OrderDetailParams.fromQueryParams(Map<String, dynamic> query) =>
    OrderDetailParams(
      orderId: query['id'] as String? ?? '',
      showReviewPrompt: query['review'] == 'true',
    );
```

## Routes

Every `Page` **must** declare `routeName` and `path` as static constants:

```dart
class LoginPage extends StatelessWidget {
  static const routeName = 'login';
  static const path = '/$routeName';
  ...
}
```

For routes with path parameters:

```dart
class OrderDetailPage extends StatelessWidget {
  static const routeName = 'order/:id';
  static const path = '/$routeName';

  /// Builds the concrete path by substituting the [orderId].
  static String buildPath(String orderId) =>
      path.replaceFirst(':id', orderId);
  ...
}
```

> **Exception:** Pages that serve as tabs within a `DefaultTabController` or as steps in a multi-page form do **not** need a route.

## `build` Method

The `build` method **must** return either:
- A `BlocProvider` / `MultiBlocProvider` → `Scaffold`
- A `PopScope` wrapping a `BlocProvider` / `MultiBlocProvider` → `Scaffold`

No other root widget is allowed.

The `Scaffold`'s `body` **must** be the feature's `View` widget.

### Single Bloc

```dart
@override
Widget build(BuildContext context) {
  return BlocProvider(
    create: (context) => LoginBloc(
      signInUseCase: context.read<SignInUseCase>(),
    ),
    child: Scaffold(
      body: const LoginView(),
    ),
  );
}
```

### Multiple Blocs

```dart
@override
Widget build(BuildContext context) {
  return MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (context) => ProfileBloc(
          getUserUseCase: context.read<GetUserUseCase>(),
        ),
      ),
      BlocProvider(
        create: (context) => AvatarBloc(
          uploadAvatarUseCase: context.read<UploadAvatarUseCase>(),
        ),
      ),
    ],
    child: Scaffold(
      body: const ProfileView(),
    ),
  );
}
```

### Preventing Back Navigation

```dart
@override
Widget build(BuildContext context) {
  return PopScope(
    canPop: false,
    child: BlocProvider(
      create: (context) => OnboardingBloc(...),
      child: Scaffold(
        body: const OnboardingView(),
      ),
    ),
  );
}
```

## Complete Example

```dart
// presentation/login/view/login_page.dart

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  static const routeName = 'login';
  static const path = '/$routeName';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LoginBloc(
        signInUseCase: context.read<SignInUseCase>(),
      ),
      child: const Scaffold(
        body: LoginView(),
      ),
    );
  }
}
```
