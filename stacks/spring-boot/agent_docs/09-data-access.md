# 09 · Data Access

The database is an infrastructure concern. That statement is not philosophical — it has a direct structural consequence: JPA `@Entity` classes belong in `infrastructure/persistence/`, not in the domain layer, and they are not the same object as the domain entity. The domain entity `User` is a plain Java class owned by the domain. The JPA entity `UserJpaEntity` is an infrastructure class that knows how to be stored in a relational table. The repository implementation is the bridge: it converts between the two representations when reading and writing.

This separation costs some boilerplate — two classes instead of one, a mapping method — and it pays for itself every time you change the database schema without touching the domain, switch from JPA to JOOQ or R2DBC without rewriting application services, or test the domain in complete isolation. The mapping is mechanical; the boundary it enforces is architectural. Spring Data JPA makes the mapping convenient but not free; convenience should not be confused with correctness.

---

## The Three Infrastructure Types

```
Domain Layer:
  User                      ← domain entity (POJO)
  UserRepository            ← port (interface)

Infrastructure Layer:
  UserJpaEntity             ← JPA-annotated persistence type
  UserJpaRepository         ← Spring Data interface (extends JpaRepository)
  UserRepositoryImpl        ← adapter: implements UserRepository, uses UserJpaRepository
```

---

## JPA Entity — Infrastructure Only

```java
// ✅ Good — JPA entity is package-private, lives entirely in infrastructure
package com.avilatek.users.infrastructure.persistence;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "users", indexes = {
    @Index(name = "idx_users_email", columnList = "email", unique = true)
})
class UserJpaEntity {

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "name", nullable = false, length = 100)
    private String name;

    @Column(name = "email", nullable = false, unique = true, length = 254)
    private String email;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private UserStatusJpa status;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Version
    @Column(name = "version")
    private Long version;  // optimistic locking

    // JPA requires no-arg constructor — keep it package-private
    UserJpaEntity() {}

    enum UserStatusJpa {
        ACTIVE, SUSPENDED
    }

    // Package-private setters — only used by UserRepositoryImpl mapper
    void setId(UUID id)                   { this.id = id; }
    void setName(String name)             { this.name = name; }
    void setEmail(String email)           { this.email = email; }
    void setStatus(UserStatusJpa status)  { this.status = status; }
    void setCreatedAt(Instant createdAt)  { this.createdAt = createdAt; }

    UUID getId()               { return id; }
    String getName()           { return name; }
    String getEmail()          { return email; }
    UserStatusJpa getStatus()  { return status; }
    Instant getCreatedAt()     { return createdAt; }
}
```

---

## Spring Data JPA Interface — Infrastructure Only

```java
// ✅ Good — Spring Data interface is package-private, used only by UserRepositoryImpl
package com.avilatek.users.infrastructure.persistence;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.Optional;
import java.util.UUID;

interface UserJpaRepository extends JpaRepository<UserJpaEntity, UUID> {

    Optional<UserJpaEntity> findByEmail(String email);

    boolean existsByEmail(String email);

    @Query("SELECT u FROM UserJpaEntity u WHERE u.status = 'ACTIVE'")
    java.util.List<UserJpaEntity> findAllActive();
}
```

---

## Repository Implementation — The Mapping Bridge

```java
// ✅ Good — full repository implementation with domain-to-JPA and JPA-to-domain mapping
package com.avilatek.users.infrastructure.persistence;

import com.avilatek.users.domain.*;
import org.springframework.dao.DataIntegrityViolationException;

import java.util.Optional;

class UserRepositoryImpl implements UserRepository {

    private final UserJpaRepository jpaRepository;

    UserRepositoryImpl(UserJpaRepository jpaRepository) {
        this.jpaRepository = jpaRepository;
    }

    @Override
    public void save(User user) {
        try {
            jpaRepository.save(toJpa(user));
        } catch (DataIntegrityViolationException ex) {
            if (isEmailConstraintViolation(ex)) {
                throw new EmailAlreadyTakenException(user.email().value());
            }
            throw ex;
        }
    }

    @Override
    public Optional<User> findById(UserId id) {
        return jpaRepository.findById(id.value()).map(this::toDomain);
    }

    @Override
    public Optional<User> findByEmail(Email email) {
        return jpaRepository.findByEmail(email.value()).map(this::toDomain);
    }

    @Override
    public boolean existsByEmail(Email email) {
        return jpaRepository.existsByEmail(email.value());
    }

    @Override
    public void delete(UserId id) {
        jpaRepository.deleteById(id.value());
    }

    // --- Mapping ---

    private UserJpaEntity toJpa(User user) {
        UserJpaEntity e = new UserJpaEntity();
        e.setId(user.id().value());
        e.setName(user.name());
        e.setEmail(user.email().value());
        e.setStatus(UserJpaEntity.UserStatusJpa.valueOf(user.status().name()));
        e.setCreatedAt(user.createdAt());
        return e;
    }

    private User toDomain(UserJpaEntity e) {
        return User.reconstitute(
            new UserId(e.getId()),
            e.getName(),
            new Email(e.getEmail()),
            User.Status.valueOf(e.getStatus().name()),
            e.getCreatedAt()
        );
    }

    private boolean isEmailConstraintViolation(DataIntegrityViolationException ex) {
        String message = ex.getMostSpecificCause().getMessage();
        return message != null && message.contains("users_email_key");
    }
}
```

---

## Flyway Migrations

Database schema changes are managed exclusively by Flyway. Never modify the schema manually or through JPA `hbm2ddl.auto`. All migration scripts live in `src/main/resources/db/migration/` and follow the naming convention `V{version}__{description}.sql`.

```sql
-- V1__create_users_table.sql
CREATE TABLE users (
    id         UUID         NOT NULL PRIMARY KEY,
    name       VARCHAR(100) NOT NULL,
    email      VARCHAR(254) NOT NULL,
    status     VARCHAR(20)  NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ  NOT NULL,
    version    BIGINT       NOT NULL DEFAULT 0,
    CONSTRAINT users_email_key UNIQUE (email),
    CONSTRAINT users_status_check CHECK (status IN ('ACTIVE', 'SUSPENDED'))
);

CREATE INDEX idx_users_email ON users (email);
```

```yaml
# application.yml — Flyway configuration
spring:
  flyway:
    enabled: true
    locations: classpath:db/migration
    baseline-on-migrate: false
    validate-on-migrate: true
  jpa:
    hibernate:
      ddl-auto: validate   # never create or update — Flyway owns the schema
    show-sql: false
    properties:
      hibernate:
        format_sql: false
        default_schema: public
```

---

## Transaction Boundaries

Transactions are owned by the **application layer**, not the repository or domain. The `@Transactional` annotation belongs on application service methods, not on repository implementations or controllers.

```java
// ✅ Good — transaction boundary at the application service method
package com.avilatek.users.application;

@Service
public class UserService {

    private final UserRepository userRepository;

    public UserService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @Transactional  // transaction starts here, commits on return, rolls back on exception
    public UserResponse createUser(CreateUserCommand command) {
        if (userRepository.existsByEmail(new Email(command.email()))) {
            throw new EmailAlreadyTakenException(command.email());
        }
        User user = User.create(command.name(), command.email());
        userRepository.save(user);
        return UserResponse.from(user);
    }

    @Transactional(readOnly = true)  // read-only hint: no dirty checking, better performance
    public UserResponse getUser(String rawId) {
        UserId id = UserId.of(rawId);
        return userRepository.findById(id)
            .map(UserResponse::from)
            .orElseThrow(() -> new UserNotFoundException(id));
    }
}
```

```java
// ❌ Bad — @Transactional on the repository implementation
class UserRepositoryImpl implements UserRepository {
    @Transactional  // ❌ transaction boundary too low; wraps only one DB call
    public void save(User user) { ... }
}
```

---

## Anti-Patterns

### ❌ Using the JPA entity as the domain entity
```java
package com.avilatek.users.domain;

@Entity  // ❌ JPA annotation in the domain layer
public class User {
    @Id private UUID id;
    private String name;
    // domain and persistence tangled — impossible to change either independently
}
```

### ❌ Exposing `UserJpaRepository` to the application layer
```java
// ❌ application layer importing infrastructure type
package com.avilatek.users.application;
import com.avilatek.users.infrastructure.persistence.UserJpaRepository;

@Service
public class UserService {
    private final UserJpaRepository jpaRepository; // bypasses domain port entirely
}
```
This skips the domain port, exposes JPA entities to the application layer, and makes the service impossible to test without a JPA context.

### ❌ `ddl-auto: create` or `ddl-auto: update` in production
```yaml
spring:
  jpa:
    hibernate:
      ddl-auto: update  # ❌ dangerous in production — drops and alters tables silently
```
Use `validate` in all environments. Let Flyway own schema changes with version-controlled SQL scripts.

### ❌ Fetching data in the presentation layer (Open Session in View)
```yaml
spring:
  jpa:
    open-in-view: true  # ❌ default in older Spring Boot — leaks DB connection to HTTP thread
```
Set `open-in-view: false`. All data fetching happens within the transaction boundary of the application service. Lazy loading outside a transaction causes `LazyInitializationException` — which is a feature, not a bug.

---

[← Testing](./08-testing.md) | [Index](./README.md) | [Next: Configuration →](./10-configuration.md)
