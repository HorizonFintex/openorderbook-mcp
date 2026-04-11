# Azure DevOps Sprint Management Skill

Use this skill when the user asks about sprint work items, creating tasks, or managing Azure DevOps work items for the HorizonCall project.

## When to Use
- User asks to **query**, **list**, or **show** sprint items (tasks, bugs, stories)
- User asks to **create a task** or work item on a sprint
- User asks about sprint status, done items, or in-progress work
- User mentions Azure DevOps, sprints, or work items in the HorizonCall context

## Prerequisites
- Azure CLI with `azure-devops` extension installed (`az extension add --name azure-devops`)
- Active login: `az login` (AAD/MSA) — must include DevOps scopes
- Org: `https://dev.azure.com/horizonglobex`
- Project: `HorizonCall`
- Team: `HorizonCall Team`

## Scripts

### Query Sprint Items
**Script**: `scripts/query-sprint.ps1`

```powershell
# All items in a sprint
.\scripts\query-sprint.ps1 -Sprint 225

# Only Done items
.\scripts\query-sprint.ps1 -Sprint 225 -State Done

# In-progress bugs only
.\scripts\query-sprint.ps1 -Sprint 225 -State "In Progress" -Type Bug
```

**Parameters**:
| Parameter | Required | Description |
|-----------|----------|-------------|
| `-Sprint` | Yes | Sprint number (e.g. 225) |
| `-State` | No | Filter: Done, To Do, In Progress |
| `-Type` | No | Filter: Task, Bug, User Story |

### Create a Task
**Script**: `scripts/create-task.ps1`

```powershell
# Basic task with defaults (Effort=7, Priority=2, Tags=mcp, Activity=Development)
.\scripts\create-task.ps1 -Title "MCP: Local Signer" -Sprint 225

# Custom effort and assignee
.\scripts\create-task.ps1 -Title "MCP: New Feature" -Sprint 226 -Effort 13 -AssignedTo "someone@horizon-globex.ie"
```

**Parameters**:
| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `-Title` | Yes | — | Task title (include "MCP: " prefix for MCP work) |
| `-Sprint` | Yes | — | Sprint number |
| `-AssignedTo` | No | andrew.legear@horizon-globex.ie | Assignee email |
| `-Effort` | No | 7 | Story points |
| `-Priority` | No | 2 | Priority (1-4) |
| `-Tags` | No | mcp | Comma-separated tags |
| `-Activity` | No | Development | Activity type |

## Important Rules
- **Always use the scripts** instead of raw `az boards` commands — they handle iteration path resolution automatically (sprint names have date suffixes like "Sprint 225 - Mar 25th to Apr 8th").
- **Effort must be set** for tasks to be marked as Done. Default is 7.
- **Title prefix**: MCP-related tasks use "MCP: " prefix by convention.
- **Sprint resolution**: Scripts query the team iteration list and match by sprint number, so you only need the number, not the full path.

## Troubleshooting
- **"not authorized"**: Run `az login` to refresh authentication.
- **"Sprint not found"**: The sprint may not exist yet. Check available sprints with `az boards iteration team list --team "HorizonCall Team" --org https://dev.azure.com/horizonglobex -p HorizonCall --query "[].path" -o tsv`.
- **Extension missing**: Run `az extension add --name azure-devops --yes`.
