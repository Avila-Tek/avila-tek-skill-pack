# Domain Layer

The domain layer is the innermost ring of the Clean Architecture. It models the real-world concepts that the application exists to address — the entities, rules, and vocabulary of the business. Every other layer serves the domain layer; the domain layer serves nobody. It has no dependencies on React Native, Expo, HTTP clients, storage libraries, or any framework concern.

If you can describe what your application does in plain English without mentioning a database, an API, or a user interface, you are describing the domain. The domain layer is the code representation of that description.

---

## What the Domain Layer Contains

```
src/domain/
├── entities/         # Domain objects with identity
├── enums/            # Typed constant sets and string literal unions
├── errors/           # Discriminated union error types
├── repositories/     # Repository interface contracts (I prefix)
└── validators/       # Zod schemas for domain input validation
```

Each subdirectory has a single, narrow responsibility. Entities define what things are. Errors define what can go wrong. Repository interfaces define how data is persisted without specifying where or how. Validators define what constitutes valid input.

---

## Absolute Constraints

The domain layer must never contain:

- Any `import from 'react'` or `import from 'react-native'`
- Any `import from 'expo-*'`
- Any HTTP client (`axios`, `fetch`)
- Any storage reference (`AsyncStorage`, `expo-secure-store`, `SQLite`)
- Any serialization library (`class-transformer`, `json-bigint`)
- Any navigation reference (`expo-router`, `@react-navigation/*`)

The only allowed imports within the domain layer are:

- Other domain files (entities, errors, enums)
- `zod` (for validators only)
- The `Result` type from `@/lib/result`
- Pure TypeScript standard library types

```typescript
// ✅ Good — Domain file with only pure TypeScript and Zod
// src/domain/entities/user.ts

export interface User {
  readonly id: string;
  readonly email: string;
  readonly displayName: string;
  readonly createdAt: Date;
}
```

```typescript
// ❌ Bad — Domain file importing infrastructure
// src/domain/repositories/i-user-repository.ts

import axios from 'axios';              // Forbidden in domain
import AsyncStorage from '@react-native-async-storage/async-storage'; // Forbidden
```

---

## File Organization

One concept per file. A file named `user.ts` contains only the `User` entity and directly related type aliases. A file named `i-user-repository.ts` contains only the `IUserRepository` interface.

Do not create files named `models.ts`, `types.ts`, or `interfaces.ts` that aggregate unrelated domain concepts. When you need to combine them, use `domain/index.ts` as the barrel export.

---

## Layer Pages

Detailed conventions for each domain subdirectory:

- [Entities](./entities.md) — Readonly interfaces, factory patterns, identity
- [Enums](./enums.md) — `const` object pattern, string literal unions
- [Repository Interfaces](./repositories.md) — Contracts, `I` prefix, Result returns
- [Validators](./validators.md) — Zod schemas, `.safeParse()`, naming

---

[← State Management](../05-state-management.md) | [Index](../README.md) | [Next: Entities →](./entities.md)
