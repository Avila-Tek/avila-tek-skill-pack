---
description: Backend auth guards and permission decorators — @ApiBearerAuth, @Permissions, role seeds
globs: "apps/api/src/**/*Controller.ts, apps/api/src/database/seeds/**"
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
@Permissions('quote:write')
async create(...) { ... }

@Get()
@Permissions('quote:read')
async findAll(...) { ... }

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
| `read` | Read operations — GET list or by ID |
| `write` | Create and update — POST, PUT, PATCH |
| `delete` | Deletion — DELETE (when separated from write) |
| `approve` | Approval flows — PATCH approve/reject |
| `manage` | Full module administration |

Examples: `quote:read`, `quote:write`, `quote:approve`, `client:read`, `client:write`.

---

### 4. Register the permission in the seed

Add the permission in `apps/api/src/database/seeds/roles.seed.ts` under `PERMISSIONS` and assign it to the corresponding roles in `ROLE_PERMISSIONS`:

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
- [ ] Every write endpoint has `@Permissions('<module>:write')`
- [ ] Every sensitive read endpoint has `@Permissions('<module>:read')`
- [ ] The permission exists in `PERMISSIONS` in the seed
- [ ] The permission is assigned to the correct roles in `ROLE_PERMISSIONS`
- [ ] Truly public endpoints have `@Public()`
