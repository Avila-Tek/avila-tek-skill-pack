---
name: lark-backlog-sync
description: >
  Sync epics and user stories from the local repository to a Lark Base via the Avila Tools API.
  Use this skill whenever the user wants to push backlog items (epics, stories, HUs) to Lark,
  sync the repo backlog to Lark Base, or load epics into the project management base.
  Trigger phrases include: "sync to Lark", "push epic to Lark", "load backlog to Lark Base",
  "carga la épica al Lark", "sincroniza el backlog", "push E-002 to Lark".
  This skill reads .md files from the local repo (it does NOT clone anything),
  parses them, translates content to Spanish, and POSTs to the Lark Base endpoint.
---

# Lark Backlog Sync

Sync epic and story `.md` files from the local repo to a Lark Base. The skill reads markdown
files that are already in the working repository, parses their structured sections, translates
content fields to Spanish, and sends them to the Avila Tools API endpoint which upserts records
into a Lark Base.

## Prerequisites

This skill runs inside the repository using Claude Code. You are already in the repo — never
clone anything. The user must provide three inputs before execution can begin:

| Input       | Description                              | Example                    |
|-------------|------------------------------------------|----------------------------|
| Epic IDs    | One or more epic IDs separated by spaces | `E-002` or `E-002 E-003`  |
| API Key     | Bearer token for the Avila Tools API     | `sk-xxxx...`               |
| Base ID     | Target Lark Base identifier              | `base_abc123`              |

If any of these are missing, ask the user before proceeding.

## Repository structure

The repo follows this folder convention:

```
epics/
├── E-000_tech_platform/
│   ├── epic.md
│   └── stories/
│       ├── E-000_S-001_some_story.md
│       └── ...
├── E-002_authentication-and-registration-foundation/
│   ├── epic.md
│   └── stories/
│       ├── E-002_S-001_sign_up_with_email_password.md
│       ├── E-002_S-002_social_sign_up.md
│       └── ...
└── ...
```

Each epic folder contains an `epic.md` and a `stories/` subfolder with one `.md` per user story.

## Execution steps

### Step 1 — Locate epic folders

For each Epic ID the user provided, find the matching folder:

```bash
ls -d epics/E-002_*/ epics/E-003_*/  # one glob per ID
```

If a folder is not found for a given ID, warn the user but continue with the ones that exist.
If none are found, stop and report the error.

### Step 2 — Parse epic.md

Read `epic.md` inside each located folder. Extract fields from markdown sections:

| Source section in epic.md                    | JSON field             | Extraction rule                                                                                    |
|----------------------------------------------|------------------------|----------------------------------------------------------------------------------------------------|
| Folder name `E-XXX_slug/`                    | `id`                   | Extract `E-\d{3}` regex from the folder name                                                      |
| `# Epic E-XXX — Name (vX.X)`                | `name`                 | Text between ` — ` and ` (v` (or end of line if no version)                                       |
| `## 0) Snapshot` → `**Status:**`             | `status`               | Value after `**Status:**`                                                                          |
| `## 1) Objective (business outcome)`         | `description`          | Full paragraph content of the section                                                              |
| `## 11) Epic-level acceptance criteria`      | `acceptanceCriteria`   | Full content of the section (bullet list)                                                          |
| `## 9) Open Questions`                       | `questions`            | Full content of the section. If the section doesn't exist or is empty, use `""`                    |

**Variable fields:** Epics may also contain `priority`, `readiness`, or `tShirtSize`. Look for
them in `## 0) Snapshot` as bold-label fields (e.g., `**Priority:**`, `**Readiness:**`,
`**T-Shirt Size:**`). If found, include them in the JSON with these exact field names:

- `**Priority:**` → `priority` (integer)
- `**Readiness:**` → `readiness` (string, e.g., "KK", "KU")
- `**T-Shirt Size:**` → `tShirtSize` (string, e.g., "Large", "Extra Large")

If a variable field is not found in the `.md`, omit it entirely from the JSON — do NOT invent
default values.

### Step 3 — Parse story .md files

Read every `.md` file inside `stories/` for each epic. Extract fields from markdown sections:

| Source section in story .md                  | JSON field             | Extraction rule                                                                                    |
|----------------------------------------------|------------------------|----------------------------------------------------------------------------------------------------|
| Filename `E-XXX_S-YYY_slug.md`              | `id`                   | Extract `E-\d{3}_S-\d{3}` regex from the filename                                                 |
| `# Story E-XXX_S-YYY — Name`               | `name`                 | Text after ` — ` to end of line                                                                    |
| Snapshot table row `**Epic**`               | `epic`                 | Extract `E-\d{3}` from the Epic row value                                                         |
| Snapshot table row `**Status**`             | `status`               | Value in the Status row                                                                            |
| `## 1) User story` or `## User story`        | `description`          | Full paragraph content of the section                                                              |
| `## Acceptance criteria` (any number prefix) | `acceptanceCriteria`   | Full list content — match by section name, ignore leading `## N)` number                          |
| `## Open questions` (any number prefix)      | `questions`            | Full content. Match by name, ignore leading number. If section absent or empty, use `""`          |

**Variable fields:** Stories may also contain `priority`, `readiness`, `tShirtSize`, or
`dependencies`. Apply the same logic as epics:

- `**Priority:**` → `priority` (integer)
- `**Readiness:**` → `readiness` (string)
- `**T-Shirt Size:**` → `tShirtSize` (string)
- `**Dependencies:**` or a `## Dependencies` section → `dependencies` (array of story ID strings, e.g., `["E-002_S-003"]`)

If a variable field is not found, omit it from the JSON.

### Step 4 — Translate to Spanish

Translate the following fields to Spanish while preserving the original structure (numbering,
bullet points, line breaks, code references, proper nouns, technical terms):

- `name`
- `description`
- `acceptanceCriteria`
- `questions`

**Fields that must NOT be translated:** `id`, `epic`, `status`, `priority`, `readiness`,
`tShirtSize`, `dependencies`.

Translation guidelines:
- Use Latin American Spanish conventions.
- Keep technical terms in English where standard (e.g., "monorepo", "endpoint", "JWT",
  "reCAPTCHA", "Argon2id", "OAuth", "TOTP").
- Translate Open Question metadata labels:
  - "Owner" → "Responsable"
  - "Due stage" → "Etapa"
  - "Status" → "Estado"
  - "Resolution" → "Resolución"
  - "Open" → "Abierto"
  - "Resolved" → "Resuelto"
- Preserve markdown formatting, numbered lists, and bullet structure.

### Step 5 — Build JSON payload and show preview

Assemble the full JSON body. The structure adapts to whichever fields were found in the `.md`
files. Here is an example with all possible fields present:

```json
{
  "baseId": "<USER_BASE_ID>",
  "epics": [
    {
      "id": "E-002",
      "name": "Fundamentos de Autenticación y Registro",
      "description": "Establecer la base segura de identidad y acceso...",
      "acceptanceCriteria": "- El usuario puede registrarse con email/contraseña.\n- ...",
      "questions": "OQ1: ¿Qué clave de coincidencia usa Canguro Azul...?\n- Responsable: ...",
      "status": "Draft",
      "priority": 1,
      "readiness": "KK",
      "tShirtSize": "Large"
    }
  ],
  "stories": [
    {
      "id": "E-002_S-001",
      "name": "Registro con Email y Contraseña",
      "description": "Como usuario emprendedor, quiero registrarme...",
      "acceptanceCriteria": "1. La plataforma permite a un nuevo usuario...\n2. ...",
      "questions": "OQ-01: Si un email de verificación falla...\n- Estado: Resuelto\n\nOQ-02: ...",
      "epic": "E-002",
      "status": "Draft",
      "priority": 1,
      "readiness": "KK",
      "dependencies": ["E-002_S-003"]
    }
  ]
}
```

And here is an example where variable fields are absent (because they weren't in the `.md`):

```json
{
  "baseId": "<USER_BASE_ID>",
  "epics": [
    {
      "id": "E-002",
      "name": "Fundamentos de Autenticación y Registro",
      "description": "Establecer la base segura de identidad y acceso...",
      "acceptanceCriteria": "- El usuario puede registrarse con email/contraseña.\n- ...",
      "questions": "OQ1: ¿Qué clave de coincidencia usa Canguro Azul...?\n- Responsable: ...",
      "status": "Draft"
    }
  ],
  "stories": [
    {
      "id": "E-002_S-001",
      "name": "Registro con Email y Contraseña",
      "description": "Como usuario emprendedor, quiero registrarme...",
      "acceptanceCriteria": "1. La plataforma permite a un nuevo usuario...\n2. ...",
      "questions": "OQ-01: Si un email de verificación falla...\n- Estado: Resuelto",
      "epic": "E-002",
      "status": "Draft"
    }
  ]
}
```

Before sending, show a summary preview to the user:

```
📋 Sync preview:

Epics: 2
  E-002 → Fundamentos de Autenticación y Registro (10 stories)
  E-003 → Configuración de Perfil (5 stories)

Total stories: 15

Confirm send to Lark Base?
```

Wait for user confirmation before proceeding to the POST.

### Step 6 — POST to the endpoint

Save the payload to a temp file and execute the request:

```bash
cat > /tmp/lark-payload.json << 'PAYLOAD'
<THE_JSON_BODY>
PAYLOAD

curl -s -w "\n%{http_code}" -X POST \
  https://avila-tools-api-qa.onrender.com/api/v1/projects/records \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <API_KEY>" \
  -d @/tmp/lark-payload.json
```

The endpoint performs native upsert: it creates records that don't exist and overwrites records
that already exist.

### Step 7 — Report results

Parse the API response and report back to the user.

**On success:**
```
✅ Sync completed successfully

Epics:   2 processed
Stories: 15 processed

  E-002 (10 stories) → Fundamentos de Autenticación y Registro
  E-003 (5 stories)  → Configuración de Perfil
```

**On failure:**
```
❌ Sync failed

Status: 400
Error: <error message from response>

The payload was saved to /tmp/lark-payload.json for inspection.
```

**On partial issues (some epic folders not found):**
```
⚠️ Sync completed with warnings

Processed: E-002 (10 stories), E-003 (5 stories)
Not found in repo: E-007
```

## Important rules

- Never clone the repository. You are already inside it.
- Never invent or assume field values. Only include fields that actually exist in the .md files.
- The `questions` field can be empty — send `""` if the section doesn't exist in the .md.
- If the API returns an error, show the full response body to help the user debug.
- The endpoint URL is: `https://avila-tools-api-qa.onrender.com/api/v1/projects/records`
- Auth is via `Authorization: Bearer <API_KEY>` header.
- All content fields (name, description, acceptanceCriteria, questions) are translated to Spanish.
- Structural/ID fields (id, epic, status, priority, readiness, tShirtSize, dependencies) are never translated.
- Always confirm with the user before executing the POST.
