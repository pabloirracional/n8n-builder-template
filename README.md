# n8n-builder

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![n8n](https://img.shields.io/badge/n8n-workflow%20automation-EA4B71?logo=n8n&logoColor=white)](https://n8n.io/)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-6B4FBB?logo=anthropic&logoColor=white)](https://claude.com/claude-code)
[![MCP](https://img.shields.io/badge/Docker%20Desktop-MCP%20Toolkit-2496ED?logo=docker&logoColor=white)](https://www.docker.com/products/mcp-toolkit/)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/pabloirracional/n8n-builder/pulls)


A project template for building and maintaining [n8n](https://n8n.io/) automations with **Claude Code**, using an MCP server ([n8n-mcp](https://github.com/czlonkowski/n8n-mcp)) to read and write workflows directly on your own n8n instance.

The idea is for this to be a starting point: clone/copy this repository, point the MCP server at your own n8n instance, and Claude Code already knows how to organize, document, and edit automations following a consistent structure.

## How it works

1. **Claude Code** is the agent that reads/edits the files in this repo.
2. An **MCP server (n8n-mcp)**, running via Docker Desktop's MCP Toolkit (or any other MCP host you prefer), connects Claude Code to your n8n instance's API.
3. Your n8n API URL and API key are configured **in the MCP server's connection settings**, never in this repository.
4. Each automation becomes a folder under `workflows/<slug>/`, containing:
   - `workflow.json`: the standard n8n workflow export (nodes, connections, parameters, credentials referenced by name).
   - `CLAUDE.md`: documentation for that automation, covering purpose, trigger, flow, external services, required credentials, field/ID mappings, known issues, and a change log.
5. The root `CLAUDE.md` holds the instructions Claude Code follows automatically while working in this project (node conventions, credentials policy, how to sync with n8n, etc.).
6. `.claude/agents/n8n-builder.md` defines a subagent specialized in creating/editing/debugging n8n workflow JSON, and Claude Code routes workflow-editing tasks to it.

## Structure

```
n8n-builder/
  CLAUDE.md                    # project-wide instructions for Claude Code
  README.md                    # this file
  .claude/
    agents/n8n-builder.md      # subagent for editing/debugging workflows
  workflows/
    _template/
      CLAUDE.md                # template for documenting a new automation
    <automation-slug>/
      CLAUDE.md
      workflow.json
```

## Getting started

1. Clone this repository.
2. Set up an n8n MCP server pointing at your n8n instance's URL and API key, in the MCP server's own configuration, **not** in this repo. **Recommended:** run [n8n-mcp](https://github.com/czlonkowski/n8n-mcp) through **Docker Desktop's MCP Toolkit**. Besides handling the connection, it also ships the node documentation/context tools, which make a real difference: the agent understands node parameters, types, and options far better than with a bare API connection, and produces more correct workflows as a result.
3. Open the project in Claude Code. The n8n tools show up automatically (as `mcp__*` tools) once the MCP server is connected.
4. To start a new automation: copy `workflows/_template/CLAUDE.md` into `workflows/<slug>/CLAUDE.md` and ask Claude Code to build the workflow. It fills in the `CLAUDE.md` and creates/edits `workflow.json` as the work progresses.
5. To edit an existing automation: ask Claude Code to pull the current workflow from n8n first, then validate and push changes back once verified.

## Credentials policy

- **No credentials, API keys, or secrets are stored in this repository.**
- Credentials are created manually in the n8n UI and referenced in workflows **only by the name** they're saved under there (e.g. `"name": "My API Connection"`).
- If a workflow needs a credential that doesn't exist yet, that's flagged in the automation's `CLAUDE.md` (under "Credentials required") for you to create/assign in the n8n UI.
- If an existing workflow has a hardcoded secret instead of a proper credential, that should be flagged, not silently fixed, since it may require coordinating a key rotation.

## Status

This repository has been cleaned up to serve as a shareable template: it keeps only `workflows/_template/` as the model to copy from. Real automations built from this template live in their own environment/use case.

## License

[MIT](LICENSE)
