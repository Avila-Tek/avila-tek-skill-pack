# 04 · Error Handling

Error handling is where architectural discipline is most frequently abandoned. Under time pressure, engineers reach for `throw`, wrap callsites in `try/catch`, and let error handling become an afterthought. The result is a codebase where error paths are invisible, untested, and inconsistent. Avila Tek takes a fundamentally different approach: errors are **values**, not exceptions.

Expected failures — a user not found, invalid credentials, a network timeout — are first-class domain concepts. They are modeled as typed discriminated unions and returned from functions alongside success values using the `Result<T, E>` pattern. `throw` is reserved exclusively for truly unrecoverable programmer errors (null dereference, programming contract violations). This discipline makes every function's failure modes explicit in its return type, reviewable in its signature, and exhaustively handleable by the caller.

---

## Discriminated Union Domain Errors

Each domain concept defines its own error union type. The discriminant field is always `type`, using `SCREAMING_SNAKE_CASE` string literals that read clearly in switch statements.

```typescript
// ✅ Good — Typed discriminated union for a domain concept
// src/domain/errors/user-errors.ts

export type UserError =
  | { type: 'USER_NOT_FOUND'; id: string }
  | { type: 'USER_UNAUTHORIZED' }
  | { type: 'USER_EMAIL_TAKEN'; email: string }
  | { type: 'USER_INVALID_CREDENTIALS' }
  | { type: 'USER_NETWORK_ERROR'; message: string };
```

```typescript
// ✅ Good — Order domain errors separate from User errors
// src/domain/errors/order-errors.ts

export type OrderError =
  | { type: 'ORDER_NOT_FOUND'; orderId: string }
  | { type: 'ORDER_ALREADY_PAID'; orderId: string }
  | { type: 'ORDER_INSUFFICIENT_STOCK'; productId: string; available: number }
  | { type: 'ORDER_NETWORK_ERROR'; message: string };
```

```typescript
// ❌ Bad — Generic error type that loses specificity
export type AppError = {
  code: string;
  message: string;
};

// ❌ Bad — Class-based exceptions for expected failures
export class UserNotFoundException extends Error {
  constructor(public readonly id: string) {
    super(`User ${id} not found`);
  }
}
```

---

## The `Result<T, E>` Pattern

`Result<T, E>` is a union type that represents either a successful value (`Ok`) or a failure value (`Err`). It is defined once in `src/lib/result.ts` and used across all layers.

```typescript
// ✅ Good — Result type definition
// src/lib/result.ts

export type Result<T, E> =
  | { success: true; data: T }
  | { success: false; error: E };

export function ok<T>(data: T): Result<T, never> {
  return { success: true, data };
}

export function err<E>(error: E): Result<never, E> {
  return { success: false, error };
}

export function isOk<T, E>(result: Result<T, E>): result is { success: true; data: T } {
  return result.success;
}

export function isErr<T, E>(result: Result<T, E>): result is { success: false; error: E } {
  return !result.success;
}
```

```typescript
// ✅ Good — Repository interface using Result
// src/domain/repositories/i-user-repository.ts

import type { Result } from '@/lib/result';
import type { User } from '@/domain/entities/user';
import type { UserError } from '@/domain/errors/user-errors';

export interface IUserRepository {
  findById(id: string): Promise<Result<User, UserError>>;
  findByEmail(email: string): Promise<Result<User, UserError>>;
  save(user: User): Promise<Result<void, UserError>>;
}
```

---

## Infrastructure: Catch and Map to Domain Errors

Infrastructure is the layer where external exceptions (HTTP errors, storage failures) are caught and mapped to the domain's typed error vocabulary. No raw exceptions escape infrastructure into the application or presentation layers.

```typescript
// ✅ Good — Infrastructure catches and maps errors
// src/infrastructure/repositories/user-repository-impl.ts

import type { IUserRepository } from '@/domain/repositories/i-user-repository';
import type { User } from '@/domain/entities/user';
import type { UserError } from '@/domain/errors/user-errors';
import { ok, err } from '@/lib/result';
import type { Result } from '@/lib/result';
import type { UserApiDataSource } from '@/infrastructure/data-sources/user-api-data-source';
import { UserDto } from '@/infrastructure/dtos/user-dto';

export class UserRepositoryImpl implements IUserRepository {
  constructor(private readonly dataSource: UserApiDataSource) {}

  async findById(id: string): Promise<Result<User, UserError>> {
    try {
      const raw = await this.dataSource.getUser(id);
      const dto = UserDto.parse(raw);
      return ok(dto.toEntity());
    } catch (error) {
      if (error instanceof Response && error.status === 404) {
        return err({ type: 'USER_NOT_FOUND', id });
      }
      if (error instanceof Response && error.status === 401) {
        return err({ type: 'USER_UNAUTHORIZED' });
      }
      const message = error instanceof Error ? error.message : 'Unknown error';
      return err({ type: 'USER_NETWORK_ERROR', message });
    }
  }

  async save(user: User): Promise<Result<void, UserError>> {
    try {
      await this.dataSource.updateUser(user.id, UserDto.fromEntity(user));
      return ok(undefined);
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Unknown error';
      return err({ type: 'USER_NETWORK_ERROR', message });
    }
  }

  async findByEmail(email: string): Promise<Result<User, UserError>> {
    try {
      const raw = await this.dataSource.getUserByEmail(email);
      const dto = UserDto.parse(raw);
      return ok(dto.toEntity());
    } catch (error) {
      if (error instanceof Response && error.status === 404) {
        return err({ type: 'USER_NOT_FOUND', id: email });
      }
      const message = error instanceof Error ? error.message : 'Unknown error';
      return err({ type: 'USER_NETWORK_ERROR', message });
    }
  }
}
```

---

## Using Result in Use Cases

Use cases receive `Result` from repositories and propagate or transform them. A use case may inspect the result and return a different error type, or it may short-circuit on failure.

```typescript
// ✅ Good — Use case propagates Result
// src/application/use-cases/user/get-user-profile-use-case.ts

import type { IUserRepository } from '@/domain/repositories/i-user-repository';
import type { User } from '@/domain/entities/user';
import type { UserError } from '@/domain/errors/user-errors';
import type { Result } from '@/lib/result';

export class GetUserProfileUseCase {
  constructor(private readonly userRepository: IUserRepository) {}

  async execute(userId: string): Promise<Result<User, UserError>> {
    return this.userRepository.findById(userId);
  }
}
```

```typescript
// ✅ Good — Use case with orchestration and Result chaining
// src/application/use-cases/orders/create-order-use-case.ts

import type { IOrderRepository } from '@/domain/repositories/i-order-repository';
import type { IUserRepository } from '@/domain/repositories/i-user-repository';
import type { Order } from '@/domain/entities/order';
import type { OrderError } from '@/domain/errors/order-errors';
import { ok, err, isErr } from '@/lib/result';
import type { Result } from '@/lib/result';

interface CreateOrderInput {
  userId: string;
  items: Array<{ productId: string; quantity: number }>;
}

export class CreateOrderUseCase {
  constructor(
    private readonly userRepository: IUserRepository,
    private readonly orderRepository: IOrderRepository,
  ) {}

  async execute(input: CreateOrderInput): Promise<Result<Order, OrderError>> {
    const userResult = await this.userRepository.findById(input.userId);
    if (isErr(userResult)) {
      // Map user error to order context error
      return err({ type: 'ORDER_NOT_FOUND', orderId: input.userId });
    }

    const newOrder: Order = {
      id: crypto.randomUUID(),
      userId: userResult.data.id,
      items: input.items,
      status: 'PENDING',
      createdAt: new Date(),
    };

    return this.orderRepository.save(newOrder);
  }
}
```

---

## Consuming Results in Hooks and Components

Presentation hooks handle the `Result` from use cases and expose structured state to components. Components never handle `Result` directly — they receive already-unwrapped data or typed error state from hooks.

```typescript
// ✅ Good — Hook unwraps Result and exposes typed state
// src/presentation/features/user/hooks/use-user-profile.ts

import { useQuery } from '@tanstack/react-query';
import { useUseCaseContext } from '@/presentation/context/use-case-context';
import type { User } from '@/domain/entities/user';
import type { UserError } from '@/domain/errors/user-errors';

interface UseUserProfileResult {
  user: User | undefined;
  error: UserError | null;
  isLoading: boolean;
}

export function useUserProfile(userId: string): UseUserProfileResult {
  const { getUserProfile } = useUseCaseContext();

  const query = useQuery({
    queryKey: ['user', userId],
    queryFn: async () => {
      const result = await getUserProfile.execute(userId);
      if (!result.success) {
        // Throw so TanStack Query captures it as an error state
        throw result.error;
      }
      return result.data;
    },
  });

  return {
    user: query.data,
    error: query.error as UserError | null,
    isLoading: query.isLoading,
  };
}
```

```typescript
// ✅ Good — Component receives typed error, exhaustive switch
// src/presentation/features/user/screens/UserProfileScreen.tsx

export function UserProfileScreen({ userId }: { userId: string }) {
  const { user, error, isLoading } = useUserProfile(userId);

  if (isLoading) return <LoadingSpinner />;

  if (error) {
    switch (error.type) {
      case 'USER_NOT_FOUND':
        return <ErrorView message={`User ${error.id} does not exist.`} />;
      case 'USER_UNAUTHORIZED':
        return <ErrorView message="You are not authorized to view this profile." />;
      case 'USER_NETWORK_ERROR':
        return <ErrorView message="Network error. Please try again." />;
      default:
        return <ErrorView message="An unexpected error occurred." />;
    }
  }

  if (!user) return null;

  return <UserProfileCard user={user} />;
}
```

---

## Never `throw` for Expected Failures

`throw` is reserved for programmer errors — violated preconditions, null dereferences on values that should never be null. Business failures are returned as `Result`.

```typescript
// ✅ Good — Expected failure returned as Result
async function login(email: string, password: string): Promise<Result<AuthToken, UserError>> {
  const result = await userRepository.findByEmail(email);
  if (!result.success) return err({ type: 'USER_INVALID_CREDENTIALS' });
  const isValid = await comparePassword(password, result.data.passwordHash);
  if (!isValid) return err({ type: 'USER_INVALID_CREDENTIALS' });
  return ok(generateToken(result.data));
}
```

```typescript
// ❌ Bad — Using throw for an expected, recoverable failure
async function login(email: string, password: string): Promise<AuthToken> {
  const user = await userRepository.findByEmail(email);
  if (!user) throw new Error('Invalid credentials'); // This is a business failure, not a crash
  return generateToken(user);
}
```

---

## Anti-Patterns

### ❌ Swallowing errors silently

```typescript
// ❌ Bad — Error is caught but nothing happens
async function loadUser(id: string) {
  try {
    return await userRepository.findById(id);
  } catch {
    return null; // Caller cannot distinguish "not found" from "network error"
  }
}
```

### ❌ Mixing error handling strategies

```typescript
// ❌ Bad — Some paths throw, some return null, some return Result
async function getOrder(id: string) {
  if (!id) throw new Error('ID required');        // throws
  const order = await orderRepository.find(id);
  if (!order.success) return null;                 // returns null
  if (order.data.status === 'CANCELLED') {
    return err({ type: 'ORDER_CANCELLED' });       // returns Result
  }
  return order.data;                               // returns entity directly
}
```

All paths must return `Result<T, E>`. Choose one pattern and apply it consistently.

### ❌ Error types in the wrong layer

```typescript
// ❌ Bad — Infrastructure-specific error types leaking into domain
// src/domain/errors/user-errors.ts
export type UserError =
  | { type: 'HTTP_404' }       // HTTP status codes are infrastructure details
  | { type: 'AXIOS_TIMEOUT' }  // Axios is an infrastructure concern
  | { type: 'USER_NOT_FOUND'; id: string }; // ✅ This one is correct
```

Domain errors describe business failures in business terms. Infrastructure maps technical failures to those terms.

---

[← Naming Conventions](./03-naming-conventions.md) | [Index](./README.md) | [Next: State Management →](./05-state-management.md)
