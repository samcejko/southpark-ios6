# Helpers for talking to the jailbroken iPad over SSH (dot-source this file).
#   . .\tools\ipad.ps1
#   Invoke-IPad 'uname -a'
#   Install-IPadPackage -IpaPath .\packages\run-39023296320\CityVOD-0.1.0.ipa -DebPath .\packages\run-39023296320\com.samcejko.cityvod_0.1.0_iphoneos-arm.deb
#   Get-IPadCrashLogs
#   Get-IPadSyslog

$script:IPadKey = Join-Path $env:USERPROFILE '.ssh\ipad_ios6'
$script:IPadDefaultHost = ''
$script:IPadLocalCfg = Join-Path $PSScriptRoot 'local.json'
if (Test-Path $script:IPadLocalCfg) {
    try {
        $c = Get-Content $script:IPadLocalCfg -Raw | ConvertFrom-Json
        if ($c.ipad) { $script:IPadDefaultHost = $c.ipad }
    } catch {}
}

function Assert-IPadHost([string]$IPadHost) {
    if (-not $IPadHost) { throw "No iPad address: set `"ipad`" in tools/local.json or pass -IPadHost" }
}

function Get-IPadSshArgs {
    @('-i', $script:IPadKey, '-oHostKeyAlgorithms=+ssh-rsa', '-oStrictHostKeyChecking=accept-new', '-oConnectTimeout=10', '-oBatchMode=yes', '-oLogLevel=ERROR',
      '-oServerAliveInterval=5', '-oServerAliveCountMax=4')
}

# Runs a command on the iPad and returns stdout+stderr as plain strings (never throws on stderr output).
function Invoke-IPad {
    param([Parameter(Mandatory = $true)][string]$Command, [string]$IPadHost = $script:IPadDefaultHost)
    Assert-IPadHost $IPadHost
    $ErrorActionPreference = 'Continue'
    $sshArgs = Get-IPadSshArgs
    & ssh.exe @sshArgs "root@$IPadHost" $Command 2>&1 |
        ForEach-Object { if ($_ -is [Management.Automation.ErrorRecord]) { $_.Exception.Message } else { $_ } }
}

function Copy-ToIPad {
    param([Parameter(Mandatory = $true)][string]$LocalPath, [Parameter(Mandatory = $true)][string]$RemotePath, [string]$IPadHost = $script:IPadDefaultHost)
    Assert-IPadHost $IPadHost
    $ErrorActionPreference = 'Continue'
    $sshArgs = Get-IPadSshArgs
    & scp.exe -O @sshArgs $LocalPath "root@${IPadHost}:$RemotePath" 2>&1 |
        ForEach-Object { if ($_ -is [Management.Automation.ErrorRecord]) { $_.Exception.Message } else { $_ } }
    if ($LASTEXITCODE -ne 0) { throw "scp failed for $LocalPath" }
}

function Copy-FromIPad {
    param([Parameter(Mandatory = $true)][string]$RemotePath, [Parameter(Mandatory = $true)][string]$LocalPath, [string]$IPadHost = $script:IPadDefaultHost)
    Assert-IPadHost $IPadHost
    $ErrorActionPreference = 'Continue'
    $sshArgs = Get-IPadSshArgs
    & scp.exe -O @sshArgs -r "root@${IPadHost}:$RemotePath" $LocalPath 2>&1 |
        ForEach-Object { if ($_ -is [Management.Automation.ErrorRecord]) { $_.Exception.Message } else { $_ } }
    if ($LASTEXITCODE -ne 0) { throw "scp failed for $RemotePath" }
}

function Install-IPadPackage {
    param([string]$IpaPath, [string]$DebPath, [string]$IPadHost = $script:IPadDefaultHost)
    $installed = $false
    Invoke-IPad -IPadHost $IPadHost -Command 'killall CityVOD 2>/dev/null; echo stopped' | Out-Null
    if ($IpaPath -and (Test-Path $IpaPath)) {
        Write-Host "Installing IPA $IpaPath ..."
        Copy-ToIPad -LocalPath $IpaPath -RemotePath '/tmp/cityvod.ipa' -IPadHost $IPadHost
        $out = Invoke-IPad -IPadHost $IPadHost -Command 'if command -v ipainstaller >/dev/null 2>&1; then ipainstaller -f /tmp/cityvod.ipa; echo "IPA_EXIT=$?"; elif command -v appinst >/dev/null 2>&1; then appinst /tmp/cityvod.ipa; echo "IPA_EXIT=$?"; else echo NO_INSTALLER; fi' | Out-String
        Write-Host $out
        if ($out -match 'IPA_EXIT=0' -or $out -match '(?i)installed .* successfully') { $installed = $true }
    }
    if (-not $installed -and $DebPath -and (Test-Path $DebPath)) {
        Write-Host "Installing DEB $DebPath (falls back to /Applications) ..."
        Copy-ToIPad -LocalPath $DebPath -RemotePath '/tmp/cityvod.deb' -IPadHost $IPadHost
        $out = Invoke-IPad -IPadHost $IPadHost -Command 'dpkg -i /tmp/cityvod.deb 2>&1 && { uicache 2>/dev/null; echo DEB_OK; }' | Out-String
        Write-Host $out
        if ($out -match 'DEB_OK') { $installed = $true }
    }
    if (-not $installed) { throw "Nothing installed" }
    Write-Host "Done. Tap the City VOD icon on the iPad."
}

function Get-IPadCrashLogs {
    param([string]$IPadHost = $script:IPadDefaultHost, [string]$OutDir = '')
    if (-not $OutDir) { $OutDir = Join-Path (Get-Location) 'packages\crashlogs' }
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
    $list = Invoke-IPad -IPadHost $IPadHost -Command "ls -t /var/mobile/Library/Logs/CrashReporter/ 2>/dev/null | grep -i cityvod | sed -n '1,5p'"
    foreach ($f in (@($list) -join "`n" -split "`n" | Where-Object { $_.Trim() })) {
        $name = $f.Trim()
        Copy-FromIPad -IPadHost $IPadHost -RemotePath "/var/mobile/Library/Logs/CrashReporter/$name" -LocalPath (Join-Path $OutDir $name)
        Write-Host "Fetched $name"
    }
    Get-ChildItem $OutDir -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

function Get-IPadSyslog {
    param([string]$IPadHost = $script:IPadDefaultHost, [int]$Lines = 200)
    $tail = "sed -e :a -e '`$q;N;$($Lines + 1),`$D;ba'"
    Invoke-IPad -IPadHost $IPadHost -Command "if [ -f /var/log/syslog ]; then grep -i cityvod /var/log/syslog | $tail; else echo 'no /var/log/syslog'; fi"
}

function Get-CityVODLog {
    param([int]$Lines = 40, [string]$IPadHost = $script:IPadDefaultHost)
    Invoke-IPad -IPadHost $IPadHost -Command "grep '\[CityVOD\]' /var/log/syslog | sed -e :a -e '`$q;N;$($Lines + 1),`$D;ba'"
}

function Get-IPadAppContainer {
    param([string]$IPadHost = $script:IPadDefaultHost)
    $out = (Invoke-IPad -IPadHost $IPadHost -Command "ls -d /var/mobile/Applications/*/CityVOD.app 2>/dev/null | sed -n '1p'" | Out-String).Trim()
    if ($out) { return ($out -replace '/CityVOD\.app$', '') }
    $sys = (Invoke-IPad -IPadHost $IPadHost -Command "ls -d /Applications/CityVOD.app 2>/dev/null | sed -n '1p'" | Out-String).Trim()
    if ($sys) { return '/var/mobile' }
    throw 'CityVOD is not installed on the iPad'
}

function Enable-CityVODDebug {
    param([string]$IPadHost = $script:IPadDefaultHost)
    $container = Get-IPadAppContainer -IPadHost $IPadHost
    Invoke-IPad -IPadHost $IPadHost -Command "mkdir -p '$container/Documents'; echo on > '$container/Documents/debug'; chown mobile:mobile '$container/Documents/debug'; echo DEBUG_ON" | Out-String
}

function Invoke-CityVOD {
    param([Parameter(Mandatory = $true)][string]$Url, [int]$WaitSeconds = 0, [string]$IPadHost = $script:IPadDefaultHost)
    $cmd = "uiopen '$Url'"
    if ($WaitSeconds -gt 0) { $cmd += "; sleep $WaitSeconds" }
    Invoke-IPad -IPadHost $IPadHost -Command $cmd
}

function Get-IPadScreen {
    param([Parameter(Mandatory = $true)][string]$OutFile, [switch]$Real, [string]$IPadHost = $script:IPadDefaultHost)
    $kind = if ($Real) { 'screen' } else { 'snapshot' }
    $container = Get-IPadAppContainer -IPadHost $IPadHost
    Invoke-IPad -IPadHost $IPadHost -Command "rm -f /tmp/cityvod-screen.png; uiopen 'cityvod:$kind'; sleep 3; cp '$container/tmp/screen.png' /tmp/cityvod-screen.png 2>/dev/null || cp /tmp/screen.png /tmp/cityvod-screen.png 2>/dev/null" | Out-Null
    Copy-FromIPad -IPadHost $IPadHost -RemotePath '/tmp/cityvod-screen.png' -LocalPath $OutFile
    Get-Item $OutFile
}
