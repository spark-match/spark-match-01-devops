# =============================================================================
# create-pr.ps1 — Helper para crear PRs con body bien formateado
# =============================================================================
# Uso:
#   .\create-pr.ps1 -Base dev -Head feat/mi-feature `
#                   -Title "feat: mi feature" `
#                   -BodyFile .\pr-body.md `
#                   -Assignee ahincho `
#                   -Labels enhancement,infrastructure
#
# Por que existe:
#   `gh pr create --body` con texto inline a veces interpreta caracteres
#   especiales (em-dash, backticks, acentos) raro. La forma robusta es
#   escribir el body en un .md y pasarlo con --body-file. Ademas,
#   `gh api POST .../pulls --input pr-body.json` con `\n` literales
#   DENTRO del campo `body` los renderiza como texto literal en vez
#   de saltos de linea. Este script evita ambos problemas.
#
# Requisitos:
#   - gh CLI autenticado con cuenta que tenga push access al repo
#   - El branch HEAD debe estar pusheado al remote
# =============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$Base,

    [Parameter(Mandatory=$true)]
    [string]$Head,

    [Parameter(Mandatory=$true)]
    [string]$Title,

    [Parameter(Mandatory=$true)]
    [string]$BodyFile,

    [string]$Assignee = "",

    [string[]]$Labels = @(),

    [string]$Repo = ""
)

$ErrorActionPreference = "Stop"

# Validar que el body file existe
if (-not (Test-Path $BodyFile)) {
    Write-Error "Body file not found: $BodyFile"
    exit 1
}

# Auto-detectar repo si no se pasa
if (-not $Repo) {
    $remoteUrl = git remote get-url origin 2>&1
    if ($remoteUrl -match "github\.com[:/](.+?)/(.+?)\.git$") {
        $Repo = "$($Matches[1])/$($Matches[2])"
    } else {
        Write-Error "Cannot auto-detect repo from remote URL: $remoteUrl"
        exit 1
    }
}

Write-Host "=== Creating PR ===" -ForegroundColor Cyan
Write-Host "Repo:   $Repo"
Write-Host "Base:   $Base"
Write-Host "Head:   $Head"
Write-Host "Title:  $Title"
Write-Host "Body:   $BodyFile"
Write-Host "Assignee: $Assignee"
Write-Host "Labels: $($Labels -join ', ')"
Write-Host ""

# Argumentos para gh pr create
$ghArgs = @(
    "pr", "create",
    "--repo", $Repo,
    "--base", $Base,
    "--head", $Head,
    "--title", $Title,
    "--body-file", $BodyFile
)

if ($Assignee) {
    $ghArgs += @("--assignee", $Assignee)
}

if ($Labels.Count -gt 0) {
    $ghArgs += @("--label", ($Labels -join ","))
}

# Ejecutar gh pr create
& gh @ghArgs
$exitCode = $LASTEXITCODE

if ($exitCode -ne 0) {
    Write-Error "gh pr create failed with exit code $exitCode"
    exit $exitCode
}

# Recuperar el PR number del output
$prUrl = (& gh pr list --repo $Repo --head $Head --json url --jq '.[0].url' 2>&1)
if ($prUrl -match "/pull/(\d+)") {
    $prNumber = $Matches[1]
    Write-Host ""
    Write-Host "PR #$prNumber created: $prUrl" -ForegroundColor Green
    Write-Host ""
    Write-Host "Esperando checks..." -ForegroundColor Cyan

    $timeout = 600
    $elapsed = 0
    while ($elapsed -lt $timeout) {
        $status = gh pr view $prNumber --repo $Repo --json statusCheckRollup 2>&1 | ConvertFrom-Json
        $allDone = $true
        $pendingCount = 0
        if ($status.statusCheckRollup) {
            foreach ($c in $status.statusCheckRollup) {
                if ($c.status -eq "IN_PROGRESS" -or $c.status -eq "PENDING" -or $c.status -eq "QUEUED") {
                    $allDone = $false
                    $pendingCount++
                }
            }
        }
        if ($allDone) { break }
        Start-Sleep -Seconds 10
        $elapsed += 10
    }

    # Mostrar resultado final
    $final = gh pr view $prNumber --repo $Repo --json state,statusCheckRollup 2>&1 | ConvertFrom-Json
    Write-Host ""
    if ($final.statusCheckRollup) {
        $conclusions = $final.statusCheckRollup | ForEach-Object { "$($_.name)=$($_.conclusion)" }
        Write-Host "Checks: $($conclusions -join ', ')"
    }
    Write-Host "State: $($final.state)"
}

exit 0