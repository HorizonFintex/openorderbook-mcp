<#
.SYNOPSIS
    Creates a new Task work item on a HorizonCall sprint.

.DESCRIPTION
    Creates a Task in Azure DevOps with standard defaults (Activity=Development,
    Priority=2, Effort=7, Tags=mcp). Requires the azure-devops CLI extension
    and an active `az login` session.

.PARAMETER Title
    The task title. Will be used as-is (add "MCP: " prefix yourself if needed).

.PARAMETER Sprint
    Sprint number (e.g. 225). The script resolves the full iteration path.

.PARAMETER AssignedTo
    Email of the assignee. Defaults to andrew.legear@horizon-globex.ie.

.PARAMETER Effort
    Story points / effort. Defaults to 7.

.PARAMETER Priority
    Priority (1-4). Defaults to 2.

.PARAMETER Tags
    Comma-separated tags. Defaults to "mcp".

.PARAMETER Activity
    Activity type. Defaults to "Development".

.EXAMPLE
    .\scripts\create-task.ps1 -Title "MCP: Local Signer" -Sprint 225
    .\scripts\create-task.ps1 -Title "MCP: New Feature" -Sprint 226 -Effort 13
    .\scripts\create-task.ps1 -Title "MCP: Fix Bug" -Sprint 225 -AssignedTo "someone@horizon-globex.ie"
#>

param(
    [Parameter(Mandatory)]
    [string]$Title,

    [Parameter(Mandatory)]
    [int]$Sprint,

    [string]$AssignedTo = 'andrew.legear@horizon-globex.ie',

    [double]$Effort = 7,

    [int]$Priority = 2,

    [string]$Tags = 'mcp',

    [string]$Activity = 'Development'
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

$iterationPath = ($match | Select-Object -First 1).Trim()
Write-Host "Found: $iterationPath" -ForegroundColor Green

# --- Create work item ---
Write-Host "Creating task: $Title" -ForegroundColor Cyan

$result = az boards work-item create `
    --type Task `
    --title $Title `
    --org $Org `
    -p $Project `
    --assigned-to $AssignedTo `
    --iteration $iterationPath `
    --area $Project `
    --fields "Microsoft.VSTS.Common.Activity=$Activity" `
             "Microsoft.VSTS.Common.Priority=$Priority" `
             "Microsoft.VSTS.Scheduling.Effort=$Effort" `
             "Microsoft.VSTS.Scheduling.OriginalEstimate=$Effort" `
             "Microsoft.VSTS.Scheduling.RemainingWork=$Effort" `
             "System.Tags=$Tags" `
    --output json 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to create work item: $result"
    exit 1
}

$item = $result | ConvertFrom-Json
$id = $item.id

Write-Host ""
Write-Host "Created task #$id" -ForegroundColor Green
Write-Host "  Title:    $Title"
Write-Host "  Sprint:   $iterationPath"
Write-Host "  Assigned: $AssignedTo"
Write-Host "  Effort:   $Effort"
Write-Host "  Priority: $Priority"
Write-Host "  Tags:     $Tags"
Write-Host "  URL:      https://horizonglobex.visualstudio.com/HorizonCall/_workitems/edit/$id"
