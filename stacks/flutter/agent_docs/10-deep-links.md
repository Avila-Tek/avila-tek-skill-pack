# Deep Links

## Overview

Deep links allow users to open specific screens inside the app from external sources such as browsers, emails, or push notifications. This guide covers Android App Links, iOS Universal Links, well-known file hosting, a global `DeepLinkBloc`, and testing strategies using the [`app_links`](https://pub.dev/packages/app_links) package.

---

## Setup

Add the dependency and disable Flutter's built-in deep linking on **both** platforms so `app_links` has full control.

```yaml
dependencies:
  app_links: ^6.3.2
```

**Android** -- add inside the `<activity>` element with `.MainActivity` in `AndroidManifest.xml`:

```xml
<meta-data android:name="flutter_deeplinking_enabled" android:value="false" />
```

**iOS** -- add to `Info.plist`:

```xml
<key>FlutterDeepLinkingEnabled</key>
<false/>
```

---

## Android Configuration

Add an intent filter inside the `<activity>` tag of `AndroidManifest.xml`:

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="https" android:host="example.com" />
</intent-filter>
```

### Multi-Flavor Host Configuration

Define `manifestPlaceholders` in `android/app/build.gradle` so each flavor resolves its own domain:

```gradle
productFlavors {
    production {
        dimension "default"
        applicationIdSuffix ""
        manifestPlaceholders = [appName: "AppName", appLinkHost: "example.com"]
    }
    staging {
        dimension "default"
        applicationIdSuffix ".stg"
        manifestPlaceholders = [appName: "[STG] AppName", appLinkHost: "stg.example.com"]
    }
    development {
        dimension "default"
        applicationIdSuffix ".dev"
        manifestPlaceholders = [appName: "[DEV] AppName", appLinkHost: "dev.example.com"]
    }
}
```

Then reference the placeholder in the intent filter:

```xml
// ✅ Good — domain varies per flavor automatically
<data android:scheme="https" android:host="${appLinkHost}" />
```

```xml
// ❌ Bad — hardcoded domain breaks staging and development builds
<data android:scheme="https" android:host="example.com" />
```

> For app links to work from the browser, the scheme **must** be `https`.

---

## iOS Configuration

Add the Associated Domains capability in Xcode: **Runner** target > **Signing & Capabilities** > **+ Capability** > **Associated Domains**. Click **+** and enter `applinks:<web-domain>` (e.g., `applinks:example.com`).

---

## Well-Known Files

Two server-hosted files prove domain ownership to the operating systems.

### assetlinks.json (Android)

Host at `https://<domain>/.well-known/assetlinks.json`. Obtain the SHA-256 fingerprint from the **Play Store Console** (Release > Setup > App Integrity > App signing) for production, or via `keytool` for development/staging:

```bash
keytool -list -v -keystore <path-to-keystore>
```

```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "com.example",
    "sha256_cert_fingerprints": ["FF:2A:CF:7B:DD:CC:..."]
  }
}]
```

### apple-app-site-association (iOS)

Host at `https://<domain>/.well-known/apple-app-site-association`. This file **must not** have a `.json` extension. The `appID` format is `<teamId>.<bundleId>`.

```json
{
  "applinks": {
    "apps": [],
    "details": [{
      "appIDs": ["S8QB4VV633.com.example.app"],
      "paths": ["*"],
      "components": [{ "/": "/*" }]
    }]
  },
  "webcredentials": { "apps": ["S8QB4VV633.com.example.app"] }
}
```

The `paths` array controls which URLs open the app. `*` forwards every path; narrow it when only certain routes should deep-link.

---

## DeepLinkBloc

Create a global Bloc in the `core` layer. Provide it at the highest level (typically `app.dart`) via `BlocProvider`. Three states drive navigation:

- **`DeepLinkInitial`** -- no link pending; stores authentication flag.
- **`DeepLinkLoaded`** -- a link is ready to navigate.
- **`AppLinkAuthRequired`** -- a link arrived but the user must log in first.

### States

```dart
// core/deep_link/deep_link_state.dart
part of 'deep_link_bloc.dart';

abstract class DeepLinkState {
  const DeepLinkState({this.isAuthenticated = false});
  final bool isAuthenticated;
}

class DeepLinkInitial extends DeepLinkState {
  const DeepLinkInitial({super.isAuthenticated});
}

class DeepLinkLoaded extends DeepLinkState {
  const DeepLinkLoaded({required this.link, super.isAuthenticated});
  final Uri link;
}

class AppLinkAuthRequired extends DeepLinkState {
  const AppLinkAuthRequired({required this.link, super.isAuthenticated});
  final Uri link;
}
```

### Events

Four events drive the Bloc: `DeepLinkStarted` (checks for an initial link at app launch), `AppLinkReceived` (processes an incoming URI), `UserAuthenticated` (transitions pending links after login), and `UserLoggedOut` (resets to initial state).

```dart
// core/deep_link/deep_link_event.dart
part of 'deep_link_bloc.dart';

abstract class DeepLinkEvent extends Equatable {
  const DeepLinkEvent();
  @override
  List<Object> get props => [];
}

class DeepLinkStarted extends DeepLinkEvent {
  const DeepLinkStarted({required this.isAuthenticated});
  final bool isAuthenticated;
  @override
  List<Object> get props => [isAuthenticated];
}

class AppLinkReceived extends DeepLinkEvent {
  const AppLinkReceived(this.link);
  final Uri link;
  @override
  List<Object> get props => [link];
}

class UserAuthenticated extends DeepLinkEvent {}
class UserLoggedOut extends DeepLinkEvent {}
```

### Bloc Implementation

The constructor subscribes to `AppLinks.uriLinkStream` so links received while the app is in the foreground are captured. `_onAppLinkReceived` decodes the URI and checks `urlRequiresAuthentication()` -- a project-specific helper that returns `true` for routes requiring a logged-in user.

```dart
// core/deep_link/deep_link_bloc.dart
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'deep_link_event.dart';
part 'deep_link_state.dart';

class DeepLinkBloc extends Bloc<DeepLinkEvent, DeepLinkState> {
  DeepLinkBloc() : super(const DeepLinkInitial()) {
    on<DeepLinkStarted>(_onDeepLinkStarted);
    on<AppLinkReceived>(_onAppLinkReceived);
    on<UserAuthenticated>(_onUserAuthenticated);
    on<UserLoggedOut>((event, emit) => emit(const DeepLinkInitial()));

    _sub = _appLinks.uriLinkStream.listen((uri) {
      if (uri != null) add(AppLinkReceived(uri));
    });
  }

  static final _appLinks = AppLinks();
  StreamSubscription<Uri?>? _sub;

  FutureOr<void> _onDeepLinkStarted(
    DeepLinkStarted event, Emitter<DeepLinkState> emit,
  ) async {
    emit(DeepLinkInitial(isAuthenticated: event.isAuthenticated));
    final initial = await _appLinks.getInitialLink();
    if (initial != null) add(AppLinkReceived(initial));
  }

  FutureOr<void> _onAppLinkReceived(
    AppLinkReceived event, Emitter<DeepLinkState> emit,
  ) {
    final uri = Uri.parse(Uri.decodeFull(event.link.toString()));
    if (urlRequiresAuthentication(uri) && !state.isAuthenticated) {
      emit(AppLinkAuthRequired(link: uri, isAuthenticated: state.isAuthenticated));
    } else {
      emit(DeepLinkLoaded(link: uri, isAuthenticated: state.isAuthenticated));
    }
  }

  FutureOr<void> _onUserAuthenticated(
    UserAuthenticated event, Emitter<DeepLinkState> emit,
  ) async {
    final current = state;
    await Future<void>.delayed(const Duration(seconds: 4));
    if (current is AppLinkAuthRequired) {
      emit(DeepLinkLoaded(link: current.link, isAuthenticated: true));
    } else {
      emit(const DeepLinkInitial(isAuthenticated: true));
    }
  }

  @override
  Future<void> close() { _sub?.cancel(); return super.close(); }
}
```

---

## BlocListener for Navigation

Place a `BlocListener<DeepLinkBloc, DeepLinkState>` at a level where routing is available (e.g., inside the `MaterialApp` builder or a top-level shell widget).

```dart
// ✅ Good — reacts to deep-link states and navigates accordingly
BlocListener<DeepLinkBloc, DeepLinkState>(
  listenWhen: (previous, current) => previous != current,
  listener: (context, state) async {
    if (state is AppLinkAuthRequired) {
      await context.push(LoginPage.path);
    }

    if (state is DeepLinkLoaded) {
      final uriPath = state.link.path;
      final uriQuery = state.link.query;

      final shellRoutes =
          AppShellBranch.values.map((branch) => branch.path);

      // Shell routes use go() to replace the current stack;
      // other routes use push() to add on top.
      if (shellRoutes.contains(uriPath)) {
        context.go('$uriPath?$uriQuery');
      } else {
        await context.push('$uriPath?$uriQuery');
      }
    }
  },
)
```

Forward authentication state changes so `DeepLinkBloc` transitions from `AppLinkAuthRequired` to `DeepLinkLoaded` after login:

```dart
// ✅ Good — bridges UserBloc auth changes into DeepLinkBloc
BlocListener<UserBloc, UserState>(
  listenWhen: (previous, current) => previous.status != current.status,
  listener: (context, state) {
    if (state.status.isAuthenticated) {
      context.read<DeepLinkBloc>().add(UserAuthenticated());
    }
    if (state.status.isUnauthenticated) {
      context.read<DeepLinkBloc>().add(UserLoggedOut());
    }
  },
)
```

---

## Testing Deep Links

**Android emulator** -- simulate an intent via `adb`:

```bash
adb shell 'am start -a android.intent.action.VIEW \
    -c android.intent.category.BROWSABLE \
    -d "https://<domain>/some/path"' <package-name>
```

**iOS simulator** -- use the Xcode CLI:

```bash
xcrun simctl openurl booted https://<domain>/some/path
```

**Physical device** -- open the Notes app, type the full URL, and tap it. Physical-device testing is the only way to fully validate the well-known file handshake on both platforms.

> Emulator/simulator commands verify intent-filter routing but do **not** validate the well-known files. Always test on a real device before release.

---

## Anti-Patterns

| Anti-Pattern | Why It Fails | Correct Approach |
|---|---|---|
| Not disabling Flutter's default deep linking | Both Flutter and `app_links` compete for the same URI, causing duplicate or missed navigation | Set `flutter_deeplinking_enabled` to `false` on both platforms |
| Hardcoding the domain in `AndroidManifest.xml` | Staging and development builds point at the production domain | Use `manifestPlaceholders` with `${appLinkHost}` per flavor |
| Ignoring auth-required deep links | User lands on a protected screen with no session and sees an error | Check `urlRequiresAuthentication()` and emit `AppLinkAuthRequired`; navigate after login |
| Skipping well-known file verification | The OS cannot prove domain ownership, so links open the browser instead of the app | Host `assetlinks.json` and `apple-app-site-association` at `/.well-known/` |
| Only testing on emulators/simulators | Emulator commands bypass the well-known file check; real links may still fail | Always verify on a physical device before release |
| Placing the `BlocListener` too deep in the widget tree | Deep links that arrive before the listener is mounted are silently dropped | Provide `DeepLinkBloc` at the app root and listen at the top-level shell |
