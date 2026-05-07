# Spring Boot — Code Review Reference

## Architecture Red Flags

These are blocking findings in a code review:

- `@Entity` or `@Table` annotation on a class inside `domain/` package — JPA annotations belong exclusively in `infrastructure/persistence/`
- `@Autowired` field injection — constructor injection with `final` fields is mandatory everywhere
- `@SpringBootTest` used where a unit test with plain JUnit + Mockito would suffice — reserve `@SpringBootTest` for true integration tests
- `@ControllerAdvice` missing or exceptions caught with ad-hoc `try/catch` in controllers — all exceptions must flow to `GlobalExceptionHandler`
- `@Value` annotation for config — use `@ConfigurationProperties` with a typed POJO instead
- Generic `RuntimeException` or `Exception` thrown where a domain-specific exception should be used
- Catching and re-throwing an exception with no added value (`catch (e) { throw e; }`)
- Service class importing a JPA repository interface directly (bypasses the application layer)

## Dependency Injection

Constructor injection with `final` fields — always:

```java
// ✅ Constructor injection
@Service
public class UserService {
    private final UserRepository userRepository;

    public UserService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }
}

// ❌ Field injection — never
@Autowired
private UserRepository userRepository;
```

For multiple beans of the same type, use `@Configuration` with explicit `@Bean` methods — never `@Qualifier` as a workaround.

## Layer Boundaries

- **Presentation** (`@RestController`): parse request → validate → call service → map to response DTO. Zero business logic.
- **Application** (`@Service`): orchestrate domain operations. No JPA/Hibernate imports.
- **Domain**: pure Java. Zero Spring imports, zero JPA imports.
- **Infrastructure**: `@Entity`, `@Repository`, external adapters. Only layer that may import JPA.

Domain objects are never serialized directly — always use a response DTO/record:

```java
// ✅ Map domain → response DTO in controller
return UserResponse.from(user);

// ❌ Serialize domain entity directly
return user; // exposes internal fields, coupling domain to HTTP contract
```

## Error Handling

All exceptions mapped in `@RestControllerAdvice` using RFC 7807 `ProblemDetail`. Log once here — never at domain or service level:

```java
@ExceptionHandler(UserNotFoundException.class)
public ProblemDetail handleUserNotFound(UserNotFoundException ex) {
    log.error("User not found", ex); // ← log once, here
    return ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, ex.getMessage());
}
```

## Configuration

`@ConfigurationProperties` for all config — never `@Value`:

```java
// ✅
@ConfigurationProperties(prefix = "jwt")
public record JwtProperties(String secret, Duration accessTokenExpiry, Duration refreshTokenExpiry) {}

// ❌
@Value("${jwt.secret}") private String jwtSecret;
```

## Testing Standards (Review Axis)

Verify that new code includes the correct test level:
- Domain logic → plain JUnit 5, no Spring context
- Repository → `@DataJpaTest` + Testcontainers (real PostgreSQL, never H2)
- Controller → `@WebMvcTest` + `@MockBean`
- Only true integration → `@SpringBootTest`

Test naming: `methodName_givenCondition_thenExpectedResult` — no `testX()`, no `shouldDoX()`.

## Flyway Migrations

Any schema change must include a sequential Flyway migration:

```sql
-- db/migration/V{N}__description.sql
ALTER TABLE users ADD COLUMN phone VARCHAR(20);
```

Migrations are numbered sequentially. Never modify an existing migration that has already run in any environment.

## Verification Checklist

- [ ] `./gradlew build` (or `./mvnw verify`) — passes
- [ ] No `@Entity`/`@Table` in `domain/` package
- [ ] No field `@Autowired` — constructor injection everywhere
- [ ] `@ControllerAdvice` handles all exceptions — no ad-hoc `try/catch` in controllers
- [ ] New `@RestController` endpoints have `@PreAuthorize` or are explicitly `permitAll()`
- [ ] Flyway migration added for any schema change
- [ ] No `@SpringBootTest` where plain JUnit would suffice
- [ ] Test naming follows `methodName_givenCondition_thenExpectedResult`
- [ ] No `@Value` — all config via `@ConfigurationProperties`
- [ ] Domain objects never returned directly from controllers — always a DTO
