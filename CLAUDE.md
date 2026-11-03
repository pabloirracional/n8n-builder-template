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

The default is the **n8n public API, called directly** through
`scripts/n8n-api.ps1` with the URL and key from a local `.env`. An MCP server
(n8n-mcp via Docker Desktop) is an **optional** extra for node documentation;
in recent tests it adds much less than it used to, so nothing in this project
depends on it.

| Channel | Status | Used for |
|---------|--------|----------|
| Direct API (`.env` + `scripts/n8n-api.ps1`) | **Default, required** | All reads/writes on the instance: list, get, create, update workflows; executions and retries |
| Docker Desktop MCP Toolkit (n8n-mcp) | Optional | Node docs, properties, operations, templates, offline validation of node configs |

### Direct API (`.env` + `scripts/n8n-api.ps1`)

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
  3 `.env` missing or empty. On exit code 3, stop and ask the user to fill in
  `.env` from `.env.example`; don't try to work around it.
- `PUT /workflows/:id` is strict (`additionalProperties: false`, `name`
  required): send only `name`, `nodes`, `connections`, `settings` (and
  `staticData` if needed), never the raw GET response. Inside `settings`, drop
  `binaryMode` and `timeSavedMode` (returned by GET on recent n8n versions,
  rejected by PUT). Build the body with a Node script, not PowerShell 5.1
  `ConvertTo-Json` (it mangles nested JSON).
- Retry an execution: `POST executions/{id}/retry` with body `{"loadWorkflow":true}`
  (= "Retry with currently saved workflow"). Retry resumes from the failed node
  **by name**, so renaming/removing that node breaks retries of past failures.
- **A PUT on an active workflow publishes immediately.** Before pushing, diff
  `nodes`/`connections` against `activeVersion` so unpublished draft changes
  don't go live by accident.

### Optional: Docker Desktop MCP Toolkit (n8n-mcp)

- If configured, Docker Desktop hosts a profile with the
  [n8n-mcp](https://github.com/czlonkowski/n8n-mcp) server, and Claude Code sees
  its tools as `mcp__MCP_DOCKER__*`. If those tools aren't present, just work
  from the API and existing workflows on the instance.
- Use it only for node knowledge: `search_nodes`, `get_node_essentials`,
  `get_node_documentation`, `search_node_properties`, `validate_node_operation`,
  templates.
- **Don't use its `n8n_*` tools to read or write workflows.** The Docker
  catalog image (`mcp/n8n:latest`) lags far behind upstream n8n-mcp:
  - it may report false `typeVersion` errors for nodes newer than its database
    (e.g. HTTP Request `typeVersion` above what it knows);
  - its `n8n_update_partial_workflow` fails against recent n8n with
    `request/body must NOT have additional properties`;
  - its `n8n_*` CRUD tools can fail with `AUTHENTICATION_ERROR` or on
    responses over ~1 MB.

  Treat its node info as a hint, not ground truth: a `typeVersion` it rejects
  may still be valid on the instance, so check an existing workflow there
  before downgrading anything.
- For an up-to-date node database, build a custom image from upstream and
  point the profile at it (`docker mcp catalog create`).

## Credentials policy (important)

- **Never ask the user for API keys, tokens, or credential secrets, and never
  write them into any file in this repo.** The only exception is the n8n API
  key in the gitignored `.env`, which the user fills in by hand and Claude
  never reads. Workflow credentials are configured manually by the person
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
