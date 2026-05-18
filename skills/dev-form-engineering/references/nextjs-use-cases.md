# Use Cases (application/useCases/) — Next.js

Use cases are async functions with dependency injection that handle the full submit flow: mutation + toast + navigation. The Form widget calls the use case, never the mutation directly.

## Pattern

```typescript
interface CreateEntityUseCaseDeps {
  mutateAsync: (input: TCreateEntityInput) => Promise<Safe<ManageEntityData>>;
  showToast: (options: ToastOptions) => void;
  router: AppRouterInstance;
}

async function createEntityUseCase(
  form: TManageEntityForm,
  deps: CreateEntityUseCaseDeps
): Promise<void> {
  const input = toCreateInput(form);
  const result = await deps.mutateAsync(input).catch(() => null);
  if (!result) {
    deps.showToast({ type: 'error', title: 'Ha ocurrido un error inesperado' });
    return;
  }
  if (!result.success) {
    deps.showToast({ type: 'error', title: result.error });
    return;
  }
  deps.showToast({ type: 'success', title: result.message ?? 'Entidad creada exitosamente' });
  deps.router.push(routeBuilders.entities());
}
```

## Wiring in the Form Widget

```typescript
const createUseCase = useCreateEntityUseCase(); // returns the async fn with deps injected
const updateUseCase = useUpdateEntityUseCase(entityId);

function handleConfirm(): void {
  const data = methods.getValues();
  if (formType === formTypeEnumObject.create) {
    createUseCase(data);
  } else {
    updateUseCase(data);
  }
}
```

## Key rules

- One use case per action (create, update)
- Use case handles the full flow: transform → mutate → toast → navigate
- Form widget never calls mutation directly
- Dependencies injected via hook wrapper, not imported globally
- Use `result.message` from the API with a hardcoded fallback string
- Create use case navigates away on success; update use case stays on page and shows a toast
