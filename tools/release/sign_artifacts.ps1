<#
.SYNOPSIS
    Sign every binary in a release artifact, timestamped.

.DESCRIPTION
    ================================================================
    ONE ENTRY POINT, PARAMETERISED OVER CERTIFICATE SOURCE -- DR-006(3)
    ================================================================
    Canon calls this "the only consequence that costs anything now, and
    the one that must not be skipped":

      "The signing script is parameterised over certificate source and
       never hardcodes self-signed. One entry point taking the source as a
       parameter -- self-signed from a named store thumbprint, a `.pfx`, or
       Trusted Signing -- with everything downstream (timestamping,
       hashing, the verification step, the artifact list) identical across
       sources. This is the difference between the named fallback being a
       config change and being a rewrite."

    So the source resolves to a certificate (or, for Trusted Signing, to a
    signtool invocation) in ONE place at the top, and every line after that
    is source-agnostic. -Thumbprint, -PfxPath and -TrustedSigning are
    mutually exclusive; exactly one is required. Adding a fourth source
    means adding a branch to `Resolve-SigningSource` and nothing else.

    TRUSTED SIGNING IS WIRED, NOT ASSUMED. Canon flags it "VERIFY:
    Microsoft Trusted Signing eligibility before relying on the fallback
    being available on demand". So that branch shells out to `signtool`
    with the dlib parameters Microsoft documents, and it FAILS LOUDLY if
    signtool or the dlib is absent rather than silently falling back to
    self-signed -- a fallback that silently downgraded the trust model
    would be the worst possible behaviour for this particular script.

    ================================================================
    TIMESTAMPING IS NOT OPTIONAL AND THERE IS NO SWITCH FOR IT
    ================================================================
    DR-006's build-side gate clause 4 -- "the signature still validates
    after the signing certificate has expired" -- is the whole point of the
    gate, and it is delivered ENTIRELY by the RFC 3161 counter-signature.
    Without it, every previously shipped binary starts reporting
    `NotTimeValid` the day the certificate lapses, and there is no way to
    fix files already on people's machines.

    An `-SkipTimestamp` switch would exist only to produce artifacts that
    fail in a year, so there is none. `verify_signatures.ps1` checks the
    counter-signature is really there rather than trusting that this ran.

.PARAMETER Path
    A directory (every .exe/.dll under it is signed) or a single file.

.PARAMETER Thumbprint
    Self-signed / imported certificate, by thumbprint, from the current
    user's or the machine's personal store.

.PARAMETER PfxPath
    A .pfx file. -PfxPassword is prompted for if not supplied. NEVER
    committed -- .gitignore refuses *.pfx.

.PARAMETER TrustedSigning
    Use Microsoft Trusted Signing via signtool + the Azure dlib. Requires
    -TrustedSigningMetadata pointing at the JSON metadata file.

.EXAMPLE
    pwsh -File tools/release/sign_artifacts.ps1 -Path dist/RackMate-portable -Thumbprint ABC123...
    pwsh -File tools/release/sign_artifacts.ps1 -Path dist/RackMate-portable -PfxPath key.pfx
#>
[CmdletBinding(DefaultParameterSetName = 'Thumbprint')]
param(
    [Parameter(Mandatory)][string]$Path,

    [Parameter(Mandatory, ParameterSetName = 'Thumbprint')]
    [string]$Thumbprint,

    [Parameter(Mandatory, ParameterSetName = 'Pfx')]
    [string]$PfxPath,
    [Parameter(ParameterSetName = 'Pfx')]
    [securestring]$PfxPassword,

    [Parameter(Mandatory, ParameterSetName = 'TrustedSigning')]
    [switch]$TrustedSigning,
    [Parameter(Mandatory, ParameterSetName = 'TrustedSigning')]
    [string]$TrustedSigningMetadata,
    [Parameter(ParameterSetName = 'TrustedSigning')]
    [string]$SignToolPath,
    [Parameter(ParameterSetName = 'TrustedSigning')]
    [string]$DlibPath,

    # RFC 3161. DigiCert's is free, unauthenticated and does not expire
    # with our certificate. THE `/t` FORM IS NOT THIS -- Authenticode's
    # legacy timestamp protocol is SHA-1 based; `Set-AuthenticodeSignature
    # -TimestampServer` issues an RFC 3161 request.
    [string]$TimestampServer = 'http://timestamp.digicert.com',
    [ValidateSet('SHA256', 'SHA384', 'SHA512')]
    [string]$HashAlgorithm = 'SHA256',

    # Re-sign binaries that already carry somebody else's signature. See
    # the skip logic below for why that is not the default.
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# --- the ONE source-dependent step (DR-006 consequence 3) ----------------
function Resolve-SigningSource {
    switch ($PSCmdlet.ParameterSetName) {
        'Thumbprint' {
            $found = @(
                Get-ChildItem 'Cert:\CurrentUser\My', 'Cert:\LocalMachine\My' `
                    -ErrorAction SilentlyContinue |
                    Where-Object { $_.Thumbprint -eq $Thumbprint }
            )
            if ($found.Count -eq 0) {
                throw "no certificate with thumbprint $Thumbprint in CurrentUser\My or LocalMachine\My. Mint one with tools/release/new_signing_cert.ps1."
            }
            return @{ Kind = 'Certificate'; Certificate = $found[0] }
        }
        'Pfx' {
            if (-not (Test-Path $PfxPath)) { throw "no .pfx at $PfxPath" }
            if (-not $PfxPassword) {
                $PfxPassword = Read-Host -AsSecureString "password for $PfxPath"
            }
            $cert = Get-PfxCertificate -FilePath $PfxPath -Password $PfxPassword
            return @{ Kind = 'Certificate'; Certificate = $cert }
        }
        'TrustedSigning' {
            if (-not $SignToolPath) {
                $SignToolPath = (Get-Command signtool.exe -ErrorAction SilentlyContinue).Source
            }
            if (-not $SignToolPath -or -not (Test-Path $SignToolPath)) {
                throw 'Trusted Signing needs signtool.exe (Windows SDK). Pass -SignToolPath. NOT falling back to a self-signed certificate: a silent downgrade of the trust model is the worst thing this script could do.'
            }
            if (-not $DlibPath -or -not (Test-Path $DlibPath)) {
                throw 'Trusted Signing needs the Azure Code Signing dlib. Pass -DlibPath. See canon DR-006 s11.6.5: eligibility is flagged VERIFY and is not asserted to be available on demand.'
            }
            if (-not (Test-Path $TrustedSigningMetadata)) {
                throw "no Trusted Signing metadata at $TrustedSigningMetadata"
            }
            return @{ Kind = 'SignTool' }
        }
    }
}

# --- everything below is IDENTICAL across sources ------------------------
function Invoke-Sign {
    param([string]$File, [hashtable]$Source)

    if ($Source.Kind -eq 'Certificate') {
        $result = Set-AuthenticodeSignature `
            -FilePath $File `
            -Certificate $Source.Certificate `
            -TimestampServer $TimestampServer `
            -HashAlgorithm $HashAlgorithm `
            -ErrorAction Stop
        return $result.Status
    }

    $args = @(
        'sign',
        '/v',
        '/debug',
        '/fd', $HashAlgorithm,
        '/tr', $TimestampServer,
        '/td', $HashAlgorithm,
        '/dlib', $DlibPath,
        '/dmdf', $TrustedSigningMetadata,
        $File
    )
    & $SignToolPath @args | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "signtool failed on $File ($LASTEXITCODE)" }
    return (Get-AuthenticodeSignature -FilePath $File).Status
}

$source = Resolve-SigningSource

Write-Host '== sign release artifacts =='
Write-Host "  source    : $($PSCmdlet.ParameterSetName)"
if ($source.Kind -eq 'Certificate') {
    Write-Host "  subject   : $($source.Certificate.Subject)"
    Write-Host "  expires   : $($source.Certificate.NotAfter.ToString('yyyy-MM-dd'))"
}
Write-Host "  timestamp : $TimestampServer"
Write-Host "  hash      : $HashAlgorithm"

if (-not (Test-Path $Path)) { throw "nothing to sign at $Path" }

# THE ARTIFACT LIST IS SOURCE-AGNOSTIC TOO -- consequence 4's "one
# certificate, one script, N outputs". A directory signs every PE in it,
# so the portable tree and a future installer's payload take the same
# path, and a plugin DLL added later is signed without anyone editing a
# list.
$candidates = @(
    if (Test-Path $Path -PathType Container) {
        Get-ChildItem $Path -Recurse -File -Include *.exe, *.dll |
            ForEach-Object { $_.FullName }
    } else {
        (Resolve-Path $Path).Path
    }
)

if ($candidates.Count -eq 0) { throw "no .exe or .dll found under $Path" }

# ═════════════════════════════════════════════════════════════════════
# SOMEBODY ELSE'S SIGNED BINARY IS LEFT ALONE — "PRODUCES", NOT "SHIPS"
# ═════════════════════════════════════════════════════════════════════
# DR-006 consequence 4 is "every artifact a release PRODUCES signs with the
# same certificate and the same script". The portable tree also CARRIES
# three files this project does not produce: Microsoft's redistributable
# MSVCP140 / VCRUNTIME140 / VCRUNTIME140_1, which arrive already signed by
# Microsoft with a chain that validates on every Windows machine on earth.
#
# Re-signing those REPLACES that signature with ours. On a machine that has
# not received our .cer — which is every machine until the GPO lands — that
# trades a universally trusted signature for an untrusted one, and it
# destroys the provenance of a file we did not write. It makes the artifact
# strictly worse and it is what the first run of this script actually did.
#
# So: a file already signed by a DIFFERENT publisher is skipped and
# reported. -Force overrides, because "never" is too strong a word for a
# script (a repackaged binary might genuinely need re-signing), but the
# default is the one that cannot quietly downgrade a trust chain.
$targets = @()
$skipped = @()
foreach ($c in $candidates) {
    if ($Force) { $targets += $c; continue }
    $existing = Get-AuthenticodeSignature -FilePath $c
    $signer = $existing.SignerCertificate
    $oursThumb = if ($source.Kind -eq 'Certificate') { $source.Certificate.Thumbprint } else { $null }
    if ($signer -and $signer.Thumbprint -ne $oursThumb) {
        $skipped += [pscustomobject]@{
            Name   = Split-Path -Leaf $c
            Signer = $signer.Subject
        }
        continue
    }
    $targets += $c
}

foreach ($s in $skipped) {
    $cn = ($s.Signer -split ',')[0]
    Write-Host ("  skip  {0,-38} already signed by {1}" -f $s.Name, $cn)
}

if ($targets.Count -eq 0) {
    throw "every binary under $Path is already signed by somebody else. Use -Force only if you mean to replace their signatures."
}

# ═════════════════════════════════════════════════════════════════════
# WHAT THIS SCRIPT MAY JUDGE, AND WHAT IT MAY NOT
# ═════════════════════════════════════════════════════════════════════
# THIS SCRIPT ASKS "was a signature written, with the right certificate,
# carrying a real timestamp". It deliberately does NOT ask "is it trusted",
# because trust is a property of the MACHINE THIS RAN ON and not of the
# artifact. A self-signed publisher is untrusted on every machine that has
# not received the .cer -- which is every machine until the GPO lands, and
# is the correct state for a build agent.
#
# The first draft treated `Status -eq 'Valid'` as the pass condition and
# `UntrustedRoot` as the one tolerated failure. Both halves were wrong, and
# running it is what showed that: PowerShell reports an untrusted
# self-signed chain as `UnknownError`, with the truth only in
# `StatusMessage` ("terminated in a root certificate which is not trusted
# by the trust provider"). So a status allowlist was matching on a string
# the API does not actually return, and would have failed the build on a
# perfectly-signed artifact.
#
# `SignerCertificate` and `TimeStamperCertificate` are objects rather than
# strings: they are either there or they are not, and no store state
# changes that. Those are the two questions this script can answer
# honestly. `verify_signatures.ps1 -RequireTrusted` is where trust is
# asked, on a machine that is supposed to have the certificate.
$failed = @()
foreach ($t in $targets) {
    $null = Invoke-Sign -File $t -Source $source
    $name = Split-Path -Leaf $t
    $sig = Get-AuthenticodeSignature -FilePath $t

    if (-not $sig.SignerCertificate) {
        $failed += "$name (no signature written: $($sig.StatusMessage))"
        Write-Host ("  FAIL  {0}" -f $name)
        continue
    }
    if (-not $sig.TimeStamperCertificate) {
        # NOT A WARNING. An untimestamped binary is one that starts
        # reporting NotTimeValid the day the certificate lapses, on every
        # machine it has already been copied to, with no way to fix it
        # there. DR-006's clause 4 exists for precisely this and there is
        # no switch to skip it.
        $failed += "$name (NO TIMESTAMP -- will fail the day the cert expires)"
        Write-Host ("  FAIL  {0}  no counter-signature" -f $name)
        continue
    }
    if ($source.Kind -eq 'Certificate' -and
        $sig.SignerCertificate.Thumbprint -ne $source.Certificate.Thumbprint) {
        $failed += "$name (signed by an unexpected certificate)"
        Write-Host ("  FAIL  {0}" -f $name)
        continue
    }
    $trust = if ($sig.Status -eq 'Valid') { 'trusted here' } else { 'not trusted here' }
    Write-Host ("  ok    {0,-38} timestamped, {1}" -f $name, $trust)
}

Write-Host ''
Write-Host "  signed $($targets.Count) file(s)"
if ($failed.Count -gt 0) {
    Write-Host "##vso[task.logissue type=error]signing failed: $($failed -join '; ')"
    exit 1
}
Write-Host ''
Write-Host 'Now verify -- the signature is not the gate, the gate is:'
Write-Host "  pwsh -File tools/release/verify_signatures.ps1 -Path '$Path'"
