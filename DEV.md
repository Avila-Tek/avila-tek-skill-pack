# Dev Track — Guía completa

> **Audiencia:** Developer
> **Objetivo:** Implementar una story de forma estructurada — spec → plan → código → review → ship.

---

## El dev track funciona con o sin planning

Si el Tech Lead ya corrió las planning skills (0-6), existe un story file en `docs/epics/`. El dev lo toma como punto de partida — es el insumo principal de `/spec`.

Si **no existe** un story file (proyecto sin planning track, repo externo, tarea nueva), el dev track funciona igual. `/spec` simplemente corre en modo estándar: hace preguntas de clarificación sobre objetivo, usuarios, stack, y constraints — y genera el spec desde cero.

---

## Los tres mecanismos de activación

### 1. Slash commands — invocación explícita

El dev escribe el comando directamente. Son el punto de entrada principal del workflow.

| Comando | Qué hace |
|---|---|
| `/spec` | Genera un spec antes de escribir código |
| `/plan` | Descompone el spec en tareas ordenadas |
| `/build` | Implementa la próxima tarea de forma incremental |
| `/review` | Code review de 5 ejes antes de mergear |
| `/test` | Workflow TDD: tests primero |
| `/ship` | Checklist de pre-lanzamiento a producción |
| `/code-simplify` | Simplifica código sin cambiar comportamiento |

### 2. Encadenamiento automático — transparente

Al correr un comando, Claude activa skills secundarias automáticamente según lo que ocurra. El dev no hace nada extra.

```
/build
  ├── siempre encadena:  dev-incremental-implementation
  ├── siempre encadena:  dev-test-driven-development
  ├── si falla algo:     dev-debugging-and-error-recovery
  ├── al commitear:      dev-git-workflow-and-versioning
  └── si es UI/browser:  dev-browser-testing-with-devtools

/review
  ├── si hay findings de seguridad:    dev-security-and-hardening
  └── si hay findings de performance:  dev-performance-optimization
```

Piénsalo como un médico generalista que deriva a especialistas. El dev habla con `/build`; `/build` enruta a `debugging`, `security`, o `devtools` según lo que aparezca.

### 3. Lenguaje natural — contextual

Todas las skills también se activan cuando el dev describe la situación:

```
"hay un memory leak en este componente"    → dev-performance-optimization
"quiero migrar de REST a GraphQL"          → dev-deprecation-and-migration
"escribe un ADR para esta decisión"        → dev-documentation-and-adrs
"diseña la API para este feature"          → dev-api-and-interface-design
"configura el pipeline de CI"              → dev-ci-cd-and-automation
"quiero explorar el approach antes"        → dev-idea-refine
```

---

## El workflow con story file (Story-Driven Mode)

Cuando el Tech Lead generó las stories con planning skill-5, el dev tiene este punto de partida:

```
docs/epics/E-002_auth/stories/E-002_S-001_sign_up/
└── E-002_S-001_sign_up.md    ← el dev empieza aquí
```

**Paso a paso:**

```
                        Story file
                            │
                     ┌──────▼───────┐
          /spec       │              │  Lee Block A (user story, ACs, ranked tasks)
     Story-Driven     │   spec.md    │  Lee Block B (technical scope, business rules)
         Mode         │              │  Solo pregunta sobre gaps que la story no cubre
                      └──────┬───────┘  Escribe spec.md en la misma carpeta
                             │
                      ┌──────▼───────┐
          /plan        │              │  Lee spec.md
                       │   plan.md    │  Descompone en tareas ordenadas (vertical slicing)
                       │   todo.md    │  Escribe plan.md + todo.md en la misma carpeta
                      └──────┬───────┘
                             │
                      ┌──────▼───────┐
          /build       │              │  Lee spec.md + plan.md
                       │   Código     │  Implementa tarea por tarea
                       │   Tests      │  Test → implement → verify → commit
                      └──────┬───────┘  Itera hasta completar todas las tareas
                             │
                      ┌──────▼───────┐
          /review      │              │  Verifica los ACs de la story
                       │   Review     │  Five-axis review (correctness, readability,
                      └──────────────┘  architecture, security, performance)
```

**Todos los artifacts de una story viven juntos:**

```
docs/epics/E-002_auth/stories/E-002_S-001_sign_up/
├── E-002_S-001_sign_up.md    ← story file (planning output — no modificar)
├── spec.md                   ← /spec
├── plan.md                   ← /plan
└── todo.md                   ← /plan
```

---

## Skills Reference

### Skills con comando

---

#### `dev-spec-driven-development` → `/spec`

Escribe un spec estructurado antes de cualquier código. El spec es la fuente de verdad compartida entre el dev y Claude — define qué se construye, por qué, y cómo sabremos que está listo.

**Con story file (Story-Driven Mode):**
El story file es el insumo principal. Las secciones se mapean al template del spec:

| Sección de la story | Sección del spec |
|---|---|
| Section 1 — User Story | Objective |
| Section 2 — Acceptance Criteria | Success Criteria |
| Section 3 — Ranked Tasks | base para Tasks |
| Section 4 — Technical Scope | Tech Stack + Boundaries |
| Section 5 — Business Rules | Boundaries (constraints) |
| Section 6 — Data Model | Project Structure (si hay cambios de schema) |

Claude solo pregunta sobre gaps que la story no cubre (ej: comandos de build, framework de tests, estilo de código).

**Sin story file (modo estándar):**
Claude pregunta sobre objetivo, usuarios, features, stack, constraints y boundaries. Genera el spec desde cero.

- **Output:** `spec.md` (en la carpeta de la story si existe, o donde el dev indique)

---

#### `dev-planning-and-task-breakdown` → `/plan`

Descompone el spec en tareas pequeñas y verificables con criterios de aceptación explícitos y orden de dependencias. Usa vertical slicing — cada tarea entrega un camino completo funcionando a través del stack, no una capa horizontal.

- **Input:** `spec.md` aprobado
- **Output:** `plan.md` (plan completo con fases y checkpoints) + `todo.md` (checklist plano de tareas)
- **Regla:** Ninguna tarea debe tocar más de ~5 archivos. Si lo hace, hay que descomponerla más.

---

#### `dev-incremental-implementation` → `/build`

Implementa en slices verticales delgados: una pieza, testearla, verificarla, commitearla, luego la siguiente. Cada incremento deja el sistema en estado funcional y testeable.

- **Siempre encadena:** `dev-test-driven-development` (en cada incremento)
- **Si falla:** activa `dev-debugging-and-error-recovery` automáticamente
- **Al commitear:** sigue `dev-git-workflow-and-versioning`
- **Regla:** Nunca más de ~100 líneas sin correr tests.

---

#### `dev-test-driven-development` → `/test` · auto-encadenado desde `/build`

Desarrollo guiado por tests: escribe el test que falla primero, luego implementa el mínimo código para pasarlo, luego refactoriza. Para bugs: patrón Prove-It — escribe el test que reproduce el bug antes de corregirlo.

- **Ciclo:** RED (test falla) → GREEN (implementación mínima) → REFACTOR

---

#### `dev-code-review-and-quality` → `/review`

Code review multi-eje: Correctness, Readability, Architecture, Security, Performance. En proyectos con story file, también verifica que cada Acceptance Criterion (Block A, Section 2) esté cubierto por tests e implementación.

- **Auto-encadena:** `dev-security-and-hardening` si hay findings de seguridad
- **Auto-encadena:** `dev-performance-optimization` si hay findings de performance
- **Output:** Review estructurado con findings etiquetados Critical / Important / Suggestion con referencias `file:line`

---

#### `dev-code-simplification` → `/code-simplify`

Refactoriza código para mayor claridad sin cambiar comportamiento. Targets: abstracción innecesaria, código más difícil de leer de lo que debería, complejidad acumulada.

- **Regla:** Los tests deben pasar antes y después. Nunca cambia comportamiento.

---

#### `dev-shipping-and-launch` → `/ship`

Checklist de pre-lanzamiento a producción: Code Quality (tests, build, lint), Security (audit, secrets, auth), Performance (Core Web Vitals, N+1, bundle), Accessibility, Infrastructure (env vars, migrations, monitoring), Documentation (README, ADRs, changelog).

- **Output:** Reporte de checks passing/failing + plan de rollback antes de proceder.

---

### Skills sin comando (automáticas o por lenguaje natural)

---

#### `dev-debugging-and-error-recovery`

Debugging sistemático de causa raíz. Diagnostica por qué fallan tests, se rompe el build, o el comportamiento no coincide con lo esperado. Enfoque estructurado: reproducir → aislar → identificar causa → corregir → verificar. Nunca adivinar y parchear.

- **Auto-activada:** Cuando `/build` encuentra un fallo
- **Lenguaje natural:** "este test está fallando", "el build se rompió", "arregla este error"

---

#### `dev-security-and-hardening`

Security review y hardening para código que maneja input de usuario, autenticación, almacenamiento de datos, o integraciones externas. Chequea: validación de input, manejo de secrets, auth/authz, SQL injection, XSS, vulnerabilidades en dependencias.

- **Auto-activada:** Desde `/review` cuando hay findings de seguridad
- **Lenguaje natural:** "security review", "¿es seguro este input?", "harden este endpoint"

---

#### `dev-performance-optimization`

Profiling y optimización de performance. Targets: N+1 queries, operaciones sin bounds, Core Web Vitals, tiempos de carga, memory leaks. Medir antes de optimizar — nunca adivinar.

- **Auto-activada:** Desde `/review` cuando hay findings de performance
- **Lenguaje natural:** "esto es lento", "optimiza esta query", "memory leak", "Core Web Vitals"

---

#### `dev-api-and-interface-design`

Diseño de APIs estables y fronteras de módulos. Cubre: diseño de endpoints REST y GraphQL, contratos de tipos entre módulos, fronteras frontend/backend, estrategias de versionado. Énfasis en estabilidad — una API mal diseñada es costosa de cambiar.

- **Lenguaje natural:** "diseña esta API", "cómo debería verse esta interfaz", "define el contrato"

---

#### `dev-frontend-ui-engineering`

Construcción de UIs de calidad production. Cubre: arquitectura de componentes, state management, layout, performance (re-renders, bundle size), accesibilidad básica, y la brecha entre UI generada por AI y UI de calidad production.

- **Lenguaje natural:** "construye esta UI", "este componente necesita trabajo", "frontend patterns"

---

#### `dev-documentation-and-adrs`

Escribe documentación y Architecture Decision Records (ADRs). Los ADRs registran *por qué* se tomó una decisión técnica — invaluables cuando el autor original se va o la pregunta resurge meses después.

- **Lenguaje natural:** "escribe un ADR para esta decisión", "documenta esto", "por qué elegimos X"
- **Output:** Archivos en `docs/adrs/`

---

#### `dev-git-workflow-and-versioning`

Estructura las prácticas de git: commits atómicos, naming de branches, resolución de conflictos, organización del trabajo en streams paralelos. Cada commit es una unidad lógica — no un checkpoint ni un save.

- **Auto-activada:** Desde `/build` al commitear
- **Lenguaje natural:** "cómo estructuro estos commits", "git workflow", "naming de branches"

---

#### `dev-ci-cd-and-automation`

Setup y modificación de pipelines CI/CD. Cubre: quality gates, test runners en CI, estrategias de deployment, automatización de build. Un pipeline de CI es la red de seguridad que atrapa regresiones antes de que lleguen a producción.

- **Lenguaje natural:** "configura CI", "automatiza el build", "configura el pipeline"

---

#### `dev-browser-testing-with-devtools`

Testing de comportamiento en el browser usando Chrome DevTools MCP. Inspecciona el DOM, captura errores de consola, analiza network requests, profila performance, verifica output visual con datos reales del runtime.

- **Auto-activada:** Desde `/build` cuando se construyen features de browser
- **Lenguaje natural:** "testea esto en el browser", "inspecciona el DOM", "revisa los network requests"

---

#### `dev-context-engineering`

Configura y optimiza el contexto que Claude tiene acceso en cada paso. Carga los archivos correctos, evita saturar el agente con contenido irrelevante, configura rules files para un proyecto. Mejor contexto = mejor output.

- **Lenguaje natural:** "qué contexto necesito para esto", "carga los archivos correctos", "configura el contexto"

---

#### `dev-deprecation-and-migration`

Gestiona la remoción de sistemas, APIs o features viejas y la migración a nuevas. Cubre: deprecation warnings, migration paths, ventanas de backwards compatibility, decidir cuándo dar de baja vs mantener.

- **Lenguaje natural:** "depreca esta API", "migra de X a Y", "cómo damos de baja este feature"

---

#### `dev-using-agent-skills`

Meta-skill: descubre qué skill aplica a la tarea actual y cómo invocarla. Usar al inicio de una sesión si no está claro qué skill usar, o cuando una tarea no encaja en una categoría obvia.

- **Lenguaje natural:** "qué skill uso para esto", "cómo uso las skills", "cuál es el approach correcto"

---

#### `dev-idea-refine`

Explorar y refinar ideas a través de pensamiento divergente y convergente estructurado antes de comprometerse con un spec. Usar cuando el problema no está completamente definido, cuando existen múltiples approaches, o cuando hay que pensar antes de construir.

- **Lenguaje natural:** "idea-refine", "ideate on this", "explora este approach antes de que nos comprometamos"

---

## Instalación

Copiar estas carpetas a `.claude/` en tu proyecto:

```
.claude/
├── skills/
│   ├── dev-spec-driven-development/
│   ├── dev-planning-and-task-breakdown/
│   ├── dev-incremental-implementation/
│   ├── dev-test-driven-development/
│   ├── dev-code-review-and-quality/
│   ├── dev-code-simplification/
│   ├── dev-shipping-and-launch/
│   ├── dev-debugging-and-error-recovery/
│   ├── dev-security-and-hardening/
│   ├── dev-performance-optimization/
│   ├── dev-api-and-interface-design/
│   ├── dev-frontend-ui-engineering/
│   ├── dev-documentation-and-adrs/
│   ├── dev-git-workflow-and-versioning/
│   ├── dev-ci-cd-and-automation/
│   ├── dev-browser-testing-with-devtools/
│   ├── dev-context-engineering/
│   ├── dev-deprecation-and-migration/
│   ├── dev-using-agent-skills/
│   └── dev-idea-refine/
├── commands/
│   ├── spec.md
│   ├── plan.md
│   ├── build.md
│   ├── review.md
│   ├── test.md
│   ├── ship.md
│   └── code-simplify.md
├── agents/
│   ├── code-reviewer.md
│   ├── security-auditor.md
│   └── test-engineer.md
└── references/
    ├── security-checklist.md
    ├── testing-checklist.md
    ├── performance-checklist.md
    └── accessibility-checklist.md
```

Si también usas el planning track, ver [PLANNING.md](PLANNING.md) para instalar esas skills.
