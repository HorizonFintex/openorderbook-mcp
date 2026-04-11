<#
.SYNOPSIS
    Queries Azure DevOps work items for a given sprint.

.DESCRIPTION
    Lists work items in a HorizonCall sprint, optionally filtered by state
    and/or work item type. Requires the azure-devops CLI extension and an
    active `az login` session.

.PARAMETER Sprint
    Sprint number (e.g. 225). The script resolves the full iteration path
    by querying the team's iteration list.

.PARAMETER State
    Filter by work item state (e.g. Done, To Do, In Progress). If omitted,
    returns all states.

.PARAMETER Type
    Filter by work item type (e.g. Task, Bug, User Story). If omitted,
    returns all types.

.EXAMPLE
    .\scripts\query-sprint.ps1 -Sprint 225
    .\scripts\query-sprint.ps1 -Sprint 225 -State Done
    .\scripts\query-sprint.ps1 -Sprint 225 -State "In Progress" -Type Bug
#>

param(
    [Parameter(Mandatory)]
    [int]$Sprint,

    [string]$State,

    [string]$Type
)

$ErrorActionPreference = 'Stop'

$Org     = 'https://dev.azure.com/horizonglobex'
$Project = 'HorizonCall'
$Team    = 'HorizonCall Team'

# --- Resolve full iteration path ---
Write-Host "Resolving iteration path for Sprint $Sprint..." -ForegroundColor Cyan

$iterations = az boards iteration team list `
    --team $Team --org $Org -p $Project `
    --query "[].path" -o tsv 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to list iterations. Are you logged in? Run: az login"
    exit 1
}

$match = $iterations | Where-Object { $_ -match "\\Sprint $Sprint " -or $_ -match "\\Sprint $Sprint$" }

if (-not $match) {
    Write-Error "Sprint $Sprint not found. Available sprints containing '$Sprint':"
    $iterations | Where-Object { $_ -match $Sprint } | ForEach-Object { Write-Host "  $_" }
    exit 1
}

# Take first match if multiple
$iterationPath = ($match | Select-Object -First 1).Trim()
Write-Host "Found: $iterationPath" -ForegroundColor Green

# --- Build WIQL ---
$conditions = @(
    "[System.IterationPath] = '$iterationPath'"
)

if ($State) {
    $conditions += "[System.State] = '$State'"
}

if ($Type) {
    $conditions += "[System.WorkItemType] = '$Type'"
}

$where = $conditions -join ' AND '
$wiql = "SELECT [System.Id], [System.WorkItemType], [System.Title], [System.AssignedTo], [System.State] FROM WorkItems WHERE $where ORDER BY [System.Id]"

Write-Host "Running query..." -ForegroundColor Cyan

# --- Execute ---
az boards query --wiql $wiql --org $Org -p $Project --output table 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Error "Query failed. Check your az login session."
    exit 1
}
