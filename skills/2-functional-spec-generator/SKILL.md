---
name: functional-spec-generator
description: >
  Generates a complete Functional Spec document (Spec Funcional) from a design document (PDF, DOCX, or MD).
  Use this skill whenever the user wants to create, draft, or generate a functional specification,
  functional spec, spec funcional, or "spec" from a design doc, design document, epic design, wireframe
  description, or any written product/feature description. Also trigger when the user says things like
  "generate the spec from this doc", "create a functional spec", "write the spec for this feature",
  "turn this design into a spec", "dame el spec funcional", "genera el spec de esta épica", or any
  variation. If the user uploads a PDF, DOCX, or MD file alongside a request to produce a spec or
  functional document, always use this skill.
---

# Functional Spec Generator

Generates a complete **Spec Funcional** document from a written design document (PDF, DOCX, or MD).
Audience: mixed stakeholders (developers, QA, product managers).
Output format: flexible — infer from user context (default: `.docx`; also supports `.md`).
Output language: **always Spanish**, regardless of the input document language.

---

## Step 1 — Read the Input Design Doc

Locate the source document using this priority order:
1. `docs/inputs/` in the project repo (preferred for Claude Code — e.g. `docs/inputs/design_doc.pdf`)
2. `/mnt/user-data/uploads/` (Claude Desktop uploads)
3. A path explicitly provided by the user

If no path is specified, check `docs/inputs/` first before asking the user.

Determine the file type from the path and extract text accordingly.

**PDF:**
```python
from pypdf import PdfReader
r = PdfReader("docs/inputs/<file>.pdf")
text = "\n".join(page.extract_text() for page in r.pages)
print(text)
```

**DOCX:**
```bash
pandoc docs/inputs/<file>.docx -t markdown
```

**MD / TXT:**
```bash
cat docs/inputs/<file>.md
```

Always read the full document before generating anything.

---

## Step 1.5 — Check for Figma Input (optional)

If the tool `mcp__plugin_figma_figma__get_design_context` is available in this session, ask the user: "¿Tienes un link de Figma del diseño? Si lo tienes, puedo leerlo y usarlo como input adicional." If the user provides a Figma URL, read the design using that tool and incorporate it as supplementary input alongside the design doc. If not available or the user declines, skip this step.

---

## Step 2 — Identify the Target Epic

The design doc may describe multiple epics. If the user named a specific one, extract only that epic's content. If no epic was specified and there are multiple, ask the user which one to spec.

---

## Step 3 — Analyze and Map Content

Before writing, identify from the design doc:
- The epic name and goal (in 2–4 bullet points, not a paragraph)
- Actors: users, internal systems, third-party services
- Flows described (explicit or implicit) — each becomes a named flow in section 4
- Business and functional rules
- Integrations and their data contracts
- States of key objects (lifecycle)
- Edge cases — named and grouped
- Data fields and validations per flow
- Any genuinely open questions (only include if actually unresolved in the doc)

---

## Step 4 — Generate the Spec

Populate ALL 10 sections using the canonical template below. The structure is **mandatory and fixed** — never add, remove, or rename sections. Write the output **always in Spanish**.

### No-invention rule (mandatory, no exceptions)

**Every piece of content in the spec must come directly and explicitly from the design doc. Never invent, infer, assume, or extrapolate anything not written in the doc.**

- Never add actors, rules, flows, integrations, errors, KPIs, or criteria that are not explicitly described in the design doc.
- Never complete or elaborate a concept beyond what the doc states.
- Never use general knowledge or best practices to fill gaps.
- Never add examples that are not in the doc.
- When information for a field is missing: use `[PENDIENTE: descripción de qué falta]`. This is the only acceptable way to handle gaps.
- When in doubt about whether something is in the doc: do not include it — use `[PENDIENTE]`.

### Formatting rules (mandatory)

- Every bullet in sections 1, 2, 3, 6, 7, 8, 9, 10 uses **bold_prefix + text** format: the field label is bold, followed by the content. Example: `• Objetivo de la épica: [contenido]` where "Objetivo de la épica:" is bold.
- Section 5 flows follow the exact sub-structure: Entrada, Proceso del Sistema, Bloqueos Funcionales, Integración, Resultado final — then Detalles with: Reglas funcionales, Casos bordes, Datos y validaciones del flujo, Estados funcionales.
- Keep language functional. Avoid unnecessary technical implementation details unless they are explicit functional requirements in the design doc.
- If information for a field is missing: use `[PENDIENTE: descripción de qué falta]` — never skip or leave blank.
- **Anti-repetición:** Nunca repetir información entre secciones. Si un dato ya aparece en flujos (sección 5), no repetirlo en reglas de negocio (sección 4) ni en criterios de aceptación (sección 9). Cada dato vive en una sola sección.
- **Compacidad:** Preferir bullets concisos sobre párrafos. Si un punto puede decirse en una línea, no usar dos.

---

## Canonical Spec Template (10 sections — MANDATORY)

The template below defines the exact output structure. All section names and field labels are in Spanish and must be reproduced exactly as written here.

### Header

```
Spec Funcional: [Nombre de la Épica]
| Proyecto | Responsable | Editores | Estado |
```

---

### 1. Resumen ejecutivo y objetivo

Máximo 3 bullets cortos. Sin párrafo introductorio. Cada bullet máximo 1 línea.

- **Objetivo de la épica:** [Propósito principal y qué problema resuelve para el usuario].
- **Dependencias críticas:** [Sistemas, APIs o módulos previos necesarios para este desarrollo].
- **Métricas de éxito (KPIs):** [Indicadores cuantificables de negocio o producto impactados].

---

### 2. Alcance (In & Out)

- **Incluido en la épica:** [Listado de funcionalidades incluidas].
- **Fuera de alcance de la épica:** [Listado de exclusiones explícitas para evitar ambigüedades].

---

### 3. Matriz de actores y roles

- **Usuarios finales:** [Quién usa la funcionalidad, ej: Cliente, Admin, Soporte].
- **Servicios de terceros / integraciones:** [APIs o proveedores externos que intervienen — solo si aplican al proyecto, ej: Google Auth, Stripe, Maps]. Si no aplica: omitir este bullet.

---

### 4. Reglas de negocio aplicables a la épica

Reglas globales que rigen toda la funcionalidad, independientemente del flujo específico. **Solo incluir reglas que impactan directamente la programación o la definición de épicas/HUs.** Excluir cualquier regla que ya esté cubierta en criterios de aceptación (sección 9). Si una regla describe un comportamiento verificable en QA, pertenece a la sección 9, no aquí.

- [Regla 1]
- [Regla 2]
- [Regla N]

---

### 5. Definición de Flujos (Step-by-Step)

Repeat for each flow (N flows total).

**Flujo [A]: [Nombre del Flujo]**
- **Entrada:** [Punto de inicio y acción que dispara el flujo].
- **Proceso del Sistema:** [Pasos, validaciones automáticas, lógica de fondo y comunicaciones enviadas].
- **Bloqueos Funcionales:** [Pasos obligatorios que impiden avanzar si no se completan].
- **Integración:** [Momento en que se consulta o envía información a servicios externos].
- **Resultado final:** [Estado final del usuario y del sistema al terminar con éxito].

**Detalles del Flujo [A]:**
- **Reglas funcionales:** [Lógica específica que aplica solo a este camino].
- **Casos bordes:** [Escenarios atípicos: datos duplicados, errores de red, registros existentes].
- **Datos y validaciones del flujo:** [Campos mínimos, formatos requeridos, etc].
- **Estados funcionales:** [Ciclo de vida de los objetos, ej: Pendiente → Activo].

---

### 6. Integraciones externas

Solo listar integraciones explícitamente mencionadas en el design doc. No inventar endpoints, parámetros ni comportamientos no descritos. Repeat for each integration (N integrations total).

**[Nombre del Servicio/API]**
- **Para qué se usa:** [En qué flujos interviene y con qué propósito].
- **Documentación:** [URL o referencia provista en el design doc. Si no fue provista: "buscar documentación oficial del proveedor antes del desarrollo"].

---

### 7. Reglas de experiencia generales

- **[Regla 1]:** [Descripción].
- **[Regla 2]:** [Descripción].
- **[Regla N]:** [Descripción].

---

### 8. Errores esperados

- **[Error A]:** [Causa y mensaje/acción propuesta].
- **[Error B]:** [Causa y mensaje/acción propuesta].

---

### 9. Criterios de aceptación

- **[Criterio 1]:** [Condición sine qua non para el paso a producción].
- **[Criterio 2]:** [Comportamiento esperado en escenarios críticos].
- **[Criterio N]:** [Validación de flujos de extremo a extremo].

---

### 10. Preguntas abiertas

- **[Duda 1]:** [Temas técnicos o de negocio pendientes de definición].
- **[Duda 2]:** [Limitaciones de terceros por confirmar].
- If there are no genuine open questions: write a single bullet `N/A`.

---

## Step 5 — Resolve Open Questions Interactively

Before producing any output file, review the draft internally and identify all genuinely open questions (section 10 of the draft). If there are any:

1. List them to the user in the conversation — numbered, concise.
2. Wait for the user's responses.
3. Incorporate the answers into the draft before writing the file.
4. If there are no open questions, proceed directly to Step 6.

Never generate the output file while open questions remain unresolved.

---

## Step 6 — Produce the Output File

### Default: DOCX output
Read `/mnt/skills/public/docx/SKILL.md` before generating.
Install if needed: `npm install -g docx`

Key formatting rules:
- **Title** (large, bold): `Spec Funcional: [Epic Name]`
- **Header table**: Proyecto, Responsable, Editores, Estado
- **Section headers** (H1): numbered exactly as the template, e.g. `1. Resumen ejecutivo y objetivo`
- **Sub-headers** (H2): flow names (e.g. `Flujo A: Registro manual`), integration names
- **Bullets**: always `bold_prefix + text` — use `bBold(label, text)` pattern. Always use `LevelFormat.BULLET`, never unicode bullets.
- **Page size**: A4
- Validate: `python scripts/office/validate.py`
- Output: `/mnt/user-data/outputs/spec_funcional_<epic_name>.docx`

### Markdown output (when user requests .md)
Output to `/mnt/user-data/outputs/spec_funcional_<epic_name>.md`

---

## Step 7 — Present and Offer Follow-up

1. Call `present_files` with the output path.
2. One sentence: epic name + number of flows documented.
3. Offer: "¿Quieres ajustar alguna sección?"

---

## Quality Checklist

- [ ] All 10 sections present with exact names from the template
- [ ] Every bullet uses bold_prefix + text format
- [ ] Section 1 has exactly 3 bullets — no intro paragraph
- [ ] Section 3 has no "Sistemas internos" bullet
- [ ] Section 5 flows each have: Entrada, Proceso del Sistema, Bloqueos Funcionales, Integración, Resultado final + Detalles (Reglas funcionales, Casos bordes, Datos y validaciones, Estados funcionales)
- [ ] Section 6 integrations only list what's explicitly in the design doc — no invented API details
- [ ] No information repeated across sections 4, 5, and 9
- [ ] Open questions were presented interactively before generating the file
- [ ] Missing info uses `[PENDIENTE: ...]` — never skipped
- [ ] Output is written in Spanish regardless of the input language

---

## Reference

Template source: `/mnt/skills/functional-spec-generator/references/template.md`
For DOCX creation: `/mnt/skills/public/docx/SKILL.md`
For reading input files: `/mnt/skills/public/file-reading/SKILL.md`

## Final reminder before generating

Before writing a single word of content: ask yourself for each field — **"Is this explicitly in the design doc?"** If the answer is not a clear yes, write `[PENDIENTE]` instead.
