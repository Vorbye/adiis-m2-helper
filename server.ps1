# AHK Manager - local PowerShell server; no Python required.
Add-Type -AssemblyName System.Windows.Forms
$ErrorActionPreference = 'Stop'
Add-Type -Path (Join-Path $PSScriptRoot 'MetinWindows.cs') -ReferencedAssemblies System.Windows.Forms,System.Drawing
function List-MetinWindows {
  return @{windows=@([MetinWindows]::List());processName='metin2client.exe'}
}

$root = Join-Path $env:APPDATA 'AHKManager'
New-Item -ItemType Directory -Path $root -Force | Out-Null
$toolsFile = Join-Path $root 'helper-tools.json'
$tools = @{windowSound=$true;timerSound=$true;notes='';timers=@();presets=@();noteItems=@();overlay=$true}
if (Test-Path $toolsFile) {
  $loaded=Get-Content -LiteralPath $toolsFile -Raw -Encoding UTF8 | ConvertFrom-Json
  $tools.windowSound=[bool]$loaded.windowSound
  $tools.timerSound=[bool]$loaded.timerSound
  $tools.notes=[string]$loaded.notes
  if ($null -ne $loaded.overlay) {$tools.overlay=[bool]$loaded.overlay}
  $tools.presets=@($loaded.presets | Where-Object {$null -ne $_} | ForEach-Object {@{id=[string]$_.id;name=[string]$_.name;seconds=[long]$_.seconds}})
  $tools.noteItems=@($loaded.noteItems | Where-Object {$null -ne $_} | ForEach-Object {@{id=[string]$_.id;name=[string]$_.name;text=[string]$_.text}})
  if ($null -eq $loaded.noteItems -and $tools.notes) {$tools.noteItems=@(@{id=[guid]::NewGuid().ToString('N');name='Bisherige Notizen';text=$tools.notes})}

  $tools.timers=@($loaded.timers | ForEach-Object { @{id=[string]$_.id;name=[string]$_.name;duration=[long]$_.duration;remaining=[long]$_.remaining;deadline=[long]$_.deadline;state=[string]$_.state} })
}
function Sync-Tools {
  [HelperMonitor]::Settings($script:tools.windowSound,$script:tools.timerSound)
  $active=@($script:tools.timers | Where-Object {$_.state -eq 'running'})
  [HelperMonitor]::SetTimers([string[]]@($active | ForEach-Object {$_.id}),[long[]]@($active | ForEach-Object {$_.deadline}))
}
function Sync-Overlay {
  $t=@($script:tools.timers)
  [TimerOverlay]::Update($script:tools.overlay,[string[]]@($t|ForEach-Object {$_.name}),[string[]]@($t|ForEach-Object {$_.state}),[long[]]@($t|ForEach-Object {$_.deadline}),[long[]]@($t|ForEach-Object {$_.remaining}),(Join-Path $root 'timer-overlay-position.txt'))
}
function Save-Tools {
  $tmp=$toolsFile+'.tmp'
  [IO.File]::WriteAllText($tmp,(ConvertTo-Json -InputObject $script:tools -Depth 8),(New-Object Text.UTF8Encoding($false)))
  # Windows PowerShell binds $null to an empty string for this overload.
  # File.Replace rejects that as a backup path; use an actual sibling file.
  if ([IO.File]::Exists($toolsFile)) {[IO.File]::Replace($tmp,$toolsFile,($toolsFile+'.bak'),$true)} else {[IO.File]::Move($tmp,$toolsFile)}
  Sync-Tools
  Sync-Overlay
}
function Tools-State {
  return @{windowSound=$script:tools.windowSound;timerSound=$script:tools.timerSound;notes=$script:tools.notes;timers=@($script:tools.timers);presets=@($script:tools.presets);noteItems=@($script:tools.noteItems);overlay=$script:tools.overlay;events=@([HelperMonitor]::Events());now=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()}
}
Sync-Tools
Sync-Overlay
[HelperMonitor]::Start($tools.windowSound,$tools.timerSound)

$config = Join-Path $root 'scripts.json'
$items = @()
if (Test-Path $config) { try { $items = @((Get-Content -LiteralPath $config -Raw -Encoding UTF8 | ConvertFrom-Json)) } catch { $items = @() } }
$processes = @{}
$namesFile = Join-Path $root 'names.json'
$names = @{}
if (Test-Path $namesFile) {
  try {
    $savedNames = Get-Content -LiteralPath $namesFile -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($property in $savedNames.PSObject.Properties) { $names[$property.Name] = [string]$property.Value }
  } catch { $names = @{} }
}
$metaFile = Join-Path $root 'metadata.json'
$metadata = @{}
if (Test-Path $metaFile) {
  try {
    $stored = Get-Content -LiteralPath $metaFile -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($entry in $stored.PSObject.Properties) { $metadata[$entry.Name] = @{favorite=[bool]$entry.Value.favorite;group=[string]$entry.Value.group;autostart=[bool]$entry.Value.autostart} }
  } catch { $metadata = @{} }
}
$groupsFile = Join-Path $root 'groups.json'
$groups = @('Allgemein')
if (Test-Path $groupsFile) {
  try { $groups = @((Get-Content -LiteralPath $groupsFile -Raw -Encoding UTF8 | ConvertFrom-Json) | ForEach-Object { [string]$_ }) } catch { $groups = @('Allgemein') }
}
foreach ($entry in $metadata.Values) { if ($entry.group -and $groups -notcontains $entry.group) { $groups += $entry.group } }
if ($groups -notcontains 'Allgemein') { $groups = @('Allgemein') + $groups }
$groups = @($groups | Select-Object -Unique)
function Save-Groups { [IO.File]::WriteAllText($groupsFile,(ConvertTo-Json -InputObject @($script:groups) -Depth 4),(New-Object Text.UTF8Encoding($false))) }
function Save-Metadata { [IO.File]::WriteAllText($metaFile,(ConvertTo-Json -InputObject $script:metadata -Depth 6),(New-Object Text.UTF8Encoding($false))) }
function Get-Meta([string]$path) {
  if (-not $script:metadata.ContainsKey($path)) { $script:metadata[$path] = @{favorite=$false;group='Allgemein';autostart=$false} }
  return $script:metadata[$path]
}
function Save-Names { [IO.File]::WriteAllText($namesFile, (ConvertTo-Json -InputObject $script:names -Depth 4), (New-Object Text.UTF8Encoding($false))) }
$utf8 = New-Object System.Text.UTF8Encoding($false, $true)
function Save-List { [System.IO.File]::WriteAllText($config, (ConvertTo-Json -InputObject @($script:items) -Depth 4), (New-Object System.Text.UTF8Encoding($false))) }
function Find-AHK {
  $appDir = if ($env:AHK_MANAGER_APP_DIR) { $env:AHK_MANAGER_APP_DIR } else { Split-Path -Parent $PSCommandPath }
  $candidates = @(
    (Join-Path $appDir 'App\AutoHotkey\AutoHotkey64.exe'),
    (Join-Path $appDir 'App\AutoHotkey\AutoHotkey.exe'),
    (Join-Path $env:ProgramFiles 'AutoHotkey\v2\AutoHotkey64.exe'),
    (Join-Path $env:ProgramFiles 'AutoHotkey\v2\AutoHotkey.exe'),
    (Join-Path $env:LOCALAPPDATA 'Programs\AutoHotkey\v2\AutoHotkey64.exe'),
    (Join-Path $env:LOCALAPPDATA 'Programs\AutoHotkey\v2\AutoHotkey.exe')
  )
  foreach ($candidate in $candidates) { if (Test-Path -LiteralPath $candidate) { return $candidate } }
  try { $cmd = Get-Command AutoHotkey.exe -ErrorAction Stop; if ($cmd.Source) { return $cmd.Source } } catch {}
  return ''
}
$interpreter = Find-AHK
function Send-Json($response, $data, $status=200) {
  $bytes = [System.Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -InputObject $data -Depth 8 -Compress))
  $response.StatusCode = $status
  $response.ContentType = 'application/json; charset=utf-8'
  $response.ContentLength64 = $bytes.Length
  $response.OutputStream.Write($bytes,0,$bytes.Length)
  $response.Close()
}
function Get-Body($request) {
  $reader = New-Object System.IO.StreamReader($request.InputStream, [System.Text.Encoding]::UTF8)
  try { return ($reader.ReadToEnd() | ConvertFrom-Json) } finally { $reader.Close() }
}
function Resolve-Index($value) {
  $i = [int]$value
  if ($i -lt 0 -or $i -ge $script:items.Count) { throw 'Skript nicht gefunden.' }
  return $i
}
# Match the full selected script path in the AutoHotkey process command line.
function Get-ScriptProcesses([string]$scriptPath) {
  $result = @()
  $full = [IO.Path]::GetFullPath($scriptPath)
  $escaped = [regex]::Escape($full)
  $pattern = '(?i)(?:^|\s)(?:"' + $escaped + '"|' + $escaped + ')(?=\s|$)'
  foreach ($entry in @(Get-CimInstance Win32_Process -ErrorAction Stop)) {
    if ($entry.Name -notmatch '(?i)^AutoHotkey.*\.exe$') { continue }
    $command = [string]$entry.CommandLine
    if ($command -and [regex]::IsMatch($command, $pattern)) { $result += $entry }
  }
  return $result
}
# WM_CLOSE requests the same graceful script exit as the tray icon's Exit action.
# Send it only to hidden AutoHotkey windows belonging to the selected process ID.
Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class AhkCloseWindow {
  public delegate bool EnumProc(IntPtr hwnd, IntPtr arg);
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc callback, IntPtr arg);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr hwnd, StringBuilder text, int max);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
  [DllImport("user32.dll")] static extern bool PostMessage(IntPtr hwnd, uint message, IntPtr w, IntPtr l);
  public static int CloseAhk(uint targetPid) {
    int count=0;
    EnumWindows((hwnd,arg)=>{
      uint pid; GetWindowThreadProcessId(hwnd,out pid);
      if(pid==targetPid) {
        var cls=new StringBuilder(256);
        GetClassName(hwnd,cls,cls.Capacity);
        if(cls.ToString()=="AutoHotkey") {
          if(PostMessage(hwnd,0x0010,IntPtr.Zero,IntPtr.Zero)) count++;
        }
      }
      return true;
    },IntPtr.Zero);
    return count;
  }
}
'@
function List-Items {
  $out = @()
  foreach ($p in $script:items) {
    $running = $false
    try { $running = @(Get-ScriptProcesses $p).Count -gt 0 } catch { if ($script:processes.ContainsKey($p)) { try { $running = -not $script:processes[$p].HasExited } catch {} } }
    $displayName = [IO.Path]::GetFileNameWithoutExtension($p)
    if ($script:names.ContainsKey($p) -and $script:names[$p]) { $displayName = $script:names[$p] }
    $meta=Get-Meta $p
    $out += @{path=$p;name=$displayName;running=$running;exists=[IO.File]::Exists($p);hasBackup=[IO.File]::Exists($p+'.bak');favorite=[bool]$meta.favorite;group=[string]$meta.group;autostart=[bool]$meta.autostart}
  }
  return @{items=$out;groups=@($script:groups);interpreter=$script:interpreter;admin=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)}
}
# Own dialogs with a topmost window so Edge cannot hide them behind itself.
function Show-FrontDialog($dialog) {
  $owner = New-Object System.Windows.Forms.Form
  $owner.Text = 'AHK Manager - Dateiauswahl'
  $owner.Size = New-Object System.Drawing.Size(320,90)
  $owner.StartPosition = 'CenterScreen'
  $owner.TopMost = $true
  $owner.ShowInTaskbar = $true
  try {
    $owner.Show()
    $owner.Activate()
    return $dialog.ShowDialog($owner)
  } finally { $owner.Close(); $owner.Dispose(); $dialog.Dispose() }
}
# Loopback-only server, random free port selected by OS
$socket = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback,0)
$socket.Start(); $port = ([System.Net.IPEndPoint]$socket.LocalEndpoint).Port; $socket.Stop()
$token = [guid]::NewGuid().ToString('N')
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://127.0.0.1:$port/")
$listener.Start()
$url = "http://127.0.0.1:$port/?token=$token"
# Native WebView2 host receives the one-time URL via a per-launch file.
if ($env:AHK_MANAGER_READY_FILE) {
  [IO.File]::WriteAllText($env:AHK_MANAGER_READY_FILE, $url, (New-Object Text.UTF8Encoding($false)))
} else {
  throw 'Dieses Backend muss ueber Adiis-m2-helper.exe gestartet werden.'
}

function Start-ManagedScript([string]$p) {
  if (-not [IO.File]::Exists($p)) { throw 'Skriptdatei fehlt.' }
  if (-not $script:interpreter -or -not [IO.File]::Exists($script:interpreter)) { $script:interpreter=Find-AHK }
  if (-not $script:interpreter -or -not [IO.File]::Exists($script:interpreter)) { throw 'AutoHotkey v2 fehlt. Bitte im App-Ordner AutoHotkey bereitstellen oder AutoHotkey v2 installieren.' }
  if (@(Get-ScriptProcesses $p).Count -gt 0) { return }
  $proc=Start-Process -FilePath $script:interpreter -ArgumentList ('"'+$p+'"') -WorkingDirectory ([IO.Path]::GetDirectoryName($p)) -PassThru
  $script:processes[$p]=$proc
}
# Autostart only on manager launch; skip already running scripts.
foreach ($p in $items) {
  if ((Get-Meta $p).autostart -and [IO.File]::Exists($p)) { try { Start-ManagedScript $p } catch {} }
}

try {
while ($listener.IsListening) {
  $ctx = $listener.GetContext(); $req = $ctx.Request; $res = $ctx.Response
  try {
    # Reject cross-origin requests and requests without the per-launch secret.
    if ($req.QueryString['token'] -ne $token -and $req.Headers['X-AHK-Token'] -ne $token) { Send-Json $res @{error='Nicht autorisiert.'} 403; continue }
    if ($req.HttpMethod -eq 'GET' -and $req.Url.AbsolutePath -eq '/') {
      $html = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'index.html'),[Text.Encoding]::UTF8)
      $html = $html.Replace('__ICON_TOKEN__', $token)
      $bytes = [Text.Encoding]::UTF8.GetBytes($html)
      $res.ContentType='text/html; charset=utf-8';$res.ContentLength64=$bytes.Length;$res.OutputStream.Write($bytes,0,$bytes.Length);$res.Close();continue
    }
    if ($req.HttpMethod -eq 'GET' -and $req.Url.AbsolutePath -eq '/icon.png') {
      $bytes=[IO.File]::ReadAllBytes((Join-Path $PSScriptRoot 'icon.png'))
      $res.ContentType='image/png';$res.ContentLength64=$bytes.Length;$res.OutputStream.Write($bytes,0,$bytes.Length);$res.Close();continue
    }
    if ($req.Url.AbsolutePath -ne '/api') { Send-Json $res @{error='Unbekannter Endpunkt.'} 404;continue }
    if ($req.HttpMethod -ne 'POST') { Send-Json $res @{error='Nur POST erlaubt.'} 405;continue }
    $b=Get-Body $req
    switch ($b.action) {
      'list' { Send-Json $res (List-Items) }
      'metinList' { Send-Json $res (List-MetinWindows) }
      'toolsState' { Send-Json $res (Tools-State) }
      'toolsSettings' {
        if ($null -ne $b.windowSound) {$tools.windowSound=[bool]$b.windowSound}
        if ($null -ne $b.timerSound) {$tools.timerSound=[bool]$b.timerSound}
        if ($null -ne $b.overlay) {$tools.overlay=[bool]$b.overlay}
        Save-Tools;Send-Json $res (Tools-State)
      }
      'testTone' { [HelperMonitor]::TestTone();Send-Json $res @{ok=$true} }
      'saveNotes' {
        $text=[string]$b.text
        if ($text.Length -gt 200000) {throw 'Notiz ist zu lang (maximal 200.000 Zeichen).'}
        $note=@($tools.noteItems|Where-Object {$_.id -eq [string]$b.id})
        if ($note.Count -ne 1) {throw 'Notiz nicht gefunden.'}
        $note[0].text=$text;Save-Tools;Send-Json $res @{ok=$true}
      }
      'noteCreate' {
        $name=([string]$b.name).Trim()
        if ($name.Length -lt 1 -or $name.Length -gt 80) {throw 'Notizname: 1 bis 80 Zeichen.'}
        if ($tools.noteItems.Count -ge 200) {throw 'Maximal 200 Notizen.'}
        $tools.noteItems+=@{id=[guid]::NewGuid().ToString('N');name=$name;text=''}
        Save-Tools;Send-Json $res (Tools-State)
      }
      'noteReorder' {
        $requested=@($b.ids | ForEach-Object {[string]$_})
        if ($requested.Count -ne $tools.noteItems.Count) {throw 'Notizliste hat sich geändert. Bitte erneut versuchen.'}
        $byId=@{}
        foreach ($note in $tools.noteItems) {$byId[$note.id]=$note}
        $seen=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
        foreach ($id in $requested) {
          if (-not $byId.ContainsKey($id) -or -not $seen.Add($id)) {throw 'Ungültige Notizreihenfolge.'}
        }
        $tools.noteItems=@($requested | ForEach-Object {$byId[$_]})
        Save-Tools;Send-Json $res (Tools-State)
      }
      'noteChange' {
        $note=@($tools.noteItems|Where-Object {$_.id -eq [string]$b.id})
        if ($note.Count -ne 1) {throw 'Notiz nicht gefunden.'}
        if ($b.command -eq 'delete') {$tools.noteItems=@($tools.noteItems|Where-Object {$_.id -ne [string]$b.id})}
        elseif ($b.command -eq 'rename') {
          $name=([string]$b.name).Trim()
          if ($name.Length -lt 1 -or $name.Length -gt 80) {throw 'Notizname: 1 bis 80 Zeichen.'}
          $note[0].name=$name
        } else {throw 'Unbekannte Notizaktion.'}
        Save-Tools;Send-Json $res (Tools-State)
      }
      'presetSave' {
        $name=([string]$b.name).Trim();$seconds=[long]$b.seconds
        if ($name.Length -lt 1 -or $name.Length -gt 80 -or $seconds -lt 1 -or $seconds -gt 604800) {throw 'Bitte Name und Dauer von 1 Sekunde bis 7 Tagen eingeben.'}
        $existing=@($tools.presets | Where-Object {$_.name -ieq $name})
        if ($existing.Count -gt 0) {$existing[0].seconds=$seconds}
        else {
          if ($tools.presets.Count -ge 100) {throw 'Maximal 100 Timer-Vorlagen.'}
          $tools.presets+=@{id=[guid]::NewGuid().ToString('N');name=$name;seconds=$seconds}
        }
        Save-Tools;Send-Json $res (Tools-State)
      }
      'presetDelete' {
        $tools.presets=@($tools.presets|Where-Object {$_.id -ne [string]$b.id})
        Save-Tools;Send-Json $res (Tools-State)
      }
      'timerCreate' {
        if ($tools.timers.Count -ge 30) {throw 'Maximal 30 Timer gleichzeitig.'}
        $name=([string]$b.name).Trim();$seconds=[long]$b.seconds
        if ($name.Length -lt 1 -or $name.Length -gt 80) {throw 'Bitte einen Namen mit 1 bis 80 Zeichen eingeben.'}
        if ($seconds -lt 1 -or $seconds -gt 604800) {throw 'Timerdauer: 1 Sekunde bis 7 Tage.'}
        $ms=$seconds*1000
        $tools.timers+=@{id=[guid]::NewGuid().ToString('N');name=$name;duration=$ms;remaining=$ms;deadline=([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()+$ms);state='running'}
        Save-Tools;Send-Json $res (Tools-State)
      }
      'timerChange' {
        $timer=@($tools.timers | Where-Object {$_.id -eq [string]$b.id})
        if ($timer.Count -ne 1) {throw 'Timer nicht gefunden.'}
        $t=$timer[0];$now=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        switch ([string]$b.command) {
          'pause' {if ($t.state -eq 'running') {$t.remaining=[Math]::Max(0,$t.deadline-$now);$t.state='paused';$t.deadline=0}}
          'resume' {if ($t.state -eq 'paused' -and $t.remaining -gt 0) {$t.deadline=$now+$t.remaining;$t.state='running'}}
          'restart' {$t.remaining=$t.duration;$t.deadline=$now+$t.duration;$t.state='running'}
          'delete' {$tools.timers=@($tools.timers | Where-Object {$_.id -ne $t.id})}
          default {throw 'Unbekannte Timeraktion.'}
        }
        Save-Tools;Send-Json $res (Tools-State)
      }

      'metinHighlight' {
        [MetinWindows]::Highlight([string]$b.handle,[int]$b.pid,[string]$b.started)
        Send-Json $res @{ok=$true}
      }
      'metinClose' {
        [HelperMonitor]::Close([string]$b.handle,[int]$b.pid,[string]$b.started)
        Send-Json $res @{ok=$true}
      }
      'createGroup' {
        $g=([string]$b.name).Trim()
        if ($g.Length -lt 1 -or $g.Length -gt 40) { throw 'Gruppenname muss 1 bis 40 Zeichen haben.' }
        if ($g -match '[\\/<>:"|?*]') { throw 'Der Gruppenname enthaelt ungueltige Zeichen.' }
        if (@($script:groups | Where-Object { $_ -ieq $g }).Count -gt 0) { throw 'Diese Gruppe gibt es bereits.' }
        $script:groups += $g
        Save-Groups
        Send-Json $res (List-Items)
      }
      'reorder' {
        $requested=@($b.paths | ForEach-Object { [string]$_ })
        if ($requested.Count -ne $script:items.Count) { throw 'Die Skriptliste hat sich geändert. Bitte erneut versuchen.' }
        $known=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
        foreach($path in $script:items) { [void]$known.Add([string]$path) }
        $seen=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
        foreach($path in $requested) {
          if (-not $known.Contains($path) -or -not $seen.Add($path)) { throw 'Ungültige Skriptreihenfolge.' }
        }
        $script:items=@($requested)
        Save-List
        Send-Json $res (List-Items)
      }
      'deleteGroup' {
        $name=([string]$b.name).Trim()
        if ($name -eq 'Allgemein') { throw 'Die Gruppe Allgemein kann nicht gelöscht werden.' }
        if ($script:groups -notcontains $name) { throw 'Diese Gruppe existiert nicht.' }
        $script:groups=@($script:groups | Where-Object { $_ -ine $name })
        foreach($meta in $script:metadata.Values) { if ($meta.group -ieq $name) { $meta.group='Allgemein' } }
        Save-Metadata
        Save-Groups
        Send-Json $res (List-Items)
      }
      'openPath' {
        $i=Resolve-Index $b.index
        $p=[string]$script:items[$i]
        if (-not [IO.File]::Exists($p)) { throw 'Skriptdatei existiert nicht mehr.' }
        Start-Process -FilePath 'explorer.exe' -ArgumentList ('/select,"' + $p + '"')
        Send-Json $res @{ok=$true}
      }
      'quit' { Send-Json $res @{ok=$true}; $listener.Stop() }
      'pick' {
        $dialog=New-Object System.Windows.Forms.OpenFileDialog
        $dialog.Filter='AutoHotkey-Skripte (*.ahk)|*.ahk';$dialog.Multiselect=$true;$dialog.Title='AHK-Dateien auswählen'
        if ((Show-FrontDialog $dialog) -eq [Windows.Forms.DialogResult]::OK) {
          foreach($p in $dialog.FileNames) { if ($script:items -notcontains $p) { $script:items += $p } };Save-List
        }
        Send-Json $res (List-Items)
      }
      'folder' {
        $dialog=New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.Description='Ordner mit AHK-Skripten auswählen'
        if ((Show-FrontDialog $dialog) -eq [Windows.Forms.DialogResult]::OK) {
          foreach($f in @(Get-ChildItem -LiteralPath $dialog.SelectedPath -Filter '*.ahk' -File)) { if ($script:items -notcontains $f.FullName) { $script:items += $f.FullName } };Save-List
        }
        Send-Json $res (List-Items)
      }
      'create' {
        $name=([string]$b.name).Trim()
        if ($name -match '(?i)\.ahk$') { $name=$name.Substring(0,$name.Length-4) }
        if ($name.Length -lt 1 -or $name.Length -gt 80 -or $name -match '[<>:\"/\\|?*]' -or $name.EndsWith('.') -or $name.EndsWith(' ')) { throw 'Ungueltiger Dateiname. Bitte 1-80 Zeichen ohne Sonderzeichen verwenden.' }
        if ($name -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$') { throw 'Dieser Dateiname ist unter Windows reserviert.' }
        $appFolder = if ($env:AHK_MANAGER_APP_DIR) { $env:AHK_MANAGER_APP_DIR } else { $PSScriptRoot }
        $scriptFolder=Join-Path $appFolder 'Scripts'
        New-Item -ItemType Directory -Path $scriptFolder -Force | Out-Null
        $newPath=Join-Path $scriptFolder ($name+'.ahk')
        if ([IO.File]::Exists($newPath)) { throw 'Ein Skript mit diesem Namen existiert bereits.' }
        $content="#Requires AutoHotkey v2.0`r`n#SingleInstance Force`r`n`r`n; $name`r`n"
        $bytes=(New-Object Text.UTF8Encoding($false)).GetBytes($content)
        $stream=New-Object IO.FileStream($newPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
        try { $stream.Write($bytes,0,$bytes.Length) } finally { $stream.Dispose() }
        if ($script:items -notcontains $newPath) { $script:items+= $newPath;Save-List }
        $result=List-Items
        $result | Add-Member -NotePropertyName createdPath -NotePropertyValue $newPath -Force
        Send-Json $res $result
      }
      'pickexe' {
        $dialog=New-Object System.Windows.Forms.OpenFileDialog
        $dialog.Filter='Programme (*.exe)|*.exe';$dialog.Title='AutoHotkey v2 Interpreter auswählen'
        if ((Show-FrontDialog $dialog) -eq [Windows.Forms.DialogResult]::OK) { $script:interpreter=$dialog.FileName }
        Send-Json $res (List-Items)
      }
      'meta' {
        $i=Resolve-Index $b.index;$p=$script:items[$i];$m=Get-Meta $p
        if ($null -ne $b.favorite) { $m.favorite=[bool]$b.favorite }
        if ($null -ne $b.autostart) { $m.autostart=[bool]$b.autostart }
        if ($null -ne $b.group) {
          $g=([string]$b.group).Trim()
          if ($g.Length -lt 1 -or $g.Length -gt 40) { throw 'Gruppenname muss 1 bis 40 Zeichen enthalten.' }
          if ($script:groups -notcontains $g) { throw 'Bitte eine vorhandene Gruppe auswaehlen.' }
          $m.group=$g
        }
        Save-Metadata;Send-Json $res (List-Items)
      }
      'relink' {
        $i=Resolve-Index $b.index;$old=$script:items[$i]
        $dialog=New-Object System.Windows.Forms.OpenFileDialog
        $dialog.Filter='AutoHotkey-Skripte (*.ahk)|*.ahk';$dialog.Title='Neuen Speicherort auswählen'
        if ((Show-FrontDialog $dialog) -eq [Windows.Forms.DialogResult]::OK) {
          $new=$dialog.FileName
          if ($new -ne $old -and $script:items -contains $new) { throw 'Dieses Skript ist bereits eingetragen.' }
          $script:items[$i]=$new
          if ($script:names.ContainsKey($old)) { $script:names[$new]=$script:names[$old];$script:names.Remove($old);Save-Names }
          if ($script:metadata.ContainsKey($old)) { $script:metadata[$new]=$script:metadata[$old];$script:metadata.Remove($old);Save-Metadata }
          Save-List
        }
        Send-Json $res (List-Items)
      }
      'rename' {
        $i=Resolve-Index $b.index
        $p=$script:items[$i]
        $newName=[string]$b.name
        $newName=$newName.Trim()
        if ($newName.Length -lt 1 -or $newName.Length -gt 80) { throw 'Der Name muss zwischen 1 und 80 Zeichen lang sein.' }
        $script:names[$p]=$newName
        Save-Names
        Send-Json $res (List-Items)
      }
      'read' {
        $i=Resolve-Index $b.index;$p=$script:items[$i]
        $bytes=[IO.File]::ReadAllBytes($p)
        $encoding='utf8';$bom=$false
        if ($bytes.Length -ge 2 -and $bytes[0] -eq 255 -and $bytes[1] -eq 254) { $encoding='utf16le';$content=[Text.Encoding]::Unicode.GetString($bytes,2,$bytes.Length-2) }
        elseif ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) { $bom=$true;$content=$utf8.GetString($bytes,3,$bytes.Length-3) }
        else { $content=$utf8.GetString($bytes) }
        Send-Json $res @{content=$content;encoding=$encoding;bom=$bom}
      }
      'save' {
        $i=Resolve-Index $b.index;$p=$script:items[$i]
        if (-not [IO.File]::Exists($p)) { throw 'Datei existiert nicht mehr.' }
        $backup=$p+'.bak';[IO.File]::Copy($p,$backup,$true)
        if ($b.encoding -eq 'utf16le') { $enc=[Text.Encoding]::Unicode }
        elseif ($b.bom) { $enc=New-Object Text.UTF8Encoding($true) }
        else { $enc=New-Object Text.UTF8Encoding($false) }
        [IO.File]::WriteAllText($p,[string]$b.content,$enc)
        Send-Json $res @{ok=$true;backup=$backup}
      }
      'restoreBackup' {
        $i=Resolve-Index $b.index;$p=$script:items[$i]
        $backup=$p+'.bak'
        if (-not [IO.File]::Exists($p)) { throw 'Skriptdatei nicht gefunden.' }
        if (-not [IO.File]::Exists($backup)) { throw 'Keine vorherige Sicherung vorhanden.' }
        # A second safety copy of the current version; do not overwrite the .bak.
        [IO.File]::Copy($p,$p+'.vor-wiederherstellung.bak',$true)
        [IO.File]::Copy($backup,$p,$true)
        Send-Json $res @{ok=$true;previous=$backup;currentSafety=$p+'.vor-wiederherstellung.bak'}
      }
      'start' {
        $i=Resolve-Index $b.index;$p=$script:items[$i]
        Start-ManagedScript $p
        Send-Json $res (List-Items)
      }
      'stop' {
        $i=Resolve-Index $b.index; $p=$script:items[$i]
        $ids = New-Object 'System.Collections.Generic.HashSet[int]'
        foreach ($entry in @(Get-ScriptProcesses $p)) { [void]$ids.Add([int]$entry.ProcessId) }
        if ($script:processes.ContainsKey($p)) {
          $tracked = $script:processes[$p]
          try {
            $tracked.Refresh()
            if (-not $tracked.HasExited -and $tracked.ProcessName -match '(?i)^AutoHotkey') {
              [void]$ids.Add([int]$tracked.Id)
            }
          } catch {}
        }
        if ($ids.Count -eq 0) { throw 'Kein laufender Prozess fuer dieses Skript gefunden. Bitte Skript ueber den Manager starten und erneut testen.' }
        $closed = 0
        foreach ($pidToClose in $ids) {
          $process = Get-Process -Id $pidToClose -ErrorAction SilentlyContinue
          if (-not $process -or $process.ProcessName -notmatch '(?i)^AutoHotkey') { continue }
          # Request graceful exit, then terminate if the script remains active.
          [void][AhkCloseWindow]::CloseAhk([uint32]$pidToClose)
          try { $process.WaitForExit(1800) } catch {}
          $process.Refresh()
          if (-not $process.HasExited) {
            Stop-Process -Id $pidToClose -Force -ErrorAction Stop
            try { $process.WaitForExit(1200) } catch {}
          }
          $closed++
        }
        if ($script:processes.ContainsKey($p)) { $script:processes.Remove($p) }
        if ($closed -eq 0) { throw 'Skript konnte nicht beendet werden. Bitte den AHK-Prozess und seine Administratorrechte pruefen.' }
        Send-Json $res (List-Items)
      }
      'removeMissing' {
        $script:items=@($script:items | Where-Object { [IO.File]::Exists($_) })
        Save-List;Send-Json $res (List-Items)
      }
      'remove' {
        $i=Resolve-Index $b.index
        $removePath=$script:items[$i]
        $script:items=@($script:items | Where-Object { $_ -ne $removePath })
        Save-List;Send-Json $res (List-Items)
      }
      default { Send-Json $res @{error='Unbekannte Aktion.'} 400 }
    }
  } catch { try { Send-Json $res @{error=$_.Exception.Message} 500 } catch {} }
}
} finally { $listener.Stop();$listener.Close() }
