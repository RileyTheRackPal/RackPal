<#
.SYNOPSIS
    Mint a self-signed code-signing certificate for internal distribution
    (DR-006), and export the PUBLIC half for deployment.

.DESCRIPTION
    DR-006(a): "a code-signing certificate minted with PowerShell
    `New-SelfSignedCertificate`, applied with `Set-AuthenticodeSignature`
    and a timestamp server, with the public `.cer` deployed to
    `LocalMachine\Root` AND `LocalMachine\TrustedPublisher` on every target
    machine, ideally by Group Policy."

    This script does the minting and the .cer export. It does NOT deploy
    anything and does NOT sign anything -- deployment is a GPO task
    described in docs/14-deployment.md, and signing is
    `sign_artifacts.ps1`.

    ================================================================
    THE PRIVATE KEY NEVER LEAVES THE MACHINE'S STORE
    ================================================================
    The certificate is created in `Cert:\CurrentUser\My` and the script
    prints its THUMBPRINT, which is what `sign_artifacts.ps1` takes. There
    is deliberately no `-ExportPfx` switch: a .pfx is the private key in a
    file, and DR-006's whole distribution story rests on target machines
    being told to TRUST this publisher. A leaked self-signed key that every
    org machine trusts is a worse position than no signing at all. If a
    build agent genuinely needs one, export it by hand, understand where it
    lives, and note that `.gitignore` refuses to let it near a commit.

    ================================================================
    BOTH STORES, AND THEY DO DIFFERENT JOBS
    ================================================================
    `Root` is what makes the CHAIN validate -- without it
    `Get-AuthenticodeSignature` reports `UntrustedRoot`. `TrustedPublisher`
    is what makes the publisher TRUSTED rather than merely known, which is
    what suppresses the "unknown publisher" prompt. Deploying one and not
    the other is the common half-failure, and it produces a signature that
    validates while Windows still warns.

.PARAMETER Subject
    The publisher name users see in the file's Digital Signatures tab.

.PARAMETER Years
    Validity. Self-signed certificates cost nothing to re-mint, but
    re-minting means re-deploying the .cer -- and every binary signed with
    the old one keeps validating ONLY if it was timestamped. See
    `verify_signatures.ps1` clause 4.

.EXAMPLE
    pwsh -File tools/release/new_signing_cert.ps1 -Subject 'CN=NBS Games'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Subject,
    [int]$Years = 3,
    [string]$CerOut = 'dist/rackpal-publisher.cer'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($Subject -notmatch '^CN=') {
    throw "Subject must be a distinguished name, e.g. 'CN=NBS Games'."
}

$cert = New-SelfSignedCertificate `
    -Type CodeSigningCert `
    -Subject $Subject `
    -CertStoreLocation 'Cert:\CurrentUser\My' `
    -KeyUsage DigitalSignature `
    -KeyLength 3072 `
    -HashAlgorithm SHA256 `
    -NotAfter (Get-Date).AddYears($Years)

$dir = Split-Path -Parent $CerOut
if ($dir -and -not (Test-Path $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}
Export-Certificate -Cert $cert -FilePath $CerOut -Force | Out-Null

Write-Host ''
Write-Host '== signing certificate minted =='
Write-Host "  subject    : $($cert.Subject)"
Write-Host "  thumbprint : $($cert.Thumbprint)"
Write-Host "  not after  : $($cert.NotAfter.ToString('yyyy-MM-dd'))"
Write-Host "  public .cer: $CerOut"
Write-Host ''
Write-Host 'The PRIVATE key stays in Cert:\CurrentUser\My. Sign with:'
Write-Host "  pwsh -File tools/release/sign_artifacts.ps1 -Path dist/RackPal-portable -Thumbprint $($cert.Thumbprint)"
Write-Host ''
Write-Host 'Deploy the PUBLIC .cer to every target machine, by GPO, into BOTH:'
Write-Host '  LocalMachine\Root             (makes the chain validate)'
Write-Host '  LocalMachine\TrustedPublisher (makes the publisher trusted)'
Write-Host 'One without the other gives a valid signature that still warns.'
Write-Host 'See docs/14-deployment.md.'
