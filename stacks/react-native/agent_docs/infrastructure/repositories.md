# Repository Implementations

The repository implementation is where the domain's abstract contract meets concrete infrastructure. It is the single place that knows both the domain interface it must satisfy and the data source it must use to satisfy it. Repository implementations compose data sources, parse their raw output through DTOs, catch exceptions, and translate everything into the `Result<T, E>` values that the rest of the application depends on.

The implementation is deliberately unglamorous. Its job is to be a reliable, tested translation layer. Every method is a pipeline: call the data source, validate the shape, map to a domain entity, return `ok(entity)` on success, catch any failure, map to a typed domain error, return `err(error)` on failure.

---

## Implementing the Domain Interface

A repository implementation declares that it `implements` the corresponding domain interface. TypeScript will enforce that every method in the interface is correctly implemented.

```typescript
// ✅ Good — Complete user repository implementation
// src/infrastructure/repositories/user-repository-impl.ts

import type { IUserRepository } from '@/domain/repositories/i-user-repository';
import type { User } from '@/domain/entities/user';
import type { UserError } from '@/domain/errors/user-errors';
import { ok, err } from '@/lib/result';
import type { Result } from '@/lib/result';
import { userDtoSchema, UserDtoMapper } from '@/infrastructure/dtos/user-dto';
import type { UserApiDataSource } from '@/infrastructure/data-sources/user-api-data-source';

export class UserRepositoryImpl implements IUserRepository {
  constructor(private readonly dataSource: UserApiDataSource) {}

  async findById(id: string): Promise<Result<User, UserError>> {
    try {
      const raw = await this.dataSource.getUser(id);
      const dto = userDtoSchema.parse(raw);
      return ok(UserDtoMapper.toEntity(dto));
    } catch (error) {
      return this.mapError(error, id);
    }
  }

  async findByEmail(email: string): Promise<Result<User, UserError>> {
    try {
      const raw = await this.dataSource.getUserByEmail(email);
      const dto = userDtoSchema.parse(raw);
      return ok(UserDtoMapper.toEntity(dto));
    } catch (error) {
      return this.mapError(error, email);
    }
  }

  async save(user: User): Promise<Result<void, UserError>> {
    try {
      await this.dataSource.updateUser(user.id, UserDtoMapper.fromEntity(user));
      return ok(undefined);
    } catch (error) {
      return this.mapError(error, user.id);
    }
  }

  async delete(id: string): Promise<Result<void, UserError>> {
    try {
      await this.dataSource.deleteUser(id);
      return ok(undefined);
    } catch (error) {
      return this.mapError(error, id);
    }
  }

  private mapError(error: unknown, id: string): Result<never, UserError> {
    if (isAxiosError(error)) {
      if (error.response?.status === 404) return err({ type: 'USER_NOT_FOUND', id });
      if (error.response?.status === 401) return err({ type: 'USER_UNAUTHORIZED' });
      if (error.response?.status === 409) return err({ type: 'USER_EMAIL_TAKEN', email: id });
    }
    const message = error instanceof Error ? error.message : 'Unknown error';
    return err({ type: 'USER_NETWORK_ERROR', message });
  }
}

function isAxiosError(error: unknown): error is { response?: { status: number } } {
  return typeof error === 'object' && error !== null && 'response' in error;
}
```

---

## Constructor Injection of Data Sources

Data sources are injected through the constructor. The repository implementation never imports and instantiates its data source directly. This allows the composition root to provide real data sources in production and mock data sources in tests.

```typescript
// ✅ Good — Data source injected through constructor
export class UserRepositoryImpl implements IUserRepository {
  constructor(private readonly dataSource: UserApiDataSource) {}
}

// In composition root:
const dataSource = new UserApiDataSource(axiosClient);
const repository = new UserRepositoryImpl(dataSource);
```

```typescript
// ❌ Bad — Repository creates its own dependency
export class UserRepositoryImpl implements IUserRepository {
  private readonly dataSource = new UserApiDataSource(axiosClient); // Cannot be mocked
}
```

---

## Complete Order Repository Example

```typescript
// ✅ Good — Order repository with list support and error mapping
// src/infrastructure/repositories/order-repository-impl.ts

import type { IOrderRepository, OrderFilters } from '@/domain/repositories/i-order-repository';
import type { Order } from '@/domain/entities/order';
import type { OrderError } from '@/domain/errors/order-errors';
import { ok, err } from '@/lib/result';
import type { Result } from '@/lib/result';
import { orderDtoSchema, orderListDtoSchema, OrderDtoMapper } from '@/infrastructure/dtos/order-dto';
import type { OrderApiDataSource } from '@/infrastructure/data-sources/order-api-data-source';

export class OrderRepositoryImpl implements IOrderRepository {
  constructor(private readonly dataSource: OrderApiDataSource) {}

  async findById(id: string): Promise<Result<Order, OrderError>> {
    try {
      const raw = await this.dataSource.getOrder(id);
      const dto = orderDtoSchema.parse(raw);
      return ok(OrderDtoMapper.toEntity(dto));
    } catch (error) {
      return this.mapError(error, id);
    }
  }

  async findByUserId(
    userId: string,
    filters?: OrderFilters,
  ): Promise<Result<Order[], OrderError>> {
    try {
      const raw = await this.dataSource.getOrdersByUserId(userId);
      const listDto = orderListDtoSchema.parse(raw);
      return ok(listDto.data.map(OrderDtoMapper.toEntity));
    } catch (error) {
      return this.mapError(error, userId);
    }
  }

  async save(order: Order): Promise<Result<Order, OrderError>> {
    try {
      const payload = OrderDtoMapper.fromEntity(order);
      const raw = await this.dataSource.createOrder(payload);
      const dto = orderDtoSchema.parse(raw);
      return ok(OrderDtoMapper.toEntity(dto));
    } catch (error) {
      return this.mapError(error, order.id);
    }
  }

  async cancel(orderId: string): Promise<Result<void, OrderError>> {
    try {
      await this.dataSource.cancelOrder(orderId);
      return ok(undefined);
    } catch (error) {
      return this.mapError(error, orderId);
    }
  }

  private mapError(error: unknown, orderId: string): Result<never, OrderError> {
    if (isAxiosError(error)) {
      if (error.response?.status === 404) return err({ type: 'ORDER_NOT_FOUND', orderId });
      if (error.response?.status === 409) return err({ type: 'ORDER_ALREADY_PAID', orderId });
    }
    const message = error instanceof Error ? error.message : 'Unknown error';
    return err({ type: 'ORDER_NETWORK_ERROR', message });
  }
}

function isAxiosError(error: unknown): error is { response?: { status: number } } {
  return typeof error === 'object' && error !== null && 'response' in error;
}
```

---

## Anti-Patterns

### ❌ Business logic in the repository

```typescript
// ❌ Bad — Repository making business decisions
export class OrderRepositoryImpl implements IOrderRepository {
  async cancel(orderId: string): Promise<Result<void, OrderError>> {
    const order = await this.dataSource.getOrder(orderId);
    // Business rule — belongs in CancelOrderUseCase
    if (order.status === 'delivered') {
      return err({ type: 'ORDER_ALREADY_PAID', orderId });
    }
    await this.dataSource.cancelOrder(orderId);
    return ok(undefined);
  }
}
```

### ❌ Letting exceptions escape upward

```typescript
// ❌ Bad — No try/catch — exceptions propagate to use cases
export class UserRepositoryImpl implements IUserRepository {
  async findById(id: string): Promise<Result<User, UserError>> {
    const raw = await this.dataSource.getUser(id); // AxiosError propagates up uncaught
    const dto = userDtoSchema.parse(raw);
    return ok(UserDtoMapper.toEntity(dto));
  }
}
```

Every repository method must have a `try/catch`. The use case must never receive an unhandled exception from the repository.

### ❌ Returning raw data instead of Result

```typescript
// ❌ Bad — Repository returns raw DTO, not entity wrapped in Result
async findById(id: string): Promise<UserDto | null> {
  const raw = await this.dataSource.getUser(id);
  return raw as UserDto ?? null;
}
```

---

[← DTOs](./dtos.md) | [Index](../README.md) | [Next: Presentation Layer →](../presentation/presentation.md)
