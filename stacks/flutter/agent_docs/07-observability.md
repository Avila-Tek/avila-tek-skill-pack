# Observability

## Core Principle

A mobile application that cannot be observed cannot be maintained. Observability in Flutter means answering three questions: "What went wrong?" (error categorization), "How did the user get there?" (breadcrumbs and context), and "What was the app doing?" (structured logs). These concerns live in the infrastructure layer and must not leak domain knowledge upward.

---

## Error Categorization

Define a strict error hierarchy. Errors originate as `ServerError` from the network layer, pass through an `ErrorMapper`, and emerge as `AppError` subtypes the presentation layer can act on.

```dart
// domain/errors/base_error.dart
abstract class BaseError {
  final String message;
  final DateTime timestamp;
  const BaseError({required this.message, required this.timestamp});
}

// infrastructure/errors/server_error.dart
enum ServerErrorType {
  badRequest(400), unauthorized(401), forbidden(403), notFound(404),
  conflict(409), tooManyRequests(429), internalServer(500), unknown(0);

  final int code;
  const ServerErrorType(this.code);

  factory ServerErrorType.fromStatusCode(int statusCode) =>
    ServerErrorType.values.firstWhere((e) => e.code == statusCode, orElse: () => ServerErrorType.unknown);
}

class ServerError extends BaseError {
  final ServerErrorType type;
  final int statusCode;
  ServerError({required this.type, required this.statusCode, required super.message, required super.timestamp});

  factory ServerError.fromResponse(int statusCode, String body) => ServerError(
    type: ServerErrorType.fromStatusCode(statusCode), statusCode: statusCode,
    message: body, timestamp: DateTime.now(),
  );
}

// domain/errors/app_error.dart
sealed class AppError extends BaseError {
  const AppError({required super.message, required super.timestamp});
}
class AuthenticationError extends AppError {
  const AuthenticationError({required super.message, required super.timestamp});
}
class NotFoundError extends AppError {
  final String resource;
  const NotFoundError({required this.resource, required super.message, required super.timestamp});
}
class ConflictError extends AppError {
  const ConflictError({required super.message, required super.timestamp});
}
class RateLimitError extends AppError {
  final Duration retryAfter;
  const RateLimitError({required this.retryAfter, required super.message, required super.timestamp});
}
class NetworkError extends AppError {
  const NetworkError({required super.message, required super.timestamp});
}
class UnexpectedError extends AppError {
  final Object? originalError;
  const UnexpectedError({this.originalError, required super.message, required super.timestamp});
}
```

```dart
// infrastructure/errors/error_mapper.dart
class ErrorMapper {
  AppError mapServerError(ServerError error) {
    final now = error.timestamp;
    return switch (error.type) {
      ServerErrorType.unauthorized || ServerErrorType.forbidden =>
        AuthenticationError(message: error.message, timestamp: now),
      ServerErrorType.notFound =>
        NotFoundError(resource: '', message: error.message, timestamp: now),
      ServerErrorType.conflict =>
        ConflictError(message: error.message, timestamp: now),
      ServerErrorType.tooManyRequests =>
        RateLimitError(retryAfter: const Duration(seconds: 30), message: error.message, timestamp: now),
      _ => UnexpectedError(message: error.message, timestamp: now),
    };
  }
}
```

---

## Centralized Error Handler

A single `ErrorHandler` dispatches UI responses based on the `AppError` subtype. The presentation layer calls this handler instead of scattering `switch` expressions across every Bloc listener.

```dart
// presentation/error_handler.dart
class ErrorHandler {
  final GlobalKey<NavigatorState> navigatorKey;
  final GlobalKey<ScaffoldMessengerState> messengerKey;
  const ErrorHandler({required this.navigatorKey, required this.messengerKey});

  void handle(AppError error) {
    switch (error) {
      case AuthenticationError():
        navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (_) => false);
      case NotFoundError(:final resource):
        _showSnackBar('$resource not found.');
      case ConflictError(:final message):
        _showDialog(title: 'Conflict', body: message);
      case RateLimitError(:final retryAfter):
        _showSnackBar('Too many requests. Retry in ${retryAfter.inSeconds}s.');
      case NetworkError():
        _showSnackBar('Connection lost. Check your network.');
      case UnexpectedError():
        AppLogger.instance.error('Unhandled error', error: error);
    }
  }

  void _showSnackBar(String text) =>
    messengerKey.currentState?.showSnackBar(SnackBar(content: Text(text)));

  void _showDialog({required String title, required String body}) {
    final ctx = navigatorKey.currentContext;
    if (ctx != null) showDialog(context: ctx, builder: (_) => AlertDialog(title: Text(title), content: Text(body)));
  }
}
```

---

## Sentry Integration

Use Sentry for crash reporting in all environments except local debug builds. Wrap app initialization with `SentryFlutter.init` and capture errors from Flutter's framework, the platform dispatcher, and Bloc.

```dart
// main.dart
Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn = const String.fromEnvironment('SENTRY_DSN');
      options.environment = const String.fromEnvironment('APP_ENV', defaultValue: 'development');
      options.tracesSampleRate = 0.2;
      options.attachScreenshot = true;
      options.sendDefaultPii = false;
    },
    appRunner: () => runApp(SentryWidget(child: const App())),
  );
}
```

Create an `ErrorRadarDelegate` interface so the domain never depends on the Sentry SDK directly.

```dart
// domain/services/error_radar_delegate.dart
abstract class ErrorRadarDelegate {
  Future<void> captureError(Object error, {StackTrace? stackTrace, Map<String, dynamic>? extras});
}

// infrastructure/sentry/sentry_error_radar.dart
class SentryErrorRadar implements ErrorRadarDelegate {
  @override
  Future<void> captureError(Object error, {StackTrace? stackTrace, Map<String, dynamic>? extras}) async {
    await Sentry.captureException(error, stackTrace: stackTrace, withScope: (scope) {
      extras?.forEach((key, value) => scope.setExtra(key, value));
    });
  }
}

// infrastructure/sentry/sentry_bloc_observer.dart
class SentryBlocObserver extends BlocObserver {
  final ErrorRadarDelegate _radar;
  const SentryBlocObserver(this._radar);

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    _radar.captureError(error, stackTrace: stackTrace, extras: {'bloc': bloc.runtimeType.toString()});
    super.onError(bloc, error, stackTrace);
  }
}
```

---

## Event Enrichment

Attach user identity, device metadata, and navigation breadcrumbs to every Sentry event so errors have full context.

```dart
// ✅ Good — enrich scope after successful authentication
void configureUserScope(User user) {
  Sentry.configureScope((scope) {
    scope.setUser(SentryUser(id: user.id, email: user.email));
    scope.setTag('app_version', AppConfig.version);
    scope.setTag('flavor', AppConfig.flavor);
    scope.setTag('os', Platform.operatingSystem);
  });
}

// ✅ Good — breadcrumbs for navigation events
class SentryNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    Sentry.addBreadcrumb(Breadcrumb(
      category: 'navigation', message: 'Pushed ${route.settings.name}', level: SentryLevel.info,
    ));
  }
}
```

```dart
// ❌ Bad — no user context, no tags, no breadcrumbs
Sentry.captureException(error);
// Stack trace alone does not tell you who was affected or what they were doing
```

---

## Debug Symbol Upload

Without debug symbols, Sentry shows obfuscated stack traces. Configure Codemagic CI to upload dSYMs (iOS) and ProGuard mappings (Android) after every release build.

```yaml
# codemagic.yaml (relevant section)
scripts:
  - name: Upload iOS debug symbols to Sentry
    script: |
      sentry-cli upload-dif \
        --org "$SENTRY_ORG" --project "$SENTRY_PROJECT" \
        --auth-token "$SENTRY_AUTH_TOKEN" \
        build/ios/archive/Runner.xcarchive/dSYMs

  - name: Upload Android mapping file to Sentry
    script: |
      sentry-cli upload-proguard \
        --org "$SENTRY_ORG" --project "$SENTRY_PROJECT" \
        --auth-token "$SENTRY_AUTH_TOKEN" \
        build/app/outputs/mapping/release/mapping.txt
```

Store `SENTRY_ORG`, `SENTRY_PROJECT`, and `SENTRY_AUTH_TOKEN` as encrypted environment variables in Codemagic.

---

## Structured Logging with Loki

Use a singleton `AppLogger` for structured log entries. In production, logs ship to Grafana Loki. In development, they print to the console.

```dart
// infrastructure/logger/app_logger.dart
class AppLogger {
  AppLogger._();
  static final AppLogger instance = AppLogger._();

  void info(String message, {Map<String, dynamic>? data}) => _log('INFO', message, data: data);
  void warning(String message, {Map<String, dynamic>? data}) => _log('WARNING', message, data: data);
  void success(String message, {Map<String, dynamic>? data}) => _log('SUCCESS', message, data: data);
  void request(String method, String url, {Map<String, dynamic>? headers}) =>
    _log('REQUEST', '$method $url', data: {'headers': headers});
  void response(String method, String url, int statusCode, {Duration? duration}) =>
    _log('RESPONSE', '$method $url [$statusCode]', data: {
      'statusCode': statusCode, if (duration != null) 'durationMs': duration.inMilliseconds,
    });

  void error(String message, {Object? error, StackTrace? stackTrace, Map<String, dynamic>? data}) {
    _log('ERROR', message, data: {
      ...?data, if (error != null) 'error': error.toString(),
      if (stackTrace != null) 'stackTrace': stackTrace.toString(),
    });
  }

  void _log(String level, String message, {Map<String, dynamic>? data}) {
    final entry = {'level': level, 'message': message, 'timestamp': DateTime.now().toIso8601String(), ...?data};
    debugPrint(entry.toString()); // In production, forward to Loki instead
  }
}
```

```dart
// infrastructure/http/interceptor_http_client.dart
class InterceptorHttpClient extends http.BaseClient {
  final http.Client _inner;
  final AppLogger _logger;
  InterceptorHttpClient(this._inner, this._logger);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    _logger.request(request.method, request.url.toString());
    final stopwatch = Stopwatch()..start();
    final response = await _inner.send(request);
    stopwatch.stop();
    _logger.response(request.method, request.url.toString(), response.statusCode, duration: stopwatch.elapsed);
    return response;
  }
}
```

```dart
// ✅ Good — use the interceptor client for all HTTP calls
final client = InterceptorHttpClient(http.Client(), AppLogger.instance);
```

```dart
// ❌ Bad — using print() for logging
print('API call to /users returned 200'); // No structure, no level, lost in noise
```

---

## Anti-Patterns

### Using print() instead of structured logger

```dart
// ❌ Bad — print() has no log level, no timestamps, no structured data
void fetchUser() { print('fetching user...'); }
```

Use `AppLogger.instance.info(...)` so logs can be filtered, searched, and correlated.

### No error categorization

```dart
// ❌ Bad — catching everything as a generic string
try { await api.getUser(id); } catch (e) { showSnackBar('Something went wrong: $e'); }
```

Map every server response to a typed `AppError` subclass so the presentation layer reacts appropriately.

### Catching errors without reporting

```dart
// ❌ Bad — error is swallowed silently
try { await riskyOperation(); } catch (_) { /* Do nothing */ }
```

At minimum, report to `ErrorRadarDelegate` so the error appears in Sentry. Silent catches hide production bugs.

### No debug symbols in CI

Building release artifacts without uploading dSYMs or ProGuard mappings means obfuscated Sentry traces. Symbol upload must be a mandatory CI step.

### Logging sensitive user data

```dart
// ❌ Bad — logging the entire user object including tokens and PII
AppLogger.instance.info('User logged in', data: {'user': user.toJson()});
```

Log only identifiers (`userId`, `email`), never tokens, passwords, or data under privacy regulations.
