# 02 · Package Design

Java's package system is an access-control mechanism, not just a namespace organiser. The `public` modifier in Java means "accessible to the entire JVM classpath" — that is a very wide contract to publish. Most classes in a Spring Boot application do not need to be public. A `UserRepositoryImpl` that implements a `UserRepository` interface should be invisible to everything except the `@Configuration` class that wires it. Making it public by default is a mistake; it means any class anywhere can take a hard dependency on the implementation rather than the interface.

Avila Tek enforces **package-private as the default visibility**. A class is public only when it must be accessed from outside its own package. This rule, combined with domain-per-package layout, creates cohesive modules with narrow public surfaces. The result is that changing an implementation detail — switching from one JPA strategy to another, for example — can never break a class in a different domain because no class in a different domain can reference the implementation class directly.

---

## Visibility Rules

| What                              | Visibility      | Reason                                               |
|-----------------------------------|-----------------|------------------------------------------------------|
| Domain entity                     | `public`        | Referenced by application and presentation layers    |
| Value object (record)             | `public`        | Used across layers for type safety                   |
| Repository interface (port)       | `public`        | Application service depends on it                    |
| Application service               | `public`        | Called by controller; declared in @Configuration     |
| `@RestController`                 | `public`        | Spring requires public for component scanning        |
| Repository implementation         | package-private | Only the `@Configuration` class needs it             |
| JPA entity                        | package-private | Lives entirely within `infrastructure/persistence/`  |
| Spring Data JPA interface         | package-private | Used only by the repository implementation           |
| Internal helper / mapper          | package-private | Implementation detail of the layer                   |
| `@Configuration` class            | package-private | Only Spring needs it; no direct references           |

```java
// ✅ Good — implementation is package-private; only the interface is public
package com.avilatek.users.infrastructure.persistence;

// No `public` keyword — visible only within this package
class UserRepositoryImpl implements UserRepository {
    private final UserJpaRepository jpaRepository;

    UserRepositoryImpl(UserJpaRepository jpaRepository) {
        this.jpaRepository = jpaRepository;
    }

    @Override
    public Optional<User> findById(UserId id) {
        return jpaRepository.findById(id.value()).map(UserRepositoryImpl::toDomain);
    }
}
```

```java
// ❌ Bad — public implementation exposes internals to the whole classpath
public class UserRepositoryImpl implements UserRepository { ... }
```

---

## Domain-per-Package vs Layer-per-Package

Domain-per-package groups everything related to a bounded context together. Layer-per-package groups everything at the same architectural tier together.

```
// ✅ Good — domain-per-package
com.avilatek.users.domain.User
com.avilatek.users.domain.UserRepository
com.avilatek.users.application.UserService
com.avilatek.users.infrastructure.persistence.UserJpaEntity
com.avilatek.users.presentation.UserController

com.avilatek.orders.domain.Order
com.avilatek.orders.domain.OrderRepository
com.avilatek.orders.application.OrderService
...

// ❌ Bad — layer-per-package
com.avilatek.domain.User
com.avilatek.domain.Order          ← unrelated domains share one package
com.avilatek.services.UserService
com.avilatek.services.OrderService ← forced into the same namespace
com.avilatek.controllers.UserController
com.avilatek.controllers.OrderController
```

Domain-per-package enables the package-private rule: a `UserJpaEntity` in `com.avilatek.users.infrastructure.persistence` is invisible to `com.avilatek.orders.*` without a compiler-enforced reason to expose it.

---

## What Belongs in `shared/`

The `shared` package is a bounded resource. Every type added to it increases the coupling surface between all domains. Add to `shared` only when:

1. The type is a **value object** used by more than one domain (e.g., `Money`, `PhoneNumber`, `Pagination`).
2. The type is a **base class** that provides infrastructure plumbing (e.g., `DomainException`, `AuditEntity`).
3. The type is a **utility** with zero domain knowledge (e.g., `DateTimeUtils`, `StringUtils`).

```java
// ✅ Good — shared value object with zero domain knowledge
package com.avilatek.shared.domain;

public record Money(long amountCents, String currencyCode) {
    public Money {
        if (amountCents < 0) throw new IllegalArgumentException("Amount cannot be negative");
        if (currencyCode == null || currencyCode.isBlank()) throw new IllegalArgumentException("Currency required");
    }

    public Money add(Money other) {
        if (!this.currencyCode.equals(other.currencyCode)) {
            throw new IllegalArgumentException("Currency mismatch");
        }
        return new Money(this.amountCents + other.amountCents, this.currencyCode);
    }
}
```

```java
// ❌ Bad — domain concept disguised as shared
package com.avilatek.shared.domain;

// "User" is a domain concept belonging to `com.avilatek.users`, not shared
public class User { ... }
```

---

## Circular Dependency Prohibition

Circular dependencies between domain packages are prohibited. If `users` depends on `orders` and `orders` depends on `users`, you have a design problem, not a packaging problem. The fix is to extract the shared concept into `shared/` or to introduce an event-driven integration boundary.

Enforce this rule automatically with ArchUnit in `src/test/java/com/avilatek/architecture/ArchitectureTest.java`:

```java
// ✅ Good — ArchUnit enforces the rules at test time
package com.avilatek.architecture;

import com.tngtech.archunit.junit.AnalyzeClasses;
import com.tngtech.archunit.junit.ArchTest;
import com.tngtech.archunit.lang.ArchRule;

import static com.tngtech.archunit.library.Architectures.layeredArchitecture;
import static com.tngtech.archunit.library.dependencies.SlicesRuleDefinition.slices;

@AnalyzeClasses(packages = "com.avilatek")
class ArchitectureTest {

    @ArchTest
    static final ArchRule noCircularDependencies =
        slices().matching("com.avilatek.(*)..").should().beFreeOfCycles();

    @ArchTest
    static final ArchRule domainHasNoDependencyOnInfrastructure =
        layeredArchitecture()
            .consideringAllDependencies()
            .layer("Domain").definedBy("..domain..")
            .layer("Application").definedBy("..application..")
            .layer("Infrastructure").definedBy("..infrastructure..")
            .layer("Presentation").definedBy("..presentation..")
            .whereLayer("Domain").mayNotAccessAnyLayer()
            .whereLayer("Application").mayOnlyAccessLayers("Domain")
            .whereLayer("Infrastructure").mayOnlyAccessLayers("Domain", "Application")
            .whereLayer("Presentation").mayOnlyAccessLayers("Application", "Domain");
}
```

---

## The Users Package — Full Visibility Example

```
com.avilatek.users/
├── domain/
│   ├── User.java                 public  — entity used across layers
│   ├── UserId.java               public  — value object
│   ├── Email.java                public  — value object
│   ├── UserRepository.java       public  — port (interface)
│   └── UserNotFoundException.java public — domain exception
├── application/
│   ├── UserService.java          public  — called by controller
│   ├── CreateUserCommand.java    public  — input DTO
│   └── UserResponse.java         public  — output DTO
├── infrastructure/
│   └── persistence/
│       ├── UserJpaEntity.java         package-private
│       ├── UserJpaRepository.java     package-private
│       └── UserRepositoryImpl.java    package-private
└── presentation/
    ├── UserController.java            public  (Spring requirement)
    ├── CreateUserRequest.java         public  (deserialized by Jackson)
    └── UserConfiguration.java         package-private
```

---

## Anti-Patterns

### ❌ Making everything public by default
```java
public class UserJpaEntity { ... }           // exposed to whole classpath
public class UserJpaRepository { ... }       // leaks infrastructure to domain callers
public class UserRepositoryImpl { ... }      // hides nothing
```
Java's default access (package-private) is intentional. Reserve `public` for types that form an explicit contract.

### ❌ Putting domain logic in the `shared` package
```java
package com.avilatek.shared.domain;

// This is a users concern, not a shared concern
public class UserStatus { ACTIVE, SUSPENDED, DELETED }
```
`UserStatus` belongs in `com.avilatek.users.domain`. If another domain truly needs it, that is a signal those two domains may share a bounded context boundary — reconsider the split.

### ❌ Ignoring ArchUnit failures
```java
// In UserService (application layer):
import com.avilatek.users.infrastructure.persistence.UserJpaEntity; // ❌ crosses architectural boundary
```
ArchUnit rules exist to make architectural violations fail CI. Never suppress an ArchUnit rule to make a test pass — fix the dependency direction instead.

---

[← Project Layout](./01-project-layout.md) | [Index](./README.md) | [Next: Architecture →](./03-architecture.md)
