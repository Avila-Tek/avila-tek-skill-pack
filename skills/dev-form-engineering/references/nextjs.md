# Form Engineering — Next.js

## Overview

Build production-quality forms that follow the project's `manage<Entity>` pattern — a single feature that handles create, update, and view modes via a `formType` prop. Forms use React Hook Form + Zod validation, `DetailSection` layout, self-contained data widgets, and confirmation modals before submission.

## File Structure

Every `manage<Entity>` feature follows this exact structure:

```
features/<entity>/manage<Entity>/
  domain/
    manage<Entity>.model.ts        # Domain model type + Manage<Entity>Data interface
    manage<Entity>.form.ts         # Zod schema + getDefaultValues(formType, data?)
    manage<Entity>.constants.ts    # Enums via getEnumObjectFromArray, STATUS_OPTIONS, STATUS_LABELS, PERMISSIONS
    manage<Entity>.logic.ts        # Pure UI helpers (getSubmitLabel, isFormDisabled, shouldShow*)
  application/
    mutations/
      useCreate<Entity>.mutation.ts
      useUpdate<Entity>.mutation.ts
    queries/
      useGet<Entity>.query.ts      # useGetEntity + useGetEntitySuspense + getEntityQueryOptions
    useCases/
      useCreate<Entity>.useCase.ts # Async use case: mutation + toast + navigation
      useUpdate<Entity>.useCase.ts # Async use case: mutation + toast
  infrastructure/
    manage<Entity>.service.ts      # httpClient calls returning Safe<Manage<Entity>Data>
    manage<Entity>.transform.ts    # toManageEntityData() + toCreateInput() + toUpdateInput()
    manage<Entity>.interfaces.ts   # ManageEntityApi interface
    index.ts                       # Re-export service instance
  ui/
    widgets/
      Manage<Entity>Form.tsx           # FormProvider + handleSubmit + modal orchestration
      Manage<Entity>FormContent.tsx    # Form fields with DetailSection layout
      Update<Entity>FormLoader.tsx     # Client component: useSuspenseQuery + QueryResultGuard
    components/
      Manage<Entity>Footer.tsx         # Uses FooterForm from @repo/ui
      Manage<Entity>ConfirmModal.tsx   # CreateAlertModal or SaveAlertModal based on formType
    pages/
      Create<Entity>Page.tsx           # Server component: PrefetchBoundary for create
      Update<Entity>Page.tsx           # Server component: PrefetchBoundary for edit (prefetches entity + widgets)
```

## View / Detail Mode

The `view` formType renders the form with all fields disabled and no action buttons — effectively a read-only detail page. This works when the detail view matches the form layout.

In some modules, the detail view is a completely separate page with its own layout and data. **Which approach to use depends on what the user specifies or what the Figma design shows** — never assume one or the other.

## FormType Pattern

FormType is a shared enum in `src/shared/types/formType.ts` — never in a feature-specific folder:

```typescript
import { getEnumObjectFromArray } from '@repo/utils';

const formTypes = ['view', 'create', 'update'] as const;
type FormType = (typeof formTypes)[number];
const formTypeEnumObject = getEnumObjectFromArray(formTypes);
```

Always compare with `formTypeEnumObject.create`, never `'create'` (no magic strings).

## Domain Logic (domain/logic.ts)

Pure helper functions that determine UI behavior based on formType. No side effects, no hooks:

```typescript
function getSubmitLabel(formType: FormType): string {
  if (formType === formTypeEnumObject.create) return 'Crear usuario';
  return 'Guardar cambios';
}

function isFormDisabled(formType: FormType): boolean {
  return formType === formTypeEnumObject.view;
}

function shouldShowPassword(formType: FormType): boolean {
  return formType === formTypeEnumObject.create;
}

function shouldShowDeactivateButton(formType: FormType): boolean {
  return formType === formTypeEnumObject.update;
}

function shouldShowSubmitButton(formType: FormType): boolean {
  return formType !== formTypeEnumObject.view;
}
```

## Permissions (domain/constants.ts)

Every `manage<Entity>` feature must define a `MANAGE_<ENTITY>_PERMISSIONS` constant that maps each formType to the required permission strings:

```typescript
export const MANAGE_USER_PERMISSIONS = {
  create: ['user:create'],
  update: ['user:update'],
  view: ['user:read'],
};
```

This constant is used by pages and guards to control access to each form mode.

## Form Schema (domain/form.ts)

Use Zod with `superRefine` for conditional validation per formType:

```typescript
const baseSchema = z.object({
  name: z.string().min(1, 'El nombre es obligatorio'),
  password: z.string().optional(),
});

export type TManageEntityForm = z.infer<typeof baseSchema>;
```

Use `superRefine` when you need conditional validation (e.g., password required only on create).

`getDefaultValues` returns the same shape regardless of formType, using optional `data` to populate:

```typescript
export function manageEntityDefaultValues(
  data?: ManageEntityData | null
): TManageEntityForm {
  return {
    name: data?.name ?? '',
    password: '',
  };
}
```

## Queries & Mutations (application/)

- **Queries**: export `useGet<Entity>()`, `useGet<Entity>Suspense()`, and `get<Entity>QueryOptions()` from a single file. Use `queryOptions()` from `@tanstack/react-query` as the base.
- **Mutations**: one file per mutation. Each returns a `useMutation` hook wrapping the service call.
- **Use Cases**: orchestrate mutation + toast + navigation. The Form widget calls the use case, never the mutation directly.

### Query — 3-layer structure

Every query file exports three things:

```typescript
// Layer 1 — queryOptions: always returns Safe<T>, never throws, no select
export function getEntityQueryOptions(id: number) {
  return queryOptions({
    queryKey: ['manage-entity', id],
    queryFn: () => ManageEntityService.getById(id),
    enabled: id > 0,
  });
}

// Layer 2a — useQuery: select throw → T + isError (does NOT trigger error.tsx)
export function useGetEntity(id: number) {
  return useQuery({
    ...getEntityQueryOptions(id),
    select: (result) => {
      if (!result.success) throw new Error(result.error);
      return result.data;
    },
  });
}

// Layer 2b — useSuspenseQuery: returns Safe<T> for QueryResultGuard
export function useGetEntitySuspense(id: number) {
  return useSuspenseQuery(getEntityQueryOptions(id));
}
```

Rules: the throw belongs in the hook's `select`, never in `queryFn`. Services are singletons — use `ManageEntityService.getById()`, never `new ManageEntityService()`.

### Mutation — passthrough only

```typescript
export function useCreateEntityMutation() {
  return useMutation({
    mutationFn: (form: TManageEntityForm) => ManageEntityService.create(form),
  });
}
```

No `onError`, no toast logic in mutations. Error handling goes in the use case layer.

### Cache key convention

```typescript
export const manageEntityQueryKeys = {
  all: ['manage-entity'] as const,
  detail: (id: number) => ['manage-entity', id] as const,
};
```

After mutation success, invalidate with `queryClient.invalidateQueries({ queryKey: manageEntityQueryKeys.all })`. Invalidating a parent key invalidates all children.

## Transforms (infrastructure/transform.ts)

Three transforms — one for API-to-domain, two for form-to-API:

```typescript
// API response → domain model
function toManageEntityData(dto: TEntityDto): ManageEntityData {
  return { id: dto.id, name: dto.name };
}

// Form → create API request
function toCreateInput(form: TManageEntityForm): TCreateEntityInput {
  return { name: form.name, password: form.password! };
}

// Form → update API request (no password)
function toUpdateInput(form: TManageEntityForm): TUpdateEntityInput {
  return { name: form.name };
}
```

## Use Cases (application/useCases/)

Use cases are async functions with dependency injection that handle: transform → mutate → toast → navigate. The Form widget calls the use case, never the mutation directly.

For the full pattern and wiring examples, see [nextjs-use-cases.md](./nextjs-use-cases.md).

## Form Widget (ui/widgets/Form.tsx)

The Form widget orchestrates validation, modal, and submission:

```typescript
function ManageEntityForm({ formType, data }: Props): React.ReactElement {
  const [modalOpen, setModalOpen] = React.useState(false);
  const methods = useForm<TManageEntityForm>({
    resolver: zodResolver(getManageEntityFormSchema(formType)),
    defaultValues: getDefaultValues(formType, data),
  });

  const mutation = formType === formTypeEnumObject.create
    ? useCreateEntity()
    : useUpdateEntity(data?.id);

  return (
    <FormProvider {...methods}>
      <form
        method="post"
        onSubmit={methods.handleSubmit(() => setModalOpen(true), onErrors)}
      >
        <ManageEntityFormContent formType={formType} />
        <ManageEntityFooter formType={formType} disabled={mutation.isPending} />
      </form>

      <ManageEntityConfirmModal
        formType={formType}
        open={modalOpen}
        onOpenChange={setModalOpen}
        onConfirm={handleConfirm}
        loading={mutation.isPending}
      />
    </FormProvider>
  );
}
```

Key rules:
- Always pass the form type as generic: `useForm<TManageEntityForm>()` — never cast with `as`
- `handleSubmit(() => setModalOpen(true), onErrors)` — validates first, opens modal only if valid
- The use case runs inside the modal's `onConfirm`, not on form submit
- Pass `loading={mutation.isPending}` to the modal to block buttons and close during submission

## FormContent Layout (ui/widgets/FormContent.tsx)

Use `DetailSection` + `DetailSection.Label` for section layout:

```typescript
<DetailSection>
  <DetailSection.Label size="lg">Datos personales</DetailSection.Label>
  <DetailSection.Content>
    <div className="grid grid-cols-2 gap-4">
      <FormField control={control} name="name" render={...} />
      <FormField control={control} name="email" render={...} />
    </div>
  </DetailSection.Content>
</DetailSection>
```

Rules:
- Always include `placeholder` on every input
- Error messages in Spanish
- Disable all fields when `isFormDisabled(formType)` returns true
- Conditionally show fields using logic helpers: `shouldShowPassword(formType)`

## Catalog Features (Self-Contained Data Widgets)

When a form needs a select or checkbox group that fetches data from **another module** (e.g., roles, offices, currencies), create a **catalog feature** in `packages/features/` with the naming convention `<entity>Catalog`:

```
packages/features/src/<entity>Catalog/
  application/queries/useGet<Entity>.query.ts   # useSuspenseQuery + queryOptions
  domain/<entity>Catalog.constants.ts
  domain/<entity>Catalog.model.ts
  infrastructure/                                # service + transform
  ui/widgets/<Entity>Select.tsx                  # Base: uncontrolled, fetches its own data
  ui/widgets/Form<Entity>Select.tsx              # Form wrapper: useController integration
```

### When to create a catalog feature
- A form field needs data from a different module (offices, roles, currencies, etc.)
- The same select/checkbox will be reused across multiple forms or features
- The widget needs its own API call and data transformation

### Form-integrated wrapper (for react-hook-form)

```typescript
function FormOfficeSelect({ control, name, ...props }: FormOfficeSelectProps) {
  const { field, fieldState } = useController({ control, name });
  return (
    <OfficeSelect
      value={String(field.value)}
      onValueChange={(v) => field.onChange(Number(v))}
      error={fieldState.error?.message}
      {...props}
    />
  );
}
```

The widget uses `useSuspenseQuery` — reads from cache instantly if prefetched via `PrefetchBoundary`, or suspends to the nearest `<Suspense>` fallback if not.

## Page Orchestration

Create and Update have **separate page components** (both server components). For full patterns including `PrefetchBoundary`, `UpdateEntityFormLoader`, and route page wiring, see [nextjs-page-patterns.md](./nextjs-page-patterns.md).

## Confirmation Modal Pattern

```typescript
function ManageEntityConfirmModal({ formType, open, onOpenChange, onConfirm, loading }) {
  if (formType === formTypeEnumObject.create) {
    return <CreateAlertModal ... loading={loading} />;
  }
  if (formType === formTypeEnumObject.update) {
    return <SaveAlertModal ... loading={loading} />;
  }
  return null;
}
```

The `loading` prop disables both buttons, hides the close button, and blocks `onOpenChange`.

## Footer Pattern

Use `FooterForm` from `@repo/ui`. Use logic helpers for labels and visibility:
- `getSubmitLabel(formType)` → "Crear \<entity\>" or "Guardar cambios"
- `shouldShowSubmitButton(formType)` → hidden in view mode
- `shouldShowDeactivateButton(formType)` → only in update mode

Pass `disabled={mutation.isPending}` to block the submit button during loading.

## Reusable UI Components

Reference implementations for all components below are in `stacks/nextjs/agent_docs/references/components.md`. Use those when the Prerequisites Gate finds a component missing from the project.

| Component | Category | Purpose |
|---|---|---|
| `AlertModal` / `CreateAlertModal` / `SaveAlertModal` | Form | Confirmation modals — `loading` prop blocks dismiss |
| `DetailSection` | Form | Section layout with label + content columns |
| `FooterForm` | Form | Sticky footer with primary/secondary action buttons |
| `FormSkeleton` | Form | Loading placeholder for `<Suspense>` fallback |
| `DniFormInput` | Form | Document identity input with type selector (V, E, J, G, P) |
| `PhoneFormInput` | Form | Phone input with country code selector |
| `QueryResultGuard` | Shared | Guards `Safe<T>` results, renders children only on success |
| `PrefetchBoundary` | Shared | Server component — prefetches queries before hydrating |
| `ErrorState` | Shared | Inline error page with required `redirectTo` escape hatch |
| `PermissionGuard` | Layout | Renders children only if user has required permissions |
| `AdminPageLayout` | Layout | Page shell with title, breadcrumbs, header action slot |
| `routeBuilders` | Utility | Factory functions for all app routes — never hardcode strings |

### Utilities (`@repo/utils`)
- `parseIdParam` — parses route `params.id` to number (returns 0 for invalid)
- `parsePageParam` — parses page query param to number (defaults to 1)
- `parseStatusParam` — parses status query param ('active'/'inactive') to boolean
- `getEnumObjectFromArray(arr)` — converts a `const` array into a key-value enum object so you never compare against magic strings. Example: `getEnumObjectFromArray(['active', 'inactive'] as const)` → `{ active: 'active', inactive: 'inactive' }`
- `safe(fn)` — wraps a promise or synchronous function and returns `Safe<T>` instead of throwing

## Post-Submit Behavior

- On **create** success: redirect to the entity list page via `router.push`
- On **update** success: show success toast, stay on page
- On **error**: show error toast with the message from the API response

## Strict Rules

1. **No magic strings** — all enums via `getEnumObjectFromArray`
2. **No `any`, no `as` assertions** — use proper generics; if you need `as`, the types are wrong
3. **Shared enums** (`formType`, `dniTypes`, `userStatus`) go in `shared/`, not feature folders
4. **Placeholders on all inputs**
5. **Error messages in Spanish**
6. **Separate transforms** for create vs update — never send irrelevant fields
7. **Validate before modal** — `handleSubmit` opens the modal, not the mutation
8. **Loading blocks everything** — `loading` prop on modal disables buttons + close
9. **Catalog features** — data-fetching widgets that consume other modules live in `packages/features/<entity>Catalog/`
10. **Use cases for submit** — mutations are never called directly from the Form widget
11. **Separate pages** — CreateEntityPage and UpdateEntityPage are separate server components
12. **FormLoader for edit** — Update pages use a client FormLoader with `useSuspenseQuery` + `QueryResultGuard`
13. **Logic helpers are pure** — `logic.ts` contains pure functions, no hooks, no side effects

## Verification Checklist

- [ ] FormType prop works for all modes (create, update, view)
- [ ] Zod schema with `superRefine` validates correctly per formType
- [ ] Default values are correct for each formType
- [ ] `MANAGE_<ENTITY>_PERMISSIONS` defined in `constants.ts`
- [ ] Transforms: `toManageEntityData`, `toCreateInput`, `toUpdateInput` are separate
- [ ] Use cases handle mutation + toast + navigation (not the Form widget)
- [ ] Modal opens only after successful validation
- [ ] Loading state blocks modal buttons and close
- [ ] Success redirects (create) or toasts (update)
- [ ] Error toast shows API message
- [ ] All inputs have placeholders
- [ ] All error messages are in Spanish
- [ ] No magic strings — all enum comparisons use enumObject
- [ ] Logic helpers are pure functions in `logic.ts`
- [ ] Catalog features in `packages/features/` for cross-module data widgets
- [ ] Catalog widgets use `useSuspenseQuery` with `Form*` wrappers for react-hook-form
- [ ] Create and Update pages are separate server components with `PrefetchBoundary`
- [ ] Update page uses FormLoader with `useSuspenseQuery` + `QueryResultGuard`
- [ ] Typecheck passes
- [ ] Lint passes
