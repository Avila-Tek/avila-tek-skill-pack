# 08 · Testing

A test suite is only valuable if it is fast enough to run on every commit and trustworthy enough that a green build actually means something. Avila Tek's test strategy has three levels, and they are not interchangeable. Unit tests are the foundation: they run in milliseconds, require no Spring context, and test a single class in isolation with Mockito mocks. Slice tests (`@WebMvcTest`, `@DataJpaTest`) start a partial Spring context to test a specific layer. Integration tests (`@SpringBootTest`) start the full application against a real database using Testcontainers. Use the lowest-level test that gives you confidence. Over-reliance on `@SpringBootTest` produces slow, brittle suites that developers stop running.

The test pyramid applies: many unit tests, fewer slice tests, fewest integration tests. A service with twenty use cases should have twenty unit tests and perhaps two integration tests (one happy path, one critical error path). The unit tests cover the domain logic exhaustively; the integration tests verify that the wiring works end to end. Every test is an investment in future change safety — name them clearly, keep them fast, and never share mutable state between tests.

---

## Test Naming Convention

All test methods follow the pattern: `methodName_givenCondition_thenExpectedResult`

```java
// ✅ Good — descriptive, three-part name
void createUser_givenExistingEmail_thenThrowsEmailAlreadyTakenException()
void findById_givenUnknownId_thenReturnsEmpty()
void suspend_givenActiveUser_thenStatusIsSuspended()
void suspend_givenAlreadySuspendedUser_thenThrowsIllegalStateException()

// ❌ Bad — no information about precondition or expected result
void testCreateUser()
void shouldFindUser()
void createUserFails()
```

---

## Unit Tests — JUnit 5 + Mockito

Unit tests instantiate the class under test directly using constructor injection. No Spring context. No database. Pure business logic.

```java
// ✅ Good — fast unit test for the application service
package com.avilatek.users.application;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

@ExtendWith(MockitoExtension.class)
class UserServiceTest {

    @Mock
    private UserRepository userRepository;

    private UserService userService;

    @BeforeEach
    void setUp() {
        userService = new UserService(userRepository);
    }

    @Test
    void createUser_givenExistingEmail_thenThrowsEmailAlreadyTakenException() {
        given(userRepository.existsByEmail(new Email("alice@example.com"))).willReturn(true);

        assertThatThrownBy(() ->
            userService.createUser(new CreateUserCommand("Alice", "alice@example.com"))
        ).isInstanceOf(EmailAlreadyTakenException.class)
         .hasMessageContaining("alice@example.com");

        verify(userRepository, never()).save(any());
    }

    @Test
    void createUser_givenValidInput_thenSavesUserAndReturnsResponse() {
        given(userRepository.existsByEmail(any())).willReturn(false);

        UserResponse response = userService.createUser(new CreateUserCommand("Alice", "alice@example.com"));

        verify(userRepository).save(any(User.class));
        assertThat(response.name()).isEqualTo("Alice");
        assertThat(response.email()).isEqualTo("alice@example.com");
    }

    @Test
    void getUser_givenUnknownId_thenThrowsUserNotFoundException() {
        UserId id = UserId.generate();
        given(userRepository.findById(id)).willReturn(Optional.empty());

        assertThatThrownBy(() -> userService.getUser(id.value().toString()))
            .isInstanceOf(UserNotFoundException.class);
    }
}
```

---

## Domain Entity Unit Tests

Domain entities have behaviour — that behaviour should be tested directly.

```java
// ✅ Good — domain unit test with zero infrastructure
package com.avilatek.users.domain;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class UserTest {

    @Test
    void create_givenValidInput_thenCreatesActiveUser() {
        User user = User.create("Alice", "alice@example.com");

        assertThat(user.name()).isEqualTo("Alice");
        assertThat(user.email().value()).isEqualTo("alice@example.com");
        assertThat(user.isActive()).isTrue();
        assertThat(user.id()).isNotNull();
    }

    @Test
    void create_givenBlankName_thenThrowsIllegalArgumentException() {
        assertThatThrownBy(() -> User.create("  ", "alice@example.com"))
            .isInstanceOf(IllegalArgumentException.class)
            .hasMessageContaining("name");
    }

    @Test
    void suspend_givenActiveUser_thenStatusIsSuspended() {
        User user = User.create("Alice", "alice@example.com");

        user.suspend();

        assertThat(user.isSuspended()).isTrue();
    }

    @Test
    void suspend_givenAlreadySuspendedUser_thenThrowsIllegalStateException() {
        User user = User.create("Alice", "alice@example.com");
        user.suspend();

        assertThatThrownBy(user::suspend)
            .isInstanceOf(IllegalStateException.class)
            .hasMessageContaining("already suspended");
    }
}
```

---

## Repository Tests — `@DataJpaTest` with Testcontainers

Slice tests for the repository layer use `@DataJpaTest` with a real PostgreSQL container via Testcontainers. This verifies that JPA mappings, queries, and Flyway migrations work correctly.

```java
// ✅ Good — repository test with real database via Testcontainers
package com.avilatek.users.infrastructure;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.test.autoconfigure.orm.jpa.TestEntityManager;
import org.springframework.context.annotation.Import;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;

@DataJpaTest
@Testcontainers
@Import(UserRepositoryImpl.class)
class UserRepositoryImplTest {

    @Autowired
    private UserRepository userRepository;  // the domain port, backed by UserRepositoryImpl

    @Autowired
    private TestEntityManager entityManager;

    @Test
    void save_givenValidUser_thenPersistsAndRetrievable() {
        User user = User.create("Alice", "alice@example.com");

        userRepository.save(user);
        entityManager.flush();
        entityManager.clear();

        Optional<User> found = userRepository.findById(user.id());
        assertThat(found).isPresent();
        assertThat(found.get().email().value()).isEqualTo("alice@example.com");
        assertThat(found.get().isActive()).isTrue();
    }

    @Test
    void existsByEmail_givenPersistedEmail_thenReturnsTrue() {
        User user = User.create("Bob", "bob@example.com");
        userRepository.save(user);
        entityManager.flush();

        boolean exists = userRepository.existsByEmail(new Email("bob@example.com"));

        assertThat(exists).isTrue();
    }

    @Test
    void findByEmail_givenUnknownEmail_thenReturnsEmpty() {
        Optional<User> found = userRepository.findByEmail(new Email("nobody@example.com"));

        assertThat(found).isEmpty();
    }
}
```

Configure Testcontainers in `src/test/resources/application-test.yml` or via a base class:

```java
// ✅ Good — shared Testcontainers base for all DB tests
package com.avilatek;

import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

@Testcontainers
public abstract class PostgresTestBase {

    @Container
    static final PostgreSQLContainer<?> POSTGRES =
        new PostgreSQLContainer<>("postgres:16")
            .withDatabaseName("avilatek_test")
            .withUsername("test")
            .withPassword("test");
}
```

---

## Controller Tests — `@WebMvcTest`

Slice tests for the HTTP layer mock the service layer entirely. They verify serialisation, HTTP status codes, validation, and error mapping.

```java
// ✅ Good — controller slice test with mocked service
package com.avilatek.users.presentation;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(UserController.class)
class UserControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private UserService userService;

    @Test
    void createUser_givenValidRequest_thenReturns201() throws Exception {
        given(userService.createUser(any())).willReturn(
            new UserResponse("id-123", "Alice", "alice@example.com")
        );

        mockMvc.perform(post("/api/v1/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"name": "Alice", "email": "alice@example.com", "password": "Secret123!"}
                    """))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.name").value("Alice"))
            .andExpect(jsonPath("$.email").value("alice@example.com"));
    }

    @Test
    void createUser_givenInvalidEmail_thenReturns400() throws Exception {
        mockMvc.perform(post("/api/v1/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"name": "Alice", "email": "not-an-email", "password": "Secret123!"}
                    """))
            .andExpect(status().isBadRequest());
    }
}
```

---

## Test Object Mothers

Object mothers are factory classes that create valid test domain objects. They centralise test data construction so changes to the domain model only require updating one place.

```java
// ✅ Good — object mother for User domain entity
package com.avilatek.users;

import com.avilatek.users.domain.User;

public final class UserMother {

    private UserMother() {}

    public static User activeUser() {
        return User.create("Alice Test", "alice@example.com");
    }

    public static User suspendedUser() {
        User user = activeUser();
        user.suspend();
        return user;
    }

    public static User userWithEmail(String email) {
        return User.create("Test User", email);
    }
}
```

---

## Anti-Patterns

### ❌ `@SpringBootTest` for unit tests
```java
@SpringBootTest  // ❌ starts entire context, 10+ seconds, for a 20ms test
class UserServiceTest {
    @Autowired private UserService userService;
    @MockBean private UserRepository userRepository;
}
```
Use plain JUnit + Mockito instantiation. Reserve `@SpringBootTest` for integration tests.

### ❌ Sharing mutable state between tests
```java
class UserServiceTest {
    private static User sharedUser = User.create("Alice", "alice@example.com");
    // ❌ if one test mutates sharedUser, others see the mutation
}
```
Each test should create its own objects. Use `@BeforeEach` or object mothers.

### ❌ Testing implementation details instead of behaviour
```java
// ❌ Bad — testing that a private method was called
verify(userService, times(1)).validateEmail(any());  // private method detail
```
Test observable behaviour: what was saved, what was returned, what exception was thrown.

---

[← Validation](./07-validation.md) | [Index](./README.md) | [Next: Data Access →](./09-data-access.md)
