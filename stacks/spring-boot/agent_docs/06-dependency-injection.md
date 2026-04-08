# 06 · Dependency Injection

Constructor injection is the only approved form of dependency injection at Avila Tek. The rule is simple and absolute: every dependency a class requires must be declared as a constructor parameter and assigned to a `final` field. This is not a stylistic preference — it has concrete technical consequences. Constructor injection makes dependencies explicit (you can see them in the constructor signature without reading the whole class body), makes the class instantiable without a Spring container (enabling fast unit tests), prevents circular dependency surprises (the JVM enforces acyclicity at construction time), and allows fields to be `final` (guaranteed immutability after construction).

Field injection with `@Autowired` is a legacy pattern that survives by inertia. It hides the dependency graph, it requires reflection to populate fields (which is slower and less deterministic), and it makes unit testing fragile — you either need to start a Spring context or use `ReflectionTestUtils` to inject mocks, both of which are cumbersome. When you see a class with `@Autowired` fields, the refactoring to constructor injection is always straightforward. Do it.

---

## Constructor Injection — The Only Approved Pattern

```java
// ✅ Good — constructor injection, final fields, no @Autowired anywhere
package com.avilatek.users.application;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional
public class UserService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    // Spring injects dependencies through the constructor automatically
    // @Autowired is implicit on a single-constructor class since Spring 4.3
    public UserService(UserRepository userRepository, PasswordEncoder passwordEncoder) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
    }

    public UserResponse createUser(CreateUserCommand command) {
        if (userRepository.existsByEmail(new Email(command.email()))) {
            throw new EmailAlreadyTakenException(command.email());
        }
        User user = User.create(command.name(), command.email());
        userRepository.save(user);
        return UserResponse.from(user);
    }
}
```

```java
// ❌ Bad — field injection hides dependencies, prevents final fields
@Service
public class UserService {
    @Autowired
    private UserRepository userRepository;   // mutable, hidden, not testable without Spring

    @Autowired
    private PasswordEncoder passwordEncoder; // same problems
}
```

---

## `@Configuration` Classes as Composition Roots

`@Configuration` classes are where implementations get wired to interfaces. Each domain has one configuration class in its `presentation/` package (co-located with the controller because both are Spring-infrastructure concerns). The configuration class is package-private — it is consumed by Spring via component scanning, not by other classes.

```java
// ✅ Good — wiring the port (interface) to the adapter (implementation)
package com.avilatek.users.presentation;

import com.avilatek.users.application.UserService;
import com.avilatek.users.domain.UserRepository;
import com.avilatek.users.infrastructure.persistence.UserJpaRepository;
import com.avilatek.users.infrastructure.persistence.UserRepositoryImpl;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
class UserConfiguration {

    @Bean
    UserRepository userRepository(UserJpaRepository jpaRepository) {
        return new UserRepositoryImpl(jpaRepository);
    }

    @Bean
    UserService userService(UserRepository userRepository,
                            org.springframework.security.crypto.password.PasswordEncoder passwordEncoder) {
        return new UserService(userRepository, passwordEncoder);
    }
}
```

Because `UserRepositoryImpl` is package-private (in `infrastructure/persistence/`), only `UserConfiguration` — which is part of the Spring context — can instantiate it. No other class can take a stray dependency on the implementation.

---

## `@Bean` Factory Methods

Factory methods give you full control over object construction. Unlike component scanning (`@Service`, `@Repository`), factory methods are explicit: you can see exactly what is being instantiated and what its dependencies are.

```java
// ✅ Good — explicit factory method with conditional logic
@Configuration
class SecurityConfiguration {

    @Bean
    PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder(12);
    }

    @Bean
    @Profile("!prod")
    JwtSecretKeyProvider devSecretKeyProvider() {
        // weak key acceptable in dev; prod uses a proper secret
        return () -> "dev-only-secret-key-32-chars-minimum-length";
    }

    @Bean
    @Profile("prod")
    JwtSecretKeyProvider prodSecretKeyProvider(JwtProperties properties) {
        return () -> properties.secret();
    }
}
```

---

## Testing Without Spring Context

Constructor injection makes the application service instantiable in a plain JUnit test. No `@SpringBootTest`, no `@MockBean`, no Spring context startup. The test is fast (milliseconds, not seconds) and completely isolated.

```java
// ✅ Good — unit test with no Spring context; instantiates the service directly
package com.avilatek.users.application;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.verify;

class UserServiceTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    private UserService userService;

    @BeforeEach
    void setUp() {
        MockitoAnnotations.openMocks(this);
        userService = new UserService(userRepository, passwordEncoder); // no Spring required
    }

    @Test
    void createUser_givenExistingEmail_thenThrowsEmailAlreadyTakenException() {
        given(userRepository.existsByEmail(any(Email.class))).willReturn(true);

        assertThatThrownBy(() -> userService.createUser(new CreateUserCommand("Alice", "alice@example.com")))
            .isInstanceOf(EmailAlreadyTakenException.class)
            .hasMessageContaining("alice@example.com");
    }

    @Test
    void createUser_givenValidInput_thenSavesUserAndReturnsResponse() {
        given(userRepository.existsByEmail(any(Email.class))).willReturn(false);

        UserResponse response = userService.createUser(new CreateUserCommand("Alice", "alice@example.com"));

        verify(userRepository).save(any(User.class));
        assert response.email().equals("alice@example.com");
    }
}
```

```java
// ❌ Bad — @SpringBootTest for a unit test; slow, heavy, unnecessary
@SpringBootTest
class UserServiceTest {
    @Autowired
    private UserService userService;

    @MockBean
    private UserRepository userRepository; // starts the whole Spring context just to swap one bean
}
```

---

## Dependency Injection Checklist

| Rule                                                          | Enforced By     |
|---------------------------------------------------------------|-----------------|
| All injected fields are `final`                               | Code review      |
| No `@Autowired` on fields                                     | Checkstyle rule  |
| No `@Autowired` on setter methods                             | Checkstyle rule  |
| Single-constructor classes omit `@Autowired` on constructor   | Convention       |
| Multi-constructor classes mark the injection constructor      | `@Autowired` OK here |
| `@Configuration` class wires all domain beans                 | Architecture      |
| Unit tests use constructor injection directly (no Spring)     | Test conventions |

---

## Qualifier Usage

When multiple beans of the same type exist, use `@Qualifier` on the constructor parameter — not on a field.

```java
// ✅ Good — qualifier on constructor parameter
public class ReportService {
    private final DataSource primaryDataSource;
    private final DataSource readReplicaDataSource;

    public ReportService(
        @Qualifier("primary") DataSource primaryDataSource,
        @Qualifier("readReplica") DataSource readReplicaDataSource
    ) {
        this.primaryDataSource = primaryDataSource;
        this.readReplicaDataSource = readReplicaDataSource;
    }
}
```

---

## Anti-Patterns

### ❌ `@Autowired` on a field
```java
@Service
public class UserService {
    @Autowired
    private UserRepository userRepository; // hidden dependency, untestable without Spring
}
```
The class cannot be instantiated manually. Tests must either start a Spring context or use reflection. Fields are mutable; a threading bug could replace `userRepository` at runtime.

### ❌ Setter injection
```java
@Autowired
public void setUserRepository(UserRepository repo) {
    this.userRepository = repo; // optional dependency implies the class can work without it
}
```
Setter injection implies optional dependencies. If a dependency is truly optional, say so explicitly with `@Autowired(required = false)`. Otherwise, constructor injection makes it required by default and enforces it at startup.

### ❌ Using `ApplicationContext` as a service locator
```java
@Service
public class UserService {
    @Autowired
    private ApplicationContext context;

    public void doSomething() {
        UserRepository repo = context.getBean(UserRepository.class); // ❌ service locator anti-pattern
    }
}
```
Service locator hides every dependency. The class becomes impossible to understand or test without the full context.

### ❌ Circular constructor injection
```java
@Service
public class A {
    private final B b;
    public A(B b) { this.b = b; }
}

@Service
public class B {
    private final A a;
    public B(A a) { this.a = a; } // ❌ Spring throws BeanCurrentlyInCreationException
}
```
Circular dependencies are a design smell. Introduce an interface, an event, or a third class that owns the shared behaviour.

---

[← Error Handling](./05-error-handling.md) | [Index](./README.md) | [Next: Validation →](./07-validation.md)
