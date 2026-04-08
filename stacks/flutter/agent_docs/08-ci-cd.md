# CI/CD

## Overview

Codemagic is the CI/CD platform used for all Flutter projects. It handles building, testing, code signing, and distributing applications to multiple targets:

- **Firebase App Distribution** — internal testing for dev and staging builds (Android).
- **TestFlight** — iOS beta distribution to internal and external testers.
- **App Store Connect** — production iOS releases.
- **Google Play** — production Android releases.

Every project must have a `codemagic.yaml` file at the repository root. Manual builds and ad-hoc distribution are not acceptable for any environment beyond local development.

---

## YAML Configuration

The `codemagic.yaml` file defines one or more **workflows**. Each workflow represents a build-and-deploy pipeline for a specific environment (staging, production, etc.).

```yaml
# codemagic.yaml — minimal workflow structure
workflows:
  staging-deploy:
    name: "[STG] iOS & Android deploy"
    instance_type: mac_mini_m2
    max_build_duration: 60
    environment:
      flutter: 3.29.0
      android_signing:
        - project_upload_ks
      ios_signing:
        distribution_type: app_store
        bundle_identifier: com.avilatek.example.stg
      groups:
        - firebase_credentials
        - play_store_credentials
        - staging
        - all
    cache:
      cache_paths:
        - $HOME/.gradle/caches
        - $FLUTTER_ROOT/.pub-cache
        - $HOME/Library/Caches/CocoaPods
    triggering:
      events:
        - push
      branch_patterns:
        - pattern: "staging"
          include: true
    scripts:
      # build scripts go here
    artifacts:
      - build/**/outputs/**/*.aab
      - build/**/outputs/**/*.apk
      - build/ios/ipa/*.ipa
    publishing:
      # distribution targets go here
```

```yaml
# ✅ Good — one workflow per environment with explicit trigger
workflows:
  staging-deploy:
    triggering:
      branch_patterns:
        - pattern: "staging"
  production-deploy:
    triggering:
      branch_patterns:
        - pattern: "main"
```

```yaml
# ❌ Bad — single workflow that tries to handle all environments
workflows:
  deploy-all:
    triggering:
      branch_patterns:
        - pattern: "*"
```

---

## Environment Variables

Store all secrets and environment-specific values in the Codemagic UI under **variable groups**. Reference these groups in the `environment.groups` block of each workflow.

### Standard Variable Groups

| Group | Purpose |
|---|---|
| `staging` | Environment variables for the staging build |
| `production` | Environment variables for the production build |
| `firebase_credentials` | Firebase service account JSON |
| `play_store_credentials` | Google Cloud service account JSON for Google Play |
| `all` | Variables shared across all environments |

### Adding Variables in Codemagic

1. Navigate to your application settings in Codemagic.
2. Open the **Environment variables** tab.
3. Add each variable with the correct group assignment.
4. Mark sensitive values (API keys, service account JSON, signing credentials) as **Secure**.

```yaml
# ✅ Good — secrets referenced via groups, not hardcoded
environment:
  groups:
    - firebase_credentials
    - staging
```

```yaml
# ❌ Bad — secrets hardcoded in the YAML file
environment:
  vars:
    API_KEY: "sk-live-abc123..."
    FIREBASE_TOKEN: "1//0eXxXxXx..."
```

> Secure variables cannot be read back after creation. Always store a copy of sensitive credentials in the team's secret vault.

---

## Build Scripts

The `scripts` block defines the pipeline stages that run sequentially. A standard pipeline includes: dependency installation, testing, and artifact building.

### Dependency Installation

```yaml
scripts:
  - name: Install dependencies
    script: flutter pub get
```

### Running Tests

```yaml
  - name: Run tests
    script: flutter test
```

### Building Artifacts

For **multi-flavor** apps, use `--flavor` and `--dart-define-from-file` to select the correct configuration.

```yaml
  - name: Set up environment variables
    script: |
      # Write environment variables to a JSON file for --dart-define-from-file
      cat <<EOF > env.json
      {
        "API_HOST": "$API_HOST",
        "SENTRY_DSN": "$SENTRY_DSN"
      }
      EOF

  - name: Build Android (AAB)
    script: |
      flutter build appbundle \
        --release \
        --flavor staging \
        --dart-define-from-file=env.json

  - name: Build iOS (IPA)
    script: |
      flutter build ipa \
        --release \
        --flavor staging \
        --dart-define-from-file=env.json \
        --export-options-plist=/Users/builder/export_options.plist
```

```shell
# ✅ Good — flavor and env file passed explicitly
flutter build appbundle --release --flavor staging --dart-define-from-file=env.json

# ❌ Bad — hardcoded values instead of environment variables
flutter build appbundle --release --dart-define=API_HOST=https://api.example.com
```

---

## Distribution

Configure distribution targets in the `publishing` block of each workflow.

### Firebase App Distribution (Android Internal Testing)

```yaml
publishing:
  firebase:
    firebase_service_account: $FIREBASE_SERVICE_ACCOUNT_CREDENTIALS
    android:
      app_id: $STG_FIREBASE_APPLICATION_ID
      groups:
        - beta-testers
```

Create a Firebase service account key following the [Codemagic documentation](https://docs.codemagic.io/yaml-publishing/firebase-app-distribution/) and store the JSON content in the `FIREBASE_SERVICE_ACCOUNT_CREDENTIALS` variable under the `firebase_credentials` group.

### TestFlight (iOS Beta)

```yaml
publishing:
  app_store_connect:
    auth: integration
    submit_to_testflight: true
    beta_groups:
      - Internal Testers
      - External Testers

integrations:
  app_store_connect: Avila Tek CA
```

The first TestFlight upload may fail at the publishing stage because the beta groups do not yet exist in App Store Connect. The binary still uploads; create the groups manually in App Store Connect and re-run.

### Google Play (Android Production)

```yaml
publishing:
  google_play:
    credentials: $GCLOUD_SERVICE_ACCOUNT_CREDENTIALS
    track: internal
    submit_as_draft: true
```

Create a Google Cloud service account at the **organization level** in GCP, grant it the **Service Account User** role, and invite it to Google Play Console. Store the JSON key in the `GCLOUD_SERVICE_ACCOUNT_CREDENTIALS` variable under the `play_store_credentials` group.

---

## Android Keystore

Release builds for Android require a signed keystore. Generate one with `keytool` and upload it to Codemagic.

### Generate a Keystore

```shell
keytool -genkey -v \
  -keystore upload-keystore.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload
```

> Store the keystore file and its password in the team's secret vault. Losing the keystore means losing the ability to update the app on Google Play.

### Upload to Codemagic

1. In Codemagic, navigate to **Teams** > select your team > **Code signing identities** > **Android keystores**.
2. Upload the `.jks` file and fill in the alias, keystore password, and key password.
3. Name the keystore with the convention `{project}_{type}_ks` (e.g., `avilatek_upload_ks`).

### Reference in YAML

```yaml
environment:
  android_signing:
    - avilatek_upload_ks
```

Codemagic automatically injects the keystore during the build process. No `key.properties` file is needed when using Codemagic's code signing identities.

---

## iOS Provisioning and Certificates

Apple distribution certificates expire after one year. When a certificate expires, all provisioning profiles associated with it become invalid and must be regenerated.

### Renewing Certificates

1. In Codemagic, go to **Teams** > your team > **Code signing identities** > **iOS certificates**.
2. Delete the expired certificate.
3. Click **Generate certificate**, select the distribution type, choose the correct App Store Connect API key, and create the certificate.

### Creating New Provisioning Profiles

1. Open the [Apple Developer Profiles](https://developer.apple.com/account/resources/profiles/list) page.
2. Delete expired profiles.
3. Click **+** to create a new profile. Select **App Store Connect** under **Distribution**.
4. Choose the correct bundle ID. For multi-flavor apps, create one profile per flavor.
5. Select the certificate generated in the previous step.

### Downloading Profiles to Codemagic

1. Return to Codemagic under **Code signing identities** > **iOS provisioning profiles**.
2. Click **Fetch profiles** and select the API key for the team.
3. Select the new profiles, assign them names, and click **Download selected**.

After completing these steps, iOS builds will use the renewed certificate and profiles automatically.

---

## Anti-Patterns

### Committing Secrets to the Repository

Never store API keys, service account JSON files, keystore files, or any credentials in version control. Use Codemagic environment variable groups with the **Secure** flag enabled.

### No Test Stage in the CI Pipeline

Every workflow must include a `flutter test` step before building artifacts. Skipping tests in CI defeats the purpose of continuous integration and allows regressions to reach distribution.

```yaml
# ✅ Good — tests run before build
scripts:
  - name: Install dependencies
    script: flutter pub get
  - name: Run tests
    script: flutter test
  - name: Build Android
    script: flutter build appbundle --release --flavor staging
```

```yaml
# ❌ Bad — no test step, build only
scripts:
  - name: Install dependencies
    script: flutter pub get
  - name: Build Android
    script: flutter build appbundle --release --flavor staging
```

### Manual Builds for Releases

All staging and production builds must go through Codemagic. Never build a release artifact locally and upload it manually to the App Store or Google Play. Manual builds are unreproducible and bypass CI checks.

### Hardcoded Flavor or Environment Values

Build commands must use `--flavor` and `--dart-define-from-file` (or `--dart-define`) with values sourced from Codemagic environment variables. Hardcoding URLs, API keys, or flavor names in build scripts makes it impossible to reuse workflows across environments.

### Skipping Code Signing Setup

Both Android and iOS require proper code signing before distribution. Failing to configure the keystore (Android) or provisioning profiles (iOS) results in unsigned builds that cannot be installed on real devices or uploaded to stores.
