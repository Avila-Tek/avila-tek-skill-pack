# Page Orchestration Patterns — Next.js

Create and Update have **separate page components** (both server components).

## CreateEntityPage (server component)

```tsx
async function CreateEntityPage(): Promise<React.ReactElement> {
  return (
    <PrefetchBoundary queries={[officesQueryOptions(), rolesQueryOptions()]}>
      <Suspense fallback={<FormSkeleton />}>
        <ManageEntityForm formType={formTypeEnumObject.create} />
      </Suspense>
    </PrefetchBoundary>
  );
}
```

Pass only catalog `queryOptions()` for create pages — there is no entity to prefetch.

## UpdateEntityPage (server component)

```tsx
async function UpdateEntityPage({ id }: { id: number }): Promise<React.ReactElement> {
  return (
    <PrefetchBoundary queries={[
      getEntityQueryOptions(id),
      officesQueryOptions(),
      rolesQueryOptions(),
    ]}>
      <Suspense fallback={<FormSkeleton />}>
        <UpdateEntityFormLoader id={id} />
      </Suspense>
    </PrefetchBoundary>
  );
}
```

Pass the entity query + all catalog queries. If the entity ID is invalid, `QueryResultGuard` inside the loader handles it.

## UpdateEntityFormLoader (client component)

Loads entity data via `useSuspenseQuery`, guards with `QueryResultGuard`, then renders the form:

```tsx
'use client';

function UpdateEntityFormLoader({ id }: { id: number }): React.ReactElement {
  const { data: result } = useGetEntitySuspense(id);
  return (
    <QueryResultGuard
      result={result}
      title="Entidad no encontrada"
      redirectTo={routeBuilders.entities()}
    >
      {(entityData) => (
        <ManageEntityForm formType={formTypeEnumObject.update} data={entityData} />
      )}
    </QueryResultGuard>
  );
}
```

`QueryResultGuard` requires `redirectTo` — always provide a navigation escape hatch.

## Route pages (thin wiring)

```tsx
// app/(main)/entities/create/page.tsx
export default function Page() {
  return <CreateEntityPage />;
}

// app/(main)/entities/[id]/edit/page.tsx
import { parseIdParam } from '@repo/utils';

export default async function Page({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return <UpdateEntityPage id={parseIdParam(id)} />;
}
```

## Key rules

- Create and Update are separate server components — never collapse them into one
- `PrefetchBoundary` takes `queries: QueryObserverOptions[]` — pass `queryOptions()` return values, not fetch functions
- Update page prefetches both the entity AND all catalog queries
- `<Suspense fallback={<FormSkeleton />}>` wraps the client loader
- Route pages are thin — just parameter parsing and delegation to the feature page component
- `parseIdParam` from `@repo/utils` returns 0 for invalid — `QueryResultGuard` handles "not found"
- `parsePageParam` from `@repo/utils` defaults to 1 for invalid
- `parseStatusParam` from `@repo/utils` maps `'active'`→`true`, `'inactive'`→`false`
