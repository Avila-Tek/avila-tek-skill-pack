# 12 · HTTP Layer

The HTTP layer is the thinnest possible skin over the application. A `@RestController` has one job: translate an HTTP request into an application command, call the application service, translate the result into an HTTP response. That is three steps — and only three. If a controller method contains conditional logic, domain calculations, or direct database calls, the controller is doing too much. Business logic in a controller is logic that cannot be reused, is hard to test without an HTTP context, and is invisible to the domain model.

Request and response shapes are Java Records. Records are final, immutable, concise, and their compact constructor provides a natural place for input coercion. Jackson deserialises into them; Jackson serialises from them. Domain entities never appear in HTTP responses — they are mapped to response records at the controller or mapper level. Jackson annotations (`@JsonProperty`, `@JsonIgnore`) belong exclusively on request/response records; the domain model must not know how it is serialised.

---

## Controller Structure

```java
// ✅ Good — thin controller: parse, validate, delegate, map
package com.avilatek.users.presentation;

import com.avilatek.users.application.UserService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import java.net.URI;
import java.util.UUID;

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
        return userService.createUser(
            new CreateUserCommand(request.name(), request.email())
        );
    }

    @GetMapping("/{id}")
    public UserResponse getById(@PathVariable UUID id) {
        return userService.getUser(id.toString());
    }

    @PatchMapping("/{id}/suspend")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void suspend(@PathVariable UUID id) {
        userService.suspendUser(id.toString());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable UUID id) {
        userService.deleteUser(id.toString());
        return ResponseEntity.noContent().build();
    }
}
```

---

## Request DTOs — Java Records

Request records are deserialized from JSON by Jackson. They live in `presentation/` and are never passed into the domain layer — they are converted to application commands first.

```java
// ✅ Good — request record with Bean Validation annotations
package com.avilatek.users.presentation;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CreateUserRequest(
    @NotBlank(message = "Name is required")
    @Size(min = 2, max = 100, message = "Name must be 2–100 characters")
    String name,

    @NotBlank(message = "Email is required")
    @Email(message = "Must be a valid email address")
    String email
) {}
```

```java
// ✅ Good — update request where all fields are optional (PATCH semantics)
package com.avilatek.users.presentation;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.Size;

public record UpdateUserRequest(
    @Size(min = 2, max = 100, message = "Name must be 2–100 characters")
    String name,        // null means "do not update"

    @Email(message = "Must be a valid email address")
    String email        // null means "do not update"
) {}
```

---

## Response DTOs — Java Records

Response records are serialised to JSON. They are constructed by the application service (or a mapper). Jackson annotations are acceptable here.

```java
// ✅ Good — response record; Jackson annotations allowed here, not on domain
package com.avilatek.users.presentation;

import com.fasterxml.jackson.annotation.JsonProperty;

import java.time.Instant;

public record UserResponse(
    String id,
    String name,
    String email,
    String status,

    @JsonProperty("createdAt")
    Instant createdAt
) {
    // Factory method converts domain entity to response record
    public static UserResponse from(com.avilatek.users.domain.User user) {
        return new UserResponse(
            user.id().value().toString(),
            user.name(),
            user.email().value(),
            user.status().name(),
            user.createdAt()
        );
    }
}
```

---

## Application Command Records

Commands carry the input from presentation to application layer. They contain validated primitive values — strings, UUIDs — not domain objects. The application service constructs domain objects from commands.

```java
// ✅ Good — command record between presentation and application
package com.avilatek.users.application;

public record CreateUserCommand(String name, String email) {}
```

---

## CORS Configuration

```java
// ✅ Good — explicit CORS configuration, not @CrossOrigin scattered on controllers
package com.avilatek.shared.presentation;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.List;

@Configuration
class CorsConfig {

    @Bean
    CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration config = new CorsConfiguration();
        config.setAllowedOriginPatterns(List.of(
            "https://*.avilatek.com",
            "http://localhost:3000"   // dev frontend
        ));
        config.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        config.setAllowedHeaders(List.of("Authorization", "Content-Type", "X-Correlation-Id"));
        config.setAllowCredentials(true);
        config.setMaxAge(3600L);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/api/**", config);
        return source;
    }
}
```

---

## OpenAPI with Springdoc

```kotlin
// build.gradle.kts
implementation("org.springdoc:springdoc-openapi-starter-webmvc-ui:2.5.0")
```

```yaml
# application.yml
springdoc:
  api-docs:
    path: /api-docs
  swagger-ui:
    path: /swagger-ui.html
    operationsSorter: method
  show-actuator: false
```

```java
// ✅ Good — OpenAPI annotations on controllers, not on domain
package com.avilatek.users.presentation;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;

@Tag(name = "Users", description = "User management endpoints")
@RestController
@RequestMapping("/api/v1/users")
public class UserController {

    @Operation(
        summary = "Create a new user",
        responses = {
            @ApiResponse(responseCode = "201", description = "User created"),
            @ApiResponse(responseCode = "400", description = "Validation failed"),
            @ApiResponse(responseCode = "409", description = "Email already taken")
        }
    )
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public UserResponse create(@RequestBody @Validated CreateUserRequest request) {
        return userService.createUser(new CreateUserCommand(request.name(), request.email()));
    }
}
```

---

## HTTP Status Code Conventions

| Scenario                            | Status Code             |
|-------------------------------------|-------------------------|
| Successful retrieval                | `200 OK`                |
| Successful creation                 | `201 Created`           |
| Successful update with body         | `200 OK`                |
| Successful update without body      | `204 No Content`        |
| Successful deletion                 | `204 No Content`        |
| Validation error                    | `400 Bad Request`       |
| Authentication required             | `401 Unauthorized`      |
| Authorisation denied                | `403 Forbidden`         |
| Resource not found                  | `404 Not Found`         |
| Business rule conflict              | `409 Conflict`          |
| Rate limit exceeded                 | `429 Too Many Requests` |
| Unexpected server error             | `500 Internal Server Error` |

---

## Pagination

```java
// ✅ Good — paginated response record
package com.avilatek.shared.presentation;

import java.util.List;

public record PageResponse<T>(
    List<T> content,
    int page,
    int size,
    long totalElements,
    int totalPages,
    boolean last
) {
    public static <T> PageResponse<T> from(org.springframework.data.domain.Page<T> page) {
        return new PageResponse<>(
            page.getContent(),
            page.getNumber(),
            page.getSize(),
            page.getTotalElements(),
            page.getTotalPages(),
            page.isLast()
        );
    }
}
```

---

## Anti-Patterns

### ❌ Business logic in the controller
```java
@PostMapping
public UserResponse create(@RequestBody CreateUserRequest request) {
    // ❌ business rule check in the controller
    if (request.email().endsWith("@competitor.com")) {
        throw new IllegalArgumentException("Competitor emails not allowed");
    }
    return userService.createUser(...);
}
```
This rule belongs in the domain layer or application service. Controllers cannot share logic with other entry points (CLI, event consumers).

### ❌ Returning domain entities directly from controllers
```java
@GetMapping("/{id}")
public User getById(@PathVariable UUID id) {  // ❌ returns domain entity with no Jackson control
    return userService.getUser(id.toString()); // exposes all fields including internal state
}
```
Domain entities have no Jackson annotations. Returning them couples the HTTP contract to domain internals. Map to a response record always.

### ❌ Jackson annotations on domain entities
```java
// ❌ Bad — Jackson annotations in the domain layer
package com.avilatek.users.domain;

@JsonIgnoreProperties(ignoreUnknown = true)
public final class User {
    @JsonProperty("user_id")
    private final UserId id;
    ...
}
```
The domain must not depend on Jackson. Serialisation is a presentation concern.

### ❌ Fat controllers with multiple responsibilities
```java
@RestController
public class UserController {
    @Autowired private UserJpaRepository repo;
    @Autowired private EmailService emailService;
    @Autowired private AuditService auditService;
    // ❌ controller is orchestrating business logic directly
}
```
Every dependency beyond the application service is a design smell. The controller calls one service; the service orchestrates the rest.

---

[← Observability](./11-observability.md) | [Index](./README.md) | [Next: Tooling →](./13-tooling.md)
