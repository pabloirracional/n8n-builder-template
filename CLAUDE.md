# n8n-builder

Project for building and maintaining n8n workflows.

## Status

Shareable template: it ships only `workflows/_template/` as the model to copy
from. Once real automations land under `workflows/<slug>/`, update this section
to describe what the project actually holds.

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
  Pull the latest via `scripts/n8n-api.ps1` (`GET workflows/<id>`) before
  editing, and push changes back (`PUT workflows/<id>`) once verified. See
  "Connecting to n8n" below.
- This structure applies going forward to automations we actively build or
  touch. Existing n8n workflows are not being backfilled into this structure
  automatically. Only pull one into `workflows/` when we start working on it.

## Connecting to n8n

There are two ways to connect Claude Code to n8n. Pick one per setup:

| Option | Status | How it connects |
|--------|--------|-----------------|
| Direct API (`.env` + `scripts/n8n-api.ps1`) | **Default** | The script calls the n8n public API with the URL and key from a local, gitignored `.env` |
| Docker Desktop MCP Toolkit (n8n-mcp) | Alternative | An n8n-mcp server in Docker holds the URL and key and exposes `mcp__MCP_DOCKER__*` tools to Claude Code |

Both cover the full job: list, get, create and update workflows, executions.
n8n-mcp also adds node documentation tools; in recent tests that no longer
makes as big a difference as it used to, which is why the direct API is now
the default.

Which one to use: if the user set up `.env`, use the direct API. If the
`mcp__MCP_DOCKER__n8n_*` tools are available and the user chose the MCP
route, use them. Don't mix both for writes on the same workflow in one task.

### Option 1 (default): Direct API (`.env` + `scripts/n8n-api.ps1`)

Requirements: PowerShell (Windows PowerShell 5.1 or PowerShell 7 `pwsh`) to run
the script, and Node.js to build PUT/POST bodies.

**Security rules for `.env`:**

- `.env` at the repo root holds `N8N_API_URL` and `N8N_API_KEY`. The user fills
  it in by hand from `.env.example`. It is gitignored (`.env`, `.env.*`), so it
  is never committed.
- **Never read, print, cat, type, grep, or edit `.env`, by any tool** (file
  tools or shell). Only the script loads it. `.claude/settings.json` ships deny
  rules for `Read`/`Edit`/`Write` on `.env`, but those don't cover shell
  commands, so this rule still has to be followed.
- Never paste the key into a command line, a body file, a workflow, or any
  other file. The script masks the key as `***` in everything it outputs.

**Usage** (paths are relative to `/api/v1`):

```
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/n8n-api.ps1 -Method GET -Path workflows/<id> -OutFile workflows/<slug>/workflow.json
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/n8n-api.ps1 -Method PUT -Path workflows/<id> -BodyFile <body.json>
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/n8n-api.ps1 -Method GET -Path "workflows?limit=250&excludePinnedData=true"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/n8n-api.ps1 -Method POST -Path workflows -BodyFile <body.json>
```

- `-Method` accepts `GET`, `POST`, `PUT`, `PATCH`, `DELETE`. Use `pwsh` instead
  of `powershell` on macOS/Linux. Treat `DELETE` as destructive and confirm with
  the user first.
- Exit codes: 0 ok, 1 HTTP error (status + body on stderr), 2 network error,
  3 `.env` missing or empty, 4 usage/local error (bad or missing argument,
  `-BodyFile` not found, `-OutFile` can't be written). On exit code 3, stop and
  ask the user to fill in `.env` from `.env.example`; don't try to work around
  it. On exit code 4, fix the command; except for an `-OutFile` write failure,
  nothing was sent to n8n.
- `-OutFile` creates its parent folder if needed (e.g. a new
  `workflows/<slug>/`).
- The public API has **no partial-update endpoint**. Every edit is
  GET → change locally → `PUT /workflows/:id` with the full workflow.
- `PUT /workflows/:id` is strict (`additionalProperties: false`, `name`
  required, even when unchanged): send only `name`, `nodes`, `connections`,
  `settings` (and `staticData` if needed), never the raw GET response. GET
  returns read-only fields the PUT rejects (`id`, `versionId`,
  `activeVersionId`, `versionCounter`, `activeVersion`, `triggerCount`,
  `isArchived`, `shared`, ...). Inside `settings`, drop `binaryMode` and
  `timeSavedMode` (returned by GET on recent n8n versions, rejected by PUT;
  n8n keeps their stored values). Build the body with a Node script, not
  PowerShell 5.1 `ConvertTo-Json` (it mangles nested JSON).
- Retry an execution: `POST executions/{id}/retry` with body `{"loadWorkflow":true}`
  (= "Retry with currently saved workflow"). Retry resumes from the failed node
  **by name**, so renaming/removing that node breaks retries of past failures.
- **A PUT on an active workflow publishes immediately** (`activeVersionId`
  becomes the new `versionId`). Before pushing, diff
  `nodes`/`connections` against `activeVersion` so unpublished draft changes
  don't go live by accident.

### Option 2 (alternative): Docker Desktop MCP Toolkit (n8n-mcp)

- Docker Desktop hosts a profile with the
  [n8n-mcp](https://github.com/czlonkowski/n8n-mcp) server connected to the n8n
  instance, plus Claude Code as a client of that same gateway. The n8n API URL
  and key live in that server's config inside Docker, not in this repo.
- Claude Code sees its tools as `mcp__MCP_DOCKER__*`: workflow CRUD and
  executions (`n8n_get_workflow`, `n8n_update_full_workflow`, ...) plus node
  knowledge (`search_nodes`, `get_node_essentials`, `get_node_documentation`,
  `search_node_properties`, `validate_node_operation`, templates). The node
  tools can also be used alongside Option 1 for lookups.
- **Known limitations of the Docker catalog image** (`mcp/n8n:latest`, which
  lags far behind upstream n8n-mcp):
  - `n8n_update_partial_workflow` fails against recent n8n with
    `request/body must NOT have additional properties`. Use
    `n8n_update_full_workflow` instead (it requires `name` even when
    unchanged);
  - it may report false `typeVersion` errors for nodes newer than its database
    (e.g. HTTP Request `typeVersion` above what it knows). A `typeVersion` it
    rejects may still be valid on the instance, so check an existing workflow
    there before downgrading anything;
  - its CRUD tools can fail with `AUTHENTICATION_ERROR` or on responses over
    ~1 MB. If that happens, the fix is in Docker Desktop's MCP Toolkit config,
    or switch to Option 1.
- For an up-to-date n8n-mcp, build a custom image from upstream and point the
  profile at it (`docker mcp catalog create`), which keeps the API key inside
  Docker. Don't run n8n-mcp via `npx` inside Claude Code's own config without
  the user's explicit go-ahead: that would move the n8n API key into Claude
  Code's settings.
- The same rules from Option 1 still apply: a write on an active workflow
  publishes immediately, and retries resume from the failed node by name.

## Credentials policy (important)

- **Never ask the user for API keys, tokens, or credential secrets, and never
  write them into any file in this repo.** The only exception is the n8n API
  key in the gitignored `.env` (Option 1), which the user fills in by hand and
  Claude never reads; with Option 2 the key lives in Docker instead. Workflow credentials are configured manually by the person
  building the automation, directly in the n8n UI.
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
