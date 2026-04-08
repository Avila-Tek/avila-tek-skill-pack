# Java + Spring Boot Style Guide

Avila Tek builds its Java services on **Hexagonal Architecture (Ports & Adapters)**, a structural pattern that places the domain model at the center and forces every external concern — HTTP, databases, queues, third-party APIs — to adapt to it, not the other way around. This inversion of dependency is not cosmetic. It means the domain can be tested in isolation, swapped to a different framework, or re-deployed as a CLI without touching business logic. Spring Boot is an infrastructure tool; it lives at the edges, never at the core.

Every rule in this guide exists to protect that boundary. Package-private visibility, constructor injection, separate JPA entities, thin controllers — all of these are mechanisms that enforce the Dependency Rule: source code dependencies point inward. When you find yourself fighting the architecture to make something work, that is a signal the design needs attention, not a workaround. Read these guides in order the first time; revisit individual sections as needed.

---

## Architecture Zones

```
┌──────────────────────────────────────────────────────┐
│                   PRESENTATION                        │
│         @RestController, Request/Response DTOs        │
│                 (HTTP Adapter — Input)                │
├──────────────────────────────────────────────────────┤
│                   APPLICATION                         │
│         @Service (Application Services)               │
│         Use-case orchestration, @Transactional        │
├──────────────────────────────────────────────────────┤
│                     DOMAIN                            │
│        Pure Java: Entities, Value Objects             │
│        Domain Services, Repository Interfaces         │
│              (No Spring annotations here)             │
├──────────────────────────────────────────────────────┤
│                  INFRASTRUCTURE                       │
│   JPA Entities, Spring Data Repos, Flyway, Security  │
│            (DB Adapter — Output)                      │
└──────────────────────────────────────────────────────┘
```

| Hexagonal Concept     | Spring Boot Implementation                        |
|-----------------------|---------------------------------------------------|
| Domain Entity         | Plain Java class (POJO), no framework annotations |
| Value Object          | Java `record`                                     |
| Port (output)         | Java `interface` in `domain/` package             |
| Application Service   | `@Service` class in `application/` package        |
| HTTP Adapter (input)  | `@RestController` in `presentation/` package      |
| DB Adapter (output)   | `@Repository` implementation in `infrastructure/` |
| JPA Entity            | `@Entity` class in `infrastructure/persistence/`  |
| Configuration         | `@Configuration` + `@ConfigurationProperties`     |
| Cross-cutting         | `shared/` package for value objects, base types   |

---

## Table of Contents

- [01 · Project Layout](./01-project-layout.md) — Directory structure, package conventions, Gradle setup
- [02 · Package Design](./02-package-design.md) — Visibility rules, domain-per-package, circular dependency enforcement
- [03 · Architecture](./03-architecture.md) — Hexagonal zones, Spring component mapping, Dependency Rule
- [04 · Domain Model](./04-domain-model.md) — POJOs, Records, invariant enforcement, rich vs anemic
- [05 · Error Handling](./05-error-handling.md) — Exception hierarchy, @ControllerAdvice, ProblemDetail (RFC 7807)
- [06 · Dependency Injection](./06-dependency-injection.md) — Constructor injection, @Configuration, final fields
- [07 · Validation](./07-validation.md) — Bean Validation, custom validators, DTO vs domain validation
- [08 · Testing](./08-testing.md) — Unit, slice, integration tests; Testcontainers; naming conventions
- [09 · Data Access](./09-data-access.md) — JPA entities, repository impl, Flyway migrations, @Transactional
- [10 · Configuration](./10-configuration.md) — @ConfigurationProperties, profiles, secrets, validation
- [11 · Observability](./11-observability.md) — Structured logging, MDC, Micrometer, Actuator, tracing
- [12 · HTTP Layer](./12-http-layer.md) — Thin controllers, request/response records, OpenAPI, CORS
- [13 · Tooling](./13-tooling.md) — Gradle DSL, Checkstyle, Spotless, GitHub Actions, Docker Compose
- [14 · Authentication](./14-authentication.md) — Spring Security 6, JWT filter, RBAC, method security

---

[← Style Guide Root](../../README.md)
