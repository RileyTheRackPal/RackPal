<#
.SYNOPSIS
    The analyzer gate: zero errors, zero warnings, and a RATCHETED info count.

.DESCRIPTION
    WHY THIS IS NOT `dart analyze --fatal-infos`. docs/11 section 8 asks for
    `--fatal-infos --fatal-warnings` and it is right about the reason -- "an
    info-level lint that nobody fixes is a lint that trains people to ignore
    output". It is also, today, unrunnable: the tree sits at 195 info-level
    issues under very_good_analysis 9.0.0, so `--fatal-infos` makes main red
    on the first push, and a permanently red main trains people to ignore
    output far faster than an info ever did (docs/12 section 4.1 makes exactly
    this argument).

    WHY NOT SIMPLY `flutter analyze` EITHER. It exits 1 on infos alone, so it
    has the same problem; and plain `dart analyze` exits 0 on infos, which has
    the opposite one -- it would let the count climb without limit. That is
    not hypothetical here: the salvage recorded 203 infos becoming 395 with
    nothing stopping it.

    SO: severity is gated absolutely and volume is gated by a RATCHET.

      * any ERROR   -> fail. Non-negotiable.
      * any WARNING -> fail. Non-negotiable.
      * INFO count > the pinned baseline -> fail, naming the delta.
      * INFO count < the pinned baseline -> PASS, with a warning that says to
        lower the pin. Failing an improvement would be perverse; saying
        nothing would let the ratchet rust at a number nobody revisits.

    The pin lives in ONE file, tools/ci/analyze_info_baseline.txt, so lowering
    it is a one-line reviewable diff and raising it is a visible act somebody
    has to defend in a pull request. Clearing the 195 outright, and then
    switching this gate to --fatal-infos, remains the right destination; this
    is the mechanism that stops the number moving the wrong way meanwhile.

    Severity is read from `dart analyze --format=machine`, whose first
    pipe-delimited field is the severity, rather than from an exit code --
    `dart analyze` exits 0 on infos and `flutter analyze` exits 1 on the same
    tree, so no single exit code expresses this policy.

    AND THE TWO TOOLS SEE THE SAME TREE, which is the part worth measuring
    rather than assuming: `flutter analyze` is the command this project runs
    by hand, and this gate runs the other one. Both were captured and
    compared issue by issue (file, line, rule) at commit 0fa532d -- 195
    apiece, symmetric difference empty. So a number produced here and a
    number produced by `flutter analyze` are the same number, and a
    developer's habitual command agrees with the gate. It also confirms that
    the root sweep reaches apps/rackpal, which nothing about `dart analyze .`
    in a pub workspace guarantees on its face.

.PARAMETER RepoRoot
    Repository root. Defaults to two directories above this script.

.PARAMETER BaselineFile
    File holding the single integer info baseline.

.PARAMETER UpdateBaseline
    Rewrite the baseline to the observed count instead of gating. For use by a
    human deliberately re-pinning, never by the pipeline.

.EXAMPLE
    pwsh -File tools/ci/analyze_gate.ps1
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
    [string]$BaselineFile = (Join-Path $PSScriptRoot 'analyze_info_baseline.txt'),
    [switch]$UpdateBaseline
)

$ErrorActionPreference = 'Stop'

Write-Host "== analyzer gate =="
Write-Host "repo root : $RepoRoot"

Push-Location $RepoRoot
try {
    # `--format=machine` writes SEVERITY|TYPE|CODE|FILE|LINE|COL|LEN|MESSAGE
    # to stdout, one issue per line, and nothing else.
    $raw = & dart analyze --format=machine . 2>&1
    $analyzeExit = $LASTEXITCODE
} finally {
    Pop-Location
}

$issues = @()
$toolOutput = @()
foreach ($line in $raw) {
    $text = [string]$line
    $parts = $text.Split('|')
    if ($parts.Length -ge 8 -and
        $parts[0] -in @('ERROR', 'WARNING', 'INFO')) {
        $issues += , $parts
    } elseif ($text.Trim().Length -gt 0) {
        $toolOutput += $text
    }
}

# A TOOL THAT DID NOT RUN MUST NOT READ AS A CLEAN TREE. `dart analyze` exits
# non-zero both for "found something fatal" and for "could not resolve the
# package graph"; the second produces no parseable issue lines at all, and
# without this clause it would sail through every count below as zero.
if ($analyzeExit -ne 0 -and $issues.Count -eq 0) {
    Write-Host "##vso[task.logissue type=error]dart analyze exited $analyzeExit and produced no issue lines -- it did not run. Output follows."
    $toolOutput | ForEach-Object { Write-Host "  $_" }
    exit 1
}
if ($toolOutput.Count -gt 0) {
    Write-Host "-- non-issue output from dart analyze --"
    $toolOutput | ForEach-Object { Write-Host "  $_" }
}

$errors   = @($issues | Where-Object { $_[0] -eq 'ERROR' })
$warnings = @($issues | Where-Object { $_[0] -eq 'WARNING' })
$infos    = @($issues | Where-Object { $_[0] -eq 'INFO' })

Write-Host ""
Write-Host ("errors   : {0}" -f $errors.Count)
Write-Host ("warnings : {0}" -f $warnings.Count)
Write-Host ("infos    : {0}" -f $infos.Count)

if ($infos.Count -gt 0) {
    Write-Host ""
    Write-Host "-- infos by rule (so drift is diagnosable, not just detectable) --"
    $infos |
        Group-Object { $_[2] } |
        Sort-Object Count -Descending |
        ForEach-Object { Write-Host ("  {0,5}  {1}" -f $_.Count, $_.Name) }
}

foreach ($issue in ($errors + $warnings)) {
    $severity = if ($issue[0] -eq 'ERROR') { 'error' } else { 'warning' }
    Write-Host ("##vso[task.logissue type={0};sourcepath={1};linenumber={2};columnnumber={3};code={4}]{5}" -f
        $severity, $issue[3].Replace('\\', '\'), $issue[4], $issue[5], $issue[2], $issue[7])
}

if ($UpdateBaseline) {
    # Keep the comment header; replace only the integer line.
    $existing = if (Test-Path $BaselineFile) { @(Get-Content -Path $BaselineFile) } else { @() }
    $header = @($existing | Where-Object { $_.Trim().Length -eq 0 -or $_.Trim().StartsWith('#') })
    Set-Content -Path $BaselineFile -Value ($header + [string]$infos.Count)
    Write-Host ""
    Write-Host "baseline rewritten to $($infos.Count) in $BaselineFile"
    exit 0
}

if (-not (Test-Path $BaselineFile)) {
    Write-Host "##vso[task.logissue type=error]missing baseline file $BaselineFile"
    exit 1
}
# The file is a comment header plus one integer, so the number is not a bare
# magic constant sitting on its own in a text file.
$baselineText = @(Get-Content -Path $BaselineFile |
    Where-Object { $_.Trim().Length -gt 0 -and -not $_.Trim().StartsWith('#') } |
    Select-Object -First 1)
$baseline = 0
if ($baselineText.Count -ne 1 -or
    -not [int]::TryParse($baselineText[0].Trim(), [ref]$baseline)) {
    Write-Host "##vso[task.logissue type=error]baseline file $BaselineFile holds no integer line (comments start with #)"
    exit 1
}
Write-Host ""
Write-Host ("baseline : {0}  ({1})" -f $baseline, $BaselineFile)

$failed = $false

if ($errors.Count -gt 0) {
    Write-Host "##vso[task.logissue type=error]ANALYZE GATE: $($errors.Count) error(s). The gate is zero; this is not ratcheted."
    $failed = $true
}
if ($warnings.Count -gt 0) {
    Write-Host "##vso[task.logissue type=error]ANALYZE GATE: $($warnings.Count) warning(s). The gate is zero; this is not ratcheted."
    $failed = $true
}
if ($infos.Count -gt $baseline) {
    $delta = $infos.Count - $baseline
    Write-Host "##vso[task.logissue type=error]ANALYZE GATE: info count rose by $delta ($baseline -> $($infos.Count)). Fix the new infos, or -- if they are genuinely acceptable -- raise the pin in $BaselineFile in the same change and say why in the commit message."
    Write-Host ""
    Write-Host "-- every info, so the new ones can be found --"
    $infos | ForEach-Object {
        Write-Host ("  {0}  {1}:{2}  {3}" -f $_[2], $_[3].Replace('\\', '\'), $_[4], $_[7])
    }
    $failed = $true
} elseif ($infos.Count -lt $baseline) {
    $delta = $baseline - $infos.Count
    Write-Host "##vso[task.logissue type=warning]ANALYZE GATE: info count FELL by $delta ($baseline -> $($infos.Count)). Lower the pin in $BaselineFile to $($infos.Count) so the ground you gained cannot be given back."
}

if ($failed) {
    Write-Host ""
    Write-Host "analyzer gate FAILED"
    exit 1
}

Write-Host ""
Write-Host "analyzer gate passed"
exit 0
