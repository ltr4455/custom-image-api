param(
  [ValidateSet("generate", "edit")]
  [string]$Mode = "generate",
  [string]$Endpoint = $env:CUSTOM_IMAGE_API_URL,
  [string]$ApiKey = $env:CUSTOM_IMAGE_API_KEY,
  [string]$Model = $env:CUSTOM_IMAGE_MODEL,
  [Parameter(Mandatory = $true)]
  [string]$Prompt,
  [string]$Image,
  [Parameter(Mandatory = $true)]
  [string]$Out
)

$ErrorActionPreference = "Stop"

function Import-DotEnv {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return }
  Get-Content -LiteralPath $Path | ForEach-Object {
    $line = $_.Trim()
    if (-not $line -or $line.StartsWith("#")) { return }
    $parts = $line -split "=", 2
    if ($parts.Count -ne 2) { return }
    $name = $parts[0].Trim()
    $value = $parts[1].Trim()
    $value = $value -replace '^"', '' -replace '"$', ''
    [Environment]::SetEnvironmentVariable($name, $value, "Process")
  }
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$skillDir = Split-Path -Parent $scriptDir
Import-DotEnv (Join-Path $skillDir ".env")

if (-not $Endpoint) { $Endpoint = $env:CUSTOM_IMAGE_API_URL }
if (-not $ApiKey) { $ApiKey = if ($env:CUSTOM_IMAGE_API_KEY) { $env:CUSTOM_IMAGE_API_KEY } else { $env:OPENAI_API_KEY } }
if (-not $Model) { $Model = $env:CUSTOM_IMAGE_MODEL }

function Resolve-Endpoint {
  param([string]$Url, [string]$Mode)
  if (-not $Url) {
    if ($env:OPENAI_BASE_URL) {
      $route = if ($Mode -eq "edit") { "edits" } else { "generations" }
      return "$($env:OPENAI_BASE_URL.TrimEnd('/'))/images/$route"
    }
    throw "Endpoint is required. Set CUSTOM_IMAGE_API_URL, OPENAI_BASE_URL, or pass -Endpoint."
  }
  if ($Url -match '^\d+$') {
    $route = if ($Mode -eq "edit") { "edits" } else { "generations" }
    return "http://127.0.0.1:$Url/v1/images/$route"
  }
  return $Url
}

function Get-JsonValue {
  param($Object, [string[]]$Path)
  $current = $Object
  foreach ($part in $Path) {
    if ($null -eq $current) { return $null }
    if ($current -is [array]) {
      $index = [int]$part
      if ($current.Count -le $index) { return $null }
      $current = $current[$index]
    } elseif ($current.PSObject.Properties.Name -contains $part) {
      $current = $current.$part
    } else {
      return $null
    }
  }
  return $current
}

function Extract-ImagePayload {
  param($Json)
  $paths = @(
    @("data", "0", "b64_json"),
    @("data", "0", "base64"),
    @("data", "0", "image"),
    @("b64_json"),
    @("base64"),
    @("image"),
    @("output", "0", "result")
  )
  foreach ($path in $paths) {
    $value = Get-JsonValue $Json $path
    if ($value) { return @{ Kind = "base64"; Value = [string]$value } }
  }
  $url = Get-JsonValue $Json @("data", "0", "url")
  if ($url) { return @{ Kind = "url"; Value = [string]$url } }
  throw "Could not find an image payload in the API response."
}

function Save-Base64Image {
  param([string]$Base64, [string]$Path)
  $clean = $Base64 -replace '^data:image/[^;]+;base64,', ''
  [IO.File]::WriteAllBytes($Path, [Convert]::FromBase64String($clean))
}

function New-MultipartBody {
  param(
    [hashtable]$Fields,
    [string]$FileField,
    [string]$FilePath,
    [string]$Boundary
  )
  $lineBreak = "`r`n"
  $encoding = [Text.Encoding]::UTF8
  $stream = New-Object IO.MemoryStream

  foreach ($key in $Fields.Keys) {
    $part = "--$Boundary$lineBreak" +
      "Content-Disposition: form-data; name=`"$key`"$lineBreak$lineBreak" +
      "$($Fields[$key])$lineBreak"
    $bytes = $encoding.GetBytes($part)
    $stream.Write($bytes, 0, $bytes.Length)
  }

  $fileName = [IO.Path]::GetFileName($FilePath)
  $fileHeader = "--$Boundary$lineBreak" +
    "Content-Disposition: form-data; name=`"$FileField`"; filename=`"$fileName`"$lineBreak" +
    "Content-Type: image/png$lineBreak$lineBreak"
  $headerBytes = $encoding.GetBytes($fileHeader)
  $stream.Write($headerBytes, 0, $headerBytes.Length)

  $fileBytes = [IO.File]::ReadAllBytes($FilePath)
  $stream.Write($fileBytes, 0, $fileBytes.Length)

  $footerBytes = $encoding.GetBytes("$lineBreak--$Boundary--$lineBreak")
  $stream.Write($footerBytes, 0, $footerBytes.Length)
  return $stream.ToArray()
}

$Endpoint = Resolve-Endpoint $Endpoint $Mode
if (-not $Model) { $Model = "image-model" }

$headers = @{}
if ($ApiKey) { $headers["Authorization"] = "Bearer $ApiKey" }

$outDir = Split-Path -Parent $Out
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
  New-Item -ItemType Directory -Path $outDir | Out-Null
}

if ($Mode -eq "edit") {
  if (-not $Image) { throw "Image is required in edit mode." }
  if (-not (Test-Path -LiteralPath $Image)) { throw "Image not found: $Image" }
  $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
  if ($curl) {
    $responsePath = [IO.Path]::GetTempFileName()
    $args = @("-sS", "-X", "POST", $Endpoint)
    if ($ApiKey) { $args += @("-H", "Authorization: Bearer $ApiKey") }
    $args += @("-F", "model=$Model", "-F", "prompt=$Prompt", "-F", "image=@$Image", "-o", $responsePath)
    & curl.exe @args
    if ($LASTEXITCODE -ne 0) { throw "curl.exe failed with exit code $LASTEXITCODE" }
    $raw = Get-Content -LiteralPath $responsePath -Raw
    Remove-Item -LiteralPath $responsePath -Force
    $response = $raw | ConvertFrom-Json
  } else {
    $boundary = "----CustomImageApiBoundary$([Guid]::NewGuid().ToString('N'))"
    $bodyBytes = New-MultipartBody -Fields @{
      model = $Model
      prompt = $Prompt
    } -FileField "image" -FilePath $Image -Boundary $boundary
    $response = Invoke-RestMethod -Method Post -Uri $Endpoint -Headers $headers -ContentType "multipart/form-data; boundary=$boundary" -Body $bodyBytes
  }
} else {
  $body = @{
    model = $Model
    prompt = $Prompt
  } | ConvertTo-Json -Depth 8
  $response = Invoke-RestMethod -Method Post -Uri $Endpoint -Headers $headers -ContentType "application/json" -Body $body
}

$payload = Extract-ImagePayload $response
if ($payload.Kind -eq "url") {
  Invoke-WebRequest -Uri $payload.Value -Headers $headers -OutFile $Out | Out-Null
} else {
  Save-Base64Image $payload.Value $Out
}

Write-Output "Saved image: $Out"
Write-Output "Endpoint: $Endpoint"
Write-Output "Model: $Model"
