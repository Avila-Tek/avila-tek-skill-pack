---
description: Frontend observability — Sentry integration, SentryWrapper, global-error.tsx, manual captures
globs: "apps/client/sentry.*.config.ts, apps/client/src/instrumentation*.ts, apps/client/src/lib/sentry/*.tsx, apps/client/app/global-error.tsx"
alwaysApply: false
---

# Observability (Sentry)

## Setup overview

We use `@sentry/nextjs` for error monitoring. Each app (client, admin) has its own Sentry project and configuration:

```
apps/<app>/
  sentry.server.config.ts      # Server-side initialization
  sentry.edge.config.ts         # Edge runtime initialization
  src/instrumentation.ts        # Registers server/edge configs based on runtime
  src/instrumentation-client.ts # Client-side initialization
  src/lib/sentry/
    sentryWrapper.tsx            # SentryWrapper component
```

Environment-aware: Sentry is mandatory in production. Use `tracesSampleRate` to control volume (e.g., `0.2` server, `1.0` client for smaller apps).

---

## SentryWrapper

A `'use client'` component that applies Sentry metadata (tags, context, extras, fingerprint) to all events triggered within its React subtree.

```tsx
import SentryWrapper from '@/lib/sentry/sentryWrapper';

// In a layout or page
<SentryWrapper
  tags={{ route: '/checkout', feature: 'payments' }}
  context={{ ui_state: { step: 'review' } }}
  user={{ id: user.id, email: user.email }}
  fingerprint={['ValidationError', 'checkout']}
>
  {children}
</SentryWrapper>
```

**Props:**
- `user` — Sentry user object (`id`, `email`, `username`)
- `tags` — Key-value pairs for filtering in Sentry dashboard (route, userId, feature)
- `context` — Structured data stored under Sentry "app" context
- `extras` — Additional debugging metadata
- `fingerprint` — Custom grouping array (controls how Sentry groups similar errors)
- `stripEmpty` (default: `true`) — Skip null/undefined/empty values
- `clearOnUnmount` (default: `false`) — Clears tags/user/context on unmount

**When to use:**
- Page-level layouts to tag all errors from a route group
- Feature-level wrappers for critical flows (payments, onboarding)
- Around widgets that interact with external services

---

## global-error.tsx

Every app must have `app/global-error.tsx` — the error boundary of last resort. It catches errors that no other `error.tsx` boundary handled.

```tsx
// app/global-error.tsx
'use client';

import * as Sentry from '@sentry/nextjs';

export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  Sentry.captureException(error);

  return (
    <html>
      <body>
        <h2>Something went wrong</h2>
        <button onClick={reset}>Try again</button>
      </body>
    </html>
  );
}
```

Route-specific `error.tsx` files catch errors within their segment. `global-error.tsx` catches everything else.

---

## Manual error capture

For critical paths (payments, auth, mutations), capture errors explicitly even if they are handled gracefully:

```typescript
import * as Sentry from '@sentry/nextjs';

// In a Server Action or service
const result = await safe(paymentService.charge(amount));
if (!result.success) {
  Sentry.captureException(new Error(result.error), {
    tags: { feature: 'payments', action: 'charge' },
    extra: { amount, userId },
  });
  return result;
}
```

Use `Sentry.withScope()` for server-side enrichment when you need isolated context:

```typescript
Sentry.withScope((scope) => {
  scope.setTag('feature', 'checkout');
  scope.setContext('order', { orderId, total });
  Sentry.captureException(error);
});
```

---

## Event enrichment guidelines

| Enrichment | Purpose | Example |
|---|---|---|
| **Tags** | Filterable dimensions in dashboard | `route`, `feature`, `userId`, `env` |
| **Context** | Structured data for debugging | `{ ui_state: { step, form_values } }` |
| **Extras** | Arbitrary debugging data | `{ apiResponse, requestPayload }` |
| **Fingerprint** | Custom error grouping | `['PaymentError', orderId]` |
| **User** | User identification | `{ id, email }` |

Tags should be low-cardinality (finite set of values). Don't use UUIDs as tags — use context or extras for high-cardinality data.

---

## Anti-patterns

- **No Sentry in production** — Every production deploy must have Sentry configured with a valid DSN.
- **Logging sensitive data** — Never send PII, passwords, tokens, or payment details to Sentry. Use `beforeSend` to scrub if needed.
- **Swallowing errors** — `catch (e) {}` hides bugs from both the user and the monitoring system. Always capture or re-throw.
- **No error boundaries** — Every route group should have an `error.tsx`. Don't rely only on `global-error.tsx`.
- **Over-grouping with fingerprints** — Custom fingerprints should be specific enough to distinguish different failure modes. `['error']` groups everything together.
- **Capturing expected errors** — Don't send "user not found" or "validation failed" to Sentry. These are expected and handled. Only capture unexpected failures.
