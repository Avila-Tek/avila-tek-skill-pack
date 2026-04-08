# Planning Track — Guía completa

> **Audiencia:** Tech Lead / PM
> **Objetivo:** Producir los artifacts de planificación — desde el Design Doc hasta las story files listas para que el dev las tome.

> **Nota:** "TDD" en este proyecto = **Technical Design Document**, nunca Test-Driven Development.

---

## El problema que resuelve

El conocimiento de planificación vive en cabezas, docs dispersos y threads de Slack perdidos. Cuando empieza el desarrollo, el contexto se ha degradado — los ingenieros no tienen el "por qué", los PMs no tienen trazabilidad, y el equipo pierde ciclos re-alineando. Este track produce artifacts estructurados y versionados que persisten en el repo y en Lark, manteniendo a todo el equipo alineado desde el día uno.

---

## Cómo invocar las skills de planning

Las planning skills se activan con **frases en lenguaje natural** en Claude Code. También tienen slash commands equivalentes.

```
"generate the project context"          →  /project-context-generator
"create the domain model"               →  /domain-model-generator
"generate a functional spec"            →  /functional-spec-generator
"create a TDD"                          →  /technical-design-document
"generate epics from the spec"          →  /epic-generator
"generate stories for E-002"            →  /story-generator
"sync E-002 E-003 to Lark"             →  /write-epics-and-hu-in-base
```

---

## Workflow completo

```
┌──────────────────────────────────────────────────────────────────────┐
│  INPUT: Design Doc o Intake Brief  (escrito manualmente por el equipo)│
│  Colocar en: docs/inputs/design_doc.pdf  o  intake_brief.docx        │
└────────────────────────┬─────────────────────────────────────────────┘
                         │
              ┌──────────▼───────────┐
              │  /project-context-   │  skill-0
              │  generator           │
              │                      │  Output: docs/project_context.md
              │  Contexto maestro    │  WHY + WHAT + glosario + reglas
              │  del proyecto.       │  de negocio + scope + constraints.
              │  Se crea una vez y   │  Todos los artifacts downstream
              │  se itera siempre.   │  lo referencian.
              └──────────┬───────────┘
                         │
              ┌──────────▼───────────┐
              │  /domain-model-      │  skill-1                ▲
              │  generator           │                          │
              │                      │  Output: docs/           │ Re-ejecutar
              │  Documento vivo.     │  domain_model.md         │ cuando surjan
              │  Correr temprano,    │  Entidades, estados,     │ nuevas entidades
              │  actualizar después  │  invariantes, eventos,   │ o reglas en
              │  de cada epic o TDD  │  schema DBML             │ cualquier etapa
              └──────────┬───────────┘                          │
                         │                                      │
              ┌──────────▼───────────┐                         │
              │  /functional-spec-   │  skill-2                │
              │  generator           │                          │
              │                      │  Output: Lark Wiki       │
              │  Una por épica.      │  (Markdown, en español)  │
              │  Puente entre Design │  Flujos paso a paso,     │
              │  Doc y el backlog    │  reglas, ACs, edge cases │
              └──────┬───────────────┘                         │
                     │            │                            │
           ┌─────────▼──────┐     └──────► ┌────────────────┐ │
           │  /epic-         │  skill-4     │  /technical-   │─┘
           │  generator      │              │  design-       │  skill-3
           │                 │◄─────────────│  document      │  (opcional)
           │  Output:        │  el TDD      │                │
           │  docs/epics/    │  enriquece   │  Output:       │
           │  E-XXX_slug/    │  los epics   │  docs/epics/   │
           │  epic.md        │              │  E-XXX/tdd.md  │
           └─────────┬───────┘              └────────────────┘
                     │
           ┌─────────▼────────────┐
           │  /story-generator    │  skill-5
           │                      │
           │  Una carpeta por HU. │  Output:
           │  La carpeta es el    │  docs/epics/E-XXX_slug/
           │  workspace del dev.  │  stories/E-XXX_S-YYY_slug/
           │                      │  E-XXX_S-YYY_slug.md
           │                      │
           │  ← HANDOFF al dev →  │  El dev toma esto y corre /spec
           └─────────┬────────────┘
                     │
           ┌─────────▼────────────┐
           │  /write-epics-and-   │  skill-6
           │  hu-in-base          │
           │                      │  Lee .md files → traduce a español
           │  Mantiene Lark Base  │  → POST a Avila Tools API
           │  sincronizado con    │  Requiere: Epic IDs + API Key + Base ID
           │  el repo             │  Soporta upsert. Muestra preview antes
           └──────────────────────┘  de enviar.
```

---

## Skills Reference

### `/project-context-generator` — skill-0

Genera o actualiza `docs/project_context.md` desde un Design Doc o Intake Brief. Es el **documento maestro** del proyecto — todo artifact downstream lo referencia.

**Lo que captura:** north star, glosario de dominio, business goals, métricas de éxito, roles y permisos, scope (in/out), business rules, política de datos, constraints de entrega.

| | |
|---|---|
| **Input** | `docs/inputs/design_doc.pdf` o `intake_brief.docx` |
| **Output** | `docs/project_context.md` |
| **Modos** | Create (proyecto nuevo) · Update (itera existente, agrega al Change Log) |
| **Idioma** | Siempre inglés |
| **Límite** | Máx 500 líneas — denso y de alta señal |
| **Regla clave** | Solo WHY y WHAT, nunca HOW. Sin detalles de implementación. |

---

### `/domain-model-generator` — skill-1

Genera o itera `docs/domain_model.md` — entidades, invariantes, ciclos de vida, eventos de dominio, workflows, y el schema DBML de la base de datos.

Es un **documento vivo**: correrlo temprano para establecer vocabulario compartido, y volver a correrlo cuando specs, TDDs o epics revelen nuevas entidades o reglas. Cada corrida es aditiva — nunca reescribe historia.

| | |
|---|---|
| **Input** | `docs/project_context.md` + Q&A interactivo (una pregunta a la vez) |
| **Output** | `docs/domain_model.md` |
| **Idioma** | Siempre inglés |
| **Regla clave** | Nunca inventa hechos — usa `[PENDING]` para gaps. Usa términos exactos del glosario. |

---

### `/functional-spec-generator` — skill-2

Genera una Spec Funcional completa en español desde un Design Doc para una épica específica. Es el puente entre el Design Doc y el backlog de ingeniería.

**Lo que documenta:** actores, flujos paso a paso, reglas de negocio, integraciones, edge cases, criterios de aceptación, preguntas abiertas.

| | |
|---|---|
| **Input** | Design Doc + nombre de la épica |
| **Output** | Spec Funcional `.md` para subir a Lark Wiki |
| **Cadencia** | Una por épica, antes de generar el `epic.md` |
| **Idioma** | Siempre español (sin importar el idioma del source) |

---

### `/technical-design-document` — skill-3 *(opcional)*

Genera un Technical Design Document — el blueprint técnico de una épica. Aplicar en proyectos con alta complejidad técnica o cuando la Spec Funcional no es suficiente para que el equipo tome decisiones de arquitectura.

**Lo que cubre:** problem statement, arquitectura de solución (diagramas ASCII), diseño de componentes, data model anclado al domain model, API endpoints, seguridad, integraciones.

| | |
|---|---|
| **Input** | Spec Funcional + `docs/domain_model.md` + `docs/project_context.md` |
| **Output** | `docs/epics/E-XXX_slug/tdd.md` |
| **Idioma** | Siempre inglés |
| **Nota** | Pregunta primero: ¿TDD antes o después de las epics? — cambia cómo se populan los Epic IDs |

---

### `/epic-generator` — skill-4

Genera documentos de Épica individuales desde una Spec Funcional. Cada épica es un documento standalone para sprint planning y generación de stories. Si existe un TDD, se usa automáticamente para enriquecer con detalles técnicos.

**Cada epic.md contiene:** objetivo, scope (in/out), happy path (flujo ASCII, máx 8 pasos), KPIs, user stories (3–8 por épica con ACs).

| | |
|---|---|
| **Input** | Spec Funcional (requerido) + TDD (opcional) |
| **Output** | `docs/epics/E-XXX_slug/epic.md` por épica |
| **Límite** | 150–200 líneas por épica |
| **Regla clave** | Usa `[TO BE DEFINED]` para gaps — nunca inventa contenido |

---

### `/story-generator` — skill-5

Genera todas las User Stories (HUs) de una épica. Antes de generar, resuelve todas las preguntas abiertas con el operador — el documento final no tiene ambigüedades.

**Cada story tiene dos bloques:**
- **Block A** *(leer antes de estimar)*: user story, acceptance criteria, ranked tasks (Must / Important / Optional / Nice to have)
- **Block B** *(consultar durante implementación)*: scope técnico, reglas de negocio, data model, telemetría, testing guidance

**Estructura de archivos — cada story va en su propia carpeta:**

```
docs/epics/E-XXX_slug/stories/
└── E-XXX_S-YYY_slug/               ← carpeta de la story (crear)
    └── E-XXX_S-YYY_slug.md         ← story file (mismo nombre que la carpeta)
```

La carpeta es el workspace del dev. El dev agregará `spec.md`, `plan.md` y `todo.md` al implementar.

| | |
|---|---|
| **Input** | `epic.md` + Spec Funcional (si existe) + `tdd.md` (si existe) |
| **Output** | `docs/epics/E-XXX_slug/stories/E-XXX_S-YYY_slug/E-XXX_S-YYY_slug.md` |

Una vez commiteada, el dev toma este archivo y corre `/spec` → `/plan` → `/build`. Ver [DEV.md](DEV.md).

---

### `/write-epics-and-hu-in-base` — skill-6

Lee los `.md` files de epics y stories del repo, traduce los campos de contenido al español, y los pushea a Lark Base via la Avila Tools API. Soporta upsert — registros existentes se actualizan, nuevos se crean.

| | |
|---|---|
| **Requiere** | Epic IDs (ej: `E-002 E-003`) + API Key + Base ID |
| **Output** | Epics y stories sincronizados en Lark Base |
| **Regla clave** | Muestra preview y espera confirmación antes del POST. Nunca inventa valores. |

**Endpoint:** `https://avila-tools-api-qa.onrender.com/api/v1/projects/records`

---

## Artifact Map

| Artifact | Dónde vive | Creado por |
|---|---|---|
| Design Doc | Lark Wiki | Equipo (manual) |
| `project_context.md` | `docs/` | skill-0 |
| `domain_model.md` | `docs/` | skill-1 |
| Spec Funcional | Lark Wiki | skill-2 |
| `tdd.md` | `docs/epics/E-XXX/` | skill-3 |
| `epic.md` | `docs/epics/E-XXX/` | skill-4 |
| Story folder + `.md` | `docs/epics/E-XXX/stories/E-XXX_S-YYY_slug/` | skill-5 |
| Lark Base records | Lark Base | skill-6 |

---

## Estructura de docs en el repo target

```
docs/
├── inputs/
│   ├── design_doc.pdf
│   └── intake_brief.docx
├── project_context.md
├── domain_model.md
├── epics/
│   └── E-XXX_slug/
│       ├── epic.md
│       ├── tdd.md              ← opcional
│       └── stories/
│           └── E-XXX_S-YYY_slug/
│               ├── E-XXX_S-YYY_slug.md   ← planning output (esta skill)
│               ├── spec.md               ← dev output (/spec)
│               ├── plan.md               ← dev output (/plan)
│               └── todo.md               ← dev output (/plan)
└── adrs/
```

---

## Instalación

Copiar estas carpetas a `.claude/` en tu proyecto:

```
.claude/
├── skills/
│   ├── planning-0-project-context-generator/
│   ├── planning-1-domain-model-generator/
│   ├── planning-2-functional-spec-generator/
│   ├── planning-3-technical-design-document/
│   ├── planning-4-epic-generator/
│   ├── planning-5-story-generator/
│   └── planning-6-write-epics-and-hu-in-base/
└── commands/
    ├── project-context-generator.md
    ├── domain-model-generator.md
    ├── functional-spec-generator.md
    ├── technical-design-document.md
    ├── epic-generator.md
    ├── story-generator.md
    └── write-epics-and-hu-in-base.md
```

Commitear `.claude/` al repo para que todo el equipo tenga las skills al clonar.
