# DTOs

A Data Transfer Object (DTO) represents the shape of data as it flows across a system boundary — in this case, between the external API and the application's domain model. APIs use snake_case field names, ISO date strings, and flat structures that often differ significantly from the rich, typed domain entities. DTOs bridge that gap.

DTOs in Avila Tek's codebase serve two specific purposes: they validate incoming API data using Zod to ensure it matches the expected shape, and they provide `toEntity()` and `fromEntity()` methods to convert between the API shape and the domain entity. DTOs live in the infrastructure layer because they are infrastructure concerns — they exist because of the API, not because of the business.

---

## Naming

DTOs are named with the entity name followed by the `Dto` suffix. The Zod schema for the DTO is named with the `DtoSchema` suffix.

```typescript
// ✅ Good
export const userDtoSchema = z.object({ ... });
export type UserDto = z.infer<typeof userDtoSchema>;

export const orderDtoSchema = z.object({ ... });
export type OrderDto = z.infer<typeof orderDtoSchema>;
```

---

## Zod Validation on Entry

Every DTO must be validated with Zod when it is received from an external source. Use `.parse()` inside the data source or repository — a `ZodError` thrown here is caught by the repository's `try/catch` and mapped to a domain error.

```typescript
// ✅ Good — Full DTO with Zod schema and mapping methods
// src/infrastructure/dtos/user-dto.ts

import { z } from 'zod';
import type { User } from '@/domain/entities/user';
import type { UserStatus } from '@/domain/enums/user-status';

export const userDtoSchema = z.object({
  id: z.string().uuid(),
  full_name: z.string().min(1),
  email_address: z.string().email(),
  avatar_url: z.string().url().nullable(),
  account_status: z.enum(['active', 'inactive', 'suspended', 'pending_verification']),
  created_at: z.string().datetime(),
  updated_at: z.string().datetime(),
});

export type UserDto = z.infer<typeof userDtoSchema>;

const statusMap: Record<UserDto['account_status'], UserStatus> = {
  active: 'ACTIVE',
  inactive: 'INACTIVE',
  suspended: 'SUSPENDED',
  pending_verification: 'PENDING_VERIFICATION',
};

const reverseStatusMap: Record<UserStatus, UserDto['account_status']> = {
  ACTIVE: 'active',
  INACTIVE: 'inactive',
  SUSPENDED: 'suspended',
  PENDING_VERIFICATION: 'pending_verification',
};

export class UserDtoMapper {
  static toEntity(dto: UserDto): User {
    return {
      id: dto.id,
      email: dto.email_address,
      displayName: dto.full_name,
      avatarUrl: dto.avatar_url,
      status: statusMap[dto.account_status],
      createdAt: new Date(dto.created_at),
      updatedAt: new Date(dto.updated_at),
    };
  }

  static fromEntity(user: User): Partial<UserDto> {
    return {
      id: user.id,
      full_name: user.displayName,
      email_address: user.email,
      avatar_url: user.avatarUrl,
      account_status: reverseStatusMap[user.status],
    };
  }
}
```

---

## Usage in Repository Implementations

```typescript
// ✅ Good — Repository parses DTO then maps to entity
// src/infrastructure/repositories/user-repository-impl.ts

import { userDtoSchema, UserDtoMapper } from '@/infrastructure/dtos/user-dto';
import { ok, err } from '@/lib/result';

export class UserRepositoryImpl implements IUserRepository {
  constructor(private readonly dataSource: UserApiDataSource) {}

  async findById(id: string): Promise<Result<User, UserError>> {
    try {
      const raw = await this.dataSource.getUser(id);
      const dto = userDtoSchema.parse(raw);     // Validates shape — throws ZodError if invalid
      return ok(UserDtoMapper.toEntity(dto));   // Maps to domain entity
    } catch (error) {
      if (error instanceof Response && error.status === 404) {
        return err({ type: 'USER_NOT_FOUND', id });
      }
      const message = error instanceof Error ? error.message : 'Validation error';
      return err({ type: 'USER_NETWORK_ERROR', message });
    }
  }
}
```

---

## List DTOs

When an API returns a list, define a schema for the list response as well:

```typescript
// ✅ Good — Paginated list DTO
// src/infrastructure/dtos/order-dto.ts

import { z } from 'zod';
import type { Order } from '@/domain/entities/order';

export const orderItemDtoSchema = z.object({
  product_id: z.string().uuid(),
  quantity: z.number().int().positive(),
  unit_price: z.number().nonnegative(),
});

export const orderDtoSchema = z.object({
  order_id: z.string().uuid(),
  user_id: z.string().uuid(),
  items: z.array(orderItemDtoSchema),
  status: z.enum(['pending', 'processing', 'shipped', 'delivered', 'cancelled', 'refunded']),
  total_amount: z.number().nonnegative(),
  created_at: z.string().datetime(),
});

export type OrderDto = z.infer<typeof orderDtoSchema>;

export const orderListDtoSchema = z.object({
  data: z.array(orderDtoSchema),
  total: z.number().int().nonnegative(),
  page: z.number().int().positive(),
  page_size: z.number().int().positive(),
});

export type OrderListDto = z.infer<typeof orderListDtoSchema>;

export class OrderDtoMapper {
  static toEntity(dto: OrderDto): Order {
    const statusMap: Record<OrderDto['status'], Order['status']> = {
      pending: 'PENDING',
      processing: 'PROCESSING',
      shipped: 'SHIPPED',
      delivered: 'DELIVERED',
      cancelled: 'CANCELLED',
      refunded: 'REFUNDED',
    };

    return {
      id: dto.order_id,
      userId: dto.user_id,
      items: dto.items.map((item) => ({
        productId: item.product_id,
        quantity: item.quantity,
        unitPrice: item.unit_price,
      })),
      status: statusMap[dto.status],
      totalAmount: dto.total_amount,
      createdAt: new Date(dto.created_at),
    };
  }

  static fromEntity(order: Order): Partial<OrderDto> {
    return {
      order_id: order.id,
      user_id: order.userId,
      total_amount: order.totalAmount,
    };
  }
}
```

---

## Anti-Patterns

### ❌ DTOs extending entities

```typescript
// ❌ Bad — DTO extends domain entity, coupling layers
export interface UserDto extends User {
  full_name: string;        // API field added on top of domain entity
  account_status: string;
}
```

DTOs and entities are completely separate types. They happen to represent the same concept but in different shapes. Inheritance implies that `UserDto` *is* a `User`, which is false — it is a representation of a user as seen by the API.

### ❌ Entities with DTO fields

```typescript
// ❌ Bad — Domain entity contains API-specific fields
export interface User {
  readonly id: string;
  readonly full_name: string;    // Snake_case from API — not a domain naming choice
  readonly email_address: string; // API field name leaked into domain
}
```

### ❌ No Zod validation on incoming data

```typescript
// ❌ Bad — Casting unknown data without validation
async findById(id: string): Promise<Result<User, UserError>> {
  const raw = await this.dataSource.getUser(id);
  const dto = raw as UserDto;     // No validation — runtime errors possible
  return ok(UserDtoMapper.toEntity(dto));
}
```

Always validate incoming data with `userDtoSchema.parse(raw)`. A malformed API response caught at the boundary produces a clear, mappable error. A `TypeError: Cannot read property of undefined` buried in the use case does not.

---

[← Data Sources](./data-sources.md) | [Index](../README.md) | [Next: Repository Implementations →](./repositories.md)
