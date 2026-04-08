# 03 · Architecture

Hexagonal Architecture, originally described by Alistair Cockburn, organises a system around a single invariant: the domain model has no outward dependencies. It does not know about HTTP, databases, message queues, or Spring Boot. It only knows about business concepts. Every external concern connects to the domain through a **port** — a Java interface defined in the domain layer — and is fulfilled by an **adapter** — an implementation class in the infrastructure or presentation layer. This separation means the domain can be unit-tested without starting a database, the HTTP layer can be replaced with a CLI without touching business logic, and infrastructure choices can be deferred or changed without rippling into the core.

Spring Boot maps cleanly onto this model when used with discipline. `@RestController` classes are input adapters. `@Repository` implementations are output adapters. The domain `interface` types are the ports. The only discipline required is the one Spring does not enforce for you: do not let Spring annotations cross into the domain layer. A `@Entity` annotation on a domain class is an architectural violation. An `@Autowired` field on an application service couples the class to the Spring container. These guides exist to name those violations explicitly so engineers can recognise and prevent them.

---

## Hexagonal Zones — ASCII Diagram

```
                        ┌─────────────────────────────────────────┐
                        │          PRESENTATION (Input Adapters)   │
                        │                                          │
                        │   @RestController    HTTP Client         │
                        │   gRPC Server        CLI Runner          │
                        └────────────────┬─────────────────────────┘
                                         │ calls (via interface)
                        ┌────────────────▼─────────────────────────┐
                        │          APPLICATION LAYER               │
                        │                                          │
                        │   @Service  (Use-Case Orchestration)     │
                        │   @Transactional boundaries              │
                        │   Calls domain objects + output ports    │
                        └────────────────┬─────────────────────────┘
                                         │ uses
                 ┌───────────────────────▼──────────────────────────────┐
                 │                   DOMAIN                              │
                 │                                                        │
                 │  Entities (POJO)   Value Objects (record)             │
                 │  Domain Services   Repository Interfaces (Ports)      │
                 │  Domain Exceptions                                    │
                 │                                                        │
                 │  ← No Spring annotations. No JPA. Pure Java. →        │
                 └───────────────────────┬──────────────────────────────┘
                                         │ implemented by
                        ┌────────────────▼─────────────────────────┐
                        │          INFRASTRUCTURE (Output Adapters) │
                        │                                          │
                        │   @Repository impl   JPA @Entity         │
                        │   Flyway Migrations  Email Client        │
                        │   Spring Data JPA    S3 Adapter          │
                        └──────────────────────────────────────────┘
```

Dependencies always point inward. Infrastructure knows about the domain; the domain never knows about infrastructure.

---

## Spring Component Mapping

| Spring Annotation / Concept | Hexagonal Role               | Package Location                        |
|-----------------------------|------------------------------|-----------------------------------------|
| `@RestController`           | HTTP Input Adapter           | `presentation/`                         |
| `@Service`                  | Application Service          | `application/`                          |
| `interface` (plain Java)    | Port (output)                | `domain/`                               |
| `@Repository` impl          | DB Output Adapter            | `infrastructure/persistence/`           |
| `JpaRepository` extension   | Spring Data glue             | `infrastructure/persistence/`           |
| `@Entity`                   | Infrastructure type only     | `infrastructure/persistence/`           |
| `@Component`                | Generic adapter              | `infrastructure/` (specific sub-package)|
| `@Configuration`            | Composition root / wiring    | `presentation/` (per-domain)            |
| `@ControllerAdvice`         | Cross-cutting input adapter  | `presentation/` or `shared/presentation`|

---

## The Dependency Rule in Practice

```
UserController  →  UserService (interface)  ←  UserServiceImpl
                                                      ↓
                                              UserRepository (interface)
                                                      ↑
                                              UserRepositoryImpl
                                                      ↓
                                              UserJpaRepository (Spring Data)
                                                      ↓
                                              UserJpaEntity (@Entity)
```

Source code arrows point toward the domain center. `UserController` does not know `UserServiceImpl` exists. `UserServiceImpl` does not know `UserRepositoryImpl` exists. Both depend on interfaces owned by the domain.

---

## Concrete Example — Request Flow

```java
// ✅ Good — Presentation layer: thin adapter, no business logic
package com.avilatek.users.presentation;

@RestController
@RequestMapping("/api/v1/users")
public class UserController {

    private final UserService userService;  // application-layer interface

    public UserController(UserService userService) {
        this.userService = userService;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public UserResponse create(@RequestBody @Validated CreateUserRequest request) {
        return userService.createUser(new CreateUserCommand(request.name(), request.email()));
    }
}
```

```java
// ✅ Good — Application layer: orchestrates domain, owns transaction boundary
package com.avilatek.users.application;

@Service
@Transactional
public class UserService {

    private final UserRepository userRepository;  // domain port (interface)

    public UserService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    public UserResponse createUser(CreateUserCommand command) {
        if (userRepository.existsByEmail(new Email(command.email()))) {
            throw new EmailAlreadyTakenException(command.email());
        }
        User user = User.create(command.name(), command.email());
        userRepository.save(user);
        return UserResponse.from(user);
    }
}
```

```java
// ✅ Good — Domain layer: pure Java, no framework annotations
package com.avilatek.users.domain;

public final class User {
    private final UserId id;
    private String name;
    private final Email email;

    private User(UserId id, String name, Email email) {
        this.id = id;
        this.name = name;
        this.email = email;
    }

    public static User create(String name, String rawEmail) {
        if (name == null || name.isBlank()) throw new IllegalArgumentException("Name required");
        return new User(UserId.generate(), name, new Email(rawEmail));
    }

    public UserId id() { return id; }
    public String name() { return name; }
    public Email email() { return email; }
}
```

```java
// ✅ Good — Domain port: interface owned by domain, implemented by infrastructure
package com.avilatek.users.domain;

public interface UserRepository {
    void save(User user);
    Optional<User> findById(UserId id);
    boolean existsByEmail(Email email);
}
```

---

## The JPA Entity Is Not the Domain Entity

This is the most common mistake in Spring Boot codebases. The `@Entity` annotation belongs to JPA (Jakarta Persistence), which is an infrastructure concern. A domain entity should be a plain Java class. The infrastructure layer is responsible for mapping between the two.

```java
// ✅ Good — separate JPA entity in infrastructure
package com.avilatek.users.infrastructure.persistence;

@Entity
@Table(name = "users")
class UserJpaEntity {
    @Id
    private UUID id;
    private String name;
    private String email;
    // getters and setters for JPA — no domain behaviour
}
```

```java
// ❌ Bad — domain entity polluted with JPA annotations
package com.avilatek.users.domain;

@Entity  // JPA in domain layer — architectural violation
@Table(name = "users")
public class User {
    @Id
    @GeneratedValue
    private UUID id;

    @Column(nullable = false)
    private String email;
    // domain and persistence concerns tangled together
}
```

When JPA annotations appear in the domain layer, the domain can no longer be tested without a JPA provider on the classpath. Mapping frameworks change, JPA strategies change — and every change forces you to touch domain classes.

---

## Anti-Patterns

### ❌ Controller depending directly on JPA repository
```java
@RestController
public class UserController {
    @Autowired
    private UserJpaRepository jpaRepository;  // skips domain and application entirely

    @GetMapping("/{id}")
    public UserJpaEntity getUser(@PathVariable UUID id) {
        return jpaRepository.findById(id).orElseThrow();
    }
}
```
This exposes the JPA entity directly over HTTP, bypasses all domain invariants, and makes the controller impossible to unit-test without a database.

### ❌ Application service importing infrastructure types
```java
// In application layer — violates Dependency Rule
import com.avilatek.users.infrastructure.persistence.UserJpaEntity;

@Service
public class UserService {
    public UserResponse createUser(CreateUserCommand cmd) {
        UserJpaEntity entity = new UserJpaEntity();  // ❌ depends on infrastructure
        ...
    }
}
```
The application layer owns only domain types. All persistence details are hidden behind the `UserRepository` port.

### ❌ Skipping the port — application service depends on implementation
```java
@Service
public class UserService {
    private final UserRepositoryImpl repository;  // ❌ depends on impl, not interface

    public UserService(UserRepositoryImpl repository) {
        this.repository = repository;
    }
}
```
The power of ports is that tests can inject a fake or in-memory implementation. Depending on the concrete class destroys that benefit.

---

[← Package Design](./02-package-design.md) | [Index](./README.md) | [Next: Domain Model →](./04-domain-model.md)
