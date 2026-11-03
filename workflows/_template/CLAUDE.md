# <Automation Name>

- **n8n workflow ID:** `<id>` (leave blank until created in n8n)
- **n8n workflow name:** `<exact name as it appears in n8n>`
- **Status:** draft | active | paused | deprecated
- **File:** `workflow.json` (kept in sync with the n8n instance, see "Syncing" below)

## Purpose

One or two sentences: what business problem this automation solves and who relies on it.

## Trigger

How the workflow starts: webhook (method + path), schedule/cron, manual, or triggered by another workflow.

## Flow overview

Numbered, high-level steps (not a node-by-node dump, that's what `workflow.json` is for):

1. ...
2. ...
3. ...

## External services

| Service | Used for | Base URL / notes |
|---|---|---|
| e.g. Example CRM API | Fetch order/deal details | `api.example-crm.com` |

## Credentials required

List credentials **by the name they must have inside n8n**. Never store keys/secrets/tokens here or in `workflow.json`. The person building the automation sets these up manually in the n8n UI, and Claude only references them by name.

| Credential name in n8n | Type | Used by node(s) |
|---|---|---|
| e.g. `Example CRM Connection` | OAuth2 (Example CRM) | `Example CRM - Fetch Deal`, ... |

If a credential referenced in `workflow.json` doesn't exist yet in n8n, flag it to the user instead of guessing or inventing one.

## External IDs / field mappings

Any CRM custom field IDs, status codes, or other magic constants baked into node parameters (e.g. a CRM's custom field IDs), with what they mean.

| ID/Constant | Meaning |
|---|---|
| | |

## Known issues / TODOs

- ...

## Syncing

- Pull before editing: `GET workflows/<id>` via `scripts/n8n-api.ps1` with `-OutFile workflows/<slug>/workflow.json`.
- Push after verifying: `PUT workflows/<id>` with a body holding only `name`, `nodes`, `connections`, `settings` (see "Connecting to n8n" in the root `CLAUDE.md`).
- If the workflow is active, a PUT publishes immediately.

## Change log

- `YYYY-MM-DD`: what changed and why.
