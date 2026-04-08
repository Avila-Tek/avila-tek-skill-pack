---
description: Frontend authentication — better-auth, cookie sessions, middleware route protection
globs: "apps/client/src/middleware.ts, apps/client/src/features/auth/**/*"
alwaysApply: false
---

# Authentication

## Architecture

Uses **better-auth** with a backend API (NestJS). The flow:

```
Client (Next.js) ←cookies→ API (NestJS + better-auth) ←→ Database
```

- **Sessions**: Cookie-based, stored in database. No JWTs for session management.
- **Plugins**: Email/password, email OTP (password recovery), bearer token, optional Google OAuth.
- **Auth instance**: Lives in the API (`apps/api/`), not in the Next.js apps.

---

## Frontend auth client

Client Components use the auth client with `useSession()`:

```tsx
'use client';

import { authClient } from '@/lib/auth';

export function ProfileButton() {
  const { data: session, isPending } = authClient.useSession();

  if (isPending) return <Skeleton />;
  if (!session) return <LoginButton />;

  return <UserMenu user={session.user} />;
}
```

For sign-in and sign-up, use `authClient.signIn.email()` and `authClient.signUp.email()` inside Client Components.

---

## Middleware

Route protection is handled by `middleware.ts` — not by checking session in every component.

```typescript
// src/middleware.ts
import { isAuthenticated } from '@/src/shared/routes/authMiddleware';
import { isAuthRoute, isProtectedRoute } from '@/src/shared/routes/routes.utils';

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;
  const authenticated = isAuthenticated(request);

  // Authenticated users visiting auth pages → redirect to dashboard
  if (isAuthRoute(pathname) && authenticated) {
    return NextResponse.redirect(new URL(routeBuilders.dashboard(), request.url));
  }

  // Unauthenticated users visiting protected pages → redirect to login
  if (isProtectedRoute(pathname) && !authenticated) {
    const loginUrl = new URL(
      routeBuilders.login({ callbackUrl: pathname }),
      request.url
    );
    return NextResponse.redirect(loginUrl);
  }

  return NextResponse.next();
}
```

**Key files:**
- `src/middleware.ts` — Route-level protection
- `src/shared/routes/authMiddleware.ts` — `isAuthenticated()` reads session token from cookies
- `src/shared/routes/routes.ts` — Route builders (`routeBuilders.login()`, `routeBuilders.dashboard()`)
- `src/shared/routes/routes.utils.ts` — `isAuthRoute()`, `isProtectedRoute()` matchers

---

## Route structure

Auth routes live in the `(auth)/` route group:

```
app/
  (auth)/
    login/page.tsx
    signup/page.tsx
    forgot-password/page.tsx
    verify-email/page.tsx
    callback/page.tsx       # OAuth callback
  (main)/                   # Protected routes
    ...
```

The `(auth)` group uses a shared layout. The middleware ensures authenticated users can't access auth pages and unauthenticated users can't access `(main)` pages.

See `agent_docs/frontend/routing.md` for the full route builders pattern and route classification.

---

## Session management

- **Cookies**: `better-auth.session_token` (set by better-auth) or `accessToken` (custom). Middleware checks both.
- **Context**: `useUser()` hook provides session/user data throughout the app via React context.
- **After login**: Refetch user data for subscription status, feature access, etc.

```tsx
// Typical login flow
const loginMutation = useLogin();

async function handleSubmit(data: LoginFormData) {
  const result = await loginMutation.mutateAsync(data);
  if (result.success) {
    // Session cookie is automatically set by better-auth
    // Redirect happens via middleware or manual navigation
    router.push(callbackUrl ?? '/dashboard');
  }
}
```

---

## Auth form patterns

Auth forms follow the standard form pattern: Zod schema → react-hook-form → mutation → service.

```typescript
// features/auth/domain/auth.form.ts
export const loginFormDefinition = z.object({
  email: z.string().email('Invalid email'),
  password: z.string().min(8, 'Minimum 8 characters'),
});
export type TLoginForm = z.infer<typeof loginFormDefinition>;
export function createLoginDefaultValues(): TLoginForm {
  return { email: '', password: '' };
}
```

Form components split into container (form setup + mutation) and content (UI fields):

```tsx
// LoginForm.tsx — sets up form + handles submission
const form = useForm<TLoginForm>({
  resolver: zodResolver(loginFormDefinition),
  defaultValues: createLoginDefaultValues(),
});

// LoginFormContent.tsx — renders fields using useFormContext()
const { control } = useFormContext<TLoginForm>();
```

---

## Anti-patterns

- **Calling `auth.api` from Client Components** — The auth API is server-side only. Use `authClient` in Client Components.
- **Checking session in every component** — Use middleware for route protection. Only check session where you need user data for rendering.
- **Manual cookie management** — Let better-auth handle cookies. Don't read/write auth cookies directly.
- **Auth logic in route files** — Keep auth checks in middleware. Route `page.tsx` files should assume authentication is already verified.
- **Storing tokens in localStorage only** — Use cookies for auth tokens so middleware and Server Components can access them.
