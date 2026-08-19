# n8n-builder

Project for building and maintaining n8n workflows.

## Status

Freshly set up, no workflow files yet. This file should be updated once real
workflow JSON exports and any supporting code land in the project.

## Working with this project

- Workflow definitions are n8n's standard workflow JSON export format (nodes,
  connections, parameters, credential references, settings).
- Never invent real credentials, API keys, or webhook URLs in workflow files.
  Use placeholders and flag anything the user needs to fill in via the n8n UI.
- When adding a node: give it a unique `id`, set `position` sensibly relative
  to neighboring nodes, and keep `typeVersion` aligned with the node type
  actually in use.
- When editing connections: wire them by node name, and re-check source/target
  names after any node rename; a stale name silently breaks the workflow.
- When debugging a failing workflow: read the whole JSON first (node types,
  connections, parameter expressions) before changing anything. Common causes
  of breakage: renamed nodes with stale connection references, missing
  required parameters, wrong `typeVersion`, malformed `{{ }}` expressions, or
  credentials referenced by name that don't exist in the file.

## Automation folder structure

Every automation we build or maintain gets its own folder under `workflows/`,
named as a kebab-case slug of the n8n workflow name:

```
workflows/
  <slug>/
    CLAUDE.md       # documentation for this specific automation
    workflow.json   # the n8n workflow export (nodes, connections, params)
```

- Start a new automation by copying `workflows/_template/CLAUDE.md` into the
  new `workflows/<slug>/` folder and filling it in as the workflow takes shape.
- `CLAUDE.md` inside each folder documents: purpose, trigger, high-level flow,
  external services touched, credentials required (by name only, see below),
  any CRM/external field-ID mappings baked into node parameters, known
  issues, and a short change log. Keep it updated as the workflow evolves;
  it's the context Claude reads before touching that automation again.
- `workflow.json` should stay in sync with what's actually deployed in n8n.
  Pull the latest via the n8n MCP tools (`n8n_get_workflow`) before editing,
  and push changes back (`n8n_update_partial_workflow` /
  `n8n_update_full_workflow`) once verified.
- This structure applies going forward to automations we actively build or
  touch. Existing n8n workflows are not being backfilled into this structure
  automatically. Only pull one into `workflows/` when we start working on it.

## MCP connection (Docker Desktop + n8n)

This project talks to n8n through an MCP server run via **Docker Desktop's MCP
Toolkit**, not through a direct API integration in this repo:

- Docker Desktop hosts a profile with the n8n-mcp server connected to our n8n
  instance, plus Claude Code as a client of that same gateway.
- The n8n API URL and API key are configured as that server's connection
  config inside Docker Desktop, not stored anywhere in this repository.
- Once configured, Claude Code sees the n8n tools automatically as
  `mcp__MCP_DOCKER__n8n_*` (workflow CRUD, validation, executions) plus node
  documentation/template tools from the same n8n-mcp server. No API key ever
  needs to be typed into Claude Code or committed to this repo. Docker holds
  the connection, Claude just uses the tools it exposes.
- If these tools are missing or the n8n connection looks broken, the fix is
  in Docker Desktop's MCP Toolkit (profile/server config), not in this repo's
  code, so check there before assuming the workflow files are the problem.

## Credentials policy (important)

- **Never ask the user for API keys, tokens, or credential secrets, and never
  write them into any file in this repo.** Credentials are configured
  manually by the person building the automation, directly in the n8n UI.
- Claude only ever references credentials **by the name they're saved under
  in n8n** (e.g. `"name": "Example CRM Connection"` in a node's
  `credentials` block). If a workflow needs a credential that doesn't exist
  yet, name it clearly in the node and in that automation's `CLAUDE.md` under
  "Credentials required," and tell the user to create/assign it in the n8n
  UI. Don't guess an ID or invent a placeholder secret.
- If a node in an existing workflow has a hardcoded secret (API key, token,
  etc.) directly in its parameters instead of a proper n8n credential, flag
  it. Don't silently leave it, and don't "fix" it without the user's
  go-ahead since it may require coordinating a key rotation.

## Agents

- `.claude/agents/n8n-builder.md`: subagent for building/editing/debugging
  n8n workflow JSON. Claude Code should route workflow-editing tasks to it.
