---
description: Frontend routing — route builder functions, route classification (PUBLIC/AUTH/PROTECTED), middleware
globs: "apps/client/src/shared/routes/*.ts, apps/client/src/middleware.ts, apps/client/app/**/*.tsx"
alwaysApply: false
---

# Routing

## Route builders

All navigation uses `routeBuilders` from `shared/routes/routes.ts`. No magic strings.

- Every route is a **function** — even static ones. This keeps a single pattern and allows adding params later.
- `ROUTE_PATHS` is the internal constant with path strings.
- `ROUTES` is exported for route classification (same values as `ROUTE_PATHS`).

```typescript
// shared/routes/routes.ts
const ROUTE_PATHS = {
  LOGIN: '/login',
  DASHBOARD: '/all-habits',
  SUBSCRIBE: '/subscribe',
  // ...
} as const;

export const routeBuilders = {
  login: (params?: { callbackUrl?: string }) => {
    if (!params || Object.keys(params).length === 0) return ROUTE_PATHS.LOGIN;
    const url = new URL(ROUTE_PATHS.LOGIN, 'http://dummy');
    if (params.callbackUrl) url.searchParams.set('callbackUrl', params.callbackUrl);
    return url.pathname + url.search;
  },
  dashboard: () => ROUTE_PATHS.DASHBOARD,
  subscribe: (params?: { planId?: string }) => {
    if (!params?.planId) return ROUTE_PATHS.SUBSCRIBE;
    return `${ROUTE_PATHS.SUBSCRIBE}?planId=${params.planId}`;
  },
  // ...
} as const;

export const ROUTES = ROUTE_PATHS;
```

---

## Route classification

Routes are classified into three categories in `shared/routes/routesConfig.ts`:

| Category | Meaning | Examples |
|---|---|---|
| `PUBLIC_ROUTES` | Accessible by anyone | `/login`, `/signup`, `/verify-email` |
| `AUTH_ROUTES` | Only for unauthenticated users (redirects if logged in) | `/login`, `/signup`, `/forgot-password` |
| `PROTECTED_ROUTES` | Requires authentication | `/all-habits`, `/subscribe`, `/settings/profile` |

```typescript
// shared/routes/routesConfig.ts
import { ROUTES } from './routes';

export const AUTH_ROUTES = [ROUTES.LOGIN, ROUTES.SIGNUP, ROUTES.FORGOT_PASSWORD, ROUTES.RESET_PASSWORD] as const;
export const PROTECTED_ROUTES = [ROUTES.DASHBOARD, ROUTES.SUBSCRIBE, ROUTES.PROFILE] as const;
```

Utility functions in `shared/routes/routes.utils.ts`:
- `isPublicRoute(pathname)` — checks against `PUBLIC_ROUTES`
- `isAuthRoute(pathname)` — checks against `AUTH_ROUTES`
- `isProtectedRoute(pathname)` — checks against `PROTECTED_ROUTES`

All matchers support sub-paths: `/login` matches `/login` and `/login/something`.

---

## Middleware

Route protection is handled at the middleware level in `src/middleware.ts`. See `agent_docs/frontend/authentication.md` for the full auth flow.

```typescript
// src/middleware.ts
export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;
  const authenticated = isAuthenticated(request);

  // Authenticated user on auth route → dashboard
  if (isAuthRoute(pathname) && authenticated) {
    return NextResponse.redirect(new URL(routeBuilders.dashboard(), request.url));
  }

  // Unauthenticated user on protected route → login with callback
  if (isProtectedRoute(pathname) && !authenticated) {
    return NextResponse.redirect(
      new URL(routeBuilders.login({ callbackUrl: pathname }), request.url)
    );
  }

  return NextResponse.next();
}

export const config = {
  matcher: ['/((?!api|_next/static|_next/image|favicon.ico|.*\\..*).*)'],
};
```

Authentication check reads cookies (`better_auth.session_token` or `accessToken`) in `shared/routes/authMiddleware.ts`.

---

## Navigation patterns

**Links** — use `next/link` with `routeBuilders`:

```tsx
import Link from 'next/link';
import { routeBuilders } from '@/shared/routes/routes';

<Link href={routeBuilders.plans()}>View Plans</Link>
```

**Programmatic navigation** — use `useRouter` with `routeBuilders`:

```tsx
const router = useRouter();
router.push(routeBuilders.dashboard());
router.push(routeBuilders.login({ callbackUrl: pathname }));
```

**Absolute URLs** (external services like Stripe):

```tsx
const successUrl = `${window.location.origin}${routeBuilders.subscribeSuccess()}`;
```

**Dynamic nav items** — functions that resolve based on state:

```typescript
// shared/navbar/navbar.constants.ts
export const navbarNavItems = [
  { label: 'Plans', href: routeBuilders.plans() },
  {
    label: 'My Habits',
    href: (isAuthenticated: boolean) =>
      isAuthenticated ? routeBuilders.dashboard() : routeBuilders.login(),
  },
];
```

---

## App directory organization

```
app/
  layout.tsx              # Root layout (providers, global header)
  page.tsx                # Home / landing
  (auth)/                 # Auth route group
    layout.tsx            # Auth-specific layout
    login/page.tsx
    signup/page.tsx
    forgot-password/page.tsx
    reset-password/page.tsx
    verify-email/page.tsx
    callback/page.tsx
  (main)/                 # Main app route group
    all-habits/page.tsx   # Dashboard (protected)
    plans/page.tsx        # Plans (public)
    settings/profile/page.tsx
    subscribe/page.tsx
```

Pages are thin wrappers — import from features and add metadata:

```tsx
// app/(auth)/login/page.tsx
import { LoginPage } from '@repo/features/auth/ui/pages/LoginPage';

export const metadata: Metadata = { title: 'Sign In' };

export default function LoginRoute() {
  return <LoginPage />;
}
```

---

## Adding a new route

1. Add path to `ROUTE_PATHS` in `shared/routes/routes.ts`.
2. Add builder function to `routeBuilders`.
3. Classify in `routesConfig.ts` (`PUBLIC_ROUTES`, `AUTH_ROUTES`, or `PROTECTED_ROUTES`).
4. Create the `page.tsx` in the appropriate route group (`(auth)/` or `(main)/`).
5. Page delegates to a feature page component — no business logic in the route file.

---

## Key files

- `src/shared/routes/routes.ts` — Route paths and builders
- `src/shared/routes/routesConfig.ts` — Route classification arrays
- `src/shared/routes/routes.utils.ts` — `isPublicRoute()`, `isAuthRoute()`, `isProtectedRoute()`
- `src/shared/routes/authMiddleware.ts` — `isAuthenticated()`, `getSessionToken()`
- `src/middleware.ts` — Next.js middleware (route protection)

---

## Anti-patterns

- **Magic strings** — Never use `router.push('/login')`. Always use `routeBuilders.login()`.
- **Auth checks in components** — Use middleware for route protection. Only check session in components that need user data for rendering.
- **Duplicated route paths** — All paths live in `ROUTE_PATHS`. Don't define paths anywhere else.
- **Business logic in route files** — `page.tsx` files are thin wrappers that delegate to feature pages.
- **Missing route classification** — Every new route must be added to `PUBLIC_ROUTES`, `AUTH_ROUTES`, or `PROTECTED_ROUTES`.
