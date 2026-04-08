# Practical Patterns

This guide covers recurring cross-cutting patterns that appear in most Flutter projects. Each pattern follows Clean Architecture principles and integrates with the BLoC-based state management described in the rest of this style guide.

---

## HTTP Headers Injection

Manually attaching authorization tokens and custom headers to every HTTP call is error-prone. Instead, centralize header management in a single injectable class.

```dart
// infrastructure/http/http_headers_injector.dart

/// Singleton that holds all headers to be injected into every request.
class HttpHeadersInjector {
  final Map<String, String> _headers = {};

  Map<String, String> get headers => Map.unmodifiable(_headers);

  void set(String key, String value) => _headers[key] = value;
  void remove(String key) => _headers.remove(key);
  void setAuthToken(String token) => set('Authorization', 'Bearer $token');
  void clear() => _headers.clear();
}
```

Wrap the standard `http.Client` so headers are applied transparently:

```dart
// infrastructure/http/custom_http_client.dart

class CustomHttpClient extends http.BaseClient {
  CustomHttpClient({
    required HttpHeadersInjector headersInjector,
    http.Client? inner,
  })  : _headersInjector = headersInjector,
        _inner = inner ?? http.Client();

  final HttpHeadersInjector _headersInjector;
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    // ✅ Good — headers are injected in one place for every request
    request.headers.addAll(_headersInjector.headers);
    return _inner.send(request);
  }
}
```

Register both as singletons at the composition root:

```dart
// ✅ Good — single source of truth for headers
final headersInjector = HttpHeadersInjector();
final httpClient = CustomHttpClient(headersInjector: headersInjector);
```

---

## User Session Management

A top-level `UserBloc` encapsulates the session lifecycle: checking stored credentials on startup, reacting to login/logout, and exposing the current user to any descendant widget.

```dart
// presentation/blocs/user/user_event.dart
sealed class UserEvent { const UserEvent(); }

class UserStarted extends UserEvent { const UserStarted(); }

class UserLoggedIn extends UserEvent {
  const UserLoggedIn({required this.token, required this.user});
  final String token;
  final User user;
}

class UserLoggedOut extends UserEvent { const UserLoggedOut(); }

class UserTokenRefreshed extends UserEvent {
  const UserTokenRefreshed({required this.token});
  final String token;
}
```

```dart
// presentation/blocs/user/user_state.dart
sealed class UserState { const UserState(); }

class UserInitial extends UserState { const UserInitial(); }

class UserAuthenticated extends UserState {
  const UserAuthenticated({required this.user, required this.token});
  final User user;
  final String token;
}

class UserUnauthenticated extends UserState { const UserUnauthenticated(); }
```

```dart
// presentation/blocs/user/user_bloc.dart

class UserBloc extends Bloc<UserEvent, UserState> {
  UserBloc({
    required GetStoredSessionUseCase getStoredSession,
    required PersistSessionUseCase persistSession,
    required ClearSessionUseCase clearSession,
    required HttpHeadersInjector headersInjector,
  })  : _getStoredSession = getStoredSession,
        _persistSession = persistSession,
        _clearSession = clearSession,
        _headersInjector = headersInjector,
        super(const UserInitial()) {
    on<UserStarted>(_onStarted);
    on<UserLoggedIn>(_onLoggedIn);
    on<UserLoggedOut>(_onLoggedOut);
    on<UserTokenRefreshed>(_onTokenRefreshed);
  }

  // ... private fields omitted for brevity

  Future<void> _onStarted(UserStarted event, Emitter<UserState> emit) async {
    final result = await _getStoredSession.execute().run();
    result.fold(
      (_) => emit(const UserUnauthenticated()),
      (session) {
        _headersInjector.setAuthToken(session.token);
        emit(UserAuthenticated(user: session.user, token: session.token));
      },
    );
  }

  Future<void> _onLoggedIn(UserLoggedIn event, Emitter<UserState> emit) async {
    await _persistSession.execute(token: event.token).run();
    _headersInjector.setAuthToken(event.token);
    emit(UserAuthenticated(user: event.user, token: event.token));
  }

  Future<void> _onLoggedOut(UserLoggedOut event, Emitter<UserState> emit) async {
    await _clearSession.execute().run();
    _headersInjector.clear();
    emit(const UserUnauthenticated());
  }

  Future<void> _onTokenRefreshed(UserTokenRefreshed event, Emitter<UserState> emit) async {
    await _persistSession.execute(token: event.token).run();
    _headersInjector.setAuthToken(event.token);
    if (state is UserAuthenticated) {
      final current = state as UserAuthenticated;
      emit(UserAuthenticated(user: current.user, token: event.token));
    }
  }
}
```

Provide the `UserBloc` at the **root** of the widget tree:

```dart
// ✅ Good — session available app-wide
BlocProvider(create: (_) => userBloc..add(const UserStarted()), child: const App())
```

---

## Token Refresh Strategy

When an access token expires, transparently refresh it instead of forcing the user to re-login. A `RefreshTokenInterceptor` catches `401` responses, attempts a refresh, and retries the original request.

```dart
// infrastructure/http/refresh_token_interceptor.dart

class RefreshTokenInterceptor extends http.BaseClient {
  RefreshTokenInterceptor({
    required http.Client inner,
    required RefreshTokenDataSource refreshDataSource,
    required HttpHeadersInjector headersInjector,
    required UserBloc userBloc,
  })  : _inner = inner, _refreshDataSource = refreshDataSource,
        _headersInjector = headersInjector, _userBloc = userBloc;

  // ... private fields
  bool _isRefreshing = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    if (response.statusCode != 401 || _isRefreshing) return response;

    _isRefreshing = true;
    try {
      final newToken = await _refreshDataSource.refresh();
      // ✅ Good — update shared state in one place
      _headersInjector.setAuthToken(newToken);
      _userBloc.add(UserTokenRefreshed(token: newToken));

      final retry = http.Request(request.method, request.url)
        ..headers.addAll(request.headers)
        ..headers['Authorization'] = 'Bearer $newToken';
      if (request is http.Request) retry.body = request.body;
      return _inner.send(retry);
    } catch (_) {
      // ❌ Bad — silently swallowing; instead, force re-auth
      _userBloc.add(const UserLoggedOut());
      return response;
    } finally {
      _isRefreshing = false;
    }
  }
}
```

---

## Home Screen Quick Actions

The `quick_actions` package adds shortcuts on long-press (iOS) or app icon hold (Android). Create a manager class that defines actions and maps them to navigation routes.

```dart
// presentation/quick_actions/quick_actions_manager.dart

class QuickActionsManager with WidgetsBindingObserver {
  QuickActionsManager({required this.navigatorKey});
  final GlobalKey<NavigatorState> navigatorKey;
  final QuickActions _quickActions = const QuickActions();

  void initialize() {
    _quickActions.setShortcutItems([
      const ShortcutItem(type: 'new_order', localizedTitle: 'New Order', icon: 'ic_add'),
      const ShortcutItem(type: 'search', localizedTitle: 'Search', icon: 'ic_search'),
    ]);
    _quickActions.initialize((type) => _handleAction(type));
    WidgetsBinding.instance.addObserver(this);
  }

  void dispose() => WidgetsBinding.instance.removeObserver(this);

  void _handleAction(String type) {
    // ✅ Good — map action types to named routes in one place
    final route = switch (type) {
      'new_order' => '/orders/new',
      'search'    => '/search',
      _           => null,
    };
    if (route != null) navigatorKey.currentState?.pushNamed(route);
  }
}
```

Initialize early so cold-start actions are captured before the first frame:

```dart
// ✅ Good — cold-start actions handled because initialization is early
@override
void initState() {
  super.initState();
  _quickActionsManager = QuickActionsManager(navigatorKey: _navigatorKey)..initialize();
}
```

---

## VPN Detection

Some applications restrict VPN usage for compliance. The `vpn_check` package detects active tunnels. Following Clean Architecture, the package stays encapsulated in the data layer.

```dart
// domain/repositories/vpn_repository.dart
abstract class VpnRepository {
  TaskEither<VpnError, bool> isVpnActive();
}
```

```dart
// infrastructure/repositories/vpn_repository_impl.dart
class VpnRepositoryImpl implements VpnRepository {
  @override
  TaskEither<VpnError, bool> isVpnActive() => TaskEither(() async {
    try {
      return right(await VpnCheck.isVpnActive());
    } catch (_) {
      return left(const VpnError.checkFailed());
    }
  });
}
```

```dart
// presentation/blocs/vpn/vpn_bloc.dart
class VpnBloc extends Bloc<VpnEvent, VpnState> {
  VpnBloc({required CheckVpnUseCase checkVpn})
      : _checkVpn = checkVpn, super(const VpnState.initial()) {
    on<VpnCheckRequested>(_onCheckRequested);
  }

  final CheckVpnUseCase _checkVpn;

  Future<void> _onCheckRequested(VpnCheckRequested event, Emitter<VpnState> emit) async {
    final result = await _checkVpn.execute().run();
    result.fold(
      (_) => emit(const VpnState.error()),
      (isActive) => isActive ? emit(const VpnState.detected()) : emit(const VpnState.clear()),
    );
  }
}
```

React in the widget tree with a non-blocking listener:

```dart
// ✅ Good — non-blocking check, UI reacts via BlocListener
BlocListener<VpnBloc, VpnState>(
  listener: (context, state) {
    if (state == const VpnState.detected()) {
      showDialog(context: context, barrierDismissible: false, builder: (_) => const VpnBlockedDialog());
    }
  },
  child: child,
)
```

---

## Anti-Patterns

| Anti-Pattern | Why It Hurts | Better Approach |
|---|---|---|
| Manually adding auth headers to every request | Easy to forget a call, duplicates logic | Use `HttpHeadersInjector` + `CustomHttpClient` |
| Storing tokens in `SharedPreferences` | Not encrypted; readable on rooted devices | Use `flutter_secure_storage` for sensitive data |
| No token refresh logic | Users forced to re-login on token expiry | Implement `RefreshTokenInterceptor` that retries on `401` |
| Ignoring quick-action cold starts | Actions before full load are silently dropped | Initialize `QuickActions` early in widget lifecycle |
| VPN checks blocking the UI thread | Synchronous checks freeze the app | Run asynchronously via BLoC, react with `BlocListener` |
| Scattering session logic across Blocs | Session state becomes inconsistent | Centralize in a single `UserBloc` at the root |
| Catching refresh failures silently | Users stuck with invalid token | Emit `UserLoggedOut` when refresh fails |
