# Next.js — Security Reference (OWASP Top 10)

## A01 · Broken Access Control

Route protection belongs in `middleware.ts` — not scattered across individual components:

```typescript
// ✅ src/middleware.ts — one place for auth routing
export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;
  const authenticated = isAuthenticated(request);

  if (isAuthRoute(pathname) && authenticated) {
    return NextResponse.redirect(new URL(routeBuilders.dashboard(), request.url));
  }
  if (isProtectedRoute(pathname) && !authenticated) {
    return NextResponse.redirect(new URL(routeBuilders.login({ callbackUrl: pathname }), request.url));
  }
  return NextResponse.next();
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico).*)'],
};
```

Server Actions must re-verify auth — middleware does not protect them:

```typescript
// ✅ Every Server Action that touches data must check auth
'use server';
import { auth } from '@/lib/auth';

export async function deleteTask(id: string): Promise<Safe<void>> {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return { success: false, error: 'Unauthorized' };

  // Also verify ownership:
  const task = await taskRepo.findById(id);
  if (task.userId !== session.user.id) return { success: false, error: 'Forbidden' };

  await taskRepo.delete(id);
  return { success: true, data: undefined };
}
```

## A02 · Cryptographic Failures

Never expose secrets in the client bundle. Any variable without `NEXT_PUBLIC_` prefix is server-only — but verify nothing sensitive is accidentally passed to Client Components:

```typescript
// ❌ Leaking server secret to client
export default function Page() {
  return <ClientComponent apiKey={process.env.STRIPE_SECRET_KEY} />; // ← never
}

// ✅ Keep server secrets server-side
export default async function Page() {
  const data = await fetchWithSecret(); // secret stays on the server
  return <ClientComponent data={data} />;
}
```

Sensitive cookies must be `httpOnly`, `secure`, `sameSite`:

```typescript
// better-auth handles cookie security automatically — don't override these settings
// Never store auth tokens in localStorage
```

## A03 · Injection

Validate all external inputs — API route bodies, search params, form data — with Zod before use:

```typescript
// ✅ API route handler with Zod validation
const CreateTaskSchema = z.object({
  title: z.string().trim().min(1).max(200),
  priority: z.enum(['low', 'medium', 'high']).default('medium'),
});

export async function POST(request: Request) {
  const body = await request.json();
  const result = CreateTaskSchema.safeParse(body);

  if (!result.success) {
    return Response.json(
      { error: 'VALIDATION_ERROR', details: result.error.flatten() },
      { status: 422 }
    );
  }
  // result.data is safe to use
}
```

Never use `dangerouslySetInnerHTML` with user-provided data. React auto-escapes JSX output — don't bypass it.

## A04 · Insecure Design

Server Components are the security boundary for data fetching. Never fetch sensitive data in Client Components — it will be exposed in the client bundle or network responses:

```typescript
// ✅ Data fetching in Server Component — stays on the server
export default async function OrdersPage() {
  const orders = await orderService.getUserOrders(); // server-only
  return <OrderList orders={orders} />;
}

// ❌ Fetching in Client Component exposes the full API response to the browser
'use client';
export function OrderList() {
  const { data } = useQuery({ queryFn: () => fetch('/api/admin/all-orders').then(r => r.json()) });
  // ...
}
```

## A05 · Security Misconfiguration

Security headers via `next.config`:

```typescript
// next.config.ts
const securityHeaders = [
  { key: 'X-DNS-Prefetch-Control', value: 'on' },
  { key: 'X-Frame-Options', value: 'SAMEORIGIN' },
  { key: 'X-Content-Type-Options', value: 'nosniff' },
  { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
  {
    key: 'Content-Security-Policy',
    value: [
      "default-src 'self'",
      "script-src 'self' 'unsafe-eval' 'unsafe-inline'", // tighten in prod
      "style-src 'self' 'unsafe-inline'",
      "img-src 'self' data: https:",
      "connect-src 'self'",
    ].join('; '),
  },
];

export default {
  async headers() {
    return [{ source: '/(.*)', headers: securityHeaders }];
  },
};
```

## A06 · Vulnerable and Outdated Components

```bash
npm audit             # before every release
npm audit --fix       # auto-fix where safe
```

## A07 · Identification and Authentication Failures

Authentication via better-auth (cookie-based sessions). The `auth.api` is server-side only — never call it from Client Components:

```typescript
// ✅ Server Component / Server Action
const session = await auth.api.getSession({ headers: await headers() });

// ✅ Client Component
const { data: session } = authClient.useSession();

// ❌ Never
'use client';
const session = await auth.api.getSession(...); // auth.api is server-only
```

Never store session tokens in `localStorage` — they become accessible to XSS. better-auth uses `httpOnly` cookies automatically.

## A08 · Software and Data Integrity Failures

Validate all external API responses with Zod before using the data in logic or rendering. A third-party API can return unexpected shapes or malicious content:

```typescript
// ✅ Always validate external responses
const ExternalApiSchema = z.object({
  id: z.string(),
  name: z.string(),
});

const raw = await externalApi.getUser(id);
const parsed = ExternalApiSchema.safeParse(raw);
if (!parsed.success) throw new Error('Unexpected response from external API');
```

## A09 · Security Logging and Monitoring Failures

Use structured logging. Never log request bodies that may contain passwords, tokens, or PII:

```typescript
// ✅
logger.info('Task created', { taskId: task.id, userId: session.user.id });

// ❌
logger.info('Request received', { body: request.body }); // may contain passwords
```

## A10 · Server-Side Request Forgery (SSRF)

Server Actions and API routes that fetch URLs derived from user input must validate the target:

```typescript
// ✅ Allowlist before fetching user-provided URLs
const ALLOWED_HOSTS = ['webhooks.trusted.com'];
const url = new URL(userProvidedUrl);
if (!ALLOWED_HOSTS.includes(url.hostname)) {
  return { success: false, error: 'Invalid URL' };
}
```

## Verification Checklist

- [ ] `middleware.ts` protects all routes in the `(main)/` group
- [ ] Every Server Action re-verifies auth + ownership
- [ ] No `NEXT_PUBLIC_` prefix on secrets
- [ ] No `dangerouslySetInnerHTML` with user-provided data
- [ ] All API route bodies validated with Zod before use
- [ ] Security headers configured in `next.config.ts`
- [ ] Auth tokens in `httpOnly` cookies — never `localStorage`
- [ ] External API responses validated with Zod before use
- [ ] `npm audit` clean before release
