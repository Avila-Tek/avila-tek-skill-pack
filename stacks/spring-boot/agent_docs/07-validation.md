# 07 · Validation

Validation occurs at two distinct levels in a Hexagonal Architecture and they must not be conflated. **DTO validation** (presentation layer) checks that the HTTP request is structurally sound: required fields are present, strings have the right format, numbers are in valid ranges. This is the job of Jakarta Bean Validation — annotations on request record classes, triggered automatically by `@Validated` on the controller. **Domain validation** (domain layer) checks that business invariants hold: an `Email` is semantically valid, a `User` name is not blank, a `Money` amount is non-negative. This lives in value object constructors and entity factory methods.

Mixing the two produces fragile systems. If domain validation only exists in Bean Validation annotations on a DTO, then the domain model can be instantiated in an invalid state from any path that bypasses the HTTP layer — a CLI command, an event consumer, a migration script. The domain must protect its own invariants regardless of what layer is calling it. Bean Validation is a convenience layer for HTTP clients; it is not a substitute for domain invariant enforcement.

---

## Jakarta Bean Validation on Request DTOs

Request DTOs are Java Records annotated with validation constraints. They live in the `presentation/` package and are never passed into the domain layer directly — they are converted to commands or value objects first.

```java
// ✅ Good — validated request DTO as a Java record
package com.avilatek.users.presentation;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CreateUserRequest(
    @NotBlank(message = "Name is required")
    @Size(min = 2, max = 100, message = "Name must be between 2 and 100 characters")
    String name,

    @NotBlank(message = "Email is required")
    @Email(message = "Email must be a valid email address")
    String email,

    @NotBlank(message = "Password is required")
    @Size(min = 8, message = "Password must be at least 8 characters")
    String password
) {}
```

```java
// ✅ Good — @Validated on the controller triggers Bean Validation
package com.avilatek.users.presentation;

@RestController
@RequestMapping("/api/v1/users")
public class UserController {

    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public UserResponse create(@RequestBody @Validated CreateUserRequest request) {
        // Bean Validation runs before this line is reached
        // If validation fails, MethodArgumentNotValidException is thrown
        return userService.createUser(
            new CreateUserCommand(request.name(), request.email(), request.password())
        );
    }
}
```

---

## Common Constraint Annotations

| Annotation             | Validates                                      |
|------------------------|------------------------------------------------|
| `@NotNull`             | Field is not null                              |
| `@NotBlank`            | String is not null and not whitespace-only     |
| `@NotEmpty`            | String/Collection is not null and not empty    |
| `@Email`               | String is a valid email format                 |
| `@Size(min, max)`      | String/Collection length within bounds         |
| `@Min(value)`          | Number is >= value                             |
| `@Max(value)`          | Number is <= value                             |
| `@Positive`            | Number is > 0                                  |
| `@PositiveOrZero`      | Number is >= 0                                 |
| `@Pattern(regexp)`     | String matches regex                           |
| `@Future`              | Date/time is in the future                     |
| `@Past`                | Date/time is in the past                       |

---

## Custom Validators with `@Constraint`

For business-specific validation rules that are too complex for built-in constraints, create a custom validator.

```java
// ✅ Good — custom constraint annotation
package com.avilatek.users.presentation;

import jakarta.validation.Constraint;
import jakarta.validation.Payload;

import java.lang.annotation.Documented;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

@Documented
@Constraint(validatedBy = StrongPasswordValidator.class)
@Target({ ElementType.FIELD, ElementType.PARAMETER })
@Retention(RetentionPolicy.RUNTIME)
public @interface StrongPassword {
    String message() default "Password must contain uppercase, lowercase, digit, and special character";
    Class<?>[] groups() default {};
    Class<? extends Payload>[] payload() default {};
}
```

```java
// ✅ Good — validator implementation
package com.avilatek.users.presentation;

import jakarta.validation.ConstraintValidator;
import jakarta.validation.ConstraintValidatorContext;

public class StrongPasswordValidator implements ConstraintValidator<StrongPassword, String> {

    private static final java.util.regex.Pattern PATTERN = java.util.regex.Pattern.compile(
        "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)(?=.*[^a-zA-Z0-9]).{8,}$"
    );

    @Override
    public boolean isValid(String password, ConstraintValidatorContext context) {
        if (password == null) return false;
        return PATTERN.matcher(password).matches();
    }
}
```

```java
// Usage in request record
public record CreateUserRequest(
    @NotBlank String name,
    @Email @NotBlank String email,
    @NotBlank @StrongPassword String password
) {}
```

---

## Domain Validation in Value Objects and Factory Methods

Domain invariants live in the domain layer, not in Bean Validation annotations. The canonical constructor of a record is the correct place for value object invariants.

```java
// ✅ Good — value object validates itself at construction
package com.avilatek.users.domain;

public record Email(String value) {
    public Email {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException("Email must not be blank");
        }
        // Use a real library check in production; simplified here for illustration
        if (!value.contains("@") || !value.contains(".")) {
            throw new IllegalArgumentException("Email format is invalid: " + value);
        }
        value = value.toLowerCase().strip();
    }
}
```

```java
// ✅ Good — entity factory method validates creation invariants
package com.avilatek.users.domain;

public final class User {
    public static User create(String name, String rawEmail) {
        if (name == null || name.isBlank()) {
            throw new IllegalArgumentException("User name must not be blank");
        }
        if (name.strip().length() < 2) {
            throw new IllegalArgumentException("User name is too short");
        }
        // Email record validates itself
        return new User(UserId.generate(), name.strip(), new Email(rawEmail), Status.ACTIVE, Instant.now());
    }
}
```

---

## DTO Validation vs Domain Validation

```
HTTP Request
    │
    ▼
CreateUserRequest (@Validated)   ← Bean Validation: required, format, size
    │
    ▼ (mapped to command)
CreateUserCommand
    │
    ▼
UserService.createUser()
    │
    ▼
User.create() / new Email()      ← Domain validation: semantic business invariants
    │
    ▼
UserRepository.save()
```

Bean Validation catches malformed HTTP input early and returns descriptive 400 errors to the client. Domain validation ensures business rules are never violated regardless of the entry path.

---

## Validation Groups for Partial Updates

For PATCH endpoints where only some fields are required, use validation groups.

```java
// ✅ Good — groups for create vs update validation scenarios
public interface OnCreate {}
public interface OnUpdate {}

public record UpsertUserRequest(
    @NotBlank(groups = OnCreate.class) String name,
    @Email @NotBlank(groups = OnCreate.class) String email,
    @Size(min = 8, groups = OnCreate.class) String password
) {}

// In controller:
@PostMapping
public UserResponse create(@RequestBody @Validated(OnCreate.class) UpsertUserRequest req) { ... }

@PatchMapping("/{id}")
public UserResponse update(@PathVariable UUID id,
                            @RequestBody @Validated(OnUpdate.class) UpsertUserRequest req) { ... }
```

---

## Anti-Patterns

### ❌ Validating only in Bean Validation, not in the domain
```java
// ✅ Bean Validation on DTO
public record CreateUserRequest(@NotBlank String email) {}

// ❌ No validation in the domain — Email can be created empty from other paths
public record Email(String value) {
    // no compact constructor validation
}

public class User {
    public static User create(String name, String rawEmail) {
        return new User(UserId.generate(), name, new Email(rawEmail)); // rawEmail could be blank
    }
}
```
An event consumer that directly calls `User.create()` can bypass all Bean Validation constraints.

### ❌ Returning validation errors as a generic 500
```java
@ExceptionHandler(Exception.class)
public ResponseEntity<String> handleAll(Exception ex) {
    return ResponseEntity.status(500).body("Something went wrong");
    // ❌ MethodArgumentNotValidException (400) caught here and returned as 500
}
```
Always handle `MethodArgumentNotValidException` specifically and return `400 Bad Request` with field-level error details.

### ❌ Performing database calls inside a `ConstraintValidator`
```java
public class UniqueEmailValidator implements ConstraintValidator<UniqueEmail, String> {
    @Autowired
    private UserJpaRepository jpaRepository; // ❌ DB call in a validator

    @Override
    public boolean isValid(String email, ConstraintValidatorContext ctx) {
        return !jpaRepository.existsByEmail(email); // runs on every validation call
    }
}
```
Uniqueness checks belong in the application service, where the transaction context is controlled. Running them in a validator couples Bean Validation to the database and makes it impossible to test in isolation.

---

[← Dependency Injection](./06-dependency-injection.md) | [Index](./README.md) | [Next: Testing →](./08-testing.md)
