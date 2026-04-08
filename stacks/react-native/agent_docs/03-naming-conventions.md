# 03 · Naming Conventions

Naming is the first form of documentation. A well-named file, class, or function communicates its purpose, its layer, and its role before a reader opens it. Avila Tek enforces strict, predictable naming conventions across all React Native projects so that any engineer can navigate any codebase without a guided tour.

Every convention in this guide exists for a reason. The `I` prefix on repository interfaces makes the domain contract visually distinct from its infrastructure implementation. The `UseCase` suffix signals that a class belongs to the application layer. The `use` prefix on hooks follows React's own convention and enables lint rules to enforce hook rules correctly. Deviating from these conventions for personal preference is not acceptable — consistency is the goal.

---

## File Naming

All source files use **kebab-case**. This applies to every file in every layer except React components.

| File Type | Convention | Example |
|---|---|---|
| Entity | `kebab-case.ts` | `user-profile.ts` |
| Repository interface | `i-kebab-case.ts` | `i-user-repository.ts` |
| Repository implementation | `kebab-case-impl.ts` | `user-repository-impl.ts` |
| Use case | `kebab-case-use-case.ts` | `get-user-profile-use-case.ts` |
| Data source | `kebab-case-data-source.ts` | `user-api-data-source.ts` |
| DTO | `kebab-case-dto.ts` | `user-dto.ts` |
| Validator | `kebab-case-validators.ts` | `user-validators.ts` |
| Hook | `use-kebab-case.ts` | `use-user-profile.ts` |
| Zustand store | `kebab-case-store.ts` | `ui-store.ts` |
| Component | `PascalCase.tsx` | `UserProfileCard.tsx` |
| Screen | `PascalCaseScreen.tsx` | `UserProfileScreen.tsx` |
| Expo Router route | `kebab-case.tsx` or `[param].tsx` | `user-profile.tsx`, `[id].tsx` |

```typescript
// ✅ Good — kebab-case file containing a use case
// src/application/use-cases/user/get-user-profile-use-case.ts

export class GetUserProfileUseCase { ... }
```

```typescript
// ❌ Bad — PascalCase or camelCase for non-component files
// src/application/use-cases/user/GetUserProfile.ts
// src/application/use-cases/user/getUserProfile.ts
```

---

## Component Naming

Components are named in **PascalCase** and the name must be descriptive of what the component renders. Avoid generic names like `Card`, `Item`, or `Container` in isolation — always include the domain context.

```typescript
// ✅ Good — Descriptive, context-aware names
export function UserProfileCard({ user }: UserProfileCardProps) { ... }
export function OrderStatusBadge({ status }: OrderStatusBadgeProps) { ... }
export function ProductPriceLabel({ price, currency }: ProductPriceLabelProps) { ... }
```

```typescript
// ❌ Bad — Generic names without domain context
export function Card({ data }: CardProps) { ... }
export function Badge({ value }: BadgeProps) { ... }
export function Label({ text }: LabelProps) { ... }
```

Props interfaces are always named `ComponentNameProps`:

```typescript
// ✅ Good — Props interface named after the component
interface UserProfileCardProps {
  user: User;
  onEdit?: () => void;
}

export function UserProfileCard({ user, onEdit }: UserProfileCardProps) { ... }
```

---

## Hook Naming

Custom hooks always start with the `use` prefix (React requirement) followed by a **camelCase** description of what the hook does or provides.

| Pattern | Convention | Example |
|---|---|---|
| Data fetching | `useGet[Resource]` | `useGetUserProfile` |
| Data mutation | `use[Verb][Resource]` | `useCreateOrder`, `useUpdateProfile` |
| Derived/computed | `use[Resource]` | `useUserProfile`, `useOrders` |
| Auth | `useAuth`, `useAuthGuard` | — |
| Form | `use[Resource]Form` | `useLoginForm` |

```typescript
// ✅ Good — Descriptive hook names that communicate intent
export function useGetUserProfile(userId: string) { ... }
export function useCreateOrder() { ... }
export function useUpdateUserProfile() { ... }
export function useOrderList(filters: OrderFilters) { ... }
```

```typescript
// ❌ Bad — Vague or non-conventional hook names
export function userData(id: string) { ... }         // Missing 'use' prefix
export function useData() { ... }                    // Too generic
export function useHandleOrder() { ... }             // 'Handle' is vague
```

---

## Class and Interface Naming

### Domain Interfaces

Repository interfaces in the domain layer use the `I` prefix to signal that they are contracts, not implementations. This makes it immediately clear when reading a use case constructor which dependencies are abstractions.

```typescript
// ✅ Good — I prefix for domain interfaces
export interface IUserRepository {
  findById(id: string): Promise<Result<User, UserError>>;
  save(user: User): Promise<Result<void, UserError>>;
}

export interface IOrderRepository {
  findByUserId(userId: string): Promise<Result<Order[], OrderError>>;
}
```

```typescript
// ❌ Bad — No prefix, ambiguous whether abstract or concrete
export interface UserRepository { ... }   // Is this the interface or the class?
export interface UserRepositoryInterface { ... }  // Verbose and inconsistent
```

### Use Case Classes

Use cases are classes named with the pattern: **Verb + Subject + `UseCase`**.

```typescript
// ✅ Good — Verb + Subject + UseCase
export class GetUserProfileUseCase { ... }
export class CreateOrderUseCase { ... }
export class UpdateUserAvatarUseCase { ... }
export class DeleteAccountUseCase { ... }
export class LogoutUseCase { ... }
```

```typescript
// ❌ Bad — Inconsistent or missing suffix
export class UserProfile { ... }           // No 'UseCase' suffix — ambiguous
export class HandleCreateOrder { ... }     // 'Handle' prefix is not the convention
export class UserService { ... }           // Service is an anti-pattern name in this architecture
```

### Repository Implementations

Infrastructure implementations drop the `I` prefix and add `Impl`:

```typescript
// ✅ Good — Impl suffix for concrete implementations
export class UserRepositoryImpl implements IUserRepository { ... }
export class OrderRepositoryImpl implements IOrderRepository { ... }
```

---

## DTO Naming

DTOs are named with the entity name followed by the `Dto` suffix. They live in `infrastructure/dtos/`.

```typescript
// ✅ Good — Dto suffix, entity-named
export interface UserDto {
  id: string;
  full_name: string;      // API snake_case preserved in DTO
  email_address: string;
  created_at: string;
}

export interface OrderDto {
  order_id: string;
  user_id: string;
  total_amount: number;
}
```

```typescript
// ❌ Bad — No suffix, or wrong suffix
export interface UserModel { ... }    // Model is ambiguous
export interface UserResponse { ... } // Response is too HTTP-specific
export interface UserData { ... }     // Data is too generic
```

---

## Zod Schema Naming

Zod schemas are named in **camelCase** with the entity/context name followed by `Schema`.

```typescript
// ✅ Good — camelCase + Schema suffix
export const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
});

export const createUserSchema = z.object({
  name: z.string().min(2).max(100),
  email: z.string().email(),
});

export const updateProfileSchema = z.object({
  name: z.string().min(2).max(100).optional(),
  bio: z.string().max(500).optional(),
});
```

Inferred types from schemas use **PascalCase**:

```typescript
// ✅ Good — PascalCase type inferred from schema
export type LoginInput = z.infer<typeof loginSchema>;
export type CreateUserInput = z.infer<typeof createUserSchema>;
```

```typescript
// ❌ Bad — Inconsistent schema naming
export const LoginSchema = z.object({ ... });    // PascalCase for schema variable
export const login_schema = z.object({ ... });   // snake_case
export const loginFormData = z.object({ ... });  // Missing 'Schema' suffix
```

---

## Error Type Naming

Domain error types use the entity name followed by `Error`, and their discriminant field is `type` with a string literal union:

```typescript
// ✅ Good — Discriminated union with string literals
export type UserError =
  | { type: 'USER_NOT_FOUND'; id: string }
  | { type: 'USER_UNAUTHORIZED' }
  | { type: 'USER_EMAIL_TAKEN'; email: string }
  | { type: 'USER_INVALID_CREDENTIALS' };
```

```typescript
// ❌ Bad — Class-based errors or generic error types
export class UserNotFoundException extends Error { ... }
export type UserError = { code: number; message: string }; // Not discriminated
```

---

## Import Order

ESLint with `import/order` enforces this grouping:

```typescript
// ✅ Good — Correct import order with blank-line groups
// 1. React and React Native
import React, { useState, useCallback } from 'react';
import { View, Text, Pressable } from 'react-native';

// 2. Third-party libraries
import { useQuery } from '@tanstack/react-query';
import { z } from 'zod';

// 3. Internal absolute imports (by layer, outer to inner)
import type { User } from '@/domain/entities/user';
import type { UserError } from '@/domain/errors/user-errors';
import { useUseCaseContext } from '@/presentation/context/use-case-context';

// 4. Relative imports
import { UserAvatar } from './UserAvatar';
import type { UserProfileCardProps } from './types';
```

---

## Anti-Patterns

### ❌ Generic, context-free names

```typescript
// ❌ Bad — What does this hook do? What data does it return?
export function useData() { ... }
export function useHandler() { ... }
export function useManager() { ... }
```

### ❌ Manager/Service/Helper suffixes in the domain

```typescript
// ❌ Bad — 'Service' and 'Manager' imply unclear responsibilities
export class UserService { ... }    // What does it do? Orchestrate? Persist? Transform?
export class UserManager { ... }    // Same problem
export class UserHelper { ... }     // Helpers are dumping grounds
```

Use `UseCase` for orchestration, `RepositoryImpl` for persistence, and named utility functions for transformations.

### ❌ Abbreviated names

```typescript
// ❌ Bad — Abbreviations that require context to decode
export class UsrProfUC { ... }
export function usrHook() { ... }
export interface IUsrRepo { ... }
```

---

[← Folder Structure](./02-folder-structure.md) | [Index](./README.md) | [Next: Error Handling →](./04-error-handling.md)
