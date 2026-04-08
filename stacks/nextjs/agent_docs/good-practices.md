---
description: React good practices — ternaries over &&, prop drilling limits, derived values, React.* imports
globs: "apps/client/src/**/*.tsx, apps/admin/src/**/*.tsx"
alwaysApply: false
---

# Good Practices

## React APIs via `React.*`

- Import `React` once, access hooks via `React.useState`, `React.useEffect`, etc.
- Don't destructure hooks from the React import.

```tsx
// preferred
import React from 'react';
const [value, setValue] = React.useState('');

// avoid
import React, { useState } from 'react';
```

---

## Conditional rendering

- Prefer ternaries (`condition ? <X /> : null`) over `&&` — avoids rendering `0`, `""`, or `NaN` when the condition is not strictly boolean.
- Avoid nested ternaries. Use component maps instead.

```tsx
// avoid — renders "0" when list is empty
return items.length && <List items={items} />;

// preferred
return items.length > 0 ? <List items={items} /> : <EmptyState />;
```

```tsx
// avoid nested ternaries
{status === 'loading' ? <Spinner /> : status === 'error' ? <Error /> : <Content />}

// preferred — component map
const byStatus: Record<Status, React.ReactNode> = {
  idle: <Idle />,
  loading: <Spinner />,
  error: <ErrorState />,
  success: <Content />,
};
return byStatus[status];
```

---

## Props

- Destructure in the function signature. Set defaults there.
- Avoid uncontrolled prop spreading (`{...props}`) — hides the component's API.
- Max **3 levels** of prop drilling. Beyond that, use Context or composition.

---

## JSX readability

- Move lists, filters, and complex expressions to derived values **above** the return.
- Don't define mini-components inside the render body — extract to their own component.
- Use intermediate variables for complex conditions.

```tsx
// avoid — filter + map inside JSX
return <ul>{items.filter(x => x.active).map(x => <Row key={x.id} item={x} />)}</ul>;

// preferred — derived value above return
const active = items.filter((x) => x.active);
return <ul>{active.map((x) => <Row key={x.id} item={x} />)}</ul>;
```

```tsx
// avoid — inline complex condition
if (user.isLoggedIn && user.token !== null && user.role !== 'guest') { ... }

// preferred
const isAuthenticated = user.isLoggedIn && user.token !== null && user.role !== 'guest';
if (isAuthenticated) { ... }
```

---

## Async patterns

- Prefer **async/await** over `.then()`.
- Use **`Promise.all`** for independent async operations — don't `await` sequentially.
- Avoid `await` inside loops — use `Promise.all(items.map(...))`.

```tsx
// avoid — sequential
const a = await fetch('/a');
const b = await fetch('/b');

// preferred — parallel
const [a, b] = await Promise.all([fetch('/a'), fetch('/b')]);
```

---

## Loading, error, empty states

- Every async data flow must handle **loading**, **error**, and **empty** explicitly.
- Don't assume data always exists.

```tsx
function UserList() {
  const { data, isLoading, isError } = useUsers();
  if (isLoading) return <Spinner />;
  if (isError) return <ErrorState />;
  if (!data || data.length === 0) return <EmptyState />;

  return <ul>{data.map((u) => <li key={u.id}>{u.name}</li>)}</ul>;
}
```

---

## Error differentiation

- **Handled errors** — show specific user feedback (toast, inline message).
- **Unhandled errors** — log + show generic message. Never display raw `error.message`.
