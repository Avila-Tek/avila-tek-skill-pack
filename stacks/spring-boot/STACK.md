---
stack: spring-boot
label: "Java Spring Boot"
type: backend
detection:
  files:
    - "pom.xml"
    - "build.gradle"
  content_pattern: "spring-boot"
---

# Stack: Java Spring Boot

## Summary

Java Spring Boot backend. Hexagonal Architecture with strict layer separation. JPA/Hibernate for persistence with Flyway migrations, Spring Security 6 for auth, Testcontainers for integration tests. Build tool: Gradle (or Maven). Java 21+.

## Architecture Overview

```
src/main/java/<base-package>/
  presentation/      ← @RestController — input adapters, NO business logic
  application/       ← @Service, @Transactional — orchestration only
  domain/            ← Pure Java POJOs/Records — ZERO Spring annotations
  infrastructure/    ← @Repository impl, @Entity (JPA), external adapters
src/main/resources/
  db/migration/      ← Flyway sequential migrations (V1__description.sql)
src/test/java/
  unit/              ← JUnit 5 + Mockito — no Spring context
  slice/             ← @WebMvcTest (HTTP), @DataJpaTest (DB)
  integration/       ← @SpringBootTest — sparingly
```

## Key Patterns

- **@Entity in infrastructure ONLY** — domain layer uses plain Java POJOs/Records; JPA annotations belong in infra
- **Constructor injection everywhere** — no `@Autowired` field injection; all beans declared `final`
- **Domain exception hierarchy** — `DomainException` base + domain-specific subtypes; `@ControllerAdvice` handles all
- **RFC 7807 ProblemDetail** — all HTTP error responses use `ProblemDetail` format (no custom JSON error shapes)
- **Log once at the boundary** — `@ControllerAdvice` logs the exception; never log at service or domain level
- **@ConfigurationProperties** — all config values bound via typed POJO, never raw `@Value`
- **Testcontainers for real DB** — `@DataJpaTest` always uses a real PostgreSQL container, not H2
- **Test naming** — `methodName_givenCondition_thenExpectedResult` for all test methods

## Standards Documents

Standards live in `stacks/spring-boot/agent_docs/`:

| File | Content |
|------|---------|
| `README.md` | Architecture overview — Hexagonal zones, Spring component mapping |
| `01-project-layout.md` | Directory structure, package conventions, Gradle setup |
| `02-package-design.md` | Visibility rules, domain-per-package, circular dependency enforcement |
| `03-architecture.md` | Hexagonal zones, Spring component mapping, Dependency Rule |
| `04-domain-model.md` | POJOs, Records, invariant enforcement, rich vs anemic |
| `05-error-handling.md` | Exception hierarchy, @ControllerAdvice, ProblemDetail (RFC 7807) |
| `06-dependency-injection.md` | Constructor injection, @Configuration, final fields |
| `07-validation.md` | Bean Validation, custom validators, DTO vs domain validation |
| `08-testing.md` | Unit, slice, integration tests; Testcontainers; naming conventions |
| `09-data-access.md` | JPA entities, repository impl, Flyway migrations, @Transactional |
| `10-configuration.md` | @ConfigurationProperties, profiles, secrets, validation |
| `11-observability.md` | Structured logging, MDC, Micrometer, Actuator, tracing |
| `12-http-layer.md` | Thin controllers, request/response records, OpenAPI, CORS |
| `13-tooling.md` | Gradle DSL, Checkstyle, Spotless, GitHub Actions, Docker Compose |
| `14-authentication.md` | Spring Security 6, JWT filter, RBAC, method security |

## Testing Conventions

- Unit tests: JUnit 5 + Mockito — instantiate classes directly (no Spring context), fast
- Slice tests: `@WebMvcTest` for HTTP layer (MockMvc), `@DataJpaTest` for persistence (Testcontainers)
- Integration tests: `@SpringBootTest` — use sparingly, only for critical happy paths
- Object Mothers pattern for test data factories
- 80% line coverage gate minimum

## Red Flags

- `@Entity` annotation on a class in the `domain/` package
- Service class importing a JPA repository interface directly (bypasses application layer)
- `@Autowired` field injection (use constructor injection)
- `@SpringBootTest` used for what should be a unit test
- Catching and re-throwing an exception with no added value
- Generic `RuntimeException` thrown where a domain-specific exception should be used

## Verification Checklist

- [ ] `./gradlew build` passes (or `./mvnw verify`)
- [ ] No `@Entity` or `@Table` in `domain/` package
- [ ] No field `@Autowired` — only constructor injection
- [ ] `@ControllerAdvice` handles all exceptions (no ad-hoc `try/catch` in controllers)
- [ ] New `@RestController` endpoints have security annotations or are explicitly public
- [ ] Flyway migration added for any schema change
