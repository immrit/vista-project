$ErrorActionPreference = "Stop"

Set-StrictMode -Version Latest

function Resolve-DartRef {
  param(
    [Parameter(Mandatory = $true)][string]$FromFile,
    [Parameter(Mandatory = $true)][string]$Ref
  )

  $refTrim = $Ref.Trim()
  if ($refTrim.StartsWith("dart:")) { return $null }
  if ($refTrim.StartsWith("package:")) {
    # Handle package:Vista/... imports
    $m = [regex]::Match($refTrim, "^package:(?<pkg>[^/]+)/(?<path>.+)$")
    if (!$m.Success) { return $null }
    $pkg = $m.Groups["pkg"].Value
    $path = $m.Groups["path"].Value.Replace("/", "\")
    if ($pkg -ieq "Vista" -or $pkg -ieq "vista") {
      return (Join-Path -Path $PSScriptRoot -ChildPath "..\\lib\\$path") | Resolve-Path -ErrorAction SilentlyContinue | ForEach-Object { $_.Path }
    }
    return $null
  }

  # Relative path
  $fromDir = Split-Path -Parent $FromFile
  $rel = $refTrim.Replace("/", "\")
  $candidate = Join-Path -Path $fromDir -ChildPath $rel
  $resolved = Resolve-Path -Path $candidate -ErrorAction SilentlyContinue
  if ($resolved) { return $resolved.Path }
  return $null
}

function Get-DartDeps {
  param([Parameter(Mandatory = $true)][string]$File)

  $deps = New-Object System.Collections.Generic.List[string]
  $content = Get-Content -LiteralPath $File -ErrorAction Stop

  foreach ($line in $content) {
    $m = [regex]::Match($line, '^\s*(import|export|part)\s+["''](?<ref>[^"''\r\n]+)["'']\s*;')
    if (!$m.Success) { continue }
    $ref = $m.Groups["ref"].Value
    $resolved = Resolve-DartRef -FromFile $File -Ref $ref
    if ($resolved) { $deps.Add($resolved) }
  }

  return $deps
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$libRoot = (Resolve-Path (Join-Path $repoRoot "lib")).Path
$entry = Join-Path $libRoot "main.dart"

if (!(Test-Path -LiteralPath $entry)) {
  throw "Entry point not found: $entry"
}

$dartFiles = Get-ChildItem -LiteralPath $libRoot -Recurse -File -Filter "*.dart" |
  Where-Object { $_.FullName -notmatch "\\\\.dart_tool\\\\" } |
  Where-Object { $_.Name -notmatch "\\.g\\.dart$" } |
  Where-Object { $_.Name -notmatch "\\.freezed\\.dart$" } |
  Select-Object -ExpandProperty FullName

$depsMap = @{}
foreach ($f in $dartFiles) {
  $depsMap[$f] = @(Get-DartDeps -File $f)
}

$reachable = New-Object System.Collections.Generic.HashSet[string]
$queue = New-Object System.Collections.Generic.Queue[string]

$reachable.Add((Resolve-Path $entry).Path) | Out-Null
$queue.Enqueue((Resolve-Path $entry).Path)

while ($queue.Count -gt 0) {
  $cur = $queue.Dequeue()
  if (!$depsMap.ContainsKey($cur)) { continue }
  foreach ($d in $depsMap[$cur]) {
    if ($reachable.Add($d)) {
      $queue.Enqueue($d)
    }
  }
}

$unreachable = $dartFiles | Where-Object { -not $reachable.Contains($_) } | Sort-Object

$out = [ordered]@{
  repoRoot = $repoRoot
  entry = $entry
  totalDartFiles = $dartFiles.Count
  reachableCount = $reachable.Count
  unreachableCount = $unreachable.Count
  unreachable = $unreachable
}

$jsonPath = Join-Path $repoRoot "docs\\audit_unused_dart_2026-02-05.json"
if (!(Test-Path (Split-Path -Parent $jsonPath))) {
  New-Item -ItemType Directory -Path (Split-Path -Parent $jsonPath) | Out-Null
}
$out | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

Write-Host "Wrote: $jsonPath"
Write-Host ("Unreachable: {0}" -f $unreachable.Count)
