# Table Feature — Next.js

## Overview

Build production-quality paginated table features that follow the project's `view<Entity>` pattern — a frontend feature slice with `ConfigurableTable`, URL-driven filters, server prefetch, and column visibility. The table consumes a paginated backend endpoint; designing that endpoint is outside this skill's scope (see `dev-api-and-interface-design`).

## Architecture Rules (snapshot)

This project uses **Clean Architecture** with **feature-driven** organization.

**Layer dependency direction:**
```
UI → Application → Infrastructure → Domain
```

- **Domain** — pure types, constants, logic. No imports from other layers.
- **Infrastructure** — services, transforms, API contracts. Imports only Domain.
- **Application** — React Query hooks, use cases. Imports Infrastructure + Domain.
- **UI** — pages, widgets, components. Imports Application + Domain. Never imports Infrastructure directly.

**Feature slicing rule:** A feature is a complete user-facing capability. Deleting `features/<feature>` must leave the rest of the app compilable.

**No feature-to-feature imports:**
- ✅ `features/<x>` → `shared/*`, `lib/*`, packages (`@repo/*`)
- ❌ `features/<x>` → `features/<y>`

If two features need the same thing, promote it to `shared/` or a package.

## File Structure

```
features/<parent>/<featureName>/
  domain/
    <featureName>.model.ts          # Types/interfaces for the entity
    <featureName>.constants.ts      # Label records, enum objects, filter options via labelsToFilterOptions
    <featureName>.logic.ts          # buildQueryInput(), isValidStatus(), toQueryFilters()
  application/
    queries/
      use<FeatureName>.query.ts     # queryOptions (Layer 1) + useXxx hook with select throw (Layer 2)
  infrastructure/
    <featureName>.service.ts        # httpClient calls
    <featureName>.interfaces.ts     # Request/response types (input, output)
    <featureName>.transform.ts      # API response → domain model mapping
  ui/
    components/
      <Item>StatusBadge.tsx         # Badge component for status column
      <Item>ActionsCell.tsx         # Eye icon Link to detail page
      Create<Item>Button.tsx        # Button wrapped in PermissionGuard — navigates to create route
    utils/
      <featureName>Table.columns.tsx  # TableColumn<T>[] definition
    widgets/
      <FeatureName>TableWidget.tsx    # Self-contained: filters + ConfigurableTable
    pages/
      <FeatureName>Page.tsx           # AdminPageLayout + permissions + widget
```

## Route Page (server component — thin wiring with PrefetchBoundary)

```tsx
interface UsersRouteProps {
  searchParams: Promise<Record<string, string | undefined>>;
}

export default async function UsersRoute({ searchParams }: UsersRouteProps) {
  const params = await searchParams;
  // buildQueryInput lives in domain/logic.ts — parses raw searchParams into typed ViewUsersInput
  const queryInput = buildQueryInput(params);

  return (
    <PrefetchBoundary
      queries={[
        viewUsersListQueryOptions(queryInput),
        // tableConfigurationQueryOptions only if using ConfigurableTableClientSide (server-persisted columns)
        // tableConfigurationQueryOptions('users'),
      ]}
    >
      <ViewUsersPage queryInput={queryInput} />
    </PrefetchBoundary>
  );
}
```

### `buildQueryInput` — create in `domain/logic.ts`

Parses raw `searchParams` into a typed input object. Write one per feature:

```tsx
// domain/viewUsers.logic.ts
export function buildQueryInput(
  params: Record<string, string | undefined>
): ViewUsersInput {
  return {
    page: parsePageParam(params.page),
    search: params.search ?? '',
    status: parseStatusParam(params.status),
    // add other filter params as needed
  };
}
```

Key rules:
- Use safe utils from `@repo/utils` (`parsePageParam`, `parseStatusParam`, `parseIdParam`) — never parse manually
- If using `ConfigurableTableClientSide`, add `tableConfigurationQueryOptions('your-table-id')` to the `queries` array — this loads the user's saved column config
- Pass `queryInput` as prop to the page component — do NOT re-parse URL in client components

## Table Widget (self-contained)

```tsx
function ViewUsersTableWidget({ queryInput }: Props): React.ReactElement {
  const { data, isLoading } = useViewUsers(queryInput);

  const items = data?.items ?? [];
  const pageCount = data?.pageInfo?.pageCount ?? 1;

  return (
    <ConfigurableTableClientSide<User>
      table="users"
      columns={VIEW_USERS_COLUMNS}
      data={items}
      loading={isLoading}
      page={queryInput.page}
      totalPages={pageCount}
      titleBadge={
        <TableFilterSearch
          placeholder="Buscar usuario..."
          searchParamKey="search"
        />
      }
      headerAction={
        <div className="flex gap-4">
          <TableFilterSimpleSelect
            placeholder="Rol"
            searchParamKey="role"
            options={ROLE_FILTER_OPTIONS}
            allOptionLabel="Todos"
          />
          <TableFilterSimpleSelect
            placeholder="Status"
            searchParamKey="status"
            options={STATUS_FILTER_OPTIONS}
            allOptionLabel="Todos"
          />
        </div>
      }
    />
  );
}
```

Key rules:
- Use `ConfigurableTableClientSide<T>` (not raw `Table`) for column visibility
- `TableFilterSimpleSelect` with `allOptionLabel="Todos"` — component handles the "all" option internally
- `TableFilterSearch` for text search — no external debounce/useEffect needed
- Pass `titleBadge` (search) and `headerAction` (filters) to ConfigurableTable

## Column Definitions (ui/utils/)

Separate file — never inline column JSX in the widget. Complex cells → extract to `ui/components/`:

```tsx
// ui/utils/viewUsersTable.columns.tsx
export const VIEW_USERS_COLUMNS: TableColumn<ViewUser>[] = [
  {
    id: 'name',
    header: 'Usuario',
    cell: (row) => <UserAvatarCell name={row.name} />,
  },
  {
    id: 'status',
    header: 'Status',
    cell: (row) => <UserStatusBadge status={row.status} />,
  },
  {
    id: 'actions',
    header: '',
    cell: (row) => <UserActionsCell userId={row.id} />,
  },
];
```

## Filter Options (domain/constants.ts)

Define label records and derive filter options using `labelsToFilterOptions` from `@repo/utils`. Do NOT include a "Todos" option — the component adds it via `allOptionLabel`:

```tsx
import { labelsToFilterOptions } from '@repo/utils';

export const STATUS_LABELS: Record<UserStatus, string> = {
  [userStatusEnumObject.active]: 'Activo',
  [userStatusEnumObject.inactive]: 'Inactivo',
};

// Derive filter options from labels — never define them manually
export const STATUS_FILTER_OPTIONS = labelsToFilterOptions(STATUS_LABELS);
```

If labels for a filter come from another module (roles, offices, etc.), import them from the corresponding catalog feature in `packages/features/<entity>Catalog/` (see `dev-form-engineering` for the catalog pattern).

Reference implementations for all components (`ConfigurableTableClientSide`, `SimpleTable`, `TableFilterSearch`, `TableFilterSimpleSelect`, `PrefetchBoundary`, `QueryResultGuard`, `PermissionGuard`, `AdminPageLayout`, `routeBuilders`) are in `stacks/nextjs/agent_docs/references/components.md`.

## Query (application/queries/)

Follows the same **3-layer standard** as all other queries — `queryFn` always returns `Safe<T>`, the throw belongs in the hook's `select`:

```tsx
// Layer 1 — queryOptions: passthrough Safe<T>, never throws
export function viewUsersListQueryOptions(params: ViewUsersInput) {
  return queryOptions({
    queryKey: viewUsersQueryKeys.list(params),
    queryFn: () => ViewUsersService.getUsers(params),
  });
}

// Layer 2 — hook: select throws → T + isError (React Query catches, does NOT trigger error.tsx)
export function useViewUsers(params: ViewUsersInput) {
  return useQuery({
    ...viewUsersListQueryOptions(params),
    select: (result) => {
      if (!result.success) throw new Error(result.error);
      return result.data;
    },
  });
}
```

## Permissions

Granular permissions, never a catch-all `entity:manage`:

```tsx
// Page
<AdminPageLayout permissions={MANAGE_USER_PERMISSIONS.view} ...>

// Create button
<PermissionGuard permissions={MANAGE_USER_PERMISSIONS.create}>
  <CreateUserButton />
</PermissionGuard>
```

Use the `MANAGE_<ENTITY>_PERMISSIONS` constant from the feature's `constants.ts` (see `dev-form-engineering`).

## Routes

Use `routeBuilders` from `shared/routes/`, never hardcoded strings:

```tsx
// In ActionsCell
<Link href={routeBuilders.users(userId)}>
```

## Anti-patterns

- Reading URL params in both server page AND client component (duplicate state)
- Debounce via external `useEffect` for search — use `TableFilterSearch` component
- `useCallback` with unstable dependencies (`setSearchParam` from `useUrlState`)
- Inline cell JSX in column definitions — extract to components in `ui/components/`
- Hardcoded route strings — use `routeBuilders`
- Including "Todos" in filter option arrays — `TableFilterSimpleSelect` handles it via `allOptionLabel`
- `entity:manage` catch-all permission — use granular `entity:read/create/update/delete`
- `export default` for pages/widgets — use named exports

## Utilities (`@repo/utils`)

- `parsePageParam(v)` — string → number, defaults to 1 for invalid
- `parseStatusParam(v)` — `'active'`→`true`, `'inactive'`→`false`, `undefined`→`undefined`
- `parseIdParam(v)` — string → number, returns 0 for invalid
- `getEnumObjectFromArray(arr)` — converts a `const` array to a key-value enum object for magic-string-free comparisons. Example: `getEnumObjectFromArray(['active', 'inactive'] as const)` → `{ active: 'active', inactive: 'inactive' }`
- `labelsToFilterOptions(record)` — converts a `Record<K, string>` label map to `{ value: K, label: string }[]` for `TableFilterSimpleSelect`. Never include the "all" option — the component adds it via `allOptionLabel`.

## Code Style

- `import * as React from 'react'` → use `React.useState`, `React.useCallback`, etc.
- Function declarations for components, not arrow functions
- Named exports: `export { ViewUsersPage }` not `export default`
- No magic strings — use enum objects from constants via `getEnumObjectFromArray`
- No `any` / `as any`

## Verification Checklist

- [ ] File structure follows `view<Entity>` convention
- [ ] Route page uses `PrefetchBoundary` with table data query (+ config query if using ConfigurableTableClientSide)
- [ ] Table component matches the decision from the Prerequisites Gate (ConfigurableTableClientSide or SimpleTable)
- [ ] Column definitions in separate file under `ui/utils/`
- [ ] Filter options derived via `labelsToFilterOptions` — no "Todos" in the array
- [ ] URL-driven filters via `TableFilterSimpleSelect` / `TableFilterSearch`
- [ ] Granular permissions (`entity:read`, not `entity:manage`)
- [ ] Routes use `routeBuilders`, no hardcoded strings
- [ ] No magic strings — enum objects via `getEnumObjectFromArray`
- [ ] Typecheck passes
- [ ] Lint passes
