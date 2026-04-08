# Validators

Validators enforce **field-level business rules** in the domain. They are typically used in forms but represent domain knowledge (e.g., "what is a valid email address?" is a business rule, not a UI rule).

Validators use the `FormField` and `FieldValidationFailure` base classes (from the `form_field` package or an internal equivalent).

## Naming

### Validator Classes

Validator classes **must** be named `[FieldName]Field`:

```dart
class EmailField { ... }
class PasswordField { ... }
class PhoneNumberField { ... }
```

### Validation Failure Classes

Failure classes **must** be named `[FieldName]ValidationFailure`:

```dart
class EmailValidationFailure { ... }
class PasswordValidationFailure { ... }
```

## Class Structure

### Validation Failure Hierarchy

Define a `sealed class` as the root for all failures of a given field, then enumerate specific failures as either `enum` values implementing the sealed class or concrete subclasses:

```dart
/// All validation failures for the password field.
sealed class PasswordValidationFailure extends FieldValidationFailure {
  const PasswordValidationFailure();
}

/// Simple, enumerable password failures.
enum BasicPasswordValidationFailure implements PasswordValidationFailure {
  empty,
  noUppercase,
  noDigit,
}

/// Failure with a dynamic minimum length.
class MinLengthPasswordValidationFailure extends PasswordValidationFailure {
  final int minLength;
  const MinLengthPasswordValidationFailure({required this.minLength});
}
```

### Validator Class

Validator classes **must** extend `FormField<T, E extends FieldValidationFailure>`:

```dart
class PasswordField extends FormField<String, PasswordValidationFailure> {
  ...
}
```

## Constructors

Each validator **must** implement exactly two named constructors:

### `pure`

Represents the **initial state** of a field — before the user has interacted with it. Takes an initial value (required by default, may be optional if a sensible default exists).

```dart
const PasswordField.pure(super.value) : super.pure();

// With an optional initial value:
const PasswordField.pure([String value = '']) : super.pure(value);
```

### `dirty`

Represents the **modified state** — after the user has interacted with the field. Takes a required value and triggers validation.

```dart
const PasswordField.dirty(super.value) : super.dirty();
```

## The `validator` Method

Implement `E? validator(T value)`. Return the appropriate failure object if the value is invalid, or `null` if it is valid. Validations run sequentially; return on the first failure.

```dart
@override
PasswordValidationFailure? validator(String value) {
  if (value.isEmpty) {
    return BasicPasswordValidationFailure.empty;
  }
  if (value.length < 8) {
    return const MinLengthPasswordValidationFailure(minLength: 8);
  }
  if (!value.contains(RegExp(r'[A-Z]'))) {
    return BasicPasswordValidationFailure.noUppercase;
  }
  if (!value.contains(RegExp(r'[0-9]'))) {
    return BasicPasswordValidationFailure.noDigit;
  }
  return null;
}
```

## Complete Example

```dart
// domain/validators/email_field.dart

/// Validates an email address field.
class EmailField extends FormField<String, EmailValidationFailure> {
  const EmailField.pure(super.value) : super.pure();
  const EmailField.dirty(super.value) : super.dirty();

  static final _emailRegExp = RegExp(
    r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
  );

  @override
  EmailValidationFailure? validator(String value) {
    if (value.isEmpty) return .empty;
    if (!_emailRegExp.hasMatch(value)) return .invalidFormat;
    return null;
  }
}

/// Validation failures for [EmailField].
sealed class EmailValidationFailure extends FieldValidationFailure {
  const EmailValidationFailure();
}

enum BasicEmailValidationFailure implements EmailValidationFailure {
  empty,
  invalidFormat,
}
```

## Usage in a Bloc State

```dart
class LoginState extends Equatable {
  const LoginState({
    this.email = const EmailField.pure(''),
    this.password = const PasswordField.pure(''),
    this.status = LoginStatus.initial,
  });

  final EmailField email;
  final PasswordField password;
  final LoginStatus status;

  bool get isValid => email.isValid && password.isValid;

  LoginState copyWith({ ... }) { ... }

  @override
  List<Object> get props => [email, password, status];
}
```
