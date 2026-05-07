# Flutter — Security Reference (OWASP Mobile Top 10)

## M1 · Improper Credential Usage

Never store sensitive data in `SharedPreferences` — it is unencrypted plaintext on the device. Use `flutter_secure_storage` for auth tokens, API keys, and any PII:

```dart
// ✅ flutter_secure_storage — encrypted on iOS (Keychain) and Android (Keystore)
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

await _storage.write(key: 'auth_token', value: token);
final token = await _storage.read(key: 'auth_token');
await _storage.delete(key: 'auth_token');

// ❌ SharedPreferences — unencrypted, accessible on rooted devices
final prefs = await SharedPreferences.getInstance();
await prefs.setString('auth_token', token); // never for sensitive data
```

Auth tokens managed centrally via `HttpHeadersInjector` — never scattered across HTTP calls:

```dart
// ✅ One place to set/clear auth headers
class HttpHeadersInjector {
  final Map<String, String> _headers = {};
  void setAuthToken(String token) => _headers['Authorization'] = 'Bearer $token';
  void clear() => _headers.clear();
  Map<String, String> get headers => Map.unmodifiable(_headers);
}
```

## M2 · Inadequate Supply Chain Security

Pin dependencies in `pubspec.yaml` using exact or constrained versions. Run `flutter pub outdated` regularly. Audit packages before adding them — prefer widely-used, actively maintained packages.

```bash
flutter pub outdated        # check for outdated dependencies
dart pub audit              # check for known vulnerabilities
```

## M3 · Insecure Authentication/Authorization

Session lifecycle managed by a top-level `UserBloc` — never scattered across individual BLoCs or screens:

```dart
// ✅ UserBloc at root — single source of truth for session
BlocProvider(
  create: (_) => userBloc..add(const UserStarted()),
  child: const App(),
)

// UserBloc handles: startup session check, login, logout, token refresh
// emits UserAuthenticated / UserUnauthenticated
```

Token refresh: use `RefreshTokenInterceptor` to transparently retry on 401. Emit `UserLoggedOut` when refresh fails — never silently ignore:

```dart
// ✅ On refresh failure — force re-authentication
} catch (_) {
  _userBloc.add(const UserLoggedOut()); // clear session and redirect to login
  return response;
}
// ❌ Never silently swallow refresh failures
```

## M4 · Insufficient Input/Output Validation

Validate all user input before sending to the API. Validate all API responses before use in domain logic:

```dart
// ✅ DTO validation on parse
class UserDto {
  final String id;
  final String email;

  UserDto.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String? ?? (throw FormatException('missing id')),
        email = json['email'] as String? ?? (throw FormatException('missing email'));
}

// ✅ Repository maps API exceptions to domain errors — never expose HTTP details to domain
try {
  final dto = UserDto.fromJson(response.data);
  return Right(dto.toEntity());
} on FormatException catch (e) {
  return Left(UnexpectedApiResponseError(e.message));
} on DioException catch (e) {
  return Left(_mapNetworkError(e));
}
```

## M5 · Insecure Communication

Enforce HTTPS for all API communication. For production apps, consider certificate pinning to prevent MITM attacks:

```dart
// ✅ Certificate pinning with http_certificate_pinning or custom validator
SecurityContext context = SecurityContext.defaultContext;
// Add your certificate fingerprint verification

// ❌ Never disable certificate verification
(httpClient.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
  final client = HttpClient();
  client.badCertificateCallback = (_, __, ___) => true; // NEVER in production
  return client;
};
```

Debug builds may relax certificate checking — ensure this is gated behind `kDebugMode`.

## M6 · Inadequate Privacy Controls

Never log sensitive user data. Use structured logging that excludes PII:

```dart
// ✅ Log the action, not the data
logger.info('User authenticated', {'user_id': userId});

// ❌ Never log tokens, passwords, or PII
logger.debug('Token: $token');       // credentials in logs
logger.debug('Password: $password'); // never
logger.debug('User data: $userJson'); // may contain PII
```

Clear sensitive data from memory when no longer needed (e.g., on logout):

```dart
Future<void> _onLoggedOut(UserLoggedOut event, Emitter<UserState> emit) async {
  await _clearSession.execute().run();
  _headersInjector.clear();     // clear auth headers
  emit(const UserUnauthenticated());
}
```

## M7 · Insufficient Binary Protections

Enable obfuscation for release builds:

```bash
# ✅ Obfuscate release builds
flutter build apk --obfuscate --split-debug-info=build/debug-info
flutter build ipa --obfuscate --split-debug-info=build/debug-info
```

Never include debug symbols, API keys, or environment secrets in the shipped binary. Use `--dart-define` or `--dart-define-from-file` for build-time config:

```bash
flutter build apk --dart-define=API_URL=https://api.prod.com
```

## M8 · Security Misconfiguration

Disable debug features in production builds:

```dart
// ✅ Debug-only code gated
if (kDebugMode) {
  // verbose logging, mock data, etc.
}

// ❌ Debug flags active in release
FlutterError.onError = (details) => print(details); // leaks stack traces in prod
```

Android `AndroidManifest.xml` — set `android:debuggable="false"` in release manifest. iOS — disable `NSAllowsArbitraryLoads` in production `Info.plist`.

## M9 · Insecure Data Storage

Beyond auth tokens (M1), apply secure storage broadly:

| Data Type | Storage |
|---|---|
| Auth tokens, API keys | `flutter_secure_storage` |
| User preferences, non-sensitive settings | `SharedPreferences` |
| Large files, documents | File system with proper permissions |
| Sensitive documents (medical, financial) | Encrypted file storage |

VPN detection for compliance-sensitive apps — use `vpn_check` via the domain layer:

```dart
abstract class VpnRepository {
  TaskEither<VpnError, bool> isVpnActive();
}
```

## M10 · Insufficient Cryptography

Use platform-provided cryptographic primitives. Never implement custom crypto:

```dart
// ✅ Use dart:crypto or well-maintained packages
import 'dart:convert';
import 'package:crypto/crypto.dart';

final hash = sha256.convert(utf8.encode(data)).toString();

// ❌ Never implement custom hash, encryption, or signing algorithms
```

## Verification Checklist

- [ ] All auth tokens in `flutter_secure_storage`, not `SharedPreferences`
- [ ] `HttpHeadersInjector` manages auth headers centrally
- [ ] `UserBloc` at root — single source of truth for session state
- [ ] `RefreshTokenInterceptor` retries on 401; emits `UserLoggedOut` on refresh failure
- [ ] All API responses validated with `fromJson` before domain use
- [ ] HTTPS enforced for all API calls; no `badCertificateCallback = true` in production
- [ ] No tokens, passwords, or PII in logs
- [ ] Release builds use `--obfuscate --split-debug-info`
- [ ] No debug flags active in release builds
- [ ] `dart pub audit` and `flutter pub outdated` run in CI
