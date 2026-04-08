# Testing

## Testing Strategy

Testing in a Clean Architecture project follows the same layered structure as the code itself. Each layer has distinct testing concerns and dependency rules.

| Layer | What to Test | Mocks Needed | Package |
|---|---|---|---|
| Domain | Pure logic, validators, entity rules | None | `test` |
| Application | BLoC state transitions, event handling | Use cases | `bloc_test`, `mocktail` |
| Infrastructure | Repository impls, DTO mapping, error mapping | HTTP clients, data sources | `mocktail`, `test` |
| Presentation | Widget rendering, user interactions | BLoCs | `flutter_test`, `bloc_test` |

> **Rule of thumb:** The closer to the domain, the fewer mocks you need. If a test requires many mocks, the code under test may have too many responsibilities.

---

## Domain Layer Tests

Domain tests are the simplest because domain code has **no dependencies**. Test pure functions, validators, and entity logic directly.

```dart
// test/domain/validators/email_validator_test.dart

import 'package:test/test.dart';
import 'package:my_app/domain/validators/email_validator.dart';

void main() {
  group('EmailValidator', () {
    // ✅ Good — test the behavior, not the implementation
    test('returns true for a valid email', () {
      expect(EmailValidator.isValid('user@example.com'), isTrue);
    });

    test('returns false for an email without @', () {
      expect(EmailValidator.isValid('userexample.com'), isFalse);
    });

    test('returns false for an empty string', () {
      expect(EmailValidator.isValid(''), isFalse);
    });
  });
}
```

Domain entity logic should also be tested when it contains derived values or invariant checks:

```dart
// test/domain/entities/order_test.dart

void main() {
  group('Order', () {
    test('calculates total from items', () {
      final order = Order(
        id: '1',
        items: [
          OrderItem(name: 'Widget', price: 10.0, quantity: 2),
          OrderItem(name: 'Gadget', price: 25.0, quantity: 1),
        ],
      );
      expect(order.total, equals(45.0));
    });
  });
}
```

---

## Application Layer Tests

Application layer tests verify **BLoC state transitions** in response to events. Use `bloc_test` for declarative BLoC testing and `mocktail` for mocking use case dependencies.

```dart
// test/application/blocs/login_bloc_test.dart

import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:my_app/application/blocs/login/login_bloc.dart';
import 'package:my_app/domain/use_cases/sign_in_use_case.dart';
import 'package:my_app/domain/errors/auth_error.dart';

class MockSignInUseCase extends Mock implements SignInUseCase {}

void main() {
  late MockSignInUseCase mockSignIn;

  setUp(() => mockSignIn = MockSignInUseCase());

  // ✅ Good — test the full state transition sequence
  blocTest<LoginBloc, LoginState>(
    'emits [loading, success] when sign-in succeeds',
    build: () {
      when(() => mockSignIn.execute(
        email: any(named: 'email'),
        password: any(named: 'password'),
      )).thenReturn(
        TaskEither.right(const User(id: '1', name: 'John')),
      );
      return LoginBloc(signInUseCase: mockSignIn);
    },
    act: (bloc) => bloc.add(
      const SignInRequested(email: 'a@b.com', password: '123456'),
    ),
    expect: () => [
      isA<LoginState>().having((s) => s.status, 'status', LoginStatus.loading),
      isA<LoginState>().having((s) => s.status, 'status', LoginStatus.success),
    ],
    verify: (_) {
      verify(() => mockSignIn.execute(
        email: 'a@b.com',
        password: '123456',
      )).called(1);
    },
  );

  blocTest<LoginBloc, LoginState>(
    'emits [loading, failure] when sign-in fails',
    build: () {
      when(() => mockSignIn.execute(
        email: any(named: 'email'),
        password: any(named: 'password'),
      )).thenReturn(
        TaskEither.left(AuthNetworkError.unauthorized),
      );
      return LoginBloc(signInUseCase: mockSignIn);
    },
    act: (bloc) => bloc.add(
      const SignInRequested(email: 'a@b.com', password: 'wrong'),
    ),
    expect: () => [
      isA<LoginState>().having((s) => s.status, 'status', LoginStatus.loading),
      isA<LoginState>()
          .having((s) => s.status, 'status', LoginStatus.failure)
          .having((s) => s.error, 'error', AuthNetworkError.unauthorized),
    ],
  );
}
```

---

## Infrastructure Layer Tests

Infrastructure tests verify that **repository implementations** correctly map external data to domain entities and translate exceptions into domain errors.

```dart
// test/infrastructure/repositories/user_repository_test.dart

class MockUserApi extends Mock implements UserApi {}

void main() {
  late MockUserApi mockApi;
  late UserRepositoryImpl repository;

  setUp(() {
    mockApi = MockUserApi();
    repository = UserRepositoryImpl(userApi: mockApi);
  });

  // ✅ Good — test success path with DTO-to-entity mapping
  test('getUser returns Right with User when API succeeds', () async {
    when(() => mockApi.getUser('1')).thenAnswer(
      (_) async => const UserDto(id: '1', name: 'John', email: 'j@b.com'),
    );
    final result = await repository.getUser('1').run();

    expect(result.isRight(), isTrue);
    result.fold(
      (_) => fail('Expected Right'),
      (user) => expect(user.id, equals('1')),
    );
  });

  // ✅ Good — test error mapping from exception to domain error
  test('getUser returns Left on NotFoundException', () async {
    when(() => mockApi.getUser('999')).thenThrow(NotFoundException());
    final result = await repository.getUser('999').run();

    expect(result.isLeft(), isTrue);
    result.fold(
      (error) => expect(error, isA<UserNotFoundError>()),
      (_) => fail('Expected Left'),
    );
  });
}
```

Always test **DTO mapping** (`fromJson` and `toEntity`) in separate test files to catch serialization regressions early:

```dart
// test/infrastructure/dtos/user_dto_test.dart

group('UserDto', () {
  test('fromJson creates a valid DTO', () {
    final dto = UserDto.fromJson({'id': '1', 'name': 'John', 'email': 'j@b.com'});
    expect(dto.id, equals('1'));
  });

  test('toEntity maps correctly to domain entity', () {
    const dto = UserDto(id: '1', name: 'John', email: 'j@b.com');
    expect(dto.toEntity().name, equals('John'));
  });
});
```

---

## Presentation Layer Tests

Presentation tests verify that widgets render correctly and respond to user interactions. Use `MockBloc` from `bloc_test` to control the state the widget sees.

```dart
// test/presentation/features/login/login_body_test.dart

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_app/application/blocs/login/login_bloc.dart';
import 'package:my_app/presentation/features/login/login_body.dart';

class MockLoginBloc extends MockBloc<LoginEvent, LoginState>
    implements LoginBloc {}

void main() {
  late MockLoginBloc mockBloc;

  setUp(() => mockBloc = MockLoginBloc());

  Widget buildSubject() => MaterialApp(
    home: BlocProvider<LoginBloc>.value(
      value: mockBloc,
      child: const Scaffold(body: LoginBody()),
    ),
  );

  // ✅ Good — test what the user sees, not the widget tree structure
  testWidgets('shows email and password fields', (tester) async {
    when(() => mockBloc.state).thenReturn(const LoginState());
    await tester.pumpWidget(buildSubject());
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('dispatches SignInRequested on submit', (tester) async {
    when(() => mockBloc.state).thenReturn(const LoginState());
    await tester.pumpWidget(buildSubject());

    await tester.enterText(find.byKey(const Key('login_email_field')), 'a@b.com');
    await tester.enterText(find.byKey(const Key('login_password_field')), '123456');
    await tester.tap(find.byKey(const Key('login_submit_button')));

    verify(() => mockBloc.add(
      const SignInRequested(email: 'a@b.com', password: '123456'),
    )).called(1);
  });

  testWidgets('shows error message on failure state', (tester) async {
    when(() => mockBloc.state).thenReturn(
      const LoginState(status: LoginStatus.failure),
    );
    await tester.pumpWidget(buildSubject());
    expect(find.text('Login failed. Please try again.'), findsOneWidget);
  });
}
```

---

## Integration Tests

Integration tests verify complete user journeys. They use `integration_test` and run on a real device or emulator.

```dart
// integration_test/login_flow_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('user can log in and see the home screen', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('login_email_field')), 'test@example.com');
    await tester.enterText(find.byKey(const Key('login_password_field')), 'password123');
    await tester.tap(find.byKey(const Key('login_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('Welcome'), findsOneWidget);
  });
}
```

Keep integration tests focused on **critical user paths** (sign in, checkout, onboarding). They are slower than unit and widget tests, so use them sparingly.

---

## Test Organization

Mirror the `lib/` folder structure in `test/`. Every source file with logic should have a corresponding `_test.dart` file.

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

Use `group()` to organize related tests. Keep descriptions concise and behavior-focused.

```dart
// ✅ Good — groups describe the subject, tests describe the behavior
group('EmailValidator', () {
  test('accepts valid emails', () { ... });
  test('rejects emails without @', () { ... });
});

// ❌ Bad — flat list of tests without grouping
test('EmailValidator accepts valid emails', () { ... });
test('EmailValidator rejects emails without @', () { ... });
```

Name test files `<source_file>_test.dart`. Start test descriptions with a lowercase verb describing the behavior (e.g., `'returns true for valid input'`, `'emits [loading, success] when...'`).

---

## Anti-Patterns

- **Testing implementation details instead of behavior.** Verify what the code *does*, not how it does it. If refactoring breaks tests but not behavior, the tests are too tightly coupled.

- **Skipping BLoC state transition tests.** Every event should have at least one `blocTest` verifying the full sequence of emitted states, including the loading state.

- **Widget tests that depend on exact widget tree structure.** Use `find.byType`, `find.byKey`, or `find.text` instead of positional finders that break when the layout changes.

- **Not using `mocktail` for dependency mocking.** Always mock dependencies at layer boundaries. Domain tests need no mocks; application tests mock use cases; infrastructure tests mock data sources; presentation tests mock BLoCs.

- **Testing private methods directly.** Private methods are implementation details. Test them indirectly through the public API that calls them.

- **Writing integration tests for everything.** Reserve integration tests for critical user flows and rely on unit and widget tests for coverage.

- **Not verifying mock interactions.** Use `verify()` to confirm the expected use case or event was called with the correct arguments.
