# MCP Servers

This plugin ships 6 MCP servers that install automatically when the plugin is installed. Servers are defined in `.mcp.json`.

---

## Included servers

### Context7 — Up-to-date library docs

Resolves current documentation for any npm library directly into context. Prevents Claude from using stale APIs or patterns from its training data.

- **Package:** `@upstash/context7-mcp`
- **Credentials:** None required
- **Typical use:** "Use context7 to check drizzle-orm docs" / "How do I do X in Next.js 15?"

---

### ShadCN — UI components

Access the shadcn/ui component catalog with global registry support. Browse, explore, and integrate components.

- **Package:** `@krazor/shadcn-mcp`
- **Credentials:** None required
- **Typical use:** "What variants does the shadcn Button have?" / "Give me the Dialog component code"

---

### Fetch — Web content

Downloads and parses web content (HTML, JSON, PDFs) from any public URL. Useful for reading docs, external APIs, or reference pages.

- **Package:** `@modelcontextprotocol/server-fetch`
- **Credentials:** None required
- **Typical use:** "Fetch this URL and summarize the content" / "Read the changelog for this library"

---

### Figma — Designs and components

Reads Figma files: component structure, properties, design tokens, and layout. Used by the `figma-implement-design` and `figma-generate-design` skills.

- **Package:** `figma-mcp`
- **Required credentials:** `FIGMA_ACCESS_TOKEN`
- **How to get it:** Figma → Settings → Security → Personal Access Tokens
- **Typical use:** "Read this Figma frame and implement it"

---

### Postman — APIs and collections

Operates on the Postman API: workspaces, collections, requests, environments, and mock servers. Read, create, and run requests from Claude.

- **Package:** `@postman/postman-mcp-server`
- **Required credentials:** `POSTMAN_API_KEY`
- **How to get it:** Postman → Account → Settings → API Keys
- **Typical use:** "List my workspace collections" / "Run this request and give me the response"

---

### Chrome — Browser automation

Controls Google Chrome via the DevTools Protocol. Navigate pages, take screenshots, inspect the DOM, and execute JavaScript. Requires Chrome installed (macOS).

- **Package:** `chrome-mcp`
- **Credentials:** None required
- **Requirement:** Google Chrome installed on the system
- **Typical use:** "Open this URL and take a screenshot" / "Inspect the DOM for this element"

---

## Setting up credentials

Two servers require credentials: **Figma** (`FIGMA_ACCESS_TOKEN`) and **Postman** (`POSTMAN_API_KEY`).

The `.mcp.json` in this plugin uses variable expansion (`${VAR}`) — it never contains raw secrets. You supply the values through one of these methods:

### Option A — Claude Code local scope (recommended)

Run these commands once. Credentials are stored in `~/.claude.json` and never committed to version control:

```bash
claude mcp add --transport stdio --scope local \
  --env FIGMA_ACCESS_TOKEN=fig_xxxxxxxxxxxx \
  figma -- npx -y figma-mcp@latest

claude mcp add --transport stdio --scope local \
  --env POSTMAN_API_KEY=PMAK-xxxxxxxxxxxx \
  postman -- npx -y @postman/postman-mcp-server@latest
```

This creates a local-scoped entry that takes precedence over the plugin-provided server definition.

### Option B — Shell environment

Add to your shell profile (`~/.zshrc` or `~/.bashrc`) and restart Claude Code:

```bash
export FIGMA_ACCESS_TOKEN="fig_xxxxxxxxxxxx"
export POSTMAN_API_KEY="PMAK-xxxxxxxxxxxx"
```

Claude Code inherits environment variables from the shell that launched it, so `${FIGMA_ACCESS_TOKEN}` in `.mcp.json` resolves automatically.

### How to get the tokens

| Server | Where to generate |
|--------|------------------|
| Figma | figma.com → Settings → Security → **Personal Access Tokens** |
| Postman | postman.com → Account → Settings → **API Keys** |

### Verify servers are running

```bash
/mcp   # inside Claude Code — shows server status and available tools
```

---

## Troubleshooting

**MCP server won't start:**
Verify `npx` is available and Node.js ≥ 18 is installed.

**Figma / Postman returns 401:**
The API key expired or is incorrect. Generate a new one from the respective platform.

**Chrome MCP can't find the browser:**
Verify Chrome is installed at `/Applications/Google Chrome.app`. macOS only.

**Response contains too many tokens:**
All servers have `MAX_MCP_OUTPUT_TOKENS: 25000` set by default.
