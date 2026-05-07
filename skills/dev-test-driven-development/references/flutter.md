# Flutter — Testing Reference

## Test Strategy by Layer

| Layer | What to Test | Tools | Mocks Needed |
|---|---|---|---|
| Domain | Pure logic, validators, entity rules | `test` | None |
| Application | BLoC state transitions, event handling | `bloc_test`, `mocktail` | Use cases |
| Infrastructure | Repo impls, DTO mapping, error mapping | `mocktail` | HTTP clients, data sources |
| Presentation | Widget rendering, user interactions | `flutter_test`, `bloc_test` | BLoCs |

**Rule:** The closer to the domain, the fewer mocks. If a test requires many mocks, the code has too many responsibilities.

## 1. Domain Tests

No dependencies, no mocks. Test pure functions, validators, entity logic:

```dart
// test/domain/validators/email_validator_test.dart
void main() {
  group('EmailValidator', () {
    test('returns true for a valid email', () {
      expect(EmailValidator.isValid('user@example.com'), isTrue);
    });
    test('returns false for an email without @', () {
      expect(EmailValidator.isValid('userexample.com'), isFalse);
    });
  });
}
```

## 2. Application (BLoC) Tests

Test full state transition sequences with `bloc_test`. Mock use cases with `mocktail`:

```dart
class MockSignInUseCase extends Mock implements SignInUseCase {}

void main() {
  late MockSignInUseCase mockSignIn;
  setUp(() => mockSignIn = MockSignInUseCase());

  // ✅ Test the full sequence: loading → success/failure
  blocTest<LoginBloc, LoginState>(
    'emits [loading, success] when sign-in succeeds',
    build: () {
      when(() => mockSignIn.execute(
        email: any(named: 'email'),
        password: any(named: 'password'),
      )).thenReturn(TaskEither.right(const User(id: '1', name: 'John')));
      return LoginBloc(signInUseCase: mockSignIn);
    },
    act: (bloc) => bloc.add(const SignInRequested(email: 'a@b.com', password: '123456')),
    expect: () => [
      isA<LoginState>().having((s) => s.status, 'status', LoginStatus.loading),
      isA<LoginState>().having((s) => s.status, 'status', LoginStatus.success),
    ],
    verify: (_) {
      verify(() => mockSignIn.execute(email: 'a@b.com', password: '123456')).called(1);
    },
  );
}
```

Every event must have at least one `blocTest` covering the full state sequence, including loading.

## 3. Infrastructure Tests

Test that repositories correctly map external data to domain entities and translate exceptions to domain errors:

```dart
class MockUserApi extends Mock implements UserApi {}

void main() {
  late MockUserApi mockApi;
  late UserRepositoryImpl repository;

  setUp(() {
    mockApi = MockUserApi();
    repository = UserRepositoryImpl(userApi: mockApi);
  });

  test('getUser returns Right with User when API succeeds', () async {
    when(() => mockApi.getUser('1')).thenAnswer(
      (_) async => const UserDto(id: '1', name: 'John', email: 'j@b.com'),
    );
    final result = await repository.getUser('1').run();
    expect(result.isRight(), isTrue);
  });

  // Always test error mapping
  test('getUser returns Left on NotFoundException', () async {
    when(() => mockApi.getUser('999')).thenThrow(NotFoundException());
    final result = await repository.getUser('999').run();
    result.fold(
      (error) => expect(error, isA<UserNotFoundError>()),
      (_) => fail('Expected Left'),
    );
  });
}
```

Also test DTO mapping (`fromJson` / `toEntity`) in separate files.

## 4. Presentation (Widget) Tests

Use `MockBloc` to control the state the widget sees:

```dart
class MockLoginBloc extends MockBloc<LoginEvent, LoginState> implements LoginBloc {}

void main() {
  late MockLoginBloc mockBloc;
  setUp(() => mockBloc = MockLoginBloc());

  Widget buildSubject() => MaterialApp(
    home: BlocProvider<LoginBloc>.value(
      value: mockBloc,
      child: const Scaffold(body: LoginBody()),
    ),
  );

  testWidgets('shows email and password fields', (tester) async {
    when(() => mockBloc.state).thenReturn(const LoginState());
    await tester.pumpWidget(buildSubject());
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('dispatches SignInRequested on submit', (tester) async {
    when(() => mockBloc.state).thenReturn(const LoginState());
    await tester.pumpWidget(buildSubject());
    await tester.enterText(find.byKey(const Key('login_email_field')), 'a@b.com');
    await tester.tap(find.byKey(const Key('login_submit_button')));
    verify(() => mockBloc.add(const SignInRequested(email: 'a@b.com', password: '123456'))).called(1);
  });
}
```

Test what the user sees, not the widget tree structure.

## 5. Integration Tests

Sparingly — only for critical user paths (sign in, checkout, onboarding):

```dart
// integration_test/login_flow_test.dart
IntegrationTestWidgetsFlutterBinding.ensureInitialized();

testWidgets('user can log in and see the home screen', (tester) async {
  app.main();
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('login_email_field')), 'test@example.com');
  await tester.tap(find.byKey(const Key('login_submit_button')));
  await tester.pumpAndSettle();
  expect(find.text('Welcome'), findsOneWidget);
});
```

## File Organization

Mirror `lib/` in `test/`:

```
test/
  domain/validators/email_validator_test.dart
  application/blocs/login/login_bloc_test.dart
  infrastructure/repositories/user_repository_test.dart
  infrastructure/dtos/user_dto_test.dart
  presentation/features/login/login_body_test.dart
integration_test/
  login_flow_test.dart
```

## Commands

```bash
flutter test                            # all unit + widget tests
flutter test integration_test/          # integration tests (needs device/emulator)
flutter test --coverage                 # with coverage
```

## Anti-Patterns

- Testing implementation details over behavior — if refactoring breaks tests but not behavior, tests are too tightly coupled
- Skipping BLoC state transition tests — every event needs at least one `blocTest` with full state sequence
- Widget tests asserting on exact tree structure — use `find.byType`, `find.byKey`, `find.text`
- Not mocking dependencies at layer boundaries
- Testing private methods — test through the public API
- Integration tests for everything — reserve for critical user flows
