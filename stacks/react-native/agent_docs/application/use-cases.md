# Use Cases

A use case is one unit of application behavior. It encapsulates a single workflow that the application can perform on behalf of a user or an automated process. `GetUserProfileUseCase` fetches and returns a user. `CreateOrderUseCase` validates input, checks availability, creates an order entity, and persists it. `LogoutUseCase` clears credentials and revokes the session.

Use cases are **classes** with a single public method: `execute()`. The class constructor declares dependencies as domain interfaces. The `execute()` method accepts typed input, performs its orchestration, and returns `Promise<Result<T, E>>`. This pattern is predictable, testable, and self-documenting.

---

## The `execute()` Method Pattern

Every use case is a class with:
- A constructor that receives repository interfaces
- A single public `execute()` method
- A `Promise<Result<T, E>>` return type

```typescript
// ✅ Good — Minimal use case with simple delegation
// src/application/use-cases/user/get-user-profile-use-case.ts

import type { IUserRepository } from '@/domain/repositories/i-user-repository';
import type { User } from '@/domain/entities/user';
import type { UserError } from '@/domain/errors/user-errors';
import type { Result } from '@/lib/result';

export class GetUserProfileUseCase {
  constructor(private readonly userRepository: IUserRepository) {}

  execute(userId: string): Promise<Result<User, UserError>> {
    return this.userRepository.findById(userId);
  }
}
```

```typescript
// ✅ Good — Use case with validation and domain logic
// src/application/use-cases/auth/login-use-case.ts

import type { IUserRepository } from '@/domain/repositories/i-user-repository';
import type { IAuthRepository } from '@/domain/repositories/i-auth-repository';
import { loginSchema } from '@/domain/validators/auth-validators';
import type { UserError } from '@/domain/errors/user-errors';
import { err } from '@/lib/result';
import type { Result } from '@/lib/result';

export interface AuthToken {
  readonly accessToken: string;
  readonly refreshToken: string;
  readonly expiresAt: Date;
}

export class LoginUseCase {
  constructor(
    private readonly userRepository: IUserRepository,
    private readonly authRepository: IAuthRepository,
  ) {}

  async execute(input: unknown): Promise<Result<AuthToken, UserError>> {
    const parsed = loginSchema.safeParse(input);
    if (!parsed.success) {
      return err({ type: 'USER_INVALID_CREDENTIALS' });
    }

    const userResult = await this.userRepository.findByEmail(parsed.data.email);
    if (!userResult.success) {
      return err({ type: 'USER_INVALID_CREDENTIALS' });
    }

    return this.authRepository.createSession(
      userResult.data.id,
      parsed.data.password,
    );
  }
}
```

---

## Constructor Injection

Dependencies are injected through the constructor. Use cases never instantiate their dependencies. The composition root (root layout) creates both the dependencies and the use case, then provides the use case through context.

```typescript
// ✅ Good — Constructor injection with multiple repositories
// src/application/use-cases/orders/create-order-use-case.ts

import type { IUserRepository } from '@/domain/repositories/i-user-repository';
import type { IOrderRepository } from '@/domain/repositories/i-order-repository';
import type { IProductRepository } from '@/domain/repositories/i-product-repository';
import type { Order } from '@/domain/entities/order';
import type { OrderError } from '@/domain/errors/order-errors';
import { ok, err, isErr } from '@/lib/result';
import type { Result } from '@/lib/result';

export interface CreateOrderInput {
  readonly userId: string;
  readonly items: ReadonlyArray<{
    readonly productId: string;
    readonly quantity: number;
  }>;
}

export class CreateOrderUseCase {
  constructor(
    private readonly userRepository: IUserRepository,
    private readonly orderRepository: IOrderRepository,
    private readonly productRepository: IProductRepository,
  ) {}

  async execute(input: CreateOrderInput): Promise<Result<Order, OrderError>> {
    // 1. Verify the user exists
    const userResult = await this.userRepository.findById(input.userId);
    if (isErr(userResult)) {
      return err({ type: 'ORDER_NOT_FOUND', orderId: input.userId });
    }

    // 2. Verify stock availability for all items
    for (const item of input.items) {
      const productResult = await this.productRepository.findById(item.productId);
      if (isErr(productResult)) {
        return err({ type: 'ORDER_NOT_FOUND', orderId: item.productId });
      }
      if (productResult.data.stock < item.quantity) {
        return err({
          type: 'ORDER_INSUFFICIENT_STOCK',
          productId: item.productId,
          available: productResult.data.stock,
        });
      }
    }

    // 3. Create the order entity
    const order: Order = {
      id: crypto.randomUUID(),
      userId: userResult.data.id,
      items: input.items.map((item) => ({
        productId: item.productId,
        quantity: item.quantity,
        unitPrice: 0, // Would be fetched from product in real implementation
      })),
      status: 'PENDING',
      totalAmount: 0, // Calculated from items
      createdAt: new Date(),
    };

    // 4. Persist the order
    return this.orderRepository.save(order);
  }
}
```

---

## Naming Convention

The naming pattern is: **Verb + Subject + `UseCase`**

| Verb | Subject | Full Name |
|---|---|---|
| Get | UserProfile | `GetUserProfileUseCase` |
| Create | Order | `CreateOrderUseCase` |
| Update | UserAvatar | `UpdateUserAvatarUseCase` |
| Delete | Account | `DeleteAccountUseCase` |
| Cancel | Order | `CancelOrderUseCase` |
| Send | EmailVerification | `SendEmailVerificationUseCase` |
| Logout | — | `LogoutUseCase` |

```typescript
// ✅ Good — Clear verb-subject naming
export class GetUserProfileUseCase { ... }
export class UpdateUserProfileUseCase { ... }
export class DeleteAccountUseCase { ... }
export class SendEmailVerificationUseCase { ... }
```

```typescript
// ❌ Bad — Vague, inconsistent, or no suffix
export class UserProfile { ... }           // No verb, no UseCase suffix
export class HandleOrder { ... }           // 'Handle' is vague
export class UserService { ... }           // Service is not a use case
export class DoCreateOrder { ... }         // 'Do' prefix is redundant noise
```

---

## Simple Delegation vs. Orchestration

Not all use cases need complex logic. A use case that simply delegates to one repository is still a valid and valuable use case — it provides a named, testable, injectable unit of behavior.

```typescript
// ✅ Good — Simple delegation use case
export class GetUserProfileUseCase {
  constructor(private readonly userRepository: IUserRepository) {}

  execute(userId: string): Promise<Result<User, UserError>> {
    return this.userRepository.findById(userId);
  }
}
```

```typescript
// ✅ Good — Orchestration use case with multiple steps
export class CheckoutUseCase {
  constructor(
    private readonly cartRepository: ICartRepository,
    private readonly orderRepository: IOrderRepository,
    private readonly paymentRepository: IPaymentRepository,
  ) {}

  async execute(userId: string, paymentMethodId: string): Promise<Result<Order, OrderError>> {
    const cartResult = await this.cartRepository.findByUserId(userId);
    if (isErr(cartResult)) return cartResult;

    const orderResult = await this.orderRepository.save({
      id: crypto.randomUUID(),
      userId,
      items: cartResult.data.items,
      status: 'PENDING',
      totalAmount: cartResult.data.total,
      createdAt: new Date(),
    });
    if (isErr(orderResult)) return orderResult;

    const paymentResult = await this.paymentRepository.charge(
      orderResult.data.id,
      paymentMethodId,
      cartResult.data.total,
    );
    if (isErr(paymentResult)) {
      await this.orderRepository.cancel(orderResult.data.id);
      return err({ type: 'ORDER_NOT_FOUND', orderId: orderResult.data.id });
    }

    return ok(orderResult.data);
  }
}
```

---

## Anti-Patterns

### ❌ God use cases

```typescript
// ❌ Bad — Use case doing too many unrelated things
export class UserUseCase {
  async getProfile(id: string) { ... }
  async updateProfile(id: string, data: unknown) { ... }
  async deleteAccount(id: string) { ... }
  async getOrders(userId: string) { ... }    // Order concern in User use case
  async sendInvoice(orderId: string) { ... } // Order concern in User use case
}
```

Each use case handles exactly one operation. `UserUseCase` should be five separate classes.

### ❌ UI logic in use cases

```typescript
// ❌ Bad — Use case managing navigation or toast state
import { router } from 'expo-router';
import { useUiStore } from '@/presentation/shared/stores/ui-store';

export class LoginUseCase {
  async execute(input: LoginInput) {
    const result = await this.authRepository.login(input);
    if (result.success) {
      router.replace('/(main)');           // Navigation is a presentation concern
      useUiStore.getState().addToast({     // UI state is a presentation concern
        message: 'Logged in!',
        type: 'success',
      });
    }
    return result;
  }
}
```

The use case returns a `Result`. The presentation hook decides what to do with that result — navigate, show a toast, update state.

### ❌ Business logic in the repository implementation instead of the use case

```typescript
// ❌ Bad — Repository impl contains order creation logic
export class OrderRepositoryImpl implements IOrderRepository {
  async createForUser(userId: string, items: OrderItem[]) {
    // Validates stock, creates entity, saves — this is application logic
    const user = await this.userDataSource.getUser(userId);
    if (!user) return err({ type: 'ORDER_NOT_FOUND', orderId: userId });
    const order = { id: uuid(), userId, items, status: 'PENDING' };
    return this.orderDataSource.save(order);
  }
}
```

Repositories persist and retrieve entities. Business logic — validation, entity creation, orchestration — lives in use cases.

---

[← Application Layer](./application.md) | [Index](../README.md) | [Next: Infrastructure Layer →](../infrastructure/infrastructure.md)
