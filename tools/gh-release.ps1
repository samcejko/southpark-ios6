# Publishes a GitHub release through the REST API: tag v<Version> at <Sha>, the CHANGELOG section as the notes,
# the IPA and DEB of a downloaded CI run (packages\run-<id>) as assets, with their SHA-256 sums in the notes.
# Usage: .\tools\gh-release.ps1 -RunDir .\packages\run-123 -Sha <commit> [-Version 0.1.0] [-Repo owner/name] [-Token ghp_xxx] [-DryRun]
param(
    [Parameter(Mandatory = $true)][string]$RunDir,
    [Parameter(Mandatory = $true)][string]$Sha,
    [string]$Version = '',
    [string]$Repo = '',
    [string]$Token = $env:GH_TOKEN,
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$localCfg = Join-Path $PSScriptRoot 'local.json'
if (Test-Path $localCfg) {
    $cfg = Get-Content $localCfg -Raw | ConvertFrom-Json
    if (-not $Repo -and $cfg.repo) { $Repo = $cfg.repo }
    if (-not $Token -and $cfg.token) { $Token = $cfg.token }
}
if (-not $Repo) { throw 'No repository (-Repo or tools/local.json)' }
if (-not $Token) { throw 'No token (-Token, GH_TOKEN or tools/local.json)' }
if (-not $Version) {
    $control = Get-Content (Join-Path $root 'control') | Where-Object { $_ -match '^Version:\s*(.+)$' } | Select-Object -First 1
    if ($control -match '^Version:\s*(.+)$') { $Version = $Matches[1].Trim() } else { throw 'Version not found in control' }
}
$tag = "v$Version"

$assets = @(Get-ChildItem $RunDir -File | Where-Object { $_.Extension -in '.ipa', '.deb' })
if (-not $assets) { throw "No .ipa/.deb in $RunDir" }

$changelog = Get-Content (Join-Path $root 'CHANGELOG.md') -Raw -Encoding UTF8
$section = ''
if ($changelog -match "(?s)## $([regex]::Escape($Version))[^\n]*\n(.*?)(\n## |\z)") { $section = $Matches[1].Trim() }
$sums = $assets | ForEach-Object { "- ``$($_.Name)`` - SHA-256 ``$((Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower())``" }
$install = '**Installation (jailbroken iOS 6):** the IPA through `ipainstaller -f CityVOD-{0}.ipa` (AppSync Unified), the DEB through `dpkg -i` followed by `su mobile -c uicache`. Both carry the same build; favourites and settings survive switching from one to the other. **iOS 14-17 (arm64, iPhone X and newer):** the `iphoneos-arm64` DEB for rootless jailbreaks (open it in Sileo or Zebra, or `dpkg -i`), the `-arm64.ipa` for TrollStore.' -f $Version
$notes = ($section, '', $install, '', '**Checksums**', ($sums -join "`n")) -join "`n"

Write-Host "Release $tag of $Repo at $($Sha.Substring(0, [Math]::Min(7, $Sha.Length)))"
Write-Host "Assets: $(($assets | ForEach-Object { $_.Name }) -join ', ')"
Write-Host "--- notes ---`n$notes`n-------------"
if ($DryRun) { Write-Host 'Dry run: nothing published.'; exit 0 }

$headers = @{ Authorization = "Bearer $Token"; Accept = 'application/vnd.github+json'; 'User-Agent' = 'cityvod-tools'; 'X-GitHub-Api-Version' = '2022-11-28' }
$api = "https://api.github.com/repos/$Repo"

$release = $null
try { $release = Invoke-RestMethod -Uri "$api/releases/tags/$tag" -Headers $headers -TimeoutSec 60 } catch { $release = $null }
if (-not $release) {
    $body = @{ tag_name = $tag; target_commitish = $Sha; name = "City VOD $Version"; body = $notes; draft = $false; prerelease = $false } | ConvertTo-Json
    $release = Invoke-RestMethod -Method Post -Uri "$api/releases" -Headers $headers -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) -TimeoutSec 60
    Write-Host "Created release $($release.id)"
} else {
    $body = @{ body = $notes; name = "City VOD $Version" } | ConvertTo-Json
    $release = Invoke-RestMethod -Method Patch -Uri "$api/releases/$($release.id)" -Headers $headers -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) -TimeoutSec 60
    Write-Host "Updated release $($release.id)"
}

# Upload assets
foreach ($asset in $assets) {
    $name = $asset.Name
    $existing = $release.assets | Where-Object { $_.name -eq $name } | Select-Object -First 1
    if ($existing) {
        Write-Host "Deleting existing asset $($existing.name) ($($existing.id))"
        Invoke-RestMethod -Method Delete -Uri "$api/releases/assets/$($existing.id)" -Headers $headers -TimeoutSec 60 | Out-Null
    }
    Write-Host "Uploading $name ($([math]::Round($asset.Length/1KB)) KB)"
    $uploadUri = "https://uploads.github.com/repos/$Repo/releases/$($release.id)/assets?name=$name"
    $bytes = [IO.File]::ReadAllBytes($asset.FullName)
    $uploadHeaders = @{ Authorization = "Bearer $Token"; Accept = 'application/vnd.github+json'; 'User-Agent' = 'cityvod-tools' }
    Invoke-RestMethod -Method Post -Uri $uploadUri -Headers $uploadHeaders -ContentType 'application/octet-stream' -Body $bytes -TimeoutSec 300 | Out-Null
}

Write-Host "Release published: $($release.html_url)"
