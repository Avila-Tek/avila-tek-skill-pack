# 11 · Observability

Observability is the ability to understand what a running system is doing from its external outputs — logs, metrics, and traces. It is not an optional feature; it is a first-class engineering requirement. A service that cannot be diagnosed in production is a service that cannot be operated. Avila Tek uses structured logging (JSON in production, human-readable in development), Micrometer for metrics exported to Prometheus, and Micrometer Tracing for distributed trace context propagation. Spring Boot Actuator exposes health and metric endpoints that integrate with monitoring infrastructure.

The logging discipline is as important as the tooling. Structured logs — where every log line is a JSON object with known fields — can be queried, aggregated, and correlated across services. Unstructured logs ("User created successfully!") disappear into noise at scale. Every log entry should answer: when did this happen, in which service, for which request, at which severity, and what was the relevant context? MDC (Mapped Diagnostic Context) provides the per-request correlation ID that ties a single user action across all log entries it generates.

---

## Structured Logging with SLF4J + Logback

SLF4J is the logging facade; Logback is the implementation bundled with Spring Boot. In development, use a human-readable pattern. In production, use JSON (Logstash encoder or the built-in Spring Boot JSON log format).

```java
// ✅ Good — SLF4J logger per class, structured arguments, no string concatenation
package com.avilatek.users.application;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@Service
@Transactional
public class UserService {

    private static final Logger log = LoggerFactory.getLogger(UserService.class);

    private final UserRepository userRepository;

    public UserService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    public UserResponse createUser(CreateUserCommand command) {
        log.debug("Creating user with email={}", command.email());

        if (userRepository.existsByEmail(new Email(command.email()))) {
            throw new EmailAlreadyTakenException(command.email());
        }

        User user = User.create(command.name(), command.email());
        userRepository.save(user);

        log.info("User created userId={} email={}", user.id().value(), user.email().value());
        return UserResponse.from(user);
    }
}
```

```java
// ❌ Bad — string concatenation builds the message even when log level is disabled
log.debug("Creating user with email: " + command.email());  // allocates string always

// ✅ Good — parameterised logging; string is only built if DEBUG is enabled
log.debug("Creating user with email={}", command.email());
```

---

## Logback Configuration

```xml
<!-- src/main/resources/logback-spring.xml -->
<configuration>

    <springProfile name="dev,test">
        <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
            <encoder>
                <pattern>%d{HH:mm:ss.SSS} [%thread] %-5level %logger{36} [%X{correlationId}] - %msg%n</pattern>
            </encoder>
        </appender>
        <root level="INFO">
            <appender-ref ref="CONSOLE" />
        </root>
        <logger name="com.avilatek" level="DEBUG" />
    </springProfile>

    <springProfile name="prod">
        <appender name="JSON_CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
            <encoder class="net.logstash.logback.encoder.LogstashEncoder">
                <includeMdcKeyName>correlationId</includeMdcKeyName>
                <includeMdcKeyName>userId</includeMdcKeyName>
                <customFields>{"service":"avilatek-service","env":"prod"}</customFields>
            </encoder>
        </appender>
        <root level="WARN">
            <appender-ref ref="JSON_CONSOLE" />
        </root>
        <logger name="com.avilatek" level="INFO" />
    </springProfile>

</configuration>
```

---

## MDC — Correlation IDs

A correlation ID ties all log lines for a single HTTP request together. Inject it via a servlet filter at the request boundary and clear it after the response.

```java
// ✅ Good — MDC filter sets correlation ID for every request
package com.avilatek.shared.presentation;

import jakarta.servlet.*;
import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.MDC;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.util.UUID;

@Component
@Order(1)
public class CorrelationIdFilter implements Filter {

    private static final String CORRELATION_ID_HEADER = "X-Correlation-Id";
    private static final String MDC_KEY = "correlationId";

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {
        HttpServletRequest httpRequest = (HttpServletRequest) request;
        String correlationId = httpRequest.getHeader(CORRELATION_ID_HEADER);
        if (correlationId == null || correlationId.isBlank()) {
            correlationId = UUID.randomUUID().toString();
        }
        MDC.put(MDC_KEY, correlationId);
        try {
            chain.doFilter(request, response);
        } finally {
            MDC.clear();  // always clear — thread pool reuse means stale MDC without this
        }
    }
}
```

---

## Micrometer — Metrics

Micrometer provides a vendor-neutral metrics API. It integrates with Spring Boot Actuator and can export to Prometheus, CloudWatch, Datadog, and others.

```java
// ✅ Good — counter and timer for a business operation
package com.avilatek.users.application;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import org.springframework.stereotype.Service;

@Service
@Transactional
public class UserService {

    private static final Logger log = LoggerFactory.getLogger(UserService.class);

    private final UserRepository userRepository;
    private final Counter userCreatedCounter;
    private final Timer userCreationTimer;

    public UserService(UserRepository userRepository, MeterRegistry meterRegistry) {
        this.userRepository = userRepository;
        this.userCreatedCounter = Counter.builder("users.created.total")
            .description("Total number of users created")
            .register(meterRegistry);
        this.userCreationTimer = Timer.builder("users.creation.duration")
            .description("Time taken to create a user")
            .register(meterRegistry);
    }

    public UserResponse createUser(CreateUserCommand command) {
        return userCreationTimer.record(() -> {
            if (userRepository.existsByEmail(new Email(command.email()))) {
                throw new EmailAlreadyTakenException(command.email());
            }
            User user = User.create(command.name(), command.email());
            userRepository.save(user);
            userCreatedCounter.increment();
            log.info("User created userId={}", user.id().value());
            return UserResponse.from(user);
        });
    }
}
```

---

## Spring Boot Actuator

```yaml
# application.yml — actuator configuration
management:
  server:
    port: 9090   # separate port for ops endpoints — not exposed via API gateway
  endpoints:
    web:
      base-path: /actuator
      exposure:
        include: health,metrics,info,prometheus,loggers
  endpoint:
    health:
      show-details: when_authorized
      show-components: when_authorized
    loggers:
      enabled: true
  metrics:
    export:
      prometheus:
        enabled: true
  health:
    db:
      enabled: true
    diskspace:
      enabled: true
```

Key endpoints:

| Endpoint                   | Purpose                                    |
|----------------------------|--------------------------------------------|
| `/actuator/health`         | Liveness + readiness probes                |
| `/actuator/metrics`        | List all registered metrics                |
| `/actuator/prometheus`     | Prometheus-format scrape endpoint          |
| `/actuator/info`           | Build info, version, git commit            |
| `/actuator/loggers`        | Runtime log level changes                  |

---

## Custom Health Indicator

```java
// ✅ Good — custom health check for an external dependency
package com.avilatek.shared.infrastructure;

import org.springframework.boot.actuate.health.Health;
import org.springframework.boot.actuate.health.HealthIndicator;
import org.springframework.stereotype.Component;

@Component("externalPaymentGateway")
public class PaymentGatewayHealthIndicator implements HealthIndicator {

    private final PaymentGatewayClient client;

    public PaymentGatewayHealthIndicator(PaymentGatewayClient client) {
        this.client = client;
    }

    @Override
    public Health health() {
        try {
            boolean reachable = client.ping();
            if (reachable) {
                return Health.up().withDetail("gateway", "reachable").build();
            }
            return Health.down().withDetail("gateway", "unreachable").build();
        } catch (Exception ex) {
            return Health.down(ex).withDetail("gateway", "error").build();
        }
    }
}
```

---

## Distributed Tracing

With Micrometer Tracing on the classpath, every incoming HTTP request automatically gets a trace ID and span ID. These propagate via HTTP headers (`traceparent` for W3C, `X-B3-TraceId` for Zipkin B3) to downstream services.

```kotlin
// build.gradle.kts — tracing dependencies
implementation("io.micrometer:micrometer-tracing-bridge-otel")
implementation("io.opentelemetry.exporter:opentelemetry-exporter-otlp")
// OR for Zipkin:
// implementation("io.micrometer:micrometer-tracing-bridge-brave")
// implementation("io.zipkin.reporter2:zipkin-reporter-brave")
```

```yaml
# application.yml — tracing configuration
management:
  tracing:
    sampling:
      probability: 1.0   # 100% in dev; use 0.1 (10%) in high-traffic prod
  otlp:
    tracing:
      endpoint: http://otel-collector:4318/v1/traces
```

---

## Anti-Patterns

### ❌ Using `System.out.println` for logging
```java
System.out.println("User created: " + userId);  // ❌ no level, no timestamp, no MDC, not configurable
```
Always use SLF4J. In tests, SLF4J with a no-op backend produces no output unless configured.

### ❌ Logging sensitive data
```java
log.info("User logged in with password={}", request.password());  // ❌ PII in logs
log.debug("JWT token={}", jwtToken);  // ❌ secrets in logs
```
Never log passwords, tokens, credit card numbers, or personally identifiable information.

### ❌ Swallowing `MDC.clear()` after the request
```java
// In a filter — missing finally block
MDC.put("correlationId", correlationId);
chain.doFilter(request, response);
// If chain.doFilter throws, MDC is never cleared
// The next request on this thread inherits the previous request's correlationId
```
Always clear MDC in a `finally` block.

### ❌ Exposing Actuator publicly without authentication
```yaml
management:
  endpoints:
    web:
      exposure:
        include: "*"   # ❌ exposes /actuator/env which may reveal secrets
```
Restrict actuator exposure to internal network (separate port + network policy) or authenticate with Spring Security.

---

[← Configuration](./10-configuration.md) | [Index](./README.md) | [Next: HTTP Layer →](./12-http-layer.md)
