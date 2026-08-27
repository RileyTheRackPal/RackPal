<#
.SYNOPSIS
    Read a PE binary's import table. No toolchain required.

.DESCRIPTION
    `Get-PEImports` returns the DLL names a .exe or .dll imports, parsed
    straight out of the file. It exists because the question "which runtime
    DLLs does the shipped build actually need" must be ANSWERED FROM THE
    BINARY, and the obvious tool for that -- `dumpbin` -- is part of a Visual
    Studio installation that a build agent may not have on PATH. This is
    ~40 lines and has no dependency at all.

    THE ALTERNATIVE WAS A HARDCODED LIST, and hardcoding it is how the list
    goes stale in silence. A plugin added in M4 that pulls `msvcp140_2.dll`
    would not change any list written today; it WOULD change this answer.
    `make_portable.ps1` derives the runtime set from these imports and
    reports it on every run, which is the same discipline
    `verify_windows_build.ps1` applies to the shipped native set: print what
    is there, compare it to what was expected, and make the surprise loud.

    WHAT IT DOES NOT DO: delay-loaded imports (a separate directory) and
    anything resolved with `LoadLibrary` at runtime are invisible here, as
    they are to `dumpbin /imports`. For the CRT question that is not a gap
    -- the C++ runtime is linked, not loaded -- but it is a real limit and
    is stated rather than discovered.
#>

Set-StrictMode -Version Latest

function Get-PEImports {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 0x40) { return @() }

    $peOff = [BitConverter]::ToInt32($bytes, 0x3C)
    if ($peOff -le 0 -or ($peOff + 24) -ge $bytes.Length) { return @() }
    # 'PE\0\0'
    if ($bytes[$peOff] -ne 0x50 -or $bytes[$peOff + 1] -ne 0x45) { return @() }

    $numSections = [BitConverter]::ToUInt16($bytes, $peOff + 6)
    $optSize     = [BitConverter]::ToUInt16($bytes, $peOff + 20)
    $magic       = [BitConverter]::ToUInt16($bytes, $peOff + 24)

    # PE32+ puts the data directories 16 bytes further in than PE32.
    $dirOff = $peOff + 24 + $(if ($magic -eq 0x20b) { 112 } else { 96 })
    $importRva = [BitConverter]::ToUInt32($bytes, $dirOff + 8)
    if ($importRva -eq 0) { return @() }

    $secStart = $peOff + 24 + $optSize
    $sections = @()
    for ($i = 0; $i -lt $numSections; $i++) {
        $s = $secStart + $i * 40
        $sections += [pscustomobject]@{
            VirtualAddress = [BitConverter]::ToUInt32($bytes, $s + 12)
            VirtualSize    = [BitConverter]::ToUInt32($bytes, $s + 8)
            RawPointer     = [BitConverter]::ToUInt32($bytes, $s + 20)
        }
    }

    function ConvertTo-FileOffset([uint32]$rva) {
        foreach ($s in $sections) {
            if ($rva -ge $s.VirtualAddress -and
                $rva -lt ($s.VirtualAddress + $s.VirtualSize)) {
                return $s.RawPointer + ($rva - $s.VirtualAddress)
            }
        }
        return 0
    }

    $names = @()
    $entry = ConvertTo-FileOffset $importRva
    if ($entry -eq 0) { return @() }
    while ($true) {
        if (($entry + 20) -gt $bytes.Length) { break }
        $nameRva = [BitConverter]::ToUInt32($bytes, $entry + 12)
        if ($nameRva -eq 0) { break }
        $at = ConvertTo-FileOffset $nameRva
        if ($at -eq 0) { break }
        $sb = New-Object System.Text.StringBuilder
        while ($at -lt $bytes.Length -and $bytes[$at] -ne 0) {
            [void]$sb.Append([char]$bytes[$at])
            $at++
        }
        $names += $sb.ToString()
        $entry += 20
    }
    return $names
}

<#
.SYNOPSIS
    The Visual C++ runtime DLLs a set of binaries needs, transitively.

.DESCRIPTION
    Starts from [Binaries], keeps every import matching the VC++ runtime
    naming pattern, then follows those DLLs' OWN imports until the set
    stops growing. The closure step is not theoretical: `msvcp140.dll`
    imports `vcruntime140.dll` and `vcruntime140_1.dll`, and a stage that
    copied only what `rackpal.exe` names directly could ship a runtime DLL
    whose own dependency is missing.

    Measured on the M2 build: the set closes at three -- MSVCP140,
    VCRUNTIME140, VCRUNTIME140_1 -- for all four shipped binaries.
    `flutter_windows.dll` needs none of them.

    THE UNIVERSAL CRT IS NOT IN THIS SET AND MUST NOT BE. `rackpal.exe`
    also imports `api-ms-win-crt-*.dll`, which are the UCRT: shipped IN-BOX
    with Windows 10 and 11, serviced by Windows Update, and not ours to
    carry. App-local UCRT deployment exists for Windows 7/8 targets, which
    M8's own criterion ("a clean Windows 11 machine") excludes.
#>
function Get-VCRuntimeClosure {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$Binaries,
        [Parameter(Mandatory)][string]$RedistDir
    )

    $pattern = '^(MSVCP|VCRUNTIME|CONCRT|VCCORLIB|MSVCR)'
    $needed = @{}
    $queue = [System.Collections.Queue]::new()
    foreach ($b in $Binaries) { $queue.Enqueue($b) }

    while ($queue.Count -gt 0) {
        $current = $queue.Dequeue()
        foreach ($import in (Get-PEImports -Path $current)) {
            if ($import -notmatch $pattern) { continue }
            $key = $import.ToLowerInvariant()
            if ($needed.ContainsKey($key)) { continue }
            $needed[$key] = $import
            $fromRedist = Join-Path $RedistDir $import
            if (Test-Path $fromRedist) { $queue.Enqueue($fromRedist) }
        }
    }
    return ($needed.Values | Sort-Object)
}
