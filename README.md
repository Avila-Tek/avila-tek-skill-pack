# Avila Tek Skill Pack

Skills de Claude Code para el ciclo completo de entrega de software — desde el primer doc de producto hasta código en producción.

> **TDD en este proyecto = Technical Design Document**, nunca Test-Driven Development.

---

## Los dos tracks

| Track | Quién lo usa | Qué produce | Guía detallada |
|---|---|---|---|
| **Planning** (skills 0–6) | Tech Lead / PM | Context, domain model, spec, TDD, epics, stories | [PLANNING.md](PLANNING.md) |
| **Dev** (20 skills + 7 comandos) | Developer | spec.md, plan.md, código, tests, ADRs | [DEV.md](DEV.md) |

El puente entre los dos tracks es el **story file**. El tech lead lo genera con el planning track; el dev lo toma y empieza a codear con el dev track.

---

## Ciclo completo

```
PLANNING TRACK (Tech Lead)                      DEV TRACK (Developer)
────────────────────────────────────            ────────────────────────────────────

Design Doc (Lark Wiki)
    │
/project-context-generator  →  project_context.md
/domain-model-generator     →  domain_model.md
/functional-spec-generator  →  Spec Funcional (Lark Wiki)
/technical-design-document  →  tdd.md  (opcional)
/epic-generator             →  epic.md
/story-generator            →  stories/E-XXX_S-YYY_slug/
                                   E-XXX_S-YYY_slug.md  ───────►  /spec  →  spec.md
/write-epics-and-hu-in-base →  Lark Base sync                     /plan  →  plan.md + todo.md
                                                                   /build →  código + tests
                                                                   /review → code review
```

---

## Estructura de docs en repos target

```
docs/
├── inputs/                         ← Design Doc, Intake Brief
├── project_context.md              ← skill-0
├── domain_model.md                 ← skill-1
├── epics/
│   └── E-XXX_slug/
│       ├── epic.md                 ← skill-4
│       ├── tdd.md                  ← skill-3 (opcional)
│       └── stories/
│           └── E-XXX_S-YYY_slug/  ← carpeta por HU (skill-5)
│               ├── E-XXX_S-YYY_slug.md  ← planning output
│               ├── spec.md              ← /spec
│               ├── plan.md             ← /plan
│               └── todo.md             ← /plan
└── adrs/
```

---

## Instalación rápida (Claude Code)

```bash
npm install -g @anthropic-ai/claude-code
```

Copiar las carpetas `skills/`, `commands/`, `agents/` y `references/` de este repo a `.claude/` en tu proyecto. Commitear `.claude/` al repo para que todo el equipo tenga las skills al clonar.

```bash
cd your-project
claude
```

Las skills se detectan automáticamente.

---

## Lark Setup

El comando `/write-epics-and-hu-in-base` requiere:

| Input | Descripción |
|---|---|
| API Key | Bearer token (`sk-xxxx...`) — obtener del project lead |
| Base ID | Identificador del Lark Base — está en la URL del Base |

Endpoint: `https://your-api.example.com/your/full/path`

---

## Principios de diseño

**Un artifact, un lugar.** El project context vive en el repo. La Spec Funcional vive en Lark Wiki. Los registros del backlog viven en Lark Base. Sin duplicación.

**El repo es la capa de ejecución.** Cuando empieza el desarrollo, todo lo necesario ya está en `docs/` — epics con ACs, stories con scope técnico y reglas de negocio, un project context con glosario y constraints.

**Las stories son el punto de handoff.** El planning track termina cuando el story file está commiteado. El dev track empieza leyéndolo. Los ACs de la story se convierten en los success criteria del spec. Nada se pierde en la traducción.

**AI asiste, humanos deciden.** Cada skill hace preguntas antes de generar. Nunca inventa reglas de negocio. El contenido final siempre es revisado y commiteado por el equipo.
