# 13 · Tooling

Build tooling is infrastructure. It should be reproducible, fast, and opinionated enough that engineers never make arbitrary choices about formatting or dependency management. Avila Tek uses Gradle with the Kotlin DSL (`build.gradle.kts`) for its expressiveness and type safety over the Groovy DSL. The Gradle wrapper (`gradlew`) pins the Gradle version in the repository, ensuring every developer and CI machine uses the same build tool version without a system installation requirement. Never install Gradle globally — always run `./gradlew`.

Code formatting is not a debate. Spotless enforces Google Java Style automatically, and Checkstyle validates structural rules that formatting cannot catch: wildcard imports, field injection annotations, test class naming. Both run in CI and block merges when violated. The philosophy is: if a rule can be automated, automate it. Code review should be for design and logic, not style.

---

## `build.gradle.kts` — Annotated

```kotlin
// build.gradle.kts
plugins {
    java
    id("org.springframework.boot") version "3.3.0"
    id("io.spring.dependency-management") version "1.1.4"
    id("com.diffplug.spotless") version "6.25.0"      // code formatting
    checkstyle                                          // structural lint
}

group = "com.avilatek"
version = "0.0.1-SNAPSHOT"

java {
    sourceCompatibility = JavaVersion.VERSION_21
    toolchain {
        languageVersion = JavaLanguageVersion.of(21)  // reproducible JDK version
    }
}

repositories {
    mavenCentral()
}

dependencies {
    // --- Web / Presentation ---
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("org.springdoc:springdoc-openapi-starter-webmvc-ui:2.5.0")

    // --- Validation ---
    implementation("org.springframework.boot:spring-boot-starter-validation")

    // --- Data Access ---
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.flywaydb:flyway-core")
    runtimeOnly("org.postgresql:postgresql")

    // --- Security ---
    implementation("org.springframework.boot:spring-boot-starter-security")
    implementation("io.jsonwebtoken:jjwt-api:0.12.5")
    runtimeOnly("io.jsonwebtoken:jjwt-impl:0.12.5")
    runtimeOnly("io.jsonwebtoken:jjwt-jackson:0.12.5")

    // --- Observability ---
    implementation("org.springframework.boot:spring-boot-starter-actuator")
    implementation("io.micrometer:micrometer-registry-prometheus")
    implementation("io.micrometer:micrometer-tracing-bridge-otel")
    implementation("io.opentelemetry.exporter:opentelemetry-exporter-otlp:1.38.0")

    // --- Configuration processor (generates IDE hints for @ConfigurationProperties) ---
    annotationProcessor("org.springframework.boot:spring-boot-configuration-processor")

    // --- Test ---
    testImplementation("org.springframework.boot:spring-boot-starter-test")  // JUnit 5, Mockito, AssertJ
    testImplementation("org.springframework.security:spring-security-test")
    testImplementation("org.testcontainers:junit-jupiter")
    testImplementation("org.testcontainers:postgresql")
    testImplementation("com.tngtech.archunit:archunit-junit5:1.3.0")
}

// --- Spotless: auto-format on build ---
spotless {
    java {
        googleJavaFormat("1.22.0")          // Google Java Format
        removeUnusedImports()
        trimTrailingWhitespace()
        endWithNewline()
    }
}

// --- Checkstyle: structural rules ---
checkstyle {
    toolVersion = "10.17.0"
    configFile = file("config/checkstyle/checkstyle.xml")
    isIgnoreFailures = false
    maxWarnings = 0
}

// --- Test configuration ---
tasks.withType<Test> {
    useJUnitPlatform()
    systemProperty("testcontainers.reuse.enable", "true")  // speed up TC in dev
}

// --- Run spotless check before build ---
tasks.named("build") {
    dependsOn("spotlessCheck")
}

// --- Gradle toolchain (reproducible JDK) ---
tasks.withType<JavaCompile> {
    options.compilerArgs.addAll(listOf("-Xlint:all", "-Werror"))
}
```

---

## `settings.gradle.kts`

```kotlin
// settings.gradle.kts
rootProject.name = "avilatek-service"

pluginManagement {
    repositories {
        gradlePluginPortal()
        mavenCentral()
    }
}
```

---

## Checkstyle Configuration

```xml
<!-- config/checkstyle/checkstyle.xml -->
<?xml version="1.0"?>
<!DOCTYPE module PUBLIC
    "-//Checkstyle//DTD Checkstyle Configuration 1.3//EN"
    "https://checkstyle.org/dtds/configuration_1_3.dtd">

<module name="Checker">
    <property name="severity" value="error"/>
    <property name="charset" value="UTF-8"/>

    <module name="TreeWalker">

        <!-- No wildcard imports -->
        <module name="AvoidStarImport"/>

        <!-- No field injection (@Autowired on fields) -->
        <module name="IllegalAnnotation">
            <property name="illegalAnnotations" value="Autowired"/>
            <property name="tokens" value="VARIABLE_DEF"/>
        </module>

        <!-- No System.out / System.err -->
        <module name="Regexp">
            <property name="format" value="System\.(out|err)\.print"/>
            <property name="illegalPattern" value="true"/>
            <property name="message" value="Use SLF4J for logging, not System.out/err"/>
        </module>

        <!-- Test class naming -->
        <module name="TypeName">
            <property name="format" value="^[A-Z][a-zA-Z0-9]*(Test|IT|Tests|Spec)?$"/>
        </module>

    </module>
</module>
```

---

## Gradle Wrapper

The wrapper pins the Gradle version. Always commit `gradlew`, `gradlew.bat`, and `gradle/wrapper/` to version control.

```bash
# Generate or update the wrapper
./gradlew wrapper --gradle-version=8.8

# Always use the wrapper — never the system Gradle
./gradlew build
./gradlew test
./gradlew spotlessApply   # auto-format all Java files
./gradlew spotlessCheck   # check formatting without applying
./gradlew checkstyleMain  # run Checkstyle on main source set
```

---

## Docker Compose for Local Development

```yaml
# compose.yml — local development services
services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_DB: avilatek_dev
      POSTGRES_USER: avilatek
      POSTGRES_PASSWORD: localdev
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U avilatek -d avilatek_dev"]
      interval: 10s
      timeout: 5s
      retries: 5

  prometheus:
    image: prom/prometheus:v2.53.0
    volumes:
      - ./config/prometheus.yml:/etc/prometheus/prometheus.yml
    ports:
      - "9090:9090"

  grafana:
    image: grafana/grafana:11.1.0
    environment:
      GF_SECURITY_ADMIN_PASSWORD: admin
    ports:
      - "3001:3000"
    depends_on:
      - prometheus

volumes:
  postgres_data:
```

```dockerfile
# Dockerfile — production image
FROM eclipse-temurin:21-jre-alpine AS runtime

WORKDIR /app

# Create non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy the fat jar built by Spring Boot
COPY build/libs/*.jar app.jar

USER appuser

EXPOSE 8080 9090

ENTRYPOINT ["java", "-XX:+UseContainerSupport", "-XX:MaxRAMPercentage=75.0", "-jar", "app.jar"]
```

---

## GitHub Actions CI

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main, development]
  pull_request:
    branches: [main, development]

jobs:
  build:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_DB: avilatek_test
          POSTGRES_USER: avilatek
          POSTGRES_PASSWORD: testpass
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up JDK 21
        uses: actions/setup-java@v4
        with:
          java-version: '21'
          distribution: 'temurin'
          cache: 'gradle'

      - name: Grant execute permission for gradlew
        run: chmod +x ./gradlew

      - name: Check formatting (Spotless)
        run: ./gradlew spotlessCheck

      - name: Run Checkstyle
        run: ./gradlew checkstyleMain checkstyleTest

      - name: Run tests
        run: ./gradlew test
        env:
          DATABASE_URL: jdbc:postgresql://localhost:5432/avilatek_test
          DATABASE_USER: avilatek
          DATABASE_PASSWORD: testpass
          JWT_SECRET: ci-test-secret-key-at-least-32-chars

      - name: Build JAR
        run: ./gradlew bootJar

      - name: Build Docker image
        run: docker build -t avilatek-service:${{ github.sha }} .

      - name: Upload test results
        uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: test-results
          path: build/reports/tests/
```

---

## Anti-Patterns

### ❌ Committing the `.gradle` directory or build outputs
```gitignore
# ❌ Missing from .gitignore
.gradle/
build/
```
Add both to `.gitignore`. The `.gradle/` directory contains cached task outputs local to the developer's machine.

### ❌ Using a system-installed Gradle instead of the wrapper
```bash
gradle build   # ❌ version may differ between developer machines and CI
./gradlew build  # ✅ uses the pinned version in gradle-wrapper.properties
```

### ❌ Skipping `spotlessApply` before committing
```bash
git add -A && git commit -m "fix: update user service"
# ❌ CI will fail on spotlessCheck if formatting is wrong
```
Run `./gradlew spotlessApply` before every commit, or configure a pre-commit hook to do it automatically.

### ❌ Running the production JAR with root permissions in Docker
```dockerfile
# ❌ Bad — running as root is a security risk
FROM eclipse-temurin:21-jre-alpine
COPY build/libs/*.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]
# no USER directive — runs as root by default
```
Always create and switch to a non-root user as shown in the Dockerfile example above.

---

[← HTTP Layer](./12-http-layer.md) | [Index](./README.md) | [Next: Authentication →](./14-authentication.md)
