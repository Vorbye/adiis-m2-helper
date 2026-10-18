param([string]$Destination = (Join-Path $PSScriptRoot 'Fertige-App\App\AutoHotkey'))
$ErrorActionPreference='Stop'
$version='2.0.19'
$url="https://github.com/AutoHotkey/AutoHotkey/releases/download/v$version/AutoHotkey_$version.zip"
$tmp=Join-Path $env:TEMP ("ahk-portable-"+[guid]::NewGuid().ToString('N'))
try {
 New-Item -ItemType Directory -Force -Path $tmp,$Destination | Out-Null
 $zip=Join-Path $tmp 'AutoHotkey.zip'
 Write-Host "Lade AutoHotkey v$version von der offiziellen GitHub-Release-Seite..."
 [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
 Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
 Expand-Archive -LiteralPath $zip -DestinationPath (Join-Path $tmp 'extract') -Force
 $exe=Get-ChildItem (Join-Path $tmp 'extract') -Recurse -File -Filter 'AutoHotkey64.exe' | Select-Object -First 1
 if (-not $exe) { throw 'AutoHotkey64.exe wurde im offiziellen ZIP nicht gefunden.' }
 Copy-Item -LiteralPath $exe.FullName -Destination (Join-Path $Destination 'AutoHotkey64.exe') -Force
 Write-Host "Fertig: $Destination\AutoHotkey64.exe"
} catch {
 Write-Error "Portable AutoHotkey Einrichtung fehlgeschlagen: $_"
 exit 1
} finally {
 Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
