# Repository Interfaces

A repository is an abstraction over the mechanism by which entities are persisted and retrieved. The domain layer defines *what* operations are possible on a collection of entities. The infrastructure layer defines *how* those operations are performed. This inversion — defining the interface in the layer that needs it, not the layer that implements it — is what allows use cases to be tested without a database, a network, or any real data source.

Repository interfaces are the boundary between what the application knows about its data and how that data actually flows. They speak the language of the domain: they receive and return entities and domain errors, never DTOs, HTTP responses, or storage-specific types.

---

## The Contract in the Domain

Repository interfaces live in `src/domain/repositories/`. They are TypeScript interfaces prefixed with `I`. They declare methods that take domain types as parameters and return `Promise<Result<T, E>>`.

```typescript
// ✅ Good — Complete repository interface
// src/domain/repositories/i-user-repository.ts

import type { Result } from '@/lib/result';
import type { User } from '@/domain/entities/user';
import type { UserError } from '@/domain/errors/user-errors';

export interface IUserRepository {
  findById(id: string): Promise<Result<User, UserError>>;
  findByEmail(email: string): Promise<Result<User, UserError>>;
  save(user: User): Promise<Result<void, UserError>>;
  delete(id: string): Promise<Result<void, UserError>>;
}
```

```typescript
// ✅ Good — Order repository interface with list queries
// src/domain/repositories/i-order-repository.ts

import type { Result } from '@/lib/result';
import type { Order } from '@/domain/entities/order';
import type { OrderError } from '@/domain/errors/order-errors';

export interface OrderFilters {
  readonly userId?: string;
  readonly status?: string;
  readonly fromDate?: Date;
  readonly toDate?: Date;
}

export interface IOrderRepository {
  findById(id: string): Promise<Result<Order, OrderError>>;
  findByUserId(userId: string, filters?: OrderFilters): Promise<Result<Order[], OrderError>>;
  save(order: Order): Promise<Result<Order, OrderError>>;
  cancel(orderId: string): Promise<Result<void, OrderError>>;
}
```

---

## The `I` Prefix Convention

The `I` prefix is not bureaucratic noise — it communicates essential architectural information at a glance. When reading a use case constructor:

```typescript
export class GetUserProfileUseCase {
  constructor(private readonly userRepository: IUserRepository) {}
}
```

The `I` prefix tells every reader that `userRepository` is an abstraction, not a concrete class. The actual implementation is wired elsewhere (in the composition root). This distinction matters when testing, when replacing implementations, and when onboarding new engineers.

```typescript
// ✅ Good — I prefix for the interface, no prefix for the implementation
export interface IUserRepository { ... }          // Domain
export class UserRepositoryImpl implements IUserRepository { ... } // Infrastructure
```

```typescript
// ❌ Bad — Ambiguous naming without I prefix
export interface UserRepository { ... }            // Is this the interface or the class?
export class UserRepository implements UserRepository { ... } // Now it's a naming conflict
```

---

## Methods Return `Promise<Result<T, E>>`

Every repository method returns a `Promise<Result<T, E>>`. There are no methods that return `T | null`, `T | undefined`, or `T` directly. This consistency guarantees that callers always handle both success and failure paths.

```typescript
// ✅ Good — All methods return Promise<Result<T, E>>
export interface IUserRepository {
  findById(id: string): Promise<Result<User, UserError>>;
  save(user: User): Promise<Result<void, UserError>>;
}
```

```typescript
// ❌ Bad — Inconsistent return types
export interface IUserRepository {
  findById(id: string): Promise<User | null>;     // Null instead of Result
  save(user: User): Promise<void>;                // Can this fail? Unclear.
  findByEmail(email: string): Promise<User>;      // Throws on not found? Unclear.
}
```

---

## No Infrastructure Imports

Repository interfaces must contain no imports from infrastructure, HTTP, or storage libraries. They import only:
- Other domain types (entities, error types, enums)
- The `Result` type from `@/lib/result`

```typescript
// ✅ Good — Pure domain imports only
import type { Result } from '@/lib/result';
import type { User } from '@/domain/entities/user';
import type { UserError } from '@/domain/errors/user-errors';

export interface IUserRepository {
  findById(id: string): Promise<Result<User, UserError>>;
}
```

```typescript
// ❌ Bad — Infrastructure leaking into domain interface
import axios from 'axios';                    // Infrastructure
import AsyncStorage from '@react-native-async-storage/async-storage'; // Infrastructure
import { AxiosResponse } from 'axios';        // Infrastructure

export interface IUserRepository {
  findById(id: string): Promise<AxiosResponse<User>>; // DTO/HTTP type in domain
}
```

---

## Pagination Pattern

For list queries that support pagination, define a shared `PaginatedResult` type in the domain:

```typescript
// ✅ Good — Domain-level pagination abstraction
// src/domain/repositories/pagination.ts

export interface PaginatedResult<T> {
  readonly items: ReadonlyArray<T>;
  readonly total: number;
  readonly page: number;
  readonly pageSize: number;
  readonly hasNextPage: boolean;
}

export interface PaginationParams {
  readonly page: number;
  readonly pageSize: number;
}
```

```typescript
// ✅ Good — Paginated list method on repository interface
export interface IOrderRepository {
  findByUserId(
    userId: string,
    pagination: PaginationParams,
    filters?: OrderFilters,
  ): Promise<Result<PaginatedResult<Order>, OrderError>>;
}
```

---

## Anti-Patterns

### ❌ God repository with unrelated methods

```typescript
// ❌ Bad — One repository trying to do everything
export interface IAppRepository {
  getUser(id: string): Promise<Result<User, UserError>>;
  getOrders(userId: string): Promise<Result<Order[], OrderError>>;
  getProducts(): Promise<Result<Product[], ProductError>>;
  saveSettings(settings: AppSettings): Promise<Result<void, never>>;
}
```

Each domain concept gets its own repository. `IUserRepository`, `IOrderRepository`, `IProductRepository`, `ISettingsRepository` — separate, focused, independently testable.

### ❌ Returning raw API types from the interface

```typescript
// ❌ Bad — Interface returns HTTP or DTO types
export interface IUserRepository {
  findById(id: string): Promise<{ data: UserDto; status: number }>;
}
```

Repository interfaces return domain entities. The mapping from DTO to entity is the implementation's responsibility.

### ❌ Methods with side effects in names but no Result on void returns

```typescript
// ❌ Bad — fire-and-forget with no error information
export interface IUserRepository {
  sendEmailVerification(userId: string): Promise<void>; // Can this fail? No way to know.
}

// ✅ Good:
export interface IUserRepository {
  sendEmailVerification(userId: string): Promise<Result<void, UserError>>;
}
```

Even operations that return no data on success must return `Result<void, E>` so failures can be communicated.

---

[← Enums](./enums.md) | [Index](../README.md) | [Next: Validators →](./validators.md)
