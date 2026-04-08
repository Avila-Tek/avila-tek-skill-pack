# 05 · Error Handling

Error handling is not an afterthought — it is part of the domain language. When a user tries to register with an email that is already taken, the system should say `EmailAlreadyTakenException`, not `DataIntegrityViolationException`. The domain exception carries meaning; the JPA exception carries implementation detail. Translating infrastructure errors into domain terms is the responsibility of the adapter layer. Translating domain errors into HTTP responses is the responsibility of the presentation layer, specifically through a `@ControllerAdvice` handler.

The logging corollary is equally important: log at the boundary, once. An exception thrown deep in the domain should not be logged in the domain, again in the application service, and again in the controller. Log it once where it crosses the boundary into an external concern — the `@ControllerAdvice`. Every additional log site for the same exception adds noise, confuses correlation, and makes the log volume unreliable. Deep layers should throw; the boundary should log and respond.

---

## Domain Exception Hierarchy

Every bounded context defines its own exception hierarchy rooted in a domain-specific base class, which in turn extends a shared `DomainException`.

```java
// ✅ Good — shared base in the shared package
package com.avilatek.shared.domain;

public abstract class DomainException extends RuntimeException {
    protected DomainException(String message) {
        super(message);
    }

    protected DomainException(String message, Throwable cause) {
        super(message, cause);
    }
}
```

```java
// ✅ Good — domain-specific base for the users context
package com.avilatek.users.domain;

import com.avilatek.shared.domain.DomainException;

public abstract class UserException extends DomainException {
    protected UserException(String message) {
        super(message);
    }
}
```

```java
// ✅ Good — concrete domain exceptions are precise and named
package com.avilatek.users.domain;

public final class UserNotFoundException extends UserException {
    public UserNotFoundException(UserId id) {
        super("User not found: " + id.value());
    }
}
```

```java
package com.avilatek.users.domain;

public final class EmailAlreadyTakenException extends UserException {
    public EmailAlreadyTakenException(String email) {
        super("Email is already registered: " + email);
    }
}
```

---

## ProblemDetail — RFC 7807 (Spring Boot 3.x)

Spring Boot 3.x includes built-in support for `ProblemDetail` (RFC 7807). Use it as the standard HTTP error response format. It is a machine-readable JSON body with a `type`, `title`, `status`, `detail`, and optional extensions.

```json
{
  "type": "https://errors.avilatek.com/user-not-found",
  "title": "User Not Found",
  "status": 404,
  "detail": "User not found: 3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "instance": "/api/v1/users/3fa85f64-5717-4562-b3fc-2c963f66afa6"
}
```

---

## `@ControllerAdvice` — Global Exception Handler

```java
// ✅ Good — single boundary for exception-to-HTTP translation and logging
package com.avilatek.shared.presentation;

import com.avilatek.users.domain.EmailAlreadyTakenException;
import com.avilatek.users.domain.UserNotFoundException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.net.URI;

@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);
    private static final String ERROR_BASE_URI = "https://errors.avilatek.com/";

    @ExceptionHandler(UserNotFoundException.class)
    public ProblemDetail handleUserNotFound(UserNotFoundException ex) {
        log.warn("User not found: {}", ex.getMessage());
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, ex.getMessage());
        problem.setType(URI.create(ERROR_BASE_URI + "user-not-found"));
        problem.setTitle("User Not Found");
        return problem;
    }

    @ExceptionHandler(EmailAlreadyTakenException.class)
    public ProblemDetail handleEmailTaken(EmailAlreadyTakenException ex) {
        log.warn("Email conflict: {}", ex.getMessage());
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(HttpStatus.CONFLICT, ex.getMessage());
        problem.setType(URI.create(ERROR_BASE_URI + "email-already-taken"));
        problem.setTitle("Email Already Taken");
        return problem;
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ProblemDetail handleValidation(MethodArgumentNotValidException ex) {
        log.debug("Validation failed: {}", ex.getMessage());
        ProblemDetail problem = ProblemDetail.forStatus(HttpStatus.BAD_REQUEST);
        problem.setType(URI.create(ERROR_BASE_URI + "validation-error"));
        problem.setTitle("Validation Failed");
        problem.setDetail("One or more fields failed validation");
        problem.setProperty("errors", ex.getBindingResult().getFieldErrors().stream()
            .map(fe -> fe.getField() + ": " + fe.getDefaultMessage())
            .toList());
        return problem;
    }

    @ExceptionHandler(Exception.class)
    public ProblemDetail handleUnexpected(Exception ex) {
        log.error("Unexpected error", ex);
        ProblemDetail problem = ProblemDetail.forStatus(HttpStatus.INTERNAL_SERVER_ERROR);
        problem.setType(URI.create(ERROR_BASE_URI + "internal-error"));
        problem.setTitle("Internal Server Error");
        problem.setDetail("An unexpected error occurred. Please try again later.");
        return problem;
    }
}
```

---

## Translating Infrastructure Errors to Domain Errors

JPA and database exceptions are infrastructure noise. The repository implementation catches them and re-throws meaningful domain exceptions.

```java
// ✅ Good — infrastructure exception translated at the adapter boundary
package com.avilatek.users.infrastructure.persistence;

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
            // Translate infrastructure error to domain concept
            if (ex.getMessage() != null && ex.getMessage().contains("users_email_key")) {
                throw new EmailAlreadyTakenException(user.email().value());
            }
            throw ex; // unknown constraint violation — let it propagate
        }
    }
}
```

```java
// ❌ Bad — DataIntegrityViolationException leaking into the application layer
@Service
public class UserService {
    public UserResponse createUser(CreateUserCommand cmd) {
        try {
            userRepository.save(user);
        } catch (DataIntegrityViolationException ex) { // ❌ infrastructure type in application layer
            throw new EmailAlreadyTakenException(cmd.email());
        }
    }
}
```

---

## Enable RFC 7807 Globally in application.yml

```yaml
# application.yml
spring:
  mvc:
    problemdetails:
      enabled: true   # enables ProblemDetail for Spring's built-in exceptions too
```

With this flag, Spring itself will format `MethodArgumentNotValidException`, `NoHandlerFoundException`, and other built-in exceptions as `ProblemDetail` automatically. Your `@ControllerAdvice` only needs to handle domain and custom exceptions.

---

## Log Levels by Severity

| Situation                        | Log Level | Example                                    |
|----------------------------------|-----------|--------------------------------------------|
| Resource not found (404)         | `WARN`    | `log.warn("User not found: {}", id)`       |
| Business rule violation (409)    | `WARN`    | `log.warn("Email conflict: {}", email)`    |
| Validation error (400)           | `DEBUG`   | `log.debug("Validation failed: {}", msg)`  |
| Auth failure (401, 403)          | `WARN`    | `log.warn("Unauthorized access: {}", req)` |
| Unexpected exception (500)       | `ERROR`   | `log.error("Unexpected error", ex)`        |

Do not log stack traces for expected domain exceptions (404, 409, 400). Stack traces are for unexpected failures.

---

## Anti-Patterns

### ❌ Catching and re-throwing the same exception type without adding value
```java
try {
    userRepository.save(user);
} catch (UserException ex) {
    log.error("Failed to save user", ex); // ❌ logs here AND in @ControllerAdvice
    throw ex;                              // double-logged; stack trace doubled
}
```
Either handle the exception or let it propagate. Do not log and re-throw. The `@ControllerAdvice` is the designated logging site for unhandled exceptions.

### ❌ Returning `null` instead of throwing
```java
// ❌ Bad — caller must null-check; no information about why it's null
public User findById(UUID id) {
    return jpaRepository.findById(id).orElse(null);
}
```
Throw a `UserNotFoundException`. `null` is not a domain concept; it is an absence of a value that the caller cannot distinguish from a bug.

### ❌ Using generic `RuntimeException` directly
```java
throw new RuntimeException("User not found"); // ❌ no type; cannot catch specifically
throw new RuntimeException("Email taken");    // ❌ same type as "user not found"
```
Named exceptions make `@ExceptionHandler` mappings precise. They make logs searchable. They communicate intent to the next engineer.

### ❌ Swallowing exceptions silently
```java
try {
    emailService.sendWelcomeEmail(user.email().value());
} catch (Exception e) {
    // ❌ silent — the caller has no idea the email failed
}
```
At minimum, log at `ERROR` level. Prefer to let the exception propagate and decide at the boundary whether it is fatal or recoverable.

---

[← Domain Model](./04-domain-model.md) | [Index](./README.md) | [Next: Dependency Injection →](./06-dependency-injection.md)
