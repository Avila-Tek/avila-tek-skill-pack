# 10 · Configuration

Configuration is code — it deserves the same rigour as production code. `@ConfigurationProperties` binds a validated, type-safe configuration object from `application.yml`, turning loosely-typed string properties into Java classes or records that can be injected just like any other bean. When a required property is missing or malformed, the application fails at startup with a clear error message instead of failing at runtime with a `NullPointerException`. Catching misconfiguration at startup, before any request is served, is the correct behaviour.

The corollary is that secrets must never appear in `application.yml` committed to version control. Every sensitive value — database passwords, API keys, JWT secrets, SMTP credentials — flows through environment variables referenced with `${ENV_VAR_NAME}` placeholders. In production, these are injected by the deployment platform (Kubernetes secrets, AWS Parameter Store, Vault). In development, they come from a `.env` file loaded by Docker Compose. The `.env` file is gitignored; the `.env.example` file is committed with placeholder values.

---

## `@ConfigurationProperties` with Records

Java Records are ideal for configuration because they are immutable and their compact constructor can validate values at startup.

```java
// ✅ Good — type-safe configuration record with Bean Validation
package com.avilatek.shared.infrastructure.config;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

@Validated
@ConfigurationProperties(prefix = "app.database")
public record DatabaseProperties(
    @NotBlank String url,
    @NotBlank String username,
    @NotBlank String password,
    @Min(1) int poolSize,
    @Min(1000) long connectionTimeoutMs
) {}
```

```java
// ✅ Good — JWT configuration record
package com.avilatek.shared.infrastructure.config;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;
import java.time.Duration;

@Validated
@ConfigurationProperties(prefix = "app.jwt")
public record JwtProperties(
    @NotBlank String secret,
    @NotNull Duration accessTokenExpiry,
    @NotNull Duration refreshTokenExpiry
) {}
```

Enable configuration property scanning in the main class or a `@Configuration` class:

```java
// ✅ Good — enable configuration properties scanning
@SpringBootApplication
@ConfigurationPropertiesScan("com.avilatek")
public class Application {
    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }
}
```

---

## `application.yml` Structure

```yaml
# application.yml — base configuration, no environment-specific values, no secrets
spring:
  application:
    name: avilatek-service
  jpa:
    hibernate:
      ddl-auto: validate
    open-in-view: false
    show-sql: false
  flyway:
    enabled: true
    locations: classpath:db/migration
    validate-on-migrate: true
  mvc:
    problemdetails:
      enabled: true

app:
  database:
    pool-size: 10
    connection-timeout-ms: 30000
    # url, username, password come from profile-specific files or env vars

  jwt:
    access-token-expiry: PT15M    # ISO-8601 duration: 15 minutes
    refresh-token-expiry: P7D     # ISO-8601 duration: 7 days
    # secret comes from env var

management:
  endpoints:
    web:
      exposure:
        include: health,metrics,info,prometheus
  endpoint:
    health:
      show-details: when_authorized
```

```yaml
# application-dev.yml — developer defaults, no secrets committed
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/avilatek_dev
    username: avilatek
    password: ${DB_PASSWORD:localdev}   # falls back to "localdev" for dev convenience
  jpa:
    show-sql: true

app:
  database:
    url: jdbc:postgresql://localhost:5432/avilatek_dev
    username: avilatek
    password: ${DB_PASSWORD:localdev}
  jwt:
    secret: ${JWT_SECRET:dev-only-secret-32-characters-min}

logging:
  level:
    com.avilatek: DEBUG
    org.springframework.web: DEBUG
```

```yaml
# application-prod.yml — references environment variables only
app:
  database:
    url: ${DATABASE_URL}
    username: ${DATABASE_USER}
    password: ${DATABASE_PASSWORD}
    pool-size: ${DB_POOL_SIZE:20}
  jwt:
    secret: ${JWT_SECRET}

logging:
  level:
    root: WARN
    com.avilatek: INFO
```

---

## Profile-Specific Beans with `@Profile`

```java
// ✅ Good — different email sender implementations per environment
package com.avilatek.shared.infrastructure.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;

@Configuration
class EmailConfiguration {

    @Bean
    @Profile("prod")
    EmailSender smtpEmailSender(EmailProperties properties) {
        return new SmtpEmailSender(properties.host(), properties.port(), properties.username(), properties.password());
    }

    @Bean
    @Profile("!prod")  // dev and test
    EmailSender consoleEmailSender() {
        return email -> System.out.println("[DEV EMAIL] To: " + email.to() + " | Subject: " + email.subject());
    }
}
```

---

## Secrets — Environment Variables

```yaml
# application-prod.yml — every secret is an environment variable reference
app:
  jwt:
    secret: ${JWT_SECRET}             # required — app fails at startup if missing
  database:
    password: ${DATABASE_PASSWORD}    # required
  external-api:
    key: ${EXTERNAL_API_KEY}          # required
```

```bash
# .env.example — committed, shows required variables without values
DATABASE_URL=jdbc:postgresql://localhost:5432/avilatek_dev
DATABASE_USER=avilatek
DATABASE_PASSWORD=
JWT_SECRET=
EXTERNAL_API_KEY=
```

```
# .gitignore
.env          # never committed
*.env.local
```

---

## Configuration Validation at Startup

When `@Validated` is placed on a `@ConfigurationProperties` class, Bean Validation runs during context initialisation. Missing required properties or invalid values cause the application to fail immediately with a descriptive error.

```java
// ✅ Good — validation catches misconfiguration before the app starts serving requests
@Validated
@ConfigurationProperties(prefix = "app.email")
public record EmailProperties(
    @NotBlank(message = "Email host must be configured") String host,
    @Min(value = 1, message = "Email port must be positive") int port,
    @NotBlank String username,
    @NotBlank String password
) {}
```

If `app.email.host` is missing from the active profile, the application fails at startup:

```
APPLICATION STARTUP FAILED: Binding to target 'app.email' failed:
  Property: app.email.host
  Value: ""
  Reason: Email host must be configured
```

---

## Exposing Configuration as Beans for Injection

```java
// ✅ Good — configuration properties injected via constructor
@Service
public class JwtService {

    private final JwtProperties jwtProperties;

    public JwtService(JwtProperties jwtProperties) {
        this.jwtProperties = jwtProperties;
    }

    public String generateAccessToken(String subject) {
        return Jwts.builder()
            .subject(subject)
            .expiration(Date.from(Instant.now().plus(jwtProperties.accessTokenExpiry())))
            .signWith(Keys.hmacShaKeyFor(jwtProperties.secret().getBytes()))
            .compact();
    }
}
```

---

## Anti-Patterns

### ❌ Injecting `Environment` directly
```java
@Service
public class SomeService {
    @Autowired
    private Environment environment;

    public String getApiKey() {
        return environment.getProperty("app.external-api.key"); // ❌ no type safety, no validation
    }
}
```
Use `@ConfigurationProperties` records. They are type-safe, validated at startup, and injected like any other bean.

### ❌ Hardcoded secrets in YAML
```yaml
app:
  jwt:
    secret: my-super-secret-key-that-is-in-git  # ❌ committed to version control
```
Any secret committed to git is compromised. Rotate it immediately and use environment variables going forward.

### ❌ Using `@Value` for complex configuration
```java
@Service
public class UserService {
    @Value("${app.user.max-login-attempts}")
    private int maxLoginAttempts;

    @Value("${app.user.lockout-duration-minutes}")
    private int lockoutDurationMinutes;

    // Two isolated @Value fields — no grouping, no validation, no documentation
}
```
Group related properties in a `@ConfigurationProperties` record: `UserSecurityProperties(int maxLoginAttempts, int lockoutDurationMinutes)`. It is self-documenting, validatable, and injected cleanly.

### ❌ Ignoring the `spring.jpa.open-in-view` default
```yaml
# application.yml — omitting this causes WARN log and session leaks
# spring.jpa.open-in-view: true  ← default in older Spring Boot
```
Always set `spring.jpa.open-in-view: false` explicitly. The Open Session in View pattern holds a database connection for the entire HTTP request lifecycle, including time spent in the view/serialisation layer — that is connection pool waste.

---

[← Data Access](./09-data-access.md) | [Index](./README.md) | [Next: Observability →](./11-observability.md)
