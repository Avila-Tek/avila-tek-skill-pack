# Validators

Validation is a domain concern. The rules for what constitutes a valid email, a minimum-length password, or a non-negative price are business rules — they belong in the domain layer, not scattered across form handlers or API controllers. Avila Tek uses **Zod** for all validation, co-located with the domain entities they describe.

Zod schemas are the executable specification of your domain's input contracts. They document what shapes the domain accepts, validate external input at the boundary, and provide TypeScript types inferred directly from the schema. The schema and the type stay in sync automatically — you cannot have a type that allows something the schema rejects.

---

## Schema Location

Zod validators live in `src/domain/validators/`. Each file corresponds to a domain concept and exports one or more schemas plus their inferred types.

```
src/domain/validators/
├── user-validators.ts
├── order-validators.ts
└── auth-validators.ts
```

---

## Naming Convention

Schemas use **camelCase** with a `Schema` suffix. Inferred types use **PascalCase** matching their business meaning.

```typescript
// ✅ Good — Consistent schema and type naming
export const loginSchema = z.object({ ... });
export type LoginInput = z.infer<typeof loginSchema>;

export const createUserSchema = z.object({ ... });
export type CreateUserInput = z.infer<typeof createUserSchema>;

export const updateProfileSchema = z.object({ ... });
export type UpdateProfileInput = z.infer<typeof updateProfileSchema>;
```

```typescript
// ❌ Bad — Inconsistent naming
export const LoginSchema = z.object({ ... });     // PascalCase on variable
export const login_schema = z.object({ ... });    // snake_case
export const loginFormSchema = z.object({ ... }); // 'Form' is a UI concept, not domain
```

---

## Always Use `.safeParse()`, Never `.parse()`

`.parse()` throws a `ZodError` on validation failure. Thrown errors are invisible to the type system and require `try/catch` at the call site. `.safeParse()` returns a `{ success: boolean; data?: T; error?: ZodError }` object that integrates naturally with the `Result<T, E>` pattern.

```typescript
// ✅ Good — .safeParse() returns a type-safe success/failure value
// src/domain/validators/auth-validators.ts

import { z } from 'zod';

export const loginSchema = z.object({
  email: z.string().email('Must be a valid email address'),
  password: z.string().min(8, 'Password must be at least 8 characters'),
});

export type LoginInput = z.infer<typeof loginSchema>;
```

```typescript
// ✅ Good — Usage with .safeParse() in a use case
// src/application/use-cases/auth/login-use-case.ts

import { loginSchema } from '@/domain/validators/auth-validators';
import { err } from '@/lib/result';
import type { UserError } from '@/domain/errors/user-errors';

export class LoginUseCase {
  async execute(input: unknown) {
    const parsed = loginSchema.safeParse(input);
    if (!parsed.success) {
      return err<UserError>({
        type: 'USER_INVALID_CREDENTIALS',
      });
    }
    // parsed.data is now typed as LoginInput
    return this.userRepository.authenticate(parsed.data.email, parsed.data.password);
  }
}
```

```typescript
// ❌ Bad — .parse() throws, not compatible with Result pattern
const input = loginSchema.parse(rawInput); // Throws ZodError — breaks Result flow
```

---

## Complete Example: Login Schema

```typescript
// ✅ Good — Full domain validator file
// src/domain/validators/auth-validators.ts

import { z } from 'zod';

export const loginSchema = z.object({
  email: z
    .string({ required_error: 'Email is required' })
    .min(1, 'Email is required')
    .email('Must be a valid email address')
    .toLowerCase(),
  password: z
    .string({ required_error: 'Password is required' })
    .min(8, 'Password must be at least 8 characters')
    .max(128, 'Password must be less than 128 characters'),
});

export type LoginInput = z.infer<typeof loginSchema>;

export const registerSchema = z.object({
  email: z
    .string({ required_error: 'Email is required' })
    .email('Must be a valid email address')
    .toLowerCase(),
  password: z
    .string({ required_error: 'Password is required' })
    .min(8, 'Password must be at least 8 characters'),
  displayName: z
    .string({ required_error: 'Display name is required' })
    .min(2, 'Display name must be at least 2 characters')
    .max(50, 'Display name must be less than 50 characters')
    .trim(),
});

export type RegisterInput = z.infer<typeof registerSchema>;

export const forgotPasswordSchema = z.object({
  email: z.string().email('Must be a valid email address').toLowerCase(),
});

export type ForgotPasswordInput = z.infer<typeof forgotPasswordSchema>;
```

---

## User Validators Example

```typescript
// ✅ Good — User domain validators
// src/domain/validators/user-validators.ts

import { z } from 'zod';

export const updateProfileSchema = z.object({
  displayName: z
    .string()
    .min(2, 'Display name must be at least 2 characters')
    .max(50, 'Display name must be less than 50 characters')
    .trim()
    .optional(),
  bio: z
    .string()
    .max(500, 'Bio must be less than 500 characters')
    .trim()
    .optional(),
  avatarUrl: z.string().url('Must be a valid URL').nullable().optional(),
});

export type UpdateProfileInput = z.infer<typeof updateProfileSchema>;

export const userIdSchema = z.string().uuid('User ID must be a valid UUID');
```

---

## Reusing Schemas for DTO Validation

The same domain schema used for input validation can also be used in DTOs to validate API responses. This ensures consistency — the domain's definition of a valid user is the same whether the data comes from user input or from the API.

```typescript
// ✅ Good — Domain schema reused for DTO validation
// src/infrastructure/dtos/user-dto.ts

import { z } from 'zod';
import type { User } from '@/domain/entities/user';

// The DTO schema validates the raw API shape (snake_case, string dates)
export const userDtoSchema = z.object({
  id: z.string().uuid(),
  full_name: z.string().min(1),
  email_address: z.string().email(),
  created_at: z.string().datetime(),
  updated_at: z.string().datetime(),
});

export type UserDto = z.infer<typeof userDtoSchema>;

export class UserDtoMapper {
  static toEntity(dto: UserDto): User {
    return {
      id: dto.id,
      email: dto.email_address,
      displayName: dto.full_name,
      avatarUrl: null,
      status: 'ACTIVE',
      createdAt: new Date(dto.created_at),
      updatedAt: new Date(dto.updated_at),
    };
  }
}
```

---

## Anti-Patterns

### ❌ Validation logic scattered across components

```typescript
// ❌ Bad — Validation in a screen component instead of domain validators
export function LoginScreen() {
  const handleSubmit = (values: FormValues) => {
    if (!values.email.includes('@')) {
      setError('Invalid email'); // Business rule in UI
      return;
    }
    if (values.password.length < 8) {
      setError('Password too short'); // Business rule in UI
      return;
    }
  };
}
```

Email format and minimum password length are business rules. They belong in `loginSchema` and are enforced at the domain boundary.

### ❌ Using `.parse()` without a try/catch

```typescript
// ❌ Bad — .parse() throws an unhandled exception
export class LoginUseCase {
  async execute(input: unknown) {
    const data = loginSchema.parse(input); // Throws ZodError — uncaught
    return this.userRepository.authenticate(data.email, data.password);
  }
}
```

### ❌ Schema defined in the presentation layer

```typescript
// ❌ Bad — Schema defined in a form hook, not in domain
// src/presentation/features/auth/hooks/use-login-form.ts

const loginFormSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
});
```

The schema definition belongs in `src/domain/validators/`. The form hook imports and uses it.

---

[← Repository Interfaces](./repositories.md) | [Index](../README.md) | [Next: Application Layer →](../application/application.md)
