<#
.SYNOPSIS
  Calls the n8n public API (/api/v1) using N8N_API_URL and N8N_API_KEY from the .env at the repo root.
  The key is never printed: any occurrence of it in the output (stdout, stderr or -OutFile) becomes ***.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\n8n-api.ps1 -Method GET -Path workflows/<workflow-id> -OutFile workflows\<slug>\workflow.json
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\n8n-api.ps1 -Method PUT -Path workflows/<workflow-id> -BodyFile body.json

.NOTES
  Exit codes: 0 ok, 1 HTTP error (status + body on stderr), 2 network error, 3 .env missing or empty.
#>
param(
  [Parameter(Mandatory)][ValidateSet('GET', 'POST', 'PUT', 'PATCH', 'DELETE')][string]$Method,
  [Parameter(Mandatory)][string]$Path,
  [string]$BodyFile,
  [string]$OutFile
)
$ErrorActionPreference = 'Stop'

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
  $body = [IO.File]::ReadAllText((Resolve-Path $BodyFile), [Text.Encoding]::UTF8)
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
  $full = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutFile)
  [IO.File]::WriteAllText($full, $text, (New-Object Text.UTF8Encoding $false))
  Write-Output "HTTP $status -> $OutFile ($($bytes.Length) bytes)"
} else {
  Write-Output $text
}
