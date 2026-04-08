# Firebase

Firebase is the backbone of mobile infrastructure in our Flutter projects. This guide covers multi-flavor configuration, push notifications, analytics, remote config, and in-app messaging — all wired through Clean Architecture with Bloc-based state management.

---

## Multi-Flavor Configuration

Every project runs three flavors: `development`, `staging`, and `production`. Each flavor uses its own Firebase project to isolate data.

Use `flutterfire configure` to generate options per flavor:

```bash
flutterfire configure --project=my-app-dev --out=lib/firebase/firebase_options_development.dart
flutterfire configure --project=my-app-stg --out=lib/firebase/firebase_options_staging.dart
flutterfire configure --project=my-app-prod --out=lib/firebase/firebase_options_production.dart
```

On iOS, store flavor-specific plists under `ios/config/{flavor}/GoogleService-Info.plist` and add an Xcode **Run Script** build phase to copy the correct one:

```bash
FLAVOR="${PRODUCT_BUNDLE_IDENTIFIER##*.}"
if [ "$FLAVOR" == "dev" ]; then
  cp "${PROJECT_DIR}/config/development/GoogleService-Info.plist" \
     "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/GoogleService-Info.plist"
elif [ "$FLAVOR" == "stg" ]; then
  cp "${PROJECT_DIR}/config/staging/GoogleService-Info.plist" \
     "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/GoogleService-Info.plist"
else
  cp "${PROJECT_DIR}/config/production/GoogleService-Info.plist" \
     "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/GoogleService-Info.plist"
fi
```

Initialize Firebase **before** `runApp()` with the correct options:

```dart
// ✅ Good — initialize Firebase before runApp with flavor-specific options
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firebaseOptions = switch (AppFlavor.current) {
    Flavor.development => FirebaseOptionsDevelopment.currentPlatform,
    Flavor.staging     => FirebaseOptionsStaging.currentPlatform,
    Flavor.production  => FirebaseOptionsProduction.currentPlatform,
  };
  await Firebase.initializeApp(options: firebaseOptions);
  runApp(const App());
}
```

```dart
// ❌ Bad — initializing Firebase after runApp causes crashes
void main() {
  runApp(const App());
  Firebase.initializeApp(); // Too late — plugins are already running
}
```

---

## Push Notifications

Use `firebase_messaging` for FCM and `flutter_local_notifications` for foreground display. The architecture follows Clean Architecture across all layers.

**Data layer** — wraps the FCM SDK:

```dart
class FirebaseMessagingDataSource {
  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  FirebaseMessagingDataSource({
    required FirebaseMessaging messaging,
    required FlutterLocalNotificationsPlugin localNotifications,
  })  : _messaging = messaging,
        _localNotifications = localNotifications;

  Future<String?> getToken() => _messaging.getToken();

  Future<NotificationSettings> requestPermission() =>
      _messaging.requestPermission(alert: true, badge: true, sound: true);

  Stream<RemoteMessage> get onForegroundMessage =>
      FirebaseMessaging.onMessage;
}
```

**Domain layer** — no Firebase imports:

```dart
abstract class INotificationRepository {
  TaskEither<NotificationError, String> getToken();
  TaskEither<NotificationError, bool> requestPermission();
  Stream<NotificationPayload> get onNotificationReceived;
}
```

**Presentation layer** — Bloc manages permission and token state:

```dart
class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final RequestNotificationPermissionUseCase _requestPermission;
  final GetNotificationTokenUseCase _getToken;

  NotificationBloc({
    required RequestNotificationPermissionUseCase requestPermission,
    required GetNotificationTokenUseCase getToken,
  })  : _requestPermission = requestPermission,
        _getToken = getToken,
        super(const NotificationState.initial()) {
    on<NotificationPermissionRequested>(_onPermissionRequested);
    on<NotificationTokenRequested>(_onTokenRequested);
  }

  Future<void> _onPermissionRequested(
    NotificationPermissionRequested event,
    Emitter<NotificationState> emit,
  ) async {
    final result = await _requestPermission.execute().run();
    result.fold(
      (error) => emit(state.copyWith(permission: PermissionStatus.denied)),
      (granted) => emit(state.copyWith(
        permission: granted ? PermissionStatus.granted : PermissionStatus.denied,
      )),
    );
  }
}
```

Register background and terminated-state handlers in `main.dart`:

```dart
// ✅ Good — handle all three app states
FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
final initialMessage = await FirebaseMessaging.instance.getInitialMessage();

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}
```

---

## Firebase Analytics

Analytics events must respect user privacy. On iOS, App Tracking Transparency (ATT) consent is required before logging.

**Data layer** — wraps the Firebase Analytics SDK:

```dart
class AnalyticsDataSource {
  final FirebaseAnalytics _analytics;
  AnalyticsDataSource({required FirebaseAnalytics analytics})
      : _analytics = analytics;

  Future<void> logEvent({required String name, Map<String, Object>? parameters}) =>
      _analytics.logEvent(name: name, parameters: parameters);

  Future<void> setAnalyticsCollectionEnabled(bool enabled) =>
      _analytics.setAnalyticsCollectionEnabled(enabled);
}
```

**Domain layer** — framework-agnostic interface:

```dart
abstract class IAnalyticsRepository {
  TaskEither<AnalyticsError, Unit> logEvent(AnalyticsEvent event);
  TaskEither<AnalyticsError, Unit> setTrackingEnabled(bool enabled);
}
```

**ATT integration** — request consent before enabling collection:

```dart
// ✅ Good — request ATT permission before logging events on iOS
Future<void> _onTrackingConsentRequested(
  TrackingConsentRequested event,
  Emitter<AnalyticsState> emit,
) async {
  if (Platform.isIOS) {
    final status = await AppTrackingTransparency.requestTrackingAuthorization();
    final allowed = status == TrackingStatus.authorized;
    await _setTracking.execute(enabled: allowed).run();
    emit(state.copyWith(trackingEnabled: allowed));
  } else {
    await _setTracking.execute(enabled: true).run();
    emit(state.copyWith(trackingEnabled: true));
  }
}
```

```dart
// ❌ Bad — logging analytics without checking ATT consent on iOS
await _logEvent.execute(event.analyticsEvent).run(); // Violates App Store guidelines
```

---

## Remote Config

Use `firebase_remote_config` for server-driven feature flags, minimum app versions, and A/B test parameters.

**Data layer** — fetches and caches values:

```dart
class RemoteConfigDataSource {
  final FirebaseRemoteConfig _remoteConfig;
  RemoteConfigDataSource({required FirebaseRemoteConfig remoteConfig})
      : _remoteConfig = remoteConfig;

  Future<void> initialize({
    required Map<String, dynamic> defaults,
    required Duration minimumFetchInterval,
  }) async {
    await _remoteConfig.setDefaults(defaults);
    await _remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: minimumFetchInterval,
    ));
  }

  Future<void> fetchAndActivate() => _remoteConfig.fetchAndActivate();
  String getString(String key) => _remoteConfig.getString(key);
  bool getBool(String key) => _remoteConfig.getBool(key);
}
```

**Domain layer** — repository interface:

```dart
abstract class IRemoteConfigRepository {
  TaskEither<RemoteConfigError, Unit> initialize();
  TaskEither<RemoteConfigError, Unit> fetchAndActivate();
  Either<RemoteConfigError, String> getString(String key);
  Either<RemoteConfigError, bool> getBool(String key);
}
```

**Presentation layer** — load config on app start:

```dart
class RemoteConfigBloc extends Bloc<RemoteConfigEvent, RemoteConfigState> {
  final InitializeRemoteConfigUseCase _initialize;
  final FetchRemoteConfigUseCase _fetch;
  final GetRemoteConfigValueUseCase _getValue;

  RemoteConfigBloc({
    required InitializeRemoteConfigUseCase initialize,
    required FetchRemoteConfigUseCase fetch,
    required GetRemoteConfigValueUseCase getValue,
  })  : _initialize = initialize,
        _fetch = fetch,
        _getValue = getValue,
        super(const RemoteConfigState.initial()) {
    on<RemoteConfigLoadRequested>(_onLoadRequested);
  }

  Future<void> _onLoadRequested(
    RemoteConfigLoadRequested event,
    Emitter<RemoteConfigState> emit,
  ) async {
    emit(state.copyWith(status: RemoteConfigStatus.loading));
    final initResult = await _initialize.execute().run();
    final fetchResult = await _fetch.execute().run();
    if (initResult.isLeft() || fetchResult.isLeft()) {
      emit(state.copyWith(status: RemoteConfigStatus.failure));
      return;
    }
    final maintenance = _getValue.getBool('maintenance_mode').getOrElse((_) => false);
    final minVersion = _getValue.getString('min_app_version').getOrElse((_) => '1.0.0');
    emit(state.copyWith(
      status: RemoteConfigStatus.success,
      maintenanceMode: maintenance,
      minAppVersion: minVersion,
    ));
  }
}
```

---

## In-App Messaging

Firebase In-App Messaging requires minimal code. Messages are created and scheduled from the Firebase Console.

```yaml
# pubspec.yaml
dependencies:
  firebase_in_app_messaging: ^0.8.0
```

The plugin is automatically initialized with Firebase. No additional code is needed beyond the dependency. To suppress messages on specific screens (e.g., onboarding):

```dart
// ✅ Good — suppress messages during onboarding, re-enable after
await FirebaseInAppMessaging.instance.setMessagesSuppressed(true);
// ... onboarding flow ...
await FirebaseInAppMessaging.instance.setMessagesSuppressed(false);
```

---

## Anti-Patterns

**Hardcoding Firebase config** — Use flavor-specific options, never a single default config for all environments. Mixing development and production data leads to polluted analytics and accidental push notifications to real users.

**Ignoring permission denial** — Always check the authorization status after requesting notification permission. Calling `getToken()` without granted permission returns `null` silently.

**Tracking without ATT consent on iOS** — Logging analytics events before requesting App Tracking Transparency authorization violates App Store Review Guidelines. Always gate analytics collection behind the ATT prompt.

**No default values for Remote Config** — On first launch (before the first fetch completes), all Remote Config values return empty strings, `false`, or `0`. Always call `setDefaults()` before `fetchAndActivate()`.

**Initializing Firebase after runApp** — Firebase plugins may be used by widgets during build. Calling `Firebase.initializeApp()` after `runApp()` causes `LateInitializationError` or silent failures.
