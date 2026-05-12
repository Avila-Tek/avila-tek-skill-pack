---
name: dev-form-engineering
description: Use when building or modifying forms — create/edit/view flows with validation, modals, and data widgets. Use when the task involves a manage<Entity> feature, form schemas, form transforms, or confirmation modals.
---

# Form Engineering

## When to Use

- Building a new create/edit/view form for an entity
- Adding fields to an existing manage<Entity> feature
- Creating reusable form widgets (selects, checkboxes with built-in data fetching)
- Modifying form validation or submission flow
- Wiring confirmation modals to form actions

## Output Artifact

A complete `manage<Entity>` feature slice in the target project, following the active stack's conventions.

## Stack Activation Gate

Detect the active stack from the project's package files. State it explicitly: "Active stack: {name}".

| Stack | Detection signal | Reference file | Components reference |
|---|---|---|---|
| Next.js | `next` in `package.json` (not Angular, not React Native) | `references/nextjs.md` | `stacks/nextjs/agent_docs/references/components.md` |
| React Native | `react-native` in `package.json` | TODO — ask the user how forms are structured in their project | TODO |
| Angular | `angular.json` present or `@angular/core` in `package.json` | TODO — ask the user how forms are structured in their project | TODO |

Note both the **reference file path** and the **components reference path** for the active stack. Do not read them yet — the Prerequisites Gate controls when.

## Project Prerequisites Gate

**Run this immediately after stack detection, before reading the reference file or generating any code.**

**Scope:** The component roles, file patterns, and fallback search terms below apply to the **Next.js** stack. For stacks marked TODO (React Native, Angular): this gate does not apply until the user confirms how forms are structured in their project (via the Stack Activation Gate). Use that information to determine which components to look for instead.

**Step 1 — Find an existing `manage<Entity>` feature** in the project:

```
find . -name "Manage*Form.tsx" -not -path "*/node_modules/*" | head -3
```

- If found: read the Form widget file. Extract all component names from its imports — these are your Component Map values.
- If not found: grep for the names in the table below as fallback.

| Role | Fallback search terms |
|---|---|
| Confirmation modal (create) | `CreateAlertModal`, `ConfirmDialog`, `AlertModal` |
| Confirmation modal (update) | `SaveAlertModal`, `EditAlertModal`, `ConfirmDialog` |
| Form section layout | `DetailSection`, `FormSection`, `SectionLayout` |
| Sticky form footer | `FooterForm`, `FormFooter`, `StickyFooter` |
| Loading skeleton | `FormSkeleton`, `Skeleton` |
| Safe result guard | `QueryResultGuard`, `ResultGuard` |
| SSR prefetch wrapper (Next.js only) | `PrefetchBoundary`, `HydrationBoundary` |
| Route builders | `routeBuilders`, `routes`, `ROUTES` in `shared/routes/` |

**Step 2 — Output the Component Map** before doing anything else:

```
Component Map:
- Confirmation modal (create): <name or "not found">
- Confirmation modal (update): <name or "not found">
- Form section layout:         <name or "not found">
- Sticky form footer:          <name or "not found">
- Loading skeleton:            <name or "not found">
- Safe result guard:           <name or "not found">
- SSR prefetch wrapper:        <name or "not found">
- Route builders:              <found at path, or "not found">
```

**Step 3 — Resolve gaps.** For each "not found":
- For UI components: show the reference implementation from the **components reference** noted in the Stack Activation Gate. Ask: "Do you want me to create this component, or do you have an equivalent with a different name?"

In addition, for **every select or checkbox group** described in the feature spec:
- If the field's options come from another module (e.g., offices, roles, currencies) → a catalog feature will be required (see the active stack's reference file). Identify it now and flag it to the developer before continuing.

**STOP.** Output only the Component Map, gap questions, and any catalog feature flags above. Do not propose any implementation or generate any code until the user responds to every item.

**Step 3.5 — Confirm view/detail approach** before reading the reference file:
- Ask: "When a user navigates to an existing record — should the detail/view use the same form layout with fields disabled (`formType="view"`), or is it a completely separate page with a different design?"
  - **Same form layout (disabled)** → `formType="view"` on the existing `Manage<Entity>Form`
  - **Separate page** → a distinct page component outside this feature slice
- Wait for the answer before continuing.

**Step 4 — Read** the reference file identified in the Stack Activation Gate. That file may link to additional required documents — read all of them before generating any code. Generate code using the names from the Component Map — not the names in the reference file examples.

> If the active stack is marked TODO in the Stack Activation Gate, skip the Prerequisites Gate entirely. Ask the user to describe how forms are structured in their project, then derive the Component Map from their answer.

## Related Skills

- **dev-frontend-ui-engineering** — component architecture and design system adherence
- **dev-api-and-interface-design** — designing the backend endpoints the form consumes
- **dev-test-driven-development** — testing form logic, transforms, and validation
- **dev-table-feature** — for building the list/table page that the form links to. **If building both together:** implement this form feature first (`manage<Entity>`) — the table imports `MANAGE_<ENTITY>_PERMISSIONS` and `routeBuilders` from this feature.
- **dev-debugging-and-error-recovery** — when form submission fails or validation behaves unexpectedly
