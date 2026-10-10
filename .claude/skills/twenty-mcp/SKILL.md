---
name: twenty-mcp
description: Use Twenty CRM MCP at crm.lakshitukani.com — follow Plan → load_skills → learn_tools → execute_tool. Triggers on Twenty CRM, MCP, lakshitukani.com, workflows, dashboards, CRM data, or operating the deployed instance via MCP.
---

# Twenty CRM via MCP

Orchestrate the **production** Twenty workspace through MCP. Skill **content** lives in Twenty (Settings → AI → Skills) and is fetched with `load_skills` — do not copy skill bodies from this repo into prompts.

## Endpoint and config

| Item | Value |
| ---- | ----- |
| MCP URL | `https://crm.lakshitukani.com/mcp` |
| Auth | OAuth (recommended) or API key in `Authorization: Bearer …` |
| UI snippet | Twenty → **Settings → AI → More → MCP Server** |

Claude Code / Claude Desktop example (OAuth):

```json
{
  "mcpServers": {
    "twenty": {
      "type": "streamable-http",
      "url": "https://crm.lakshitukani.com/mcp"
    }
  }
}
```

Never commit API keys. Prefer `~/.claude.json` or project `.mcp.json` for secrets.

## Required workflow

For **any non-trivial** CRM task:

1. **`get_tool_catalog`** — discover tools allowed for this user/API key
2. **`load_skills`** — load domain playbooks from the workspace (see mapping below)
3. **`learn_tools`** — input schemas for tools you will call
4. **`execute_tool`** — run tools; follow skill + schema exactly

**Skip step 2** only for simple single-record CRUD (one find/create/update/delete).

Never guess tool names or parameters. Never paste skill markdown from `packages/twenty-server/.../skill-metadata/` — it may drift from production DB.

## Skills vs tools

| | Skills (`load_skills`) | Tools (`execute_tool`) |
| - | ---------------------- | ---------------------- |
| Purpose | HOW (schemas, patterns, pitfalls) | DO (API actions) |
| Source | Workspace DB (built-in + custom) | Tool catalog (250+) |
| Auto-loaded? | **No** — must call `load_skills` | **No** — learn then execute |

Built-in skill names in Twenty UI are **defaults** already in the workspace. MCP does not inject them on connect — call `load_skills` when the task needs them.

## Intent → skill mapping

| User intent | `load_skills` names |
| ----------- | ------------------- |
| Workflows, automation, triggers, cron | `workflow-building` |
| Dashboards, charts | `dashboard-building` |
| Custom objects/fields, schema | `metadata-building` |
| Search, filter, bulk records, relationships | `data-manipulation` |
| Views (layout) | `view-building` |
| View filters and sorts | `view-filters-and-sorts` |
| Python analysis, bulk ops, files | `code-interpreter` (often + `xlsx`) |
| Excel reports | `xlsx` |
| PDF / Word / PowerPoint | `pdf`, `docx`, `pptx` |
| Web research | `research` |
| Demo/sample data | `workspace-demo-seeding` |
| Remove custom objects safely | `custom-objects-cleanup` |

Load multiple skills when needed, e.g. `["xlsx", "code-interpreter"]` for Excel export via code interpreter.

Custom skills created in Twenty (Settings → AI → Skills) use the same `load_skills` mechanism — use their `name` field from the UI.

## Tool usage rules (from Twenty system prompts)

- Use **database tools** (`find_*`, `create_*`, `update_*`, `group_by_*`) for CRM data — not handcrafted API URLs
- **`http_request`** only for **external** APIs, not Twenty data
- Analytics (by/per/top/average/total): prefer **`group_by_*`** over large `find_*` pulls
- Keep limits small (5–10) until the user needs more; always filter
- Prefer batch tools (`create_many_*`, `update_many_*`) over loops
- On failure: read error, adjust args, retry; do not give up after one failure

## After `load_skills`

- Follow returned `content` markdown strictly
- Then `learn_tools` for each tool you will call
- Then `execute_tool` with validated arguments

## What this skill does not cover

- **Developing** the Twenty monorepo → use other `.claude/skills/` (e.g. syncable-entity, upstream-sync)
- **Duplicating** standard skill bodies locally — always `load_skills` from the server
- **In-app** Twenty chat system prompts — MCP only gets short server instructions plus tools; this skill supplies orchestration

## Verification

Ask: *"Load workflow-building, then list my workflows"* — confirm `load_skills` runs before `execute_tool`.

If `load_skills` returns empty names, list available skills from the error message or Twenty Settings → AI → Skills (skills must be **active**).
