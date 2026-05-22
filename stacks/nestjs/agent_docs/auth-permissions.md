---
description: Backend auth guards and permission decorators — @ApiBearerAuth, @Permissions, role seeds
globs: "apps/api/src/**/*Controller.ts, apps/api/src/infrastructure/database/seeds/**"
alwaysApply: false
---

# Auth & Permissions

> Quick reference when creating a new controller

---

## Controller — required

### 1. `@ApiBearerAuth()` on the class

Every controller that requires authentication must have `@ApiBearerAuth()` at the class level:

```typescript
@ApiBearerAuth()
@ApiTags('Quotes')
@Controller('quotes')
export class QuoteController { ... }
```

If a specific endpoint is public (no auth), use `@Public()` on that method — do not remove `@ApiBearerAuth()` from the controller.

---

### 2. `@Permissions(...)` on every protected endpoint

Every endpoint that modifies or accesses sensitive data must have a `@Permissions()` decorator:

```typescript
@Post()
@Permissions('quote:create')
async create(...) { ... }

@Get()
@Permissions('quote:read')
async findAll(...) { ... }

@Put(':id')
@Permissions('quote:update')
async update(...) { ... }

@Delete(':id')
@Permissions('quote:delete')
async delete(...) { ... }

@Patch(':id/approve')
@Permissions('quote:approve')
async approve(...) { ... }
```

**Rule**: an endpoint without `@Public()` and without `@Permissions()` is an unprotected endpoint — any authenticated user can access it.

---

### 3. Permission naming convention

```
{module}:{action}
```

| Action | When to use |
|--------|-------------|
| `read` | GET list or GET by ID |
| `create` | POST — create a new resource |
| `update` | PUT / PATCH — modify an existing resource |
| `delete` | DELETE |
| `approve` | Approval / rejection flows |
| `pay` | Payment flows |
| `send` | Send / dispatch actions |

Examples: `quote:read`, `quote:create`, `quote:update`, `quote:delete`, `quote:approve`, `quote:pay`.

---

### 4. Register the permission in the seed

Add the permission in `apps/api/src/infrastructure/database/seeds/roles.seed.ts` under `PERMISSIONS` and assign it to the corresponding roles in `ROLE_PERMISSIONS`:

```typescript
// In PERMISSIONS:
{ name: 'Read quotes', value: 'quote:read' },
{ name: 'Write quotes', value: 'quote:write' },
{ name: 'Approve quotes', value: 'quote:approve' },

// In ROLE_PERMISSIONS — assign to the appropriate role:
[UserRole.SYSTEM_ADMIN]: ALL_PERMISSION_VALUES, // automatically includes new permissions
[UserRole.COLLECTIONS_SUPERVISOR]: [
  // ...existing permissions...
  'quote:read',
],
```

> `SYSTEM_ADMIN` uses `ALL_PERMISSION_VALUES` — adding a new permission to the `PERMISSIONS` array automatically grants it to admin.

---

## Checklist

- [ ] `@ApiBearerAuth()` on the controller class
- [ ] Every `POST` endpoint uses `@Permissions('<module>:create')` by default; override with the domain-action permission when the endpoint implements a domain action (e.g., `approve`, `pay`, `send`) — see the **Action** table above as the source of truth
- [ ] Every `PUT`/`PATCH` endpoint uses `@Permissions('<module>:update')` by default; override with `@Permissions('<module>:<domain-action>')` when the endpoint implements a domain action such as `approve`, `pay`, or `send` — see Action table
- [ ] Every `DELETE` endpoint uses `@Permissions('<module>:delete')` by default; override with `@Permissions('<module>:<domain-action>')` when the endpoint implements a domain action such as `approve`, `pay`, or `send` — see Action table
- [ ] Every `GET` endpoint that returns user-specific data, exposes PII, accesses tenant-scoped lists, or returns private/internal resources has `@Permissions('<module>:read')`; public listing endpoints for authenticated users do not require it
- [ ] The permission exists in `PERMISSIONS` in the seed
- [ ] The permission is assigned to the correct roles in `ROLE_PERMISSIONS`
- [ ] Truly public endpoints have `@Public()`
