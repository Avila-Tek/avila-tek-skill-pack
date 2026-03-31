# Technical Design Document — Canonical Template

Reference template for generating TDDs. Sections marked *(if applicable)* are omitted when not relevant.

---

## Header

```
| Field     | Value                           |
|-----------|---------------------------------|
| Project   | [Project or product name]       |
| Author    | [Name or role]                  |
| Date      | [Generation date]               |
| Version   | 1.0 (Draft)                     |
| Status    | Draft                           |
| Reviewers | [TO BE DEFINED]                 |
```

---

## 1. Problem Statement

3–5 sentences: what exists today, why it's a problem, what the solution achieves.

**Example:**
> Currently, merchants must manually reconcile payments at end of day by cross-referencing bank statements with order records. This takes 2–3 hours daily and produces ~4% undetected discrepancies per month. The solution automates reconciliation and surfaces discrepancies in real time.

---

## 2. Glossary *(if applicable)*

Include only when the domain uses specialized or ambiguous terms.

- **Reconciliation**: The process of matching payment records against bank transactions
- **Settlement**: Transfer of funds from the payment processor to the merchant's bank
- **Chargeback**: A payment reversal initiated by the cardholder's bank

---

## 3. Current Situation *(if applicable)*

Describe the existing system or process being replaced or modified:
- Current architecture and components
- Technical pain points
- Constraints that must be preserved (schemas, APIs, SLAs)

Omit entirely for greenfield projects.

---

## 4. Proposed Solution

---

### 4.1. Technical Constraints & System Rules

List system invariants, DB constraints, queue rules, and technical policies. These are NOT functional rules (those belong in the Spec).

Valid examples:
- Only one active reconciliation job per merchant at a time (enforced by DB unique constraint + queue lock)
- All amounts stored as integers (cents) to avoid floating-point errors
- Webhook retries: max 3 attempts with exponential backoff

Invalid examples (belong in Spec, not here):
- ~~Merchants can trigger reconciliation from the dashboard~~
- ~~An email alert is sent when a discrepancy is found~~

Format:
- **TR-01**: [technical invariant or system constraint]
- **TR-02**: [technical invariant or system constraint]

---

### 4.2. General Flow (ASCII)

High-level end-to-end flow. Use ASCII — no Mermaid.

```
[Scheduled Trigger] → [Fetch Bank Transactions] → [Fetch Payment Records] → [Run Match Algorithm]
                                                                                      ↓
                                                                         [Discrepancies?] → Yes → [Generate Alert]
                                                                                      ↓ No
                                                                         [Mark as Reconciled]
```

Add a brief narrative (2–3 sentences) if the diagram alone isn't self-explanatory.

---

### 4.3. Epics — Technical Summary

One subsection per epic. Functional flows and objectives live in the Spec and epic docs — this section covers only the technical concerns.

#### E-001 — [Title]

- **Systems**: [list of participating systems/services]
- **Technical rules**: TR-01, TR-02
- **Notes**: [optional: short ASCII sequence sketch or constraint note]

```
User → API → [Validate TR-01] → Queue Job → Worker → DB
                                                  ↓
                                             Stripe/PayPal
```

#### E-002 — [Title]

- **Systems**: [list]
- **Technical rules**: TR-XX
- **Notes**: [optional]

---

### 4.4. Component Diagram (ASCII)

Always required. Use ASCII box diagram — no Mermaid.

```
┌─────────────────┐     ┌──────────────────────┐     ┌──────────────┐
│  Web Dashboard  │────▶│  Reconciliation API   │────▶│  PostgreSQL  │
│   (React)       │     │   (Node.js)           │     └──────────────┘
└─────────────────┘     └──────────┬───────────┘     ┌──────────────┐
                                   │                  │    Redis     │
                                   ▼                  └──────────────┘
                         ┌─────────────────┐
                         │   Bull Worker   │────▶ Stripe / PayPal
                         └─────────────────┘
```

Component responsibilities:
- **Web Dashboard**: User-facing reconciliation UI
- **Reconciliation API**: Orchestrates jobs, exposes REST endpoints
- **Bull Worker**: Processes async reconciliation jobs
- **PostgreSQL**: Persistent store for records and results
- **Redis**: Job queue and lock management

---

### 4.5. Data Model *(if applicable)*

> Entities are defined in the domain document (`docs/domain.md`). This section covers only schema-level decisions: indexes, constraints, and migrations.

**Field constraints** (non-obvious fields only):

| Field | Type | Constraints | Notes |
|-------|------|-------------|-------|
| `status` | ENUM | NOT NULL | `pending`, `in_progress`, `completed`, `has_discrepancies` |
| `amount_cents` | INTEGER | NOT NULL | Stored as cents to avoid floating-point errors (TR-02) |

Include notes on indexes, partitioning, or migration strategy if relevant.

---

### 4.6. API Design *(if applicable)*

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| POST | `/api/v1/reconciliations` | Trigger reconciliation | Bearer Token |
| GET | `/api/v1/reconciliations/:id` | Get reconciliation status | Bearer Token |
| PATCH | `/api/v1/discrepancies/:id/resolve` | Mark discrepancy resolved | Bearer Token |

For critical endpoints, include minimal request/response examples.

---

### 4.7. UI/UX *(if applicable)*

List key screens and navigation flow. No Mermaid — use a plain list or ASCII.

```
Dashboard → Reconciliation List → Reconciliation Detail → Discrepancy Review → Resolution Form
```

Reference Figma links if available.

---

### 4.8. Security Considerations *(if applicable)*

Cover only what's specific to this feature — not a generic checklist.

- **Authentication**: [method]
- **Authorization**: [roles/permissions]
- **Data protection**: [encryption, PII handling]
- **Audit trail**: [what is logged]
- **Compliance**: [PCI-DSS, GDPR, SOC 2, etc. — only if relevant]

---

### 4.9. Third-Party Integrations *(if applicable)*

For each external service:

| Aspect | Detail |
|--------|--------|
| **Service** | Stripe Payments API |
| **Purpose** | Fetch transaction records for reconciliation |
| **Auth Method** | API Key (server-side only) |
| **Rate Limits** | 100 req/sec (standard tier) |
| **Failure Handling** | Exponential backoff, max 3 retries (TR-03) |
