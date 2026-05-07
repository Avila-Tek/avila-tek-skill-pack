# Java Spring Boot — API Standards Reference

## Architecture

Hexagonal Architecture with strict layer separation. Spring annotations belong in infrastructure — domain is pure Java.

```
src/main/java/<base-package>/
  presentation/      ← @RestController — input adapters, NO business logic
  application/       ← @Service, @Transactional — orchestration only
  domain/            ← Pure Java POJOs/Records — ZERO Spring annotations
  infrastructure/    ← @Repository impl, @Entity (JPA), external adapters
src/main/resources/
  db/migration/      ← Flyway sequential migrations (V1__description.sql)
src/test/
  unit/              ← JUnit 5 + Mockito — no Spring context
  slice/             ← @WebMvcTest (HTTP), @DataJpaTest (DB)
  integration/       ← @SpringBootTest — sparingly
```

## Key Patterns

- **`@Entity` in infrastructure ONLY** — domain layer uses plain Java POJOs/Records; JPA annotations belong in infra
- **Constructor injection everywhere** — no `@Autowired` field injection; all beans declared `final`
- **Domain exception hierarchy** — `DomainException` base + domain-specific subtypes; `@ControllerAdvice` handles all
- **RFC 7807 ProblemDetail** — all HTTP error responses use `ProblemDetail` format (no custom JSON error shapes)
- **Log once at the boundary** — `@ControllerAdvice` logs; never log at service or domain level
- **`@ConfigurationProperties`** — all config bound via typed POJO, never raw `@Value`
- **Testcontainers for real DB** — `@DataJpaTest` always uses real PostgreSQL container, not H2
- **Test naming** — `methodName_givenCondition_thenExpectedResult`

## Domain Layer (pure Java)

```java
// domain/User.java — plain POJO, zero Spring imports
public record User(String id, String email, String name) {
  public User {
    if (email == null || email.isBlank()) throw new InvalidEmailException("Email required");
  }
}

// domain/exceptions/UserNotFoundException.java
public class UserNotFoundException extends DomainException {
  public UserNotFoundException(String id) {
    super("User not found: " + id, 404);
  }
}
```

## Application Layer

```java
@Service
@Transactional
public class UserService {
  private final UserRepository userRepository;  // final + constructor injection

  public UserService(UserRepository userRepository) {
    this.userRepository = userRepository;
  }

  public User register(String email, String name) {
    if (userRepository.existsByEmail(email)) throw new EmailAlreadyTakenException(email);
    User user = new User(UUID.randomUUID().toString(), email, name);
    return userRepository.save(user);
  }
}
```

## Infrastructure: JPA Entity

```java
// infrastructure/persistence/UserEntity.java — @Entity stays in infra
@Entity
@Table(name = "users")
public class UserEntity {
  @Id private String id;
  @Column(nullable = false, unique = true) private String email;
  @Column(nullable = false) private String name;

  // map to/from domain
  public User toDomain() { return new User(id, email, name); }
  public static UserEntity fromDomain(User u) {
    UserEntity e = new UserEntity();
    e.id = u.id(); e.email = u.email(); e.name = u.name();
    return e;
  }
}
```

## Presentation Layer

```java
@RestController
@RequestMapping("/api/users")
public class UserController {
  private final UserService userService;

  public UserController(UserService userService) { this.userService = userService; }

  @PostMapping
  @ResponseStatus(HttpStatus.CREATED)
  public UserResponse create(@Valid @RequestBody CreateUserRequest request) {
    User user = userService.register(request.email(), request.name());
    return UserResponse.from(user);
  }
}
```

Domain objects are never serialized directly — use response record/DTO.

## Error Handling

```java
// @ControllerAdvice maps domain exceptions to RFC 7807 ProblemDetail
@RestControllerAdvice
public class GlobalExceptionHandler {

  @ExceptionHandler(UserNotFoundException.class)
  public ProblemDetail handleUserNotFound(UserNotFoundException ex) {
    log.error("User not found", ex);  // log once here
    return ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, ex.getMessage());
  }

  @ExceptionHandler(DomainException.class)
  public ProblemDetail handleDomain(DomainException ex) {
    return ProblemDetail.forStatusAndDetail(
      HttpStatus.valueOf(ex.getStatus()), ex.getMessage()
    );
  }
}
```

HTTP response (RFC 7807):
```json
{ "type": "about:blank", "title": "Not Found", "status": 404, "detail": "User not found: 42" }
```

## Dependency Injection

Always constructor injection with `final` fields:
```java
// ✓ constructor injection
@Service
public class OrderService {
  private final UserRepository userRepository;
  private final OrderRepository orderRepository;

  public OrderService(UserRepository userRepository, OrderRepository orderRepository) {
    this.userRepository = userRepository;
    this.orderRepository = orderRepository;
  }
}

// ✗ field injection — never use
@Autowired private UserRepository userRepository;
```

For multiple beans of the same type, use `@Configuration` with explicit `@Bean` methods.

## Validation

```java
// Request DTO with Bean Validation
public record CreateUserRequest(
  @NotBlank @Email String email,
  @NotBlank @Size(max = 100) String name
) {}

// Domain validation in constructors (not Spring annotations)
public record User(String id, String email, String name) {
  public User {
    Objects.requireNonNull(email, "email required");
    if (!email.contains("@")) throw new InvalidEmailException(email);
  }
}
```

## Flyway Migrations

```sql
-- db/migration/V1__create_users.sql
CREATE TABLE users (
  id    VARCHAR(36) PRIMARY KEY,
  email VARCHAR(255) NOT NULL UNIQUE,
  name  VARCHAR(100) NOT NULL
);
```

Sequential numbered files. Run automatically at startup.

## Task Type → What to Apply

| Task | Key standards |
|---|---|
| Any endpoint | Architecture rules, constructor injection, DTOs separate from domain |
| Domain model | Pure Java — zero Spring annotations in `domain/` |
| Error handling | DomainException hierarchy + `@ControllerAdvice` + RFC 7807 |
| Data access | `@Entity` in infra only, Flyway for migrations, `@Transactional` in application |
| Auth | Spring Security 6, JWT filter, method security (`@PreAuthorize`) |
| Testing | JUnit 5 + Mockito for unit, `@WebMvcTest` for HTTP, `@DataJpaTest` + Testcontainers for DB |

For deeper standards, see `stacks/spring-boot/agent_docs/`.

## Red Flags

- `@Entity` annotation on a class in the `domain/` package
- Service class importing a JPA repository interface directly (bypasses application layer)
- `@Autowired` field injection (use constructor injection)
- `@SpringBootTest` for what should be a unit test
- Catching and re-throwing an exception with no added value
- Generic `RuntimeException` where a domain-specific exception should be used
- `@Value` for config (use `@ConfigurationProperties`)

## Verification Checklist

- [ ] `./gradlew build` (or `./mvnw verify`) passes
- [ ] No `@Entity` or `@Table` in `domain/` package
- [ ] No field `@Autowired` — only constructor injection
- [ ] `@ControllerAdvice` handles all exceptions (no ad-hoc `try/catch` in controllers)
- [ ] New `@RestController` endpoints have security annotations or are explicitly public
- [ ] Flyway migration added for any schema change
- [ ] 80% line coverage gate met
