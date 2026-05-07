# Spring Boot — Testing Reference

## Philosophy

Use the lowest-level test that gives you confidence. `@SpringBootTest` is expensive — use it only for true integration tests. Most logic should be covered by fast JUnit + Mockito unit tests.

```
@SpringBootTest    ← Full context, real DB (Testcontainers). Fewest tests.
@WebMvcTest        ← HTTP layer only, mocked service.
@DataJpaTest       ← JPA layer only, real DB via Testcontainers.
Plain JUnit        ← No Spring context. Most tests should be here.
```

## Test Naming Convention

```
methodName_givenCondition_thenExpectedResult
```

```java
// ✅ Good
void createUser_givenExistingEmail_thenThrowsEmailAlreadyTakenException()
void findById_givenUnknownId_thenReturnsEmpty()
void suspend_givenActiveUser_thenStatusIsSuspended()

// ❌ Bad
void testCreateUser()
void shouldFindUser()
```

## 1. Unit Tests — JUnit 5 + Mockito

No Spring context. Instantiate directly via constructor injection:

```java
@ExtendWith(MockitoExtension.class)
class UserServiceTest {

    @Mock private UserRepository userRepository;
    private UserService userService;

    @BeforeEach
    void setUp() { userService = new UserService(userRepository); }

    @Test
    void createUser_givenExistingEmail_thenThrowsEmailAlreadyTakenException() {
        given(userRepository.existsByEmail(new Email("alice@example.com"))).willReturn(true);

        assertThatThrownBy(() ->
            userService.createUser(new CreateUserCommand("Alice", "alice@example.com"))
        ).isInstanceOf(EmailAlreadyTakenException.class);

        verify(userRepository, never()).save(any());
    }
}
```

## 2. Domain Entity Tests

Domain entities have behavior — test it directly with zero infrastructure:

```java
class UserTest {
    @Test
    void create_givenValidInput_thenCreatesActiveUser() {
        User user = User.create("Alice", "alice@example.com");
        assertThat(user.isActive()).isTrue();
    }

    @Test
    void suspend_givenAlreadySuspendedUser_thenThrowsIllegalStateException() {
        User user = User.create("Alice", "alice@example.com");
        user.suspend();
        assertThatThrownBy(user::suspend).isInstanceOf(IllegalStateException.class);
    }
}
```

## 3. Repository Tests — `@DataJpaTest` + Testcontainers

```java
@DataJpaTest
@Testcontainers
@Import(UserRepositoryImpl.class)
class UserRepositoryImplTest {

    @Autowired private UserRepository userRepository;
    @Autowired private TestEntityManager entityManager;

    @Test
    void save_givenValidUser_thenPersistsAndRetrievable() {
        User user = User.create("Alice", "alice@example.com");
        userRepository.save(user);
        entityManager.flush();
        entityManager.clear();

        Optional<User> found = userRepository.findById(user.id());
        assertThat(found).isPresent();
        assertThat(found.get().email().value()).isEqualTo("alice@example.com");
    }
}
```

Shared Testcontainers base class:

```java
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

## 4. Controller Tests — `@WebMvcTest`

Mocks the service layer entirely. Tests serialization, HTTP status codes, validation, error mapping:

```java
@WebMvcTest(UserController.class)
class UserControllerTest {

    @Autowired private MockMvc mockMvc;
    @MockBean private UserService userService;

    @Test
    void createUser_givenValidRequest_thenReturns201() throws Exception {
        given(userService.createUser(any())).willReturn(
            new UserResponse("id-123", "Alice", "alice@example.com")
        );

        mockMvc.perform(post("/api/v1/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"name":"Alice","email":"alice@example.com","password":"Secret123!"}"""))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.name").value("Alice"));
    }

    @Test
    void createUser_givenInvalidEmail_thenReturns400() throws Exception {
        mockMvc.perform(post("/api/v1/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"name":"Alice","email":"not-an-email"}"""))
            .andExpect(status().isBadRequest());
    }
}
```

## 5. Object Mothers

Centralize test data construction so domain model changes only require one update:

```java
public final class UserMother {
    private UserMother() {}

    public static User activeUser() { return User.create("Alice Test", "alice@example.com"); }
    public static User suspendedUser() { User u = activeUser(); u.suspend(); return u; }
    public static User userWithEmail(String email) { return User.create("Test User", email); }
}
```

## Commands

```bash
./gradlew test              # all tests
./gradlew test --tests UserServiceTest  # single class
./mvnw test                 # Maven equivalent
```

## Anti-Patterns

- `@SpringBootTest` for a unit test — 10+ seconds for a 20ms test. Use plain JUnit + Mockito.
- Shared mutable state between tests — each test must create its own objects; use `@BeforeEach`
- Testing implementation details (`verify` on private methods) — test observable behavior: what was saved, returned, or thrown
- `H2` in-memory DB for repository tests — use Testcontainers with real PostgreSQL
