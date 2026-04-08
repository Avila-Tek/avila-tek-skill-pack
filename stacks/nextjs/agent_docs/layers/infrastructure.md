---
description: Infrastructure layer — API service classes, DTO transforms, constructor DI, Safe<T> returns
globs: "apps/client/src/features/**/infrastructure/*.ts, apps/admin/src/features/**/infrastructure/*.ts, packages/features/src/**/infrastructure/*.ts"
alwaysApply: false
---

# Infrastructure Layer

Adapts abstract interfaces to concrete implementations. This is the only layer that talks to external systems (APIs, databases, storage).

---

## What lives here

```
features/<feature>/infrastructure/
  *.interfaces.ts    # API contracts (what the service expects)
  *.transform.ts     # DTO ↔ Domain mapping functions
  *.service.ts       # Data-access logic (orchestrates API + transforms)
  index.ts           # Singleton service export (wires real dependencies)
```

---

## Interfaces (`*.interfaces.ts`)

Define the **contract** a service expects — not how it's implemented. This enables dependency injection and testability.

```typescript
// features/habits/infrastructure/habits.interfaces.ts
import type { Safe } from '@repo/utils';
import type { HabitDTO, CreateHabitDTO } from '@repo/schemas';

export interface HabitsApi {
  getAll(): Promise<Safe<HabitDTO[]>>;
  create(input: CreateHabitDTO): Promise<Safe<HabitDTO>>;
  getById(id: string): Promise<Safe<HabitDTO>>;
}
```

Rules:
- Interfaces define **what**, not **how**.
- No logic, no fetch calls, no transforms.
- The interface matches what the `@repo/services` API module exposes.

DTOs are defined in `@repo/schemas` (shared across apps). Infrastructure `*.interfaces.ts` files create local aliases and response wrappers — not raw DTO definitions.

---

## Services (`*.service.ts`)

Class-based services with **constructor dependency injection**. They receive an API via constructor, call it, and transform responses to domain models. Services return `Safe<T>` — they never throw.

```typescript
// features/habits/infrastructure/habits.service.ts
import type { Safe } from '@repo/utils';
import type { Habit } from '../domain/habit.model';
import type { TCreateHabitForm } from '../domain/habits.form';
import type { HabitsApi } from './habits.interfaces';
import { toHabitDomain, fromCreateHabitInput } from './habits.transform';

export class HabitsService {
  constructor(private api: HabitsApi) {}

  async getAll(): Promise<Safe<Habit[]>> {
    const result = await this.api.getAll();
    if (!result.success) return result;
    return { success: true, data: result.data.map(toHabitDomain) };
  }

  async create(data: TCreateHabitForm): Promise<Safe<Habit>> {
    const input = fromCreateHabitInput(data);
    const result = await this.api.create(input);
    if (!result.success) return result;
    return { success: true, data: toHabitDomain(result.data) };
  }

  async getById(id: string): Promise<Safe<Habit>> {
    const result = await this.api.getById(id);
    if (!result.success) return result;
    return { success: true, data: toHabitDomain(result.data) };
  }
}
```

Rules:
- **Never throw.** Return `Safe<T>` — propagate `{ success: false, error }` from the API.
- **Constructor DI** — the service depends on an interface, not a concrete implementation. This makes testing easy (inject a mock that satisfies the interface).
- Always transform responses to domain models — never return raw DTOs.
- Services orchestrate: call API, transform result, compose multiple calls if needed.

---

## Singleton export (`index.ts`)

Wire the real API implementation and export a singleton instance.

```typescript
// features/habits/infrastructure/index.ts
import { getAPIClient } from '@/lib/api';
import { HabitsService } from './habits.service';

const api = getAPIClient();
export const habitsService = new HabitsService(api.v1.habits);
```

The singleton is imported by the application layer (queries, mutations, use cases). In tests, you instantiate the service with a mock API instead.

---

## Transforms (`*.transform.ts`)

Pure functions that map between DTO shapes (from `@repo/schemas`) and domain models.

```typescript
// features/habits/infrastructure/habits.transform.ts
import type { HabitDTO, CreateHabitDTO } from '@repo/schemas';
import type { Habit } from '../domain/habit.model';
import type { TCreateHabitForm } from '../domain/habits.form';

// API response → Domain model
export function toHabitDomain(dto: HabitDTO): Habit {
  return {
    id: dto.id,
    name: dto.name,
    status: dto.status,
    userId: dto.userId,
    createdAt: new Date(dto.createdAt),
    completedAt: dto.completedAt ? new Date(dto.completedAt) : null,
  };
}

// Form data → API input
export function fromCreateHabitInput(form: TCreateHabitForm): CreateHabitDTO {
  return {
    name: form.name,
    description: form.description ?? null,
    frequency: form.frequency,
  };
}
```

Rules:
- Transforms are pure functions — no I/O, no async, no side effects.
- Name pattern: `toXDomain()` for API→Domain, `fromXInput()` for Domain→API.
- Handle nullability explicitly — don't let `undefined` leak through.

---

## When you DON'T need a service

A service is unnecessary when the code:
- Only calls one API method
- Only checks `success` / returns the result
- Doesn't transform data
- Doesn't compose multiple calls
- Doesn't make any decisions

In that case, the application layer (query/mutation hook) can call the API module directly via the singleton.

---

## Shared API Client (`@repo/services`)

The HTTP client follows a **Port/Adapter** pattern defined in `packages/services/`:

```
packages/services/
  src/
    http/
      port/httpClient.port.ts       # HttpClient interface (the contract)
      adapters/safeFetch.port.ts    # SafeFetchClient (concrete implementation)
    components/
      users.ts                      # UserApi module
      auth.ts                       # AuthApi module
    API.ts                          # Main API class (wires modules)
```

**Port** — `HttpClient` interface defines `get`, `post`, `put`, `patch`, `delete`. All methods return `Promise<Safe<T>>`.

**Adapter** — `SafeFetchClient` implements `HttpClient` using `safeFetch` from `@repo/utils`. Handles URL building, headers, auth tokens, schema validation, and envelope unwrapping.

**API class** — Receives an `HttpClient`, instantiates all API modules, and exposes them:

```typescript
// packages/services/src/API.ts
export class API {
  public readonly v1: APIService;

  constructor(config: APIConfig) {
    this.httpClient = config.httpClient ?? new SafeFetchClient({ ... });
    this.v1 = Object.freeze({
      users: new UserApi(this.httpClient),
      auth: new AuthService(this.httpClient),
    });
  }
}
```

**App-level singleton** — Each app creates one instance:

```typescript
// lib/api.ts
import { API } from '@repo/services';

let api: API | null = null;

export function getAPIClient(token?: string): API {
  if (!api) {
    api = new API({ token, baseURL: `${process.env.NEXT_PUBLIC_API_URL}/api` });
  }
  return api;
}
```

---

## Anti-patterns

- **Services that throw** — Services return `Safe<T>`. The application layer decides how to handle errors.
- **Business logic in services** — Services are data-access adapters. Rules like "can this user create more habits?" belong in `domain/*.logic.ts` or use cases.
- **Domain entities derived from ORM types** — `type Habit = InferSelectModel<typeof habits>` couples domain to infrastructure. Define domain types independently.
- **Next.js imports in infrastructure** — No `revalidatePath`, `cache()`, `redirect()` in services. Those belong in Server Actions or route files.
- **DTOs without transforms** — Never pass raw API response data to UI components. Always map through `*.transform.ts`.
- **Importing services directly in UI** — UI should go through the application layer (queries/mutations). Only Server Component pages may call services directly for simple reads.
- **Services importing API directly** — Use constructor DI. The service depends on an interface, the singleton in `index.ts` wires the real implementation.
