# 04 · Domain Model

The domain model is the heart of the application. It is where business rules live, where invariants are enforced, and where the language of the problem domain is expressed in code. A well-designed domain model is readable by a product manager, not just a programmer. It says "a User must have a valid Email" directly in its constructor — not in a validator somewhere four layers away. The domain model in a Hexagonal Architecture is pure Java: no Spring annotations, no JPA, no external dependencies of any kind. If a domain class requires a Spring context to instantiate, the design has gone wrong.

Avila Tek's domain model follows a **rich model** approach. Entities have behaviour: they enforce their own invariants, they transition through states, they produce domain events. The alternative — an anemic model, where entities are bags of getters and setters and all behaviour lives in service classes — is an anti-pattern that produces spaghetti service layers and domain logic that is difficult to test, reuse, or reason about. Give behaviour to the objects that own the data. Use Java Records for value objects and immutable data structures. Use factory methods to enforce creation invariants.

---

## Value Objects with Java Records

A value object has no identity of its own; it is defined entirely by its attributes. Java Records are the natural fit: immutable by design, equality by value, compact syntax, and canonical constructors that can validate invariants.

```java
// ✅ Good — value object as a record with invariant enforcement in compact constructor
package com.avilatek.users.domain;

public record Email(String value) {
    public Email {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException("Email must not be blank");
        }
        if (!value.contains("@")) {
            throw new IllegalArgumentException("Email must contain @: " + value);
        }
        value = value.toLowerCase().strip();
    }
}
```

```java
// ✅ Good — identity value object wrapping UUID
package com.avilatek.users.domain;

import java.util.UUID;

public record UserId(UUID value) {
    public UserId {
        if (value == null) throw new IllegalArgumentException("UserId must not be null");
    }

    public static UserId generate() {
        return new UserId(UUID.randomUUID());
    }

    public static UserId of(String raw) {
        try {
            return new UserId(UUID.fromString(raw));
        } catch (IllegalArgumentException e) {
            throw new IllegalArgumentException("Invalid UserId: " + raw, e);
        }
    }
}
```

```java
// ❌ Bad — primitive obsession; no validation, no type safety
public class User {
    private String email;   // could be anything, validated nowhere
    private String userId;  // could be any string format
}
```

---

## Domain Entities as POJOs

A domain entity has identity (it is found by ID, not by value equality) and it carries behaviour. It is a plain Java class — no JPA `@Entity`, no Jackson `@JsonProperty`, no Spring `@Component`. Those annotations belong to the infrastructure and presentation layers respectively.

```java
// ✅ Good — rich domain entity with factory method and state transition
package com.avilatek.users.domain;

import java.time.Instant;

public final class User {

    public enum Status { ACTIVE, SUSPENDED }

    private final UserId id;
    private String name;
    private final Email email;
    private Status status;
    private final Instant createdAt;

    private User(UserId id, String name, Email email, Status status, Instant createdAt) {
        this.id = id;
        this.name = name;
        this.email = email;
        this.status = status;
        this.createdAt = createdAt;
    }

    // Factory method enforces creation invariants
    public static User create(String name, String rawEmail) {
        if (name == null || name.isBlank()) {
            throw new IllegalArgumentException("User name must not be blank");
        }
        return new User(UserId.generate(), name.strip(), new Email(rawEmail), Status.ACTIVE, Instant.now());
    }

    // Reconstitution factory — used by infrastructure to rebuild from persistence
    public static User reconstitute(UserId id, String name, Email email, Status status, Instant createdAt) {
        return new User(id, name, email, status, createdAt);
    }

    // Domain behaviour: suspend() enforces the state transition rule
    public void suspend() {
        if (this.status == Status.SUSPENDED) {
            throw new IllegalStateException("User " + id.value() + " is already suspended");
        }
        this.status = Status.SUSPENDED;
    }

    public void rename(String newName) {
        if (newName == null || newName.isBlank()) {
            throw new IllegalArgumentException("Name must not be blank");
        }
        this.name = newName.strip();
    }

    public UserId id()        { return id; }
    public String name()      { return name; }
    public Email email()      { return email; }
    public Status status()    { return status; }
    public Instant createdAt(){ return createdAt; }

    public boolean isActive()    { return status == Status.ACTIVE; }
    public boolean isSuspended() { return status == Status.SUSPENDED; }
}
```

---

## Repository Port (Interface in Domain)

The domain defines *what* it needs from persistence as a Java interface. The domain does not know how it is implemented.

```java
// ✅ Good — port defined in domain layer, implemented by infrastructure
package com.avilatek.users.domain;

import java.util.Optional;

public interface UserRepository {
    void save(User user);
    Optional<User> findById(UserId id);
    Optional<User> findByEmail(Email email);
    boolean existsByEmail(Email email);
    void delete(UserId id);
}
```

---

## Separating Domain Entity from JPA Entity

The infrastructure layer owns the JPA entity. It is responsible for mapping between the JPA entity and the domain entity in both directions.

```java
// ✅ Good — JPA entity lives exclusively in infrastructure, not visible outside
package com.avilatek.users.infrastructure.persistence;

@Entity
@Table(name = "users")
class UserJpaEntity {

    @Id
    private UUID id;

    @Column(nullable = false)
    private String name;

    @Column(nullable = false, unique = true)
    private String email;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private UserStatusJpa status;

    @Column(nullable = false)
    private Instant createdAt;

    // JPA requires no-arg constructor
    protected UserJpaEntity() {}

    enum UserStatusJpa { ACTIVE, SUSPENDED }
}
```

```java
// ✅ Good — mapping in the repository implementation
package com.avilatek.users.infrastructure.persistence;

class UserRepositoryImpl implements UserRepository {

    private final UserJpaRepository jpaRepository;

    UserRepositoryImpl(UserJpaRepository jpaRepository) {
        this.jpaRepository = jpaRepository;
    }

    @Override
    public void save(User user) {
        UserJpaEntity entity = toJpa(user);
        jpaRepository.save(entity);
    }

    @Override
    public Optional<User> findById(UserId id) {
        return jpaRepository.findById(id.value()).map(this::toDomain);
    }

    private UserJpaEntity toJpa(User user) {
        UserJpaEntity e = new UserJpaEntity();
        e.id = user.id().value();
        e.name = user.name();
        e.email = user.email().value();
        e.status = UserJpaEntity.UserStatusJpa.valueOf(user.status().name());
        e.createdAt = user.createdAt();
        return e;
    }

    private User toDomain(UserJpaEntity e) {
        return User.reconstitute(
            new UserId(e.id),
            e.name,
            new Email(e.email),
            User.Status.valueOf(e.status.name()),
            e.createdAt
        );
    }
}
```

---

## Rich vs Anemic Model

```java
// ✅ Good — rich model: entity knows how to suspend itself
user.suspend();  // enforces invariants, no service logic needed

// ❌ Bad — anemic model: service does what the entity should do
public class UserService {
    public void suspendUser(UUID userId) {
        User user = userRepository.findById(userId).orElseThrow();
        if (user.getStatus().equals("SUSPENDED")) {  // string comparison — fragile
            throw new RuntimeException("already suspended");
        }
        user.setStatus("SUSPENDED");  // raw mutation, no invariant
        userRepository.save(user);
    }
}
```

When logic is distributed across service methods rather than encapsulated in the entity, duplication creeps in. Two different services may implement the suspension check differently. The entity itself owns the rule.

---

## Anti-Patterns

### ❌ JPA `@Entity` as the domain model
```java
package com.avilatek.users.domain;

@Entity  // ❌ Jakarta Persistence in the domain layer
@Table(name = "users")
public class User {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    @Email
    private String email;

    // getters, setters — no behaviour
}
```
Now every test that touches `User` needs Hibernate on the classpath. Every database schema change potentially touches the domain class. Infrastructure and domain are entangled.

### ❌ Using `String` everywhere instead of value objects
```java
// ❌ Bad — no type safety, validation scattered everywhere
public class UserService {
    public void changeEmail(String userId, String newEmail) {
        if (!newEmail.contains("@")) throw new IllegalArgumentException(...);
        // duplicated in every method that touches email
    }
}
```
A `Email` value object validates once at construction; every `Email` instance is valid by definition.

### ❌ Public setters on domain entities
```java
// ❌ Bad — any caller can put the entity into an invalid state
user.setStatus(null);
user.setEmail("");
user.setCreatedAt(Instant.now()); // mutating an immutable fact
```
Use intentional methods (`suspend()`, `activate()`, `rename()`) that encode the domain concept and enforce invariants.

---

[← Architecture](./03-architecture.md) | [Index](./README.md) | [Next: Error Handling →](./05-error-handling.md)
