<#
.SYNOPSIS
  Calls the n8n public API (/api/v1) using N8N_API_URL and N8N_API_KEY from the .env at the repo root.
  The key is never printed: any occurrence of it in the output (stdout, stderr or -OutFile) becomes ***.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\n8n-api.ps1 -Method GET -Path workflows/<workflow-id> -OutFile workflows\<slug>\workflow.json
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\n8n-api.ps1 -Method PUT -Path workflows/<workflow-id> -BodyFile body.json

.NOTES
  Exit codes: 0 ok, 1 HTTP error (status + body on stderr), 2 network error, 3 .env missing or empty,
  4 usage/local error (bad or missing argument, -BodyFile not found, -OutFile can't be written).
  Usage errors are checked before .env is read, and nothing is sent to n8n.
#>
[CmdletBinding(PositionalBinding = $false)]
param(
  [string]$Method,
  [string]$Path,
  [string]$BodyFile,
  [string]$OutFile,
  [Parameter(ValueFromRemainingArguments)][string[]]$Rest
)
$ErrorActionPreference = 'Stop'

# Usage checks: exit 4 with a short message instead of a PowerShell error or an interactive prompt.
function Exit-Usage([string]$msg) {
  [Console]::Error.WriteLine("Usage error: $msg")
  [Console]::Error.WriteLine('Usage: n8n-api.ps1 -Method GET|POST|PUT|PATCH|DELETE -Path <path under /api/v1> [-BodyFile <json>] [-OutFile <file>]')
  exit 4
}
function Get-FullPath([string]$p) { $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($p) }

if ($Rest) { Exit-Usage "unexpected argument(s): $($Rest -join ' ')" }
if (-not $Method) { Exit-Usage '-Method is required' }
$Method = $Method.ToUpperInvariant()
if (@('GET', 'POST', 'PUT', 'PATCH', 'DELETE') -notcontains $Method) { Exit-Usage "invalid -Method '$Method'" }
if (-not $Path) { Exit-Usage '-Path is required' }
if ($BodyFile) {
  $bodyPath = Get-FullPath $BodyFile
  if (-not (Test-Path -LiteralPath $bodyPath -PathType Leaf)) { Exit-Usage "-BodyFile not found: $BodyFile" }
}
if ($OutFile) {
  $outPath = Get-FullPath $OutFile
  if (Test-Path -LiteralPath $outPath -PathType Container) { Exit-Usage "-OutFile is a folder, expected a file path: $OutFile" }
  $outDir = Split-Path -Parent $outPath
  if ($outDir -and -not (Test-Path -LiteralPath $outDir -PathType Container)) {
    try { New-Item -ItemType Directory -Path $outDir -Force -ErrorAction Stop | Out-Null } catch { }
    if (-not (Test-Path -LiteralPath $outDir -PathType Container)) { Exit-Usage "cannot create folder for -OutFile: $outDir" }
  }
}

$envFile = Join-Path $PSScriptRoot '..\.env'
if (-not (Test-Path $envFile)) { [Console]::Error.WriteLine('.env not found at the repo root'); exit 3 }
$cfg = @{}
foreach ($line in Get-Content $envFile -Encoding UTF8) {
  if ($line -match '^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$') { $cfg[$Matches[1]] = $Matches[2].Trim('"', "'") }
}
$key = $cfg['N8N_API_KEY']
$base = $cfg['N8N_API_URL']
if (-not $key) { [Console]::Error.WriteLine('N8N_API_KEY is empty in .env'); exit 3 }
if (-not $base) { [Console]::Error.WriteLine('N8N_API_URL is empty in .env'); exit 3 }

function Hide([string]$s) { if ($s) { $s.Replace($key, '***') } else { $s } }

$uri = $base.TrimEnd('/') + '/api/v1/' + $Path.TrimStart('/')

Add-Type -AssemblyName System.Net.Http
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$client = New-Object System.Net.Http.HttpClient
$client.Timeout = [TimeSpan]::FromSeconds(120)
$req = New-Object System.Net.Http.HttpRequestMessage ([System.Net.Http.HttpMethod]::new($Method)), $uri
$req.Headers.Add('X-N8N-API-KEY', $key)
$req.Headers.Add('Accept', 'application/json')
if ($BodyFile) {
  try { $body = [IO.File]::ReadAllText($bodyPath, [Text.Encoding]::UTF8) }
  catch { Exit-Usage "cannot read -BodyFile: $BodyFile" }
  $req.Content = New-Object System.Net.Http.StringContent($body, [Text.Encoding]::UTF8, 'application/json')
}

try {
  $resp = $client.SendAsync($req).GetAwaiter().GetResult()
  $bytes = $resp.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
} catch {
  [Console]::Error.WriteLine((Hide ('Network error: ' + $_.Exception.GetBaseException().Message)))
  exit 2
} finally {
  $client.Dispose()
}

$raw = [Text.Encoding]::UTF8.GetString($bytes)
$text = Hide $raw
if ($text -ne $raw) { [Console]::Error.WriteLine('WARNING: the response contained the API key; it was replaced with ***') }
$status = [int]$resp.StatusCode

if (-not $resp.IsSuccessStatusCode) {
  [Console]::Error.WriteLine("HTTP $status $($resp.ReasonPhrase)`n$text")
  exit 1
}
if ($OutFile) {
  try { [IO.File]::WriteAllText($outPath, $text, (New-Object Text.UTF8Encoding $false)) }
  catch {
    [Console]::Error.WriteLine("Request succeeded (HTTP $status) but -OutFile could not be written: $OutFile")
    exit 4
  }
  Write-Output "HTTP $status -> $OutFile ($($bytes.Length) bytes)"
} else {
  Write-Output $text
}
