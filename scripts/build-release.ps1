<#
.SYNOPSIS
    Builds OpenOrderbookSignerMcp and OpenOrderbookAi binaries for all platforms
    and stages them into the openorderbook-mcp releases/ folder.

.DESCRIPTION
    Publishes the signer and AI agent as self-contained single-file executables
    for each target runtime, then copies only the release-tracked artefacts
    (binaries + contract ABIs) into releases/<rid>/.

    Pass -SkipBuild to copy only the contract JSONs and docs without
    rebuilding binaries (useful when only docs/contracts changed).

.PARAMETER TalkethRoot
    Path to the talketh.io repo root. Defaults to c:\dev\talketh.io.

.PARAMETER SkipBuild
    Skip dotnet publish; only refresh contract ABIs and verify.
#>
param(
    [string]$TalkethRoot = "c:\dev\talketh.io",
    [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Paths ───────────────────────────────────────────────────────────────────
$RepoRoot       = Split-Path -Parent $PSScriptRoot          # openorderbook-mcp root
$SignerProject  = Join-Path $TalkethRoot "scripts\OpenOrderbookSignerMcp\OpenOrderbookSignerMcp.csproj"
$AiProject      = Join-Path $TalkethRoot "OpenOrderbookAi\OpenOrderbookAi.csproj"
$ReleasesDir    = Join-Path $RepoRoot "releases"
$TempPublishDir = Join-Path $env:TEMP "oob-mcp-publish"

# Runtime IDs and binary names
$Platforms = @(
    @{ Rid = "linux-x64";   SignerBinary = "OpenOrderbookSignerMcp";     AiBinary = "openorderbook-ai" }
    @{ Rid = "osx-arm64";   SignerBinary = "OpenOrderbookSignerMcp";     AiBinary = "openorderbook-ai" }
    @{ Rid = "osx-x64";     SignerBinary = "OpenOrderbookSignerMcp";     AiBinary = "openorderbook-ai" }
    @{ Rid = "win-x64";     SignerBinary = "OpenOrderbookSignerMcp.exe"; AiBinary = "openorderbook-ai.exe" }
)

# Contract ABI files to copy (relative to publish output)
$ContractFiles = @(
    "Contracts\Multilisting\Artifacts\EventContract.json"
    "Contracts\Multilisting\Artifacts\Feeless.json"
)

# ── Validation ──────────────────────────────────────────────────────────────
if (-not (Test-Path $SignerProject)) {
    Write-Error "Signer project not found at $SignerProject.`nSet -TalkethRoot to the talketh.io repo root."
}
if (-not (Test-Path $AiProject)) {
    Write-Error "AI project not found at $AiProject.`nSet -TalkethRoot to the talketh.io repo root."
}
if (-not (Test-Path $ReleasesDir)) {
    Write-Error "releases/ directory not found at $ReleasesDir.`nRun from the openorderbook-mcp repo."
}

# ── Build ───────────────────────────────────────────────────────────────────
if (-not $SkipBuild) {
    Write-Host "`n=== Publishing signer for all platforms ===" -ForegroundColor Cyan

    foreach ($p in $Platforms) {
        $rid = $p.Rid
        $outDir = Join-Path $TempPublishDir "signer\$rid"

        Write-Host "`n--- signer: $rid ---" -ForegroundColor Yellow
        dotnet publish $SignerProject `
            --configuration Release `
            --runtime $rid `
            --self-contained true `
            /p:PublishSingleFile=true `
            --output $outDir

        if ($LASTEXITCODE -ne 0) {
            Write-Error "dotnet publish failed for signer/$rid (exit code $LASTEXITCODE)"
        }

        # Copy binary
        $srcBin = Join-Path $outDir $p.SignerBinary
        $dstBin = Join-Path $ReleasesDir "$rid\$($p.SignerBinary)"
        if (-not (Test-Path $srcBin)) {
            Write-Error "Expected binary not found: $srcBin"
        }
        Copy-Item $srcBin $dstBin -Force
        $sizeMB = [math]::Round((Get-Item $dstBin).Length / 1MB, 1)
        Write-Host "  Copied $($p.SignerBinary) ($sizeMB MB)" -ForegroundColor Green

        # Copy contract ABIs
        foreach ($cf in $ContractFiles) {
            $srcCf = Join-Path $outDir $cf
            $dstCf = Join-Path $ReleasesDir "$rid\$cf"
            $dstDir = Split-Path $dstCf -Parent
            if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Path $dstDir -Force | Out-Null }
            if (Test-Path $srcCf) {
                Copy-Item $srcCf $dstCf -Force
                Write-Host "  Copied $cf" -ForegroundColor Green
            } else {
                Write-Warning "Contract ABI not found in publish output: $srcCf"
            }
        }
    }

    Write-Host "`n=== Publishing AI agent for all platforms ===" -ForegroundColor Cyan

    foreach ($p in $Platforms) {
        $rid = $p.Rid
        $outDir = Join-Path $TempPublishDir "ai\$rid"

        Write-Host "`n--- ai: $rid ---" -ForegroundColor Yellow
        dotnet publish $AiProject `
            --configuration Release `
            --runtime $rid `
            --self-contained true `
            /p:PublishSingleFile=true `
            --output $outDir

        if ($LASTEXITCODE -ne 0) {
            Write-Error "dotnet publish failed for ai/$rid (exit code $LASTEXITCODE)"
        }

        # Copy binary
        $srcBin = Join-Path $outDir $p.AiBinary
        $dstBin = Join-Path $ReleasesDir "$rid\$($p.AiBinary)"
        if (-not (Test-Path $srcBin)) {
            Write-Error "Expected AI binary not found: $srcBin"
        }
        Copy-Item $srcBin $dstBin -Force
        $sizeMB = [math]::Round((Get-Item $dstBin).Length / 1MB, 1)
        Write-Host "  Copied $($p.AiBinary) ($sizeMB MB)" -ForegroundColor Green
    }

    # Clean up temp publish output
    Write-Host "`nCleaning temp publish directory..." -ForegroundColor Gray
    Remove-Item -Recurse -Force $TempPublishDir -ErrorAction SilentlyContinue
}

# ── Verify ──────────────────────────────────────────────────────────────────
Write-Host "`n=== Verification ===" -ForegroundColor Cyan

$allGood = $true

foreach ($p in $Platforms) {
    $rid = $p.Rid

    # Check signer binary
    $binPath = Join-Path $ReleasesDir "$rid\$($p.SignerBinary)"
    if (Test-Path $binPath) {
        $sizeMB = [math]::Round((Get-Item $binPath).Length / 1MB, 1)
        if ($sizeMB -lt 50) {
            Write-Warning "$rid signer is only $sizeMB MB — expected > 50 MB for single-file publish"
            $allGood = $false
        } else {
            Write-Host "  [OK] $rid/$($p.SignerBinary) ($sizeMB MB)" -ForegroundColor Green
        }
    } else {
        Write-Warning "$rid signer binary missing: $binPath"
        $allGood = $false
    }

    # Check AI binary
    $aiBinPath = Join-Path $ReleasesDir "$rid\$($p.AiBinary)"
    if (Test-Path $aiBinPath) {
        $sizeMB = [math]::Round((Get-Item $aiBinPath).Length / 1MB, 1)
        if ($sizeMB -lt 10) {
            Write-Warning "$rid AI agent is only $sizeMB MB — expected > 10 MB for single-file publish"
            $allGood = $false
        } else {
            Write-Host "  [OK] $rid/$($p.AiBinary) ($sizeMB MB)" -ForegroundColor Green
        }
    } else {
        Write-Warning "$rid AI binary missing: $aiBinPath"
        $allGood = $false
    }

    # Check contract ABIs
    foreach ($cf in $ContractFiles) {
        $cfPath = Join-Path $ReleasesDir "$rid\$cf"
        if (Test-Path $cfPath) {
            Write-Host "  [OK] $rid/$cf" -ForegroundColor Green
        } else {
            Write-Warning "$rid contract ABI missing: $cf"
            $allGood = $false
        }
    }
}

# Check docs exist
$RequiredDocs = @("ARCHITECTURE.md", "SETUP-MACOS.md", "SETUP-WINDOWS.md", "SKILL.md", "TOOLS-REFERENCE.md")
$docsDir = Join-Path $RepoRoot "docs"
foreach ($doc in $RequiredDocs) {
    $docPath = Join-Path $docsDir $doc
    if (Test-Path $docPath) {
        Write-Host "  [OK] docs/$doc" -ForegroundColor Green
    } else {
        Write-Warning "Doc missing: docs/$doc"
        $allGood = $false
    }
}

# Show git status summary
Write-Host "`n--- Git Status (modified/untracked in releases/ and docs/) ---" -ForegroundColor Yellow
Push-Location $RepoRoot
$status = git status --short -- releases/ docs/
if ($status) {
    $status | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Host "  (no changes)" -ForegroundColor Gray
}
Pop-Location

# Final result
if ($allGood) {
    Write-Host "`n=== RELEASE STAGED SUCCESSFULLY ===" -ForegroundColor Green
    Write-Host "Review changes with:  git -C $RepoRoot diff --stat"
    Write-Host "Commit with:          git -C $RepoRoot add -A; git -C $RepoRoot commit -m 'Release update'"
} else {
    Write-Host "`n=== RELEASE HAS WARNINGS — review above ===" -ForegroundColor Red
}
