# ERP SYSTEM CONTEXT FILE
Comprehensive specification for the Insurance + Treasury + Collections + Accounting ERP, designed for PostgreSQL, modular service boundaries, and event-driven accounting.

---

# --------------------------------------
# 1. SYSTEM OVERVIEW
A complete ERP integrating:

## Key changes from the previous context
1) **Receipt no longer stores payment method or treasury account**: the payment method lives in the **charge order/execution** and in the **movements (incoming_movement)**.
2) **Bank / BankAccount normalized**: where `bank_name` previously existed, it is replaced by `bank_id` (FK to `bank`) and/or `bank_account_id` (FK to `bank_account`).
3) **TreasuryAccount** remains as an internal account (BANK/CASH/INVESTMENT) and, when BANK, references `bank_account`.
4) **OutgoingMovement** no longer points directly to a `payment_order_id`; a reconciliation table `payment_order_outgoing_movement` is added to allow **multiple orders** per movement (and amount proration).
5) `accounting_external_account_map` is added to automatically map accounting accounts created by external models (bank, bank_account, collection_session, etc.).
6) The **Collection Sessions (Cash Register)** flow is added by **branch and currency**: `collection_session` + closing with denomination count and discrepancy approval.

---

# FULL SQL SCHEMA (PostgreSQL)

## Roles and permissions (RBAC)

### Role catalog (abbreviations)

**General**
- **CLI**: Client / Insured
- **INT**: Intermediary / Broker
- **ADM**: System Admin (catalogs, users, permissions, support)

**Collections**
- **COL_OP**: Collections Operator (Collection Analyst)
- **COL_SUP**: Collections Supervisor (Collection Supervisor)

**Treasury**
- **TRE_OP**: Treasury Operator (Treasury Analyst)
- **TRE_CMP**: Treasury Compliance (Treasury Compliance)
- **TRE_SUP**: Treasury Supervisor (Treasury Supervisor)

**Accounting (maker-checker)**
- **ACC_MKR**: Accounting - Maker (creates drafts)
- **ACC_APR**: Accounting - Approver (posts / approves)
- **ACC_PER**: Accounting - Period Controller (period/year closing)

### Official statuses (source of truth)

**receipt.status**
- `pending`, `reserved`, `paid`, `anulled`

**charge_order.status**
- `pending`, `paid`, `anulled`

**incoming_movement.status**
- `pending_validation`, `validated`, `anulled`

**collection_session.status**
- `open`, `closed`

**payment_order.status**
- `pending_aproval`, `pending_invoice`, `approved`, `paid`, `anulled`

**journal_entry.status (accounting)**
- `DRAFT`, `POSTED`, `REVERSED`

**accounting_period / year**
- `OPEN`, `CLOSED`

> "Approve accounting entry" = transition `DRAFT → POSTED`.

---

```sql
------------------------------------------------------------
-- EXTENSIONS (optional)
------------------------------------------------------------
-- CREATE EXTENSION IF NOT EXISTS pgcrypto;

------------------------------------------------------------
-- ENUMS
------------------------------------------------------------
CREATE TYPE account_nature  AS ENUM ('ASSET','LIABILITY','EQUITY','INCOME','EXPENSE');
CREATE TYPE journal_status  AS ENUM ('DRAFT','POSTED','REVERSED');
CREATE TYPE period_status AS ENUM ('OPEN','CLOSED');
CREATE TYPE invoice_status  AS ENUM ('DRAFT','ISSUED','CANCELLED','VOID');

CREATE TYPE bank_type       AS ENUM ('NATIONAL','INTERNATIONAL','OTHER');

CREATE TYPE collection_session_status AS ENUM ('OPEN','CLOSED');
CREATE TYPE session_close_status       AS ENUM ('DRAFT','SUBMITTED','APPROVED','REJECTED');
CREATE TYPE approval_status            AS ENUM ('PENDING','APPROVED','REJECTED');

------------------------------------------------------------
-- CORE / SHARED
------------------------------------------------------------

-- Multimedia / attachments (S3 URLs)
CREATE TABLE file_asset (
    id BIGSERIAL PRIMARY KEY,

    entity_type TEXT NOT NULL,  -- e.g. 'invoice', 'user', 'incoming_movement'
    entity_id   BIGINT NOT NULL,

    url       TEXT NOT NULL,
    alt       TEXT,
    mime_type TEXT NOT NULL,

    active    BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_file_asset_entity ON file_asset(entity_type, entity_id);

-- Users
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,

    first_name TEXT,
    last_name  TEXT,
    username   TEXT UNIQUE,
    email      TEXT UNIQUE,

    phone JSONB,

    is_active  BOOLEAN NOT NULL DEFAULT TRUE,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,

    client_id   BIGINT,
    broker_id   BIGINT,
    provider_id BIGINT,

    -- Branch assigned to the user (for collections department operations)
    branch_id BIGINT,

    photo_id BIGINT REFERENCES file_asset(id),

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Roles
CREATE TABLE roles (
    id BIGSERIAL PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Permissions
CREATE TABLE permissions (
    id BIGSERIAL PRIMARY KEY,
    name  TEXT NOT NULL,
    value TEXT NOT NULL,
    access JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- User ↔ Role
CREATE TABLE user_roles (
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id BIGINT NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, role_id)
);

-- Role ↔ Permission
CREATE TABLE role_permissions (
    role_id BIGINT NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    permission_id BIGINT NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
);

-- Reset token registry
CREATE TABLE reset_token (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id),
    token TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ,
    ip_address TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Notification types (templates)
CREATE TABLE notification_type (
    id SMALLSERIAL PRIMARY KEY,
    code TEXT UNIQUE NOT NULL,
    component TEXT,
    title TEXT,
    message TEXT,
    models TEXT[],
    redirect_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Notifications
CREATE TABLE notification (
    id BIGSERIAL PRIMARY KEY,
    notification_type_id SMALLINT REFERENCES notification_type(id),
    sender_user_id   BIGINT REFERENCES users(id),
    recipient_user_id BIGINT REFERENCES users(id),
    title TEXT,
    message TEXT,
    url TEXT,
    seen BOOLEAN DEFAULT FALSE,
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Audit log (history)
CREATE TABLE audit_log (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id),

    entity_type TEXT NOT NULL,
    entity_id BIGINT NOT NULL,

    action TEXT NOT NULL CHECK (action IN ('CREATE','UPDATE','DELETE','VIEW','APPROVE','REJECT')),

    message TEXT,
    metadata JSONB,

    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Requests / workflow operations
CREATE TABLE request (
    id BIGSERIAL PRIMARY KEY,

    type TEXT NOT NULL,  -- 'reschedulePayment', etc.
    status TEXT NOT NULL CHECK (status IN ('PENDING','APPROVED','REJECTED','CANCELED')),

    user_id BIGINT REFERENCES users(id),
    created_by BIGINT REFERENCES users(id),
    action_date TIMESTAMPTZ,
    action_user_id BIGINT REFERENCES users(id),

    payload JSONB NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id BIGINT,

    code TEXT,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- System params
CREATE TABLE system_param (
    key TEXT PRIMARY KEY,
    value JSONB NOT NULL,
    description TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by BIGINT REFERENCES users(id)
);

------------------------------------------------------------
-- MASTER DATA (Accounting / Dimensions)
------------------------------------------------------------

-- Currency
CREATE TABLE currency (
    code TEXT PRIMARY KEY,      -- 'USD', 'VES'
    name TEXT NOT NULL,
    is_reference_currency BOOLEAN DEFAULT FALSE
);

-- Region / Branch / Cost center
CREATE TABLE region (
    id SMALLSERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE
);

CREATE TABLE branch (
    id BIGSERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    region_id SMALLINT REFERENCES region(id)
);

CREATE TABLE cost_center (
    id BIGSERIAL PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL
);

-- Chart of accounts
CREATE TABLE accounting_account (
    id BIGSERIAL PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    level SMALLINT NOT NULL,
    parent_id BIGINT REFERENCES accounting_account(id),
    allows_posting BOOLEAN NOT NULL,
    nature account_nature NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_accounting_account_parent ON accounting_account(parent_id);
CREATE INDEX idx_accounting_account_nature ON accounting_account(nature);

-- Accounting periods
CREATE TABLE accounting_period (
    id BIGSERIAL PRIMARY KEY,
    year INTEGER NOT NULL,
    month INTEGER NOT NULL CHECK (month BETWEEN 1 AND 12),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    status period_status NOT NULL DEFAULT 'OPEN',
    is_current BOOLEAN,
    UNIQUE (year, month)
);

-- Dimensions (insurance/accounting)
CREATE TABLE line_of_business (
    id SMALLSERIAL PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL
);

CREATE TABLE coverage (
    id BIGSERIAL PRIMARY KEY,
    line_of_business_id SMALLINT NOT NULL REFERENCES line_of_business(id),
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    UNIQUE (line_of_business_id, code)
);

CREATE TABLE plan (
    id BIGSERIAL PRIMARY KEY,
    coverage_id BIGINT NOT NULL REFERENCES coverage(id),
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    UNIQUE (coverage_id, code)
);

------------------------------------------------------------
-- PEOPLE / PARTIES
------------------------------------------------------------

CREATE TABLE client (
    id BIGSERIAL PRIMARY KEY,
    external_ref TEXT NOT NULL UNIQUE,
    document_id TEXT,
    name TEXT NOT NULL
);

CREATE TABLE broker (
    id BIGSERIAL PRIMARY KEY,
    external_ref TEXT NOT NULL UNIQUE,
    code TEXT,
    name TEXT NOT NULL,
    tax_id TEXT,
    is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE payee (
    id BIGSERIAL PRIMARY KEY,
    type TEXT NOT NULL CHECK (type IN ('BROKER','SUPPLIER','EMPLOYEE','CLAIMANT','OTHER')),
    external_ref TEXT,
    name TEXT NOT NULL,
    tax_id TEXT
);

CREATE UNIQUE INDEX ux_payee_type_extref
ON payee(type, external_ref)
WHERE external_ref IS NOT NULL;

-- Providers
CREATE TABLE provider (
    id BIGSERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    rif TEXT,
    nationality TEXT,
    provider_type TEXT,
    contact_email TEXT,
    phone TEXT,
    address TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

------------------------------------------------------------
-- BANKS / BANK ACCOUNTS
------------------------------------------------------------

-- Bank (institution). Can also have a root accounting account (e.g. "National Banks").
CREATE TABLE bank (
    id BIGSERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,

    -- "Root" accounting account associated with the bank (optional if managed via map)
    accounting_account_id BIGINT REFERENCES accounting_account(id),
    accounting_account_code TEXT,

    type bank_type NOT NULL DEFAULT 'NATIONAL',
    currency_code TEXT REFERENCES currency(code),

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Bank account (operational / real bank account)
CREATE TABLE bank_account (
    id BIGSERIAL PRIMARY KEY,
    bank_id BIGINT NOT NULL REFERENCES bank(id) ON DELETE RESTRICT,

    alias TEXT,                  -- friendly name
    account_number TEXT NOT NULL,
    account_type TEXT,           -- savings/checking/etc
    currency_code TEXT NOT NULL REFERENCES currency(code),

    is_active BOOLEAN DEFAULT TRUE,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE (bank_id, account_number)
);

-- Provider bank accounts now reference bank_id (no bank_name string)
CREATE TABLE provider_bank_account (
    id BIGSERIAL PRIMARY KEY,

    provider_id BIGINT NOT NULL REFERENCES provider(id) ON DELETE CASCADE,

    bank_id BIGINT NOT NULL REFERENCES bank(id),
    account_number TEXT NOT NULL,
    account_type TEXT,
    currency_code TEXT NOT NULL REFERENCES currency(code),

    is_primary BOOLEAN DEFAULT FALSE,
    active BOOLEAN DEFAULT TRUE,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE (provider_id, account_number)
);

------------------------------------------------------------
-- TREASURY ACCOUNTS (internal cash/bank/investment)
------------------------------------------------------------
CREATE TABLE treasury_account (
    id BIGSERIAL PRIMARY KEY,
    type TEXT NOT NULL CHECK (type IN ('BANK','CASH','INVESTMENT')),
    name TEXT NOT NULL,

    currency_code TEXT NOT NULL REFERENCES currency(code),

    -- Owner branch (used to scope collection sessions and caja by branch)
    branch_id BIGINT REFERENCES branch(id),

    -- When type = BANK
    bank_account_id BIGINT REFERENCES bank_account(id),

    is_active BOOLEAN DEFAULT TRUE,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

------------------------------------------------------------
-- INSURANCE CORE
------------------------------------------------------------

CREATE TABLE policy (
    id BIGSERIAL PRIMARY KEY,
    external_ref TEXT NOT NULL UNIQUE,
    policy_number TEXT NOT NULL,
    client_id BIGINT REFERENCES client(id),
    broker_id BIGINT REFERENCES broker(id),
    line_of_business_id SMALLINT NOT NULL REFERENCES line_of_business(id),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('ACTIVE','CANCELLED','EXPIRED'))
);

CREATE TABLE policy_coverage (
    id BIGSERIAL PRIMARY KEY,
    policy_id BIGINT NOT NULL REFERENCES policy(id) ON DELETE CASCADE,
    coverage_id BIGINT NOT NULL REFERENCES coverage(id),
    plan_id BIGINT REFERENCES plan(id),
    sum_insured NUMERIC(18,2),
    UNIQUE (policy_id, coverage_id, COALESCE(plan_id, -1))
);

CREATE TABLE policy_installment (
    id BIGSERIAL PRIMARY KEY,
    policy_id BIGINT NOT NULL REFERENCES policy(id) ON DELETE CASCADE,
    installment_no INTEGER NOT NULL,
    due_date DATE NOT NULL,
    currency_code TEXT NOT NULL REFERENCES currency(code),
    premium_amount_tx NUMERIC(18,2) NOT NULL,
    taxes_amount_tx NUMERIC(18,2) NOT NULL,
    commission_amount_tx NUMERIC(18,2) NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('PENDING','PARTIALLY_PAID','PAID','CANCELLED')),
    UNIQUE (policy_id, installment_no)
);

CREATE TABLE broker_commission (
    id BIGSERIAL PRIMARY KEY,
    policy_installment_id BIGINT NOT NULL REFERENCES policy_installment(id) ON DELETE CASCADE,
    broker_id BIGINT NOT NULL REFERENCES broker(id),
    currency_code TEXT NOT NULL REFERENCES currency(code),
    amount_tx NUMERIC(18,2) NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('ACCRUED','PAYABLE','PAID'))
);

CREATE TABLE claim (
    id BIGSERIAL PRIMARY KEY,
    external_ref TEXT NOT NULL UNIQUE,
    policy_id BIGINT NOT NULL REFERENCES policy(id),
    claim_number TEXT NOT NULL,
    event_date DATE NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('OPEN','APPROVED','REJECTED','CLOSED'))
);

------------------------------------------------------------
-- CONCEPTS / ITEMS
------------------------------------------------------------

-- Payment methods (used by movements & caja)
CREATE TABLE payment_method (
    code TEXT PRIMARY KEY,          -- 'CASH','TRANSFER','ZELLE','CARD','CHECK', etc.
    description TEXT NOT NULL
);

-- Concepts (classification for charge_order & payment_order)
CREATE TABLE concept (
    id BIGSERIAL PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Item group (hierarchy + leaf maps to accounting account)
CREATE TABLE item_group (
    id BIGSERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    parent_id BIGINT REFERENCES item_group(id),
    direction TEXT NOT NULL CHECK (direction IN ('IN','OUT')),
    is_leaf BOOLEAN NOT NULL DEFAULT FALSE,
    accounting_account_id BIGINT REFERENCES accounting_account(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT chk_leaf_rules CHECK (
        (is_leaf = TRUE AND accounting_account_id IS NOT NULL)
        OR
        (is_leaf = FALSE AND accounting_account_id IS NULL)
    )
);

-- Item catalog (optional, for reuse across orders)
CREATE TABLE item (
    id BIGSERIAL PRIMARY KEY,
    code TEXT UNIQUE,
    name TEXT NOT NULL,
    description TEXT,
    item_group_id BIGINT REFERENCES item_group(id),
    default_price NUMERIC(18,4),
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

------------------------------------------------------------
-- COLLECTIONS (Incoming)
------------------------------------------------------------

-- Receipt = collection evidence (does NOT include payment method)
CREATE TABLE receipt (
    id BIGSERIAL PRIMARY KEY,
    receipt_number TEXT NOT NULL UNIQUE,
    client_id BIGINT NOT NULL REFERENCES client(id),
    broker_id BIGINT REFERENCES broker(id),
    currency_code TEXT NOT NULL REFERENCES currency(code),
    receipt_date DATE NOT NULL,
    amount_tx NUMERIC(18,2) NOT NULL CHECK (amount_tx > 0),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by BIGINT REFERENCES users(id)
);

-- Charge order (groups receipts or concept-based charges)
CREATE TABLE charge_order (
    id BIGSERIAL PRIMARY KEY,
    order_number TEXT NOT NULL UNIQUE,

    concept_id BIGINT REFERENCES concept(id),

    currency_code TEXT NOT NULL REFERENCES currency(code),

    subtotal_amount_tx NUMERIC(18,2) NOT NULL DEFAULT 0,
    total_amount_tx NUMERIC(18,2) NOT NULL DEFAULT 0,

    status TEXT NOT NULL CHECK (status IN ('DRAFT','PENDING','EXECUTED','PAID','CANCELLED')),

    created_by BIGINT REFERENCES users(id),
    approved_by BIGINT REFERENCES users(id),

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Charge order items (can reference receipts)
CREATE TABLE charge_order_item (
    id BIGSERIAL PRIMARY KEY,

    charge_order_id BIGINT NOT NULL REFERENCES charge_order(id) ON DELETE CASCADE,

    item_group_id BIGINT NOT NULL REFERENCES item_group(id),
    item_id BIGINT REFERENCES item(id),

    receipt_id BIGINT REFERENCES receipt(id),

    description TEXT,

    quantity NUMERIC(18,4) NOT NULL DEFAULT 1 CHECK (quantity > 0),
    price NUMERIC(18,4) NOT NULL DEFAULT 0 CHECK (price > 0),

    subtotal_tx NUMERIC(18,2) NOT NULL CHECK (subtotal_tx > 0),
    total_tx NUMERIC(18,2) NOT NULL CHECK (total_tx > 0),

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE UNIQUE INDEX ux_charge_order_item_receipt
ON charge_order_item(charge_order_id, receipt_id)
WHERE receipt_id IS NOT NULL;

-- Invoice (belongs to one charge_order)
CREATE TABLE invoice (
    id BIGSERIAL PRIMARY KEY,

    charge_order_id BIGINT NOT NULL REFERENCES charge_order(id) ON DELETE CASCADE,

    series TEXT,
    document_type TEXT,
    document_number TEXT NOT NULL,
    control_number TEXT,

    assignment_date DATE NOT NULL,

    status invoice_status NOT NULL DEFAULT 'ISSUED',

    pdf_url TEXT,
    file_asset_id BIGINT REFERENCES file_asset(id),

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

------------------------------------------------------------
-- TREASURY (Outgoing)
------------------------------------------------------------

CREATE TABLE payment_order (
    id BIGSERIAL PRIMARY KEY,
    order_number TEXT NOT NULL UNIQUE,

    provider_id BIGINT NOT NULL REFERENCES provider(id),
    concept_id BIGINT REFERENCES concept(id),

    invoice_type TEXT NOT NULL CHECK (invoice_type IN ('PROVIDER','INVOICELESS')),
    provider_invoice_number TEXT,
    emission_date DATE,
    expiration_date DATE,

    discount_type TEXT CHECK (discount_type IN ('FIXED','PERCENTAGE')),
    discount_value NUMERIC(18,2),
    discount_amount NUMERIC(18,2),
    description TEXT,

    currency_code TEXT NOT NULL REFERENCES currency(code),
    treasury_account_id BIGINT NOT NULL REFERENCES treasury_account(id),

    subtotal_amount_tx NUMERIC(18,2) DEFAULT 0,
    tax_iva_total_tx NUMERIC(18,2) DEFAULT 0,
    tax_islr_total_tx NUMERIC(18,2) DEFAULT 0,
    tax_other_total_tx NUMERIC(18,2) DEFAULT 0,
    total_amount_tx NUMERIC(18,2) DEFAULT 0,

    status TEXT NOT NULL CHECK (
        status IN ('DRAFT','PENDING_APROVAL','SCHEDULED','EXECUTED','PAID','CANCELLED','REJECTED')
    ),

    scheduled_date DATE,
    executed_at TIMESTAMPTZ,
    approved_at TIMESTAMPTZ,

    created_by BIGINT REFERENCES users(id),
    approved_by BIGINT REFERENCES users(id),
    executed_by BIGINT REFERENCES users(id),

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE payment_order_item (
    id BIGSERIAL PRIMARY KEY,

    payment_order_id BIGINT NOT NULL REFERENCES payment_order(id) ON DELETE CASCADE,

    item_group_id BIGINT NOT NULL REFERENCES item_group(id),
    item_id BIGINT REFERENCES item(id),

    accounting_account_id BIGINT REFERENCES accounting_account(id),

    description TEXT,

    quantity NUMERIC(18,4) NOT NULL DEFAULT 1 CHECK (quantity > 0),
    price NUMERIC(18,4) NOT NULL DEFAULT 0 CHECK (price >= 0),
    subtotal_tx NUMERIC(18,2) NOT NULL CHECK (subtotal_tx >= 0),

    tax_iva_tx NUMERIC(18,2) NOT NULL DEFAULT 0,
    tax_islr_tx NUMERIC(18,2) NOT NULL DEFAULT 0,
    tax_other_tx NUMERIC(18,2) NOT NULL DEFAULT 0,

    total_tx NUMERIC(18,2) NOT NULL CHECK (total_tx >= 0),

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

------------------------------------------------------------
-- MOVEMENTS (Incoming / Outgoing)
------------------------------------------------------------

-- Incoming movement (bank deposits, transfers, cash entries)
CREATE TABLE incoming_movement (
    id BIGSERIAL PRIMARY KEY,

    treasury_account_id BIGINT NOT NULL REFERENCES treasury_account(id),

    -- External bank metadata
    external_id TEXT,
    external_bank_id TEXT,
    bank_id BIGINT REFERENCES bank(id),
    entity_name TEXT,
    account_name TEXT,

    description TEXT,
    note TEXT,

    transaction_date DATE NOT NULL,
    timestamp BIGINT NOT NULL,
    value_date DATE,

    amount_tx NUMERIC(18,2) NOT NULL CHECK (amount_tx > 0),
    currency_code TEXT NOT NULL REFERENCES currency(code),
    -- FX rate ONLY when currency_code is not the national currency (service-level rule)
    exchange_rate NUMERIC(18,8) CHECK (exchange_rate IS NULL OR exchange_rate > 0),

    current_amount_tx NUMERIC(18,2) NOT NULL,

    reference_number TEXT,

    payment_method_code TEXT REFERENCES payment_method(code),

    origin TEXT NOT NULL CHECK (origin IN ('MANUAL','AUTOMATIC')) DEFAULT 'AUTOMATIC',

    active BOOLEAN DEFAULT TRUE,

    status TEXT NOT NULL CHECK (
        status IN ('PENDING','MANUAL_CONFIRMED','AUTO_CONFIRMED','RECONCILED','REVERSED')
    ) DEFAULT 'PENDING',

    confirmed_by BIGINT REFERENCES users(id),
    confirmed_at TIMESTAMPTZ,
    auto_confirmed_at TIMESTAMPTZ,

    charge_order_id BIGINT REFERENCES charge_order(id),

    -- Linked to a collections session (nullable for digital payments before session opens)
    collection_session_id BIGINT REFERENCES collection_session(id),
    assigned_to_session_at TIMESTAMPTZ,
    assigned_to_session_by BIGINT REFERENCES users(id),
    search_data JSONB,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Outgoing movement (bank payments, cash payments)
CREATE TABLE outgoing_movement (
    id BIGSERIAL PRIMARY KEY,

    treasury_account_id BIGINT NOT NULL REFERENCES treasury_account(id),

    external_id TEXT,
    external_bank_id TEXT,
    bank_id BIGINT REFERENCES bank(id),
    entity_name TEXT,
    account_name TEXT,

    description TEXT,
    note TEXT,

    transaction_date DATE NOT NULL,
    timestamp BIGINT NOT NULL,
    value_date DATE,

    amount_tx NUMERIC(18,2) NOT NULL CHECK (amount_tx > 0),
    currency_code TEXT NOT NULL REFERENCES currency(code),
    -- FX rate ONLY when currency_code is not the national currency (service-level rule)
    exchange_rate NUMERIC(18,8) CHECK (exchange_rate IS NULL OR exchange_rate > 0),

    current_amount_tx NUMERIC(18,2) NOT NULL,

    reference_number TEXT,

    payment_method_code TEXT REFERENCES payment_method(code),

    origin TEXT NOT NULL CHECK (origin IN ('MANUAL','AUTOMATIC')) DEFAULT 'AUTOMATIC',

    active BOOLEAN DEFAULT TRUE,

    status TEXT NOT NULL CHECK (status IN ('PENDING','CONFIRMED','RECONCILED','REVERSED')) DEFAULT 'PENDING',

    search_data JSONB,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Conciliation: many payment_orders can be paid by one outgoing_movement (with allocations)
CREATE TABLE payment_order_outgoing_movement (
    id BIGSERIAL PRIMARY KEY,
    payment_order_id BIGINT NOT NULL REFERENCES payment_order(id) ON DELETE CASCADE,
    outgoing_movement_id BIGINT NOT NULL REFERENCES outgoing_movement(id) ON DELETE CASCADE,
    allocated_amount_tx NUMERIC(18,2) NOT NULL CHECK (allocated_amount_tx > 0),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (payment_order_id, outgoing_movement_id)
);

------------------------------------------------------------
-- ACCOUNTING (Journal Entries)
------------------------------------------------------------

CREATE TABLE journal_entry (
    id BIGSERIAL PRIMARY KEY,

    journal_number TEXT NOT NULL UNIQUE,   -- e.g. '2025-000001'
    entry_date DATE NOT NULL,

    period_id BIGINT NOT NULL REFERENCES accounting_period(id),

    description TEXT,

    source_system TEXT NOT NULL,           -- 'CORE','MANUAL','TREASURY','COLLECTIONS','CASH','FX_REVAL', etc.
    source_ref TEXT,                       -- 'system:model:id'

    status journal_status NOT NULL DEFAULT 'DRAFT',
    reversed_by_id BIGINT REFERENCES journal_entry(id),

    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by BIGINT REFERENCES users(id),
    posted_at TIMESTAMPTZ,
    posted_by BIGINT REFERENCES users(id)
);

CREATE INDEX idx_journal_period ON journal_entry(period_id);
CREATE INDEX idx_journal_status ON journal_entry(status);
CREATE INDEX idx_journal_source ON journal_entry(source_system, source_ref);

CREATE TABLE journal_entry_line (
    id BIGSERIAL PRIMARY KEY,

    journal_entry_id BIGINT NOT NULL REFERENCES journal_entry(id) ON DELETE CASCADE,
    line_no INTEGER NOT NULL,

    account_id BIGINT NOT NULL REFERENCES accounting_account(id),

    currency_code TEXT NOT NULL REFERENCES currency(code),
    fx_rate NUMERIC(18,8) NOT NULL CHECK (fx_rate > 0),
    amount_tx NUMERIC(18,2) NOT NULL,      -- signed +debit / -credit
    amount_func NUMERIC(18,2) NOT NULL,

    line_of_business_id SMALLINT REFERENCES line_of_business(id),
    coverage_id BIGINT REFERENCES coverage(id),
    plan_id BIGINT REFERENCES plan(id),
    broker_id BIGINT REFERENCES broker(id),
    branch_id BIGINT REFERENCES branch(id),
    cost_center_id BIGINT REFERENCES cost_center(id),
    client_id BIGINT REFERENCES client(id),
    policy_id BIGINT REFERENCES policy(id),
    claim_id BIGINT REFERENCES claim(id),

    line_description TEXT,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by BIGINT REFERENCES users(id),

    UNIQUE (journal_entry_id, line_no)
);

CREATE INDEX idx_jline_account  ON journal_entry_line(account_id);
CREATE INDEX idx_jline_currency ON journal_entry_line(currency_code);
CREATE INDEX idx_jline_journal  ON journal_entry_line(journal_entry_id);
CREATE INDEX idx_jline_policy   ON journal_entry_line(policy_id);
CREATE INDEX idx_jline_claim    ON journal_entry_line(claim_id);
CREATE INDEX idx_jline_broker   ON journal_entry_line(broker_id);

------------------------------------------------------------
-- TAXES & WITHHOLDINGS
------------------------------------------------------------

CREATE TABLE tax_type (
    id SMALLSERIAL PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,           -- 'MUNI','ISLR_RET','IVA_RET', etc.
    name TEXT NOT NULL,
    is_withholding BOOLEAN NOT NULL
);

CREATE TABLE tax_rate (
    id BIGSERIAL PRIMARY KEY,
    tax_type_id SMALLINT NOT NULL REFERENCES tax_type(id),
    valid_from DATE NOT NULL,
    valid_to DATE,
    rate NUMERIC(9,4) NOT NULL,
    UNIQUE (tax_type_id, valid_from)
);

CREATE TABLE tax_detail (
    id BIGSERIAL PRIMARY KEY,
    journal_entry_line_id BIGINT NOT NULL REFERENCES journal_entry_line(id) ON DELETE CASCADE,
    tax_type_id SMALLINT NOT NULL REFERENCES tax_type(id),
    currency_code TEXT NOT NULL REFERENCES currency(code),
    tax_base_tx NUMERIC(18,2) NOT NULL,
    tax_amount_tx NUMERIC(18,2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_tax_detail_line ON tax_detail(journal_entry_line_id);
CREATE INDEX idx_tax_detail_type ON tax_detail(tax_type_id);

CREATE TABLE withholding_certificate (
    id BIGSERIAL PRIMARY KEY,
    certificate_number TEXT NOT NULL UNIQUE,
    tax_type_id SMALLINT NOT NULL REFERENCES tax_type(id),
    issue_date DATE NOT NULL,
    party_name TEXT NOT NULL,
    party_tax_id TEXT,
    total_base_tx NUMERIC(18,2) NOT NULL,
    total_withheld_tx NUMERIC(18,2) NOT NULL,
    currency_code TEXT NOT NULL REFERENCES currency(code),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by BIGINT REFERENCES users(id)
);

CREATE TABLE withholding_certificate_line (
    id BIGSERIAL PRIMARY KEY,
    withholding_certificate_id BIGINT NOT NULL REFERENCES withholding_certificate(id) ON DELETE CASCADE,
    journal_entry_line_id BIGINT NOT NULL REFERENCES journal_entry_line(id),
    tax_base_tx NUMERIC(18,2) NOT NULL,
    tax_withheld_tx NUMERIC(18,2) NOT NULL,
    tax_type_id SMALLINT REFERENCES tax_type(id),
    UNIQUE (withholding_certificate_id, journal_entry_line_id)
);

CREATE INDEX idx_wcert_line_cert ON withholding_certificate_line(withholding_certificate_id);
CREATE INDEX idx_wcert_line_jel  ON withholding_certificate_line(journal_entry_line_id);

------------------------------------------------------------
-- INVESTMENTS
------------------------------------------------------------
CREATE TABLE investment (
    id BIGSERIAL PRIMARY KEY,

    investment_type TEXT NOT NULL CHECK (investment_type IN ('BOND','STOCK')),
    status TEXT NOT NULL CHECK (status IN ('ACTIVE','EXPIRED','ANNULLED','SOLD')),

    purchase_date DATE NOT NULL,
    maturity_date DATE,

    nominal_amount NUMERIC(18,2),
    price_amount NUMERIC(18,2),
    quantity INTEGER,
    sell_amount NUMERIC(18,2),

    currency_code TEXT NOT NULL REFERENCES currency(code),

    treasury_account_id BIGINT REFERENCES treasury_account(id),
    journal_entry_id BIGINT REFERENCES journal_entry(id),
    payment_order_id BIGINT REFERENCES payment_order(id),

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

------------------------------------------------------------
-- INTEGRATION EVENTS (core → accounting)
------------------------------------------------------------
CREATE TABLE integration_event (
    id BIGSERIAL PRIMARY KEY,
    source_system TEXT NOT NULL,
    event_type TEXT NOT NULL,
    external_id TEXT NOT NULL,
    payload JSONB NOT NULL,
    received_at TIMESTAMPTZ DEFAULT NOW(),
    processed_at TIMESTAMPTZ,
    status TEXT NOT NULL CHECK (status IN ('PENDING','PROCESSED','ERROR')),
    error_message TEXT
);

CREATE INDEX idx_intevent_status ON integration_event(status);
CREATE INDEX idx_intevent_type   ON integration_event(event_type);
CREATE INDEX idx_intevent_ext    ON integration_event(external_id);

------------------------------------------------------------
-- ACCOUNTING EXTERNAL ACCOUNT MAP (auto-created accounts)
------------------------------------------------------------
CREATE TABLE accounting_external_account_map (
    id BIGSERIAL PRIMARY KEY,

    source_entity_type TEXT NOT NULL,   -- 'bank','bank_account','collection_session', etc.
    source_entity_id BIGINT NOT NULL,

    accounting_account_id BIGINT NOT NULL REFERENCES accounting_account(id),
    accounting_account_code TEXT,

    relation_type TEXT NOT NULL DEFAULT 'MAIN',  -- 'MAIN','CHILD','GRANDCHILD','AUX', etc.
    metadata JSONB,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by BIGINT REFERENCES users(id),

    UNIQUE (source_entity_type, source_entity_id, relation_type)
);

CREATE INDEX idx_ext_map_source ON accounting_external_account_map(source_entity_type, source_entity_id);
CREATE INDEX idx_ext_map_account ON accounting_external_account_map(accounting_account_id);

------------------------------------------------------------
-- COLLECTION SESSIONS (Collections cash register by branch and currency)
------------------------------------------------------------

-- Session container for ALL collections transactions of a branch+currency in a working day.
-- Rules (enforced at service level):
-- - Only one OPEN session per (branch_id, currency_code)
-- - CASH movements require an OPEN session
-- - DIGITAL movements may exist without session and are assigned later once session opens

CREATE TABLE collection_session (
    id BIGSERIAL PRIMARY KEY,

    branch_id BIGINT NOT NULL REFERENCES branch(id),
    currency_code TEXT NOT NULL REFERENCES currency(code),

    opened_by BIGINT NOT NULL REFERENCES users(id),
    opened_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    status collection_session_status NOT NULL DEFAULT 'OPEN',

    closed_by BIGINT REFERENCES users(id),
    closed_at TIMESTAMPTZ,

    -- Accounting linkage (one JE per CLOSED session)
    journal_entry_id BIGINT REFERENCES journal_entry(id),

    note TEXT,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Close record (cash count header). One per session.
CREATE TABLE collection_session_close (
    id BIGSERIAL PRIMARY KEY,

    collection_session_id BIGINT NOT NULL UNIQUE REFERENCES collection_session(id) ON DELETE CASCADE,

    status session_close_status NOT NULL DEFAULT 'DRAFT',

    expected_cash_tx NUMERIC(18,2) NOT NULL DEFAULT 0 CHECK (expected_cash_tx >= 0),
    counted_cash_tx  NUMERIC(18,2) NOT NULL DEFAULT 0 CHECK (counted_cash_tx >= 0),
    difference_tx    NUMERIC(18,2) NOT NULL DEFAULT 0,

    discrepancy_reason TEXT,

    created_by BIGINT REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Denomination breakdown (cash count detail)
CREATE TABLE collection_session_close_denomination (
    id BIGSERIAL PRIMARY KEY,

    collection_session_close_id BIGINT NOT NULL REFERENCES collection_session_close(id) ON DELETE CASCADE,

    denomination_value NUMERIC(18,2) NOT NULL CHECK (denomination_value > 0),
    quantity INTEGER NOT NULL CHECK (quantity >= 0),

    amount_tx NUMERIC(18,2) NOT NULL CHECK (amount_tx >= 0),

    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Approval workflow for discrepancy (only required when difference != 0)
CREATE TABLE collection_session_close_approval (
    id BIGSERIAL PRIMARY KEY,

    collection_session_close_id BIGINT NOT NULL REFERENCES collection_session_close(id) ON DELETE CASCADE,

    status approval_status NOT NULL DEFAULT 'PENDING',

    requested_by BIGINT NOT NULL REFERENCES users(id),
    requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    decided_by BIGINT REFERENCES users(id),
    decided_at TIMESTAMPTZ,

    decision_note TEXT
);

------------------------------------------------------------
-- END
------------------------------------------------------------
```

---

## Insurance Operations
- Policies, coverages, plans
- Installments & commissions
- Claims

## Treasury (Outgoing Payments)
- Payment orders
- Provider invoices (manually entered, not generated)
- Items with quantities, prices, taxes
- Scheduling, approval, execution
- Outgoing movements (bank or cash)
- Reconciliation via bank API or manual matching

## Collections (Incoming Payments)
- Charge orders
- Receipt grouping & application
- Concept-based charge orders
- Incoming movements (bank deposits, transfers, Zelle, cash)
- Reconciliation logic

## Accounting Engine
- Journal entry headers & lines
- Multi-currency: tx_amount, functional_amount
- Dimensions: LOB, coverage, plan, broker, branch, client, policy, claim
- Taxes & withholding flows
- Event-driven JE posting

## Shared Modules
- Providers + bank accounts
- Users / roles / permissions
- Reset token registry
- Notifications
- Requests
- Audit logs
- File assets (S3 URLs)
- Concepts, item groups
- Investments

---

# --------------------------------------
# 2. SYSTEM RULES & ARCHITECTURE

## 2.1 Database Philosophy
- Fully normalized PostgreSQL
- No embedded Mongo-style structures
- Files stored on S3, referenced by `file_asset`
- All accounting events executed asynchronously (queue-ready architecture)

## 2.2 Treasury Logic (Outgoing)
### Flows:
1) Create payment order
2) Select provider and invoice type
3) Add items (qty, price, tax config)
4) Calculate totals
5) Approve
6) Execute → generate outgoing movement
7) Reconcile with bank API

### Notes:
- Items dictate accounting movement (each item has account mapping thru item_group)
- Taxes exist but DO NOT affect JE automatically

## 2.3 Collections Logic (Incoming)
### Flows:
1) Create receipt(s)
2) Create charge order
3) Optionally group multiple receipts
4) Execute charge order → incoming movement
5) Reconcile with bank API

## 2.4 Movement Rules
### Both movement types share:
- treasury_account_id (internal account)
- date, timestamp
- amount, currency, fx_rate
- reconciled (bool)
- origin: Manual | Automatic
- S3 multimedia attachment

### Differences:
`incoming_movement` = deposits / incoming cash
`outgoing_movement` = payments / disbursements

## 2.5 Concepts & Item Groups
- item_group = hierarchical structure
- Each group references the accounting_account leaf
- order_items reference item_group
- order_items drive accounting

## 2.6 Providers
- name, rif, nationality, provider_type
- multiple bank accounts allowed
- provider invoices supported (manually entered)

---

# --------------------------------------
# 4. TREASURY MODULE (DETAIL)

## 4.1 Payment Orders
Supports:
- Provider invoices
- Invoiceless expenses
- Discounts (flat or percentage)
- Items with quantity × price
- Three tax fields per item (IVA, ISLR, other)
- Approval and scheduled payment date
- Execution triggers outgoing movement

## 4.2 Outgoing Movements
- Tracks each monetary outflow
- May be created manually or automatically
- Reconciled via bank API or user confirmation
- Multiple payment orders can use one outgoing movement via conciliation table

---

# --------------------------------------
# 5. COLLECTIONS MODULE (DETAIL)

## 5.1 Charge Orders
Two types:
- receipt-based charge order
- concept-based charge order

## 5.2 Incoming Movements
Same schema as outgoing but directionally inverted.

Key rule:
- One incoming movement may reconcile **multiple receipts**

---

# --------------------------------------
# 6. ACCOUNTING MODULE (DETAIL)

## 6.1 Event-Driven Posting
Modules emit events:
- receipt applied
- charge order executed
- payment order executed
- commission accrued
- claim paid
- FX revaluation

## 6.2 Journal Entries
- One header, multiple lines
- Must balance (enforced by service)
- Dimension tracking included
- Multi-currency: transaction + functional amounts

---

# --------------------------------------
# 7. PROVIDERS MODULE

## Provider
- rif
- nationality
- provider_type
- email, phone, address
- active flag

## Provider Bank Accounts
- currency_code
- bank_id (FK to bank)
- account_number
- account_type
- is_primary
- active

---

# --------------------------------------
# 8. AUTH MODULE

## User
- first_name, last_name
- username, email
- phone
- linked client/broker/provider
- file_asset photo
- active, deleted flags

## Roles & Permissions
- roles = named permission sets
- permissions = granular actions
- Many-to-many mapping tables:
  - user_roles
  - role_permissions

## Reset Tokens
Tracks:
- token
- expiration
- used_at
- ip_address

---

# --------------------------------------
# 9. FILE STORAGE MODULE

## file_asset
- url (S3)
- mime_type
- active

# --------------------------------------
# 10. NOTIFICATIONS

- notification_type (template)
- notification (actual message)
- sender → recipient

---

# --------------------------------------
# 11. REQUEST MODULE

Used for workflow actions:
- reschedule payment_order
- bill extension (legacy)
- record modifications requiring approval

---

# --------------------------------------
# 12. AUDIT LOG

Tracks:
- user
- entity
- action
- metadata
- timestamp

---

# --------------------------------------
# 13. INVESTMENTS MODULE

Supports:
- bonds
- stocks
- purchase/maturity
- linked accounting entry
- linked treasury account

---

# --------------------------------------
# 14. GLOSSARY OF DOMAIN TERMS

### Movement
A bank or cash financial event (incoming or outgoing).

### Outgoing Payment
A treasury disbursement through a payment order.

### Charge Order
Incoming collection grouped from receipts or concepts.

### Receipt
Represents a client's premium payment.

### Reconciliation
Matching order execution with bank activity.

### Concept
A predefined accounting category (via item_group).

### Item Group
Hierarchy for grouping items and linking to accounting accounts.

### Event-Driven Accounting
Journal entries generated from business events.

### Functional Currency
Base currency used internally for accounting (VES or configured).

---

# --------------------------------------
# 15. HOW TO USE THIS FILE

When starting a new ChatGPT session:

> "Load this ERP context file. Continue from where we left off."

Paste the whole content and ChatGPT will recover the architecture.

---

# --------------------------------------
# 16. NEXT STEPS

You may request:
- System-wide flow review
- Treasury redesign
- API specification
- Microservice boundaries
- Diagrams (dbdiagram, Mermaid, PlantUML)
- Performance optimization

---

## Operational note (Collection sessions vs. nightly journal entry)
- The nightly accounting job generates **1 journal entry per CLOSED `collection_session`** (per branch and currency).
- If a `collection_session` remains OPEN, the nightly job **skips that branch/currency** until it is manually closed.
- Digital movements created before opening a session are **assigned to the session** once it is opened, so they are included in that day's journal entry.
