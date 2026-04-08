# 01 · Project Layout

A project's directory structure is its first architectural statement. Before a new engineer reads a single line of business logic, the layout either communicates a coherent model or forces them to reverse-engineer one. Avila Tek uses a **domain-per-package** layout rather than a layer-per-package layout. This means `com.avilatek.users` is a cohesive vertical slice containing its own domain, application, infrastructure, and presentation sub-packages — not a flat `com.avilatek.services` that mixes every domain's application logic together.

The constraint that makes this sustainable is discipline about what crosses package boundaries. Each domain package is nearly self-contained. The `shared` package is the only legitimate source of cross-cutting types: value objects, base exception classes, audit metadata. Everything else belongs to exactly one domain. Gradle's `build.gradle.kts` governs the build; there is no Maven POM. Every dependency is declared with an explicit purpose — if you cannot explain why a library is on the classpath, it should not be there.

---

## Directory Tree

```
com.avilatek/
├── build.gradle.kts
├── settings.gradle.kts
├── gradle/
│   └── wrapper/
│       ├── gradle-wrapper.jar
│       └── gradle-wrapper.properties
├── src/
│   ├── main/
│   │   ├── java/
│   │   │   └── com/
│   │   │       └── avilatek/
│   │   │           ├── Application.java          ← entry point only
│   │   │           ├── shared/
│   │   │           │   ├── domain/
│   │   │           │   │   ├── AggregateRoot.java
│   │   │           │   │   └── DomainException.java
│   │   │           │   └── infrastructure/
│   │   │           │       └── AuditEntity.java
│   │   │           ├── users/
│   │   │           │   ├── domain/
│   │   │           │   │   ├── User.java
│   │   │           │   │   ├── UserId.java
│   │   │           │   │   ├── Email.java
│   │   │           │   │   ├── UserRepository.java    ← port (interface)
│   │   │           │   │   └── UserNotFoundException.java
│   │   │           │   ├── application/
│   │   │           │   │   ├── UserService.java
│   │   │           │   │   ├── CreateUserCommand.java
│   │   │           │   │   └── UserResponse.java
│   │   │           │   ├── infrastructure/
│   │   │           │   │   └── persistence/
│   │   │           │   │       ├── UserJpaEntity.java
│   │   │           │   │       ├── UserJpaRepository.java
│   │   │           │   │       └── UserRepositoryImpl.java
│   │   │           │   └── presentation/
│   │   │           │       ├── UserController.java
│   │   │           │       ├── CreateUserRequest.java
│   │   │           │       └── UserConfiguration.java
│   │   │           └── orders/
│   │   │               ├── domain/
│   │   │               ├── application/
│   │   │               ├── infrastructure/
│   │   │               └── presentation/
│   │   └── resources/
│   │       ├── application.yml
│   │       ├── application-dev.yml
│   │       ├── application-prod.yml
│   │       └── db/
│   │           └── migration/
│   │               ├── V1__create_users_table.sql
│   │               └── V2__create_orders_table.sql
│   └── test/
│       └── java/
│           └── com/
│               └── avilatek/
│                   ├── users/
│                   │   ├── domain/
│                   │   │   └── UserTest.java
│                   │   ├── application/
│                   │   │   └── UserServiceTest.java
│                   │   ├── infrastructure/
│                   │   │   └── UserRepositoryImplTest.java
│                   │   └── presentation/
│                   │       └── UserControllerTest.java
│                   └── architecture/
│                       └── ArchitectureTest.java   ← ArchUnit rules
```

---

## Package Naming

Packages follow the reverse-domain convention rooted at `com.avilatek`. Every top-level package after the root corresponds to a **bounded context** (a domain). Avoid generic names like `common`, `util`, or `helper` outside of `shared`. If something genuinely belongs to a specific domain, it goes there.

```java
// ✅ Good — specific domain package
package com.avilatek.users.domain;

// ✅ Good — shared cross-cutting types only
package com.avilatek.shared.domain;

// ❌ Bad — layer-per-package leaks domain concerns across layers
package com.avilatek.services;
package com.avilatek.repositories;
package com.avilatek.controllers;
```

---

## Application Entry Point

The `Application.java` class does exactly one thing: start the Spring context. No beans, no configuration logic, no `@ComponentScan` customizations unless strictly necessary.

```java
// ✅ Good — entry point only, nothing else
package com.avilatek;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class Application {
    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }
}
```

---

## `build.gradle.kts` Overview

Dependencies are grouped by layer so the intent is immediately readable.

```kotlin
// build.gradle.kts
plugins {
    java
    id("org.springframework.boot") version "3.3.0"
    id("io.spring.dependency-management") version "1.1.4"
    id("com.diffplug.spotless") version "6.25.0"
    id("checkstyle")
}

group = "com.avilatek"
version = "0.0.1-SNAPSHOT"
java.sourceCompatibility = JavaVersion.VERSION_21

dependencies {
    // --- Presentation ---
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("org.springdoc:springdoc-openapi-starter-webmvc-ui:2.5.0")

    // --- Application / Domain ---
    implementation("org.springframework.boot:spring-boot-starter-validation")

    // --- Infrastructure: Persistence ---
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.flywaydb:flyway-core")
    runtimeOnly("org.postgresql:postgresql")

    // --- Infrastructure: Security ---
    implementation("org.springframework.boot:spring-boot-starter-security")
    implementation("io.jsonwebtoken:jjwt-api:0.12.5")
    runtimeOnly("io.jsonwebtoken:jjwt-impl:0.12.5")
    runtimeOnly("io.jsonwebtoken:jjwt-jackson:0.12.5")

    // --- Observability ---
    implementation("org.springframework.boot:spring-boot-starter-actuator")
    implementation("io.micrometer:micrometer-registry-prometheus")

    // --- Configuration ---
    annotationProcessor("org.springframework.boot:spring-boot-configuration-processor")

    // --- Test ---
    testImplementation("org.springframework.boot:spring-boot-starter-test")
    testImplementation("org.springframework.security:spring-security-test")
    testImplementation("org.testcontainers:junit-jupiter")
    testImplementation("org.testcontainers:postgresql")
    testImplementation("com.tngtech.archunit:archunit-junit5:1.3.0")
}
```

---

## Resources Layout

`src/main/resources/` is organised to support Spring profiles cleanly.

```yaml
# application.yml — base configuration, no secrets
spring:
  application:
    name: avilatek-service
  profiles:
    active: dev   # overridden by environment variable in prod

# application-dev.yml — developer defaults
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/avilatek_dev

# application-prod.yml — prod-safe defaults, secrets from env vars
spring:
  datasource:
    url: ${DATABASE_URL}
    username: ${DATABASE_USER}
    password: ${DATABASE_PASSWORD}
```

Flyway migrations live in `db/migration/` using the `V{version}__{description}.sql` naming convention. Never rename or edit a migration once it has been applied to any environment.

---

## Anti-Patterns

### ❌ Layer-per-package root structure
```
com.avilatek.controllers.UserController
com.avilatek.services.UserService
com.avilatek.repositories.UserRepository
```
This forces every related class across the entire codebase to share a single flat namespace. Adding a second domain doubles the collision surface. Use domain-per-package always.

### ❌ Business logic in `Application.java`
```java
@SpringBootApplication
public class Application {
    @Bean
    public UserService userService(UserRepository repo) {
        // configuration belongs in @Configuration classes
        return new UserService(repo, new EmailService());
    }
}
```
The entry point should have a single responsibility: starting the JVM process. Move `@Bean` definitions to dedicated `@Configuration` classes inside each domain's `presentation/` package.

### ❌ Hardcoded secrets in `application.yml`
```yaml
spring:
  datasource:
    password: supersecret123   # committed to git — never do this
```
All secrets flow through environment variables. Use `${ENV_VAR_NAME}` placeholders in YAML and inject real values via your deployment platform or a secrets manager.

---

[Index](./README.md) | [Next: Package Design →](./02-package-design.md)
