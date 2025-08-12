param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$UserArgs
)

$ErrorActionPreference = 'Stop'

# --- Enhanced UTF-8 console output with Unicode support ---
$prevOutEnc = [Console]::OutputEncoding
$prevInEnc  = [Console]::InputEncoding
$prevPSOut  = $OutputEncoding
try {
  # Set both input and output to UTF-8 without BOM
  [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
  [Console]::InputEncoding  = [System.Text.UTF8Encoding]::new($false)
  $OutputEncoding           = [Console]::OutputEncoding
  
  # Enable VT100 sequences for better Unicode support on Windows 10/11
  if ([Environment]::OSVersion.Version.Major -ge 10) {
    try {
      $null = [Console]::SetWindowSize([Console]::WindowWidth, [Console]::WindowHeight)
    } catch {
      # Ignore if not supported
    }
  }
}
catch {
  # harmless on older hosts; ignore
}

# --- System Prompt ---
$SYSTEM = @'
ROLE: You are a personal assistant running inside PowerShell who can help automate various tasks on Windows 11 with various Windows, cygwin64, and other tools available at your disposal.

Rules you must follow:
1) All user requests are about automation or working with Windows in the current folder's context. Never use Google search (unless the question is not related to automation or Windows tasks). Only use shell or other tools needed to perform automation or Windows tasks to perform the user request.
2) Do NOT ask any questions; make sane assumptions on your own based on the given task.
3) Always show detailed outputs of any commands you run, tools you use, or steps you perform to complete the given user request.
4) In your answer, always provide PLAN (as # PLAN in markdown format) along with numbered list so the user can undo these steps if needed.
5) STYLE: concise, numbered, reproducible, markdown format always.
6) Always put your answer on a new line, use paragraphs, and rich formatting such as **bold**, *italic*, bullets, headings (use single # for all types of headings), etc., using markdown format.
7) Finally, verify the user request has been completed.
8) After every heading, insert one blank line before any list or paragraph.
9) Use markdown table format when it makes sense for the answer in OUTPUT section.

NOTE: Output of your answer will be forwarded to glow tool, so use markdown formatting supported by the glow tool with good terminal compatibility.

Output Format:
# PLAN:

1. Sample step 1
2. Sample step 2
3. Sample step 3

# PLAN EXECUTION:

1. Using x tool for step 1
2. Using y tool for step 2
3. Using z tool for step 3

# OUTPUT:

{Your final answer here.}

'@

# --- Helpers ---
function Set-ContentUtf8NoBom {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$Value
  )
  $enc = [System.Text.UTF8Encoding]::new($false)  # false => no BOM
  [System.IO.File]::WriteAllText($Path, $Value, $enc)
}

function Get-HttpStatusFromText {
  param([string]$Text)
  if (-not $Text) { return $null }

  # Try JSON-ish patterns first: "code": 429  OR  status 429  OR  "status":"Too Many Requests"
  $m = [regex]::Match($Text, '(?is)"code"\s*:\s*(?<code>\d{3})')
  if ($m.Success) { return [int]$m.Groups['code'].Value }

  $m = [regex]::Match($Text, '(?i)\bstatus(?:\s*code)?\D{0,5}(?<code>\d{3})')
  if ($m.Success) { return [int]$m.Groups['code'].Value }

  if ($Text -match '(?i)"status"\s*:\s*"Too\s*Many\s*Requests"|RESOURCE_EXHAUSTED') { return 429 }

  return $null
}

function Show-FriendlyGeminiError {
  param([string]$ErrorText)

  $status = Get-HttpStatusFromText -Text $ErrorText
  if ($status -eq 429) {
    # Just show friendly message in red, no error object formatting
    Write-Host "You have exhausted your quota, please try again later." -ForegroundColor Red
  }
  else {
    # For other errors, still show in red but preserve actual message
    Write-Host $ErrorText -ForegroundColor Red
  }
}

function Show-PromptDebug {
  param(
    [Parameter(Mandatory=$true)][string]$Prompt
  )
  Write-Host "----- DEBUG: Prompt being sent to AI -----" -ForegroundColor Yellow
  Write-Host $Prompt
  Write-Host "----------------------------------------" -ForegroundColor Yellow
}

function Set-ConsoleCodePage {
  param([Parameter(Mandatory)][int]$CodePage)
  try {
    # Use native Windows API for better reliability
    $null = cmd /c "chcp $CodePage 2>nul"
  } catch {
    # Fallback method
    & "$env:SystemRoot\System32\chcp.com" $CodePage > $null 2>&1
  }
}

function Get-ConsoleCodePage {
  # Returns the numeric code page (e.g., 65001)
  try {
    $out = cmd /c "chcp 2>nul"
    return [int]($out -replace '\D+','')
  } catch {
    # Fallback
    $out = & "$env:SystemRoot\System32\chcp.com" 2>$null
    return [int]($out -replace '\D+','')
  }
}

function Initialize-UnicodeEnvironment {
  # Set environment variables for better Unicode support
  $env:PYTHONIOENCODING = 'utf-8'
  $env:LC_ALL = 'C.UTF-8'
  $env:LANG = 'en_US.UTF-8'
  
  # Try to enable VT processing for Windows Terminal features
  if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
    try {
      $handle = [System.Console]::OpenStandardOutput()
      # Enable virtual terminal processing if supported
    } catch {
      # Ignore if not supported
    }
  }
}

function Show-WithGlow {
  param([Parameter(Mandatory)][string]$Path)

  $prevCp    = Get-ConsoleCodePage
  $prevLang  = $env:LANG
  $prevLcAll = $env:LC_ALL
  $prevPager = $env:GLOW_PAGER
  $prevPythonIo = $env:PYTHONIOENCODING

  Write-Host ("[Glow] Code page before: {0}" -f $prevCp) -ForegroundColor Cyan
  try {
    # Ensure UTF-8 code page
    Set-ConsoleCodePage -CodePage 65001
    Write-Host ("[Glow] Code page set to: {0}" -f (Get-ConsoleCodePage)) -ForegroundColor Green

    # Initialize Unicode environment
    Initialize-UnicodeEnvironment
    $env:GLOW_PAGER = 'never'
    
    # Additional glow-specific settings for better Unicode rendering
    $env:GLOW_STYLE = 'auto'  # Let glow auto-detect terminal capabilities
    
    Write-Host "[Glow] Rendering with Unicode support..." -ForegroundColor Yellow
    & $scriptGlow $Path
  }
  catch {
    Write-Host "Error running glow: $_" -ForegroundColor Red
    # Fallback to showing the file content directly
    Write-Host "Showing content directly:" -ForegroundColor Yellow
    Get-Content -Path $Path -Encoding UTF8 | Write-Host
  }
  finally {
    # Restore everything
    Set-ConsoleCodePage -CodePage $prevCp
    Write-Host ("[Glow] Code page restored: {0}" -f (Get-ConsoleCodePage)) -ForegroundColor Cyan
    $env:LANG       = $prevLang
    $env:LC_ALL     = $prevLcAll
    $env:GLOW_PAGER = $prevPager
    $env:PYTHONIOENCODING = $prevPythonIo
  }
}

# Initialize Unicode environment early
Initialize-UnicodeEnvironment

$NowStamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

# --- User Input Handling ---
$RawUser  = [string]::Join(' ', $UserArgs)
$SafeUser = $RawUser -replace '`','``'   # backtick → doubled backtick

# --- Compose payload ---
$PAYLOAD = @"
Today Date & Time: $NowStamp

$SYSTEM

---

USER REQUEST:
$SafeUser
"@

# Debug output (comment out when not needed)
# Show-PromptDebug -Prompt $PAYLOAD

# --- Output file & CLI args ---
$tmpFile = Join-Path $env:TEMP ("gemini_output_{0}.md" -f (Get-Random))
$gemArgs = @('--model','gemini-2.5-flash','--yolo','--prompt', $PAYLOAD)

try {
  # STREAM live to console while saving to file
  if ($PSVersionTable.PSVersion.Major -ge 7) {
    & gemini @gemArgs 2>&1 |
      Tee-Object -FilePath $tmpFile -Encoding utf8 |
      Out-Host
  } else {
    & gemini @gemArgs 2>&1 |
      Tee-Object -FilePath $tmpFile |
      Out-Host

    # Re-encode to UTF-8 (no BOM) for Glow on WinPS 5.1
    $raw = Get-Content -LiteralPath $tmpFile -Raw -Encoding UTF8
    Set-ContentUtf8NoBom -Path $tmpFile -Value $raw
  }

  # --- Post-run checks (keep streaming intact) ---
  $gemExit = $LASTEXITCODE
  $content = (Get-Content -LiteralPath $tmpFile -Raw -Encoding UTF8)

  if ($gemExit -ne 0) {
    Show-FriendlyGeminiError -ErrorText ("Gemini exited with code {0}. {1}" -f $gemExit, $content)
    exit $gemExit
  }

  # Catch silent/short error-like responses even with exit 0
  $looksErrorish = $false
  if ([string]::IsNullOrWhiteSpace($content)) { $looksErrorish = $true }
  elseif ($content.Length -lt 200 -and $content -match '(?i)\b(error|invalid|unauthorized|quota|rate|timeout|unavailable|failed|exception)\b') {
    $looksErrorish = $true
  }

  if ($looksErrorish) {
    Show-FriendlyGeminiError -ErrorText $content
    exit 1
  }
}
catch {
  Show-FriendlyGeminiError -ErrorText ("Failed to run gemini: {0}" -f $_.Exception.Message)
  exit 1
}

# --- Enhanced markdown normalization with Unicode preservation ---
$content = Get-Content -LiteralPath $tmpFile -Raw -Encoding UTF8

# Ensure exactly one blank line after headings (any ATX level)
$content = $content -replace '(?m)^(#{1,6}\s+.+)\r?\n(?!\r?\n)', "`$1`r`n`r`n"

# Strip leading BOM if present
if ($content.Length -gt 0 -and $content[0] -eq [char]0xFEFF) {
  $content = $content.Substring(1)
}

# Normalize line endings to CRLF for Windows
$content = $content -replace '\r?\n', "`r`n"

# Write back without BOM so Glow parses correctly
Set-ContentUtf8NoBom -Path $tmpFile -Value $content

Clear-Host

# --- Render with glow if available, else show saved path ---
$scriptGlow = Join-Path $PSScriptRoot 'glow.exe'
if (Test-Path $scriptGlow) {
  Show-WithGlow -Path $tmpFile
}
elseif ($glowCmd = Get-Command glow -ErrorAction SilentlyContinue) {
  $prevCp    = Get-ConsoleCodePage
  $prevLang  = $env:LANG
  $prevLcAll = $env:LC_ALL
  $prevPager = $env:GLOW_PAGER
  $prevPythonIo = $env:PYTHONIOENCODING

  try {
    Set-ConsoleCodePage -CodePage 65001

    Initialize-UnicodeEnvironment
    $env:GLOW_PAGER = 'never'
    $env:GLOW_STYLE = 'auto'

    & $glowCmd.Source $tmpFile
  }
  catch {
    Write-Host "Error running glow: $_" -ForegroundColor Red
    Get-Content -Path $tmpFile -Encoding UTF8 | Write-Host
  }
  finally {
    Set-ConsoleCodePage -CodePage $prevCp
    $env:LANG       = $prevLang
    $env:LC_ALL     = $prevLcAll
    $env:GLOW_PAGER = $prevPager
    $env:PYTHONIOENCODING = $prevPythonIo
  }
}
else {
  Write-Host "[Info] glow not found. Output saved at:`n$tmpFile"
  Write-Host "[Info] Content preview:" -ForegroundColor Yellow
  Get-Content -Path $tmpFile -Encoding UTF8 -TotalCount 10 | Write-Host
}

# --- Restore previous encodings ---
try {
  if ($prevOutEnc) { [Console]::OutputEncoding = $prevOutEnc }
  if ($prevInEnc)  { [Console]::InputEncoding  = $prevInEnc }
  if ($prevPSOut)  { $OutputEncoding           = $prevPSOut }
} catch {}