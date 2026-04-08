---
description: Backend structured logging — context fields, PII rules, log levels
globs: "apps/api/src/shared/utils/logger.ts, apps/api/src/**/infrastructure/*Adapter.ts"
alwaysApply: false
---

# Log Standardization

> Reference document. Include with `@agent_docs/backend/log-standardization.md` in skills or prompts involving logging implementation.

## Logger

Singleton at `apps/api/src/shared/utils/logger.ts`. Always import from there.

```typescript
import { Logger } from '../../../../shared/utils/logger';
```

---

## `LogContext` schema (current implementation)

```typescript
Logger.info({
  requestMethod: 'create_bank_account',  // snake_case action — REQUIRED
  requestStatus: 201,                    // HTTP status or operation code — REQUIRED
  requestError: 'none',                  // 'none' | error name — REQUIRED
  entityType: 'bank_account',            // entity name — include when entityId is present
  entityId: row.id,                      // numeric id — REQUIRED when entityType is present
  requestClient: 'web',                  // request origin — optional
}, 'BankAccount created successfully');
```

### Levels

| Level | When to use |
|-------|------------|
| `debug` | Development diagnostics |
| `info` | Successful normal operation |
| `warn` | Expected failure / validation failed |
| `error` | Unexpected failure / exception |
| `fatal` | Unrecoverable state |

---

## Where to log (boundary principle)

```
✅ Repository adapters       → successful create, update, delete
✅ Exception filters         → when catching and translating errors
✅ Critical use cases        → signup, auth, sensitive business operations
❌ Domain entities           → never
❌ Controllers               → RequestLoggerInterceptor already covers HTTP
❌ Value objects / policies  → never
```

### Correct example in adapter

```typescript
async create(account: BankAccount): Promise<BankAccount> {
  const [row] = await this.db.insert(bankAccounts).values({...}).returning();

  Logger.info({
    requestMethod: 'create_bank_account',
    requestStatus: 201,
    requestError: 'none',
    entityType: 'bank_account',
    entityId: row.id,
  }, 'BankAccount created successfully');

  return rowToEntity(row);
}
```

### Correct example in error

```typescript
Logger.error({
  requestMethod: 'update_bank_account',
  requestStatus: 404,
  requestError: 'not_found',
  entityType: 'bank_account',
  entityId: id,
}, 'BankAccount not found');
```

---

## Privacy — NEVER log

- PII: names, emails, phone numbers, identity documents
- Security: tokens, passwords, API keys, `Authorization` headers
- Full objects: never spread `req.body` or entire entities
- Financial data: amounts, bank accounts, payment data

```typescript
// ❌ BAD
Logger.info({ body: req.body }, 'Request received');
Logger.info({ email: user.email, token: jwt }, 'User logged in');

// ✅ GOOD
Logger.info({ requestMethod: 'login', requestStatus: 200, requestError: 'none', entityType: 'user', entityId: user.id }, 'User authenticated');
```

---

## Anti-patterns

| Anti-pattern | Fix |
|-------------|-----|
| `console.log(...)` | `Logger.info({...}, '...')` |
| Logging in domain layer | Move to adapter or use case |
| Generic `requestMethod` (`'action'`) | Specific operation name (`'approve_quote'`) |
| No `requestError` on errors | Include type: `'not_found'`, `'unauthorized'`, `'validation_error'` |
| `entityType` without `entityId` | Always include both together |

---

## Current state vs. company standard

The company standard (`styles-guides/docs/nestjs/17-log-standardization.md`) defines a structured JSON schema `{ context, request, content }`. Continental currently uses a bracket string format `[level:INFO][request_method:...]`.

**Pending for `telemetry-monitoring` branch:**
- Migrate `LogContext` to the `{ context, request, content }` schema from the standard
- Add `requestId` via NestJS interceptor/middleware
- Complete `RequestLoggerInterceptor` to cover `onRequest`/`onResponse`
