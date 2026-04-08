# Infrastructure Layer

The infrastructure layer is where the application meets reality. It is the layer that makes actual HTTP requests, reads from and writes to storage, and translates between the raw shapes that external systems provide and the clean domain types that the application needs. Every messy, framework-specific, failure-prone operation happens here — and is fully contained here.

Infrastructure is intentionally the only layer permitted to be messy. It uses third-party libraries. It catches exceptions. It handles serialization. It manages network quirks. The cost of this messiness is paid once, in one layer, behind clean interfaces that the rest of the application depends on without knowing any of these details.

---

## What the Infrastructure Layer Contains

```
src/infrastructure/
├── data-sources/         # Raw data access (HTTP, storage)
│   ├── user-api-data-source.ts
│   ├── order-api-data-source.ts
│   └── secure-storage-data-source.ts
├── dtos/                 # Data Transfer Objects with Zod validation
│   ├── user-dto.ts
│   └── order-dto.ts
├── repositories/         # Implementations of domain repository interfaces
│   ├── user-repository-impl.ts
│   └── order-repository-impl.ts
└── http/                 # Shared HTTP client configuration
    └── axios-client.ts
```

---

## Absolute Constraints

Infrastructure must never:
- Contain business logic (that belongs in use cases)
- Return raw API responses, DTO types, or HTTP-specific types to the application layer
- Let uncaught exceptions escape upward — all exceptions are caught and mapped to domain errors
- Import from the presentation layer

Infrastructure may import from:
- Domain layer (to implement interfaces and reference entity types)
- Third-party libraries (`axios`, `@react-native-async-storage/async-storage`, `expo-secure-store`)
- The `Result` helper (`@/lib/result`)

```typescript
// ✅ Good — Infrastructure imports domain interface to implement
import type { IUserRepository } from '@/domain/repositories/i-user-repository';
import type { User } from '@/domain/entities/user';
import { ok, err } from '@/lib/result';
import axios from 'axios';
```

```typescript
// ❌ Bad — Infrastructure contains business logic
export class UserRepositoryImpl implements IUserRepository {
  async save(user: User) {
    // Business rule — does not belong in infrastructure
    if (user.status === 'SUSPENDED') {
      return err({ type: 'USER_UNAUTHORIZED' });
    }
    await this.dataSource.updateUser(user.id, user);
    return ok(undefined);
  }
}
```

---

## File Organization

Each domain concept has its own data source, DTO, and repository implementation file. There is no shared "API service" that handles multiple domains. Keeping infrastructure files domain-aligned makes it easy to find and modify all the infrastructure for one feature without touching another.

---

## Layer Pages

- [Data Sources](./data-sources.md) — REST, AsyncStorage, expo-secure-store
- [DTOs](./dtos.md) — Zod validation, `toEntity()`, `fromEntity()`
- [Repository Implementations](./repositories.md) — Implementing domain contracts

---

[← Use Cases](../application/use-cases.md) | [Index](../README.md) | [Next: Data Sources →](./data-sources.md)
