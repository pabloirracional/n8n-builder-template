# n8n-builder

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![n8n](https://img.shields.io/badge/n8n-workflow%20automation-EA4B71?logo=n8n&logoColor=white)](https://n8n.io/)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-6B4FBB?logo=anthropic&logoColor=white)](https://claude.com/claude-code)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/pabloirracional/n8n-builder-template/pulls)


A project template for building and maintaining [n8n](https://n8n.io/) automations with **Claude Code**. Workflows are read and written on your own n8n instance **directly through the n8n public API**, using a small script and a local, gitignored `.env`.

The idea is for this to be a starting point: clone/copy this repository, point it at your own n8n instance, and Claude Code already knows how to organize, document, and edit automations following a consistent structure.

## How it works

1. **Claude Code** is the agent that reads/edits the files in this repo.
2. **By default, workflow reads/writes go straight to the n8n public API** through `scripts/n8n-api.ps1`. It loads `N8N_API_URL` and `N8N_API_KEY` from a local `.env` (never committed, never read by Claude) and masks the key in everything it prints.
3. Each automation becomes a folder under `workflows/<slug>/`, containing:
   - `workflow.json`: the standard n8n workflow export (nodes, connections, parameters, credentials referenced by name).
   - `CLAUDE.md`: documentation for that automation, covering purpose, trigger, flow, external services, required credentials, field/ID mappings, known issues, and a change log.
4. The root `CLAUDE.md` holds the instructions Claude Code follows automatically while working in this project (node conventions, security rules, how to sync with n8n, etc.).
5. `.claude/agents/n8n-builder.md` defines a subagent specialized in creating/editing/debugging n8n workflow JSON, and Claude Code routes workflow-editing tasks to it.
6. **Alternative:** instead of the script, you can connect through an MCP server ([n8n-mcp](https://github.com/czlonkowski/n8n-mcp)) in Docker Desktop's MCP Toolkit, which also reads and writes workflows and adds node documentation tools. See [Alternative: n8n-mcp via Docker](#alternative-n8n-mcp-via-docker).

## Structure

```
n8n-builder/
  CLAUDE.md                    # project-wide instructions for Claude Code
  README.md                    # this file
  LICENSE
  .env.example                 # copy to .env and fill in (.env is gitignored)
  .gitignore
  scripts/
    n8n-api.ps1                # calls the n8n public API using .env
  .claude/
    settings.json              # deny rules so Claude's file tools can't open .env
    agents/n8n-builder.md      # subagent for editing/debugging workflows
  workflows/
    _template/
      CLAUDE.md                # template for documenting a new automation
    <automation-slug>/
      CLAUDE.md
      workflow.json
```

## Requirements

- An n8n instance with the public API enabled, and an API key (n8n: **Settings > n8n API**).
- **PowerShell**: Windows PowerShell 5.1 (built into Windows) or [PowerShell 7](https://github.com/PowerShell/PowerShell) (`pwsh`, also on macOS/Linux).
- **Node.js**, used to build the JSON bodies for create/update calls.
- [Claude Code](https://claude.com/claude-code).

## Getting started

1. Clone this repository.
2. Default setup (direct API; for the MCP route see [Alternative](#alternative-n8n-mcp-via-docker)): copy `.env.example` to `.env` and fill in `N8N_API_URL` and `N8N_API_KEY` **yourself, in your editor**. Don't paste the key into the Claude Code chat.
3. Check it works:
   ```
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/n8n-api.ps1 -Method GET -Path "workflows?limit=1"
   ```
   (use `pwsh -File ...` on macOS/Linux). Exit code 3 means `.env` is missing or empty.
4. Open the project in Claude Code.
5. To start a new automation: copy `workflows/_template/CLAUDE.md` into `workflows/<slug>/CLAUDE.md` and ask Claude Code to build the workflow. It fills in the `CLAUDE.md` and creates/edits `workflow.json` as the work progresses.
6. To edit an existing automation: ask Claude Code to pull the current workflow from n8n first, then validate and push changes back once verified. Note that updating an **active** workflow publishes the change immediately.

## Security

- **The n8n API key lives only in your local `.env`.** `.env` and `.env.*` are gitignored; only `.env.example` (with no key) is versioned.
- Claude never reads `.env`: only `scripts/n8n-api.ps1` loads it, and the script replaces the key with `***` in any output.
- `.claude/settings.json` denies Claude's `Read`/`Edit`/`Write` tools on `.env`. Those rules don't cover shell commands, so the root `CLAUDE.md` also forbids reading it from the shell. If you want stricter protection, add shell deny rules in your own `.claude/settings.local.json`.
- If the key ever ends up in a commit, chat, or log, revoke it in n8n and create a new one.

## Credentials policy

- **No credentials, API keys, or secrets are stored in this repository.**
- Workflow credentials are created manually in the n8n UI and referenced in workflows **only by the name** they're saved under there (e.g. `"name": "My API Connection"`).
- If a workflow needs a credential that doesn't exist yet, that's flagged in the automation's `CLAUDE.md` (under "Credentials required") for you to create/assign in the n8n UI.
- If an existing workflow has a hardcoded secret instead of a proper credential, that should be flagged, not silently fixed, since it may require coordinating a key rotation.

## Alternative: n8n-mcp via Docker

Instead of the direct API, you can connect Claude Code to n8n through [n8n-mcp](https://github.com/czlonkowski/n8n-mcp) running in [Docker Desktop's MCP Toolkit](https://www.docker.com/products/mcp-toolkit/). The n8n URL and API key go in that server's config inside Docker (not in this repo, and no `.env` needed), and Claude Code gets tools to read/write workflows plus node documentation tools (`search_nodes`, `get_node_essentials`, `validate_node_operation`, ...).

This used to be the default. In recent tests it no longer makes as big a difference as it did, and the direct API is simpler, so the script is now the default. Things to know if you choose the MCP route:

- The Docker catalog image (`mcp/n8n:latest`) lags well behind upstream n8n-mcp.
- Its `n8n_update_partial_workflow` fails against recent n8n versions; `n8n_update_full_workflow` works.
- It may report false `typeVersion` errors on newer nodes, and its CRUD tools can fail with `AUTHENTICATION_ERROR` or on very large workflows.
- For an up-to-date version, build a custom image from upstream and point the Docker profile at it.

You can also combine both: the direct API for reads/writes and the MCP only for its node documentation tools.

## Status

This repository is a shareable template: it keeps only `workflows/_template/` as the model to copy from. Real automations built from it live in their own copies.

## License

[MIT](LICENSE)
