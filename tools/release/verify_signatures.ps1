<#
.SYNOPSIS
    DR-006 §11.6.2's BUILD-SIDE GATE, on a real artifact.

.DESCRIPTION
    Canon splits M8's SmartScreen clause because no build-side property can
    deliver it — SmartScreen fires on Mark-of-the-Web, which is a function
    of how a file ARRIVED, not of what is inside it. What is left is a real
    gate, and it is these four clauses:

      1. signed — `Get-AuthenticodeSignature` finds a signer;
      2. timestamped against an RFC 3161 authority;
      3. a valid publisher matching the declared subject;
      4. AND THE SIGNATURE STILL VALIDATES AFTER THE CERTIFICATE EXPIRES.

    Clause 4 is the point of the whole gate. Canon: "It is what proves the
    timestamp counter-signature is real rather than a flag somebody passed
    and nobody checked, and it is the part people discover too late — the
    day the certificate lapses, every previously shipped binary starts
    reporting `NotTimeValid` and there is no way to fix already-deployed
    files."

    Clauses 1–3 are checked here against the artifact. Clause 4 cannot be
    checked against a live artifact without waiting years, so canon gives
    the experiment instead and `-TestExpiry` runs it — see below.

    ================================================================
    WHAT "VALID" MEANS HERE, AND WHY IT IS NOT THE DEFAULT PASS
    ================================================================
    `Status -eq 'Valid'` requires the signing chain to be TRUSTED ON THE
    MACHINE RUNNING THIS. For a self-signed publisher that is true only
    after the .cer reaches `LocalMachine\Root`, which is a GPO task on
    target machines and is emphatically not something a build agent should
    do to itself.

    So trust is opt-in via -RequireTrusted, for running on a machine that
    is SUPPOSED to have the certificate — which is exactly the check canon
    describes as "a clean test machine showing 'Unknown publisher'" being
    the early warning for `RISK-07`'s replacement risk. Without the switch
    this gate asserts the artifact's own properties, which are the ones a
    build can control.

.PARAMETER Path
    The artifact directory or file to verify.

.PARAMETER ExpectedSubject
    Assert the signer's subject matches (clause 3). Substring match, so
    'CN=NBS Games' matches the full DN.

.PARAMETER RequireTrusted
    Also require Status -eq 'Valid'. Use on a machine that has the .cer.

.PARAMETER TestExpiry
    Run canon's own timestamp-expiry experiment (clause 4). Mints a
    certificate valid for -ExpiryWindowMinutes, signs two copies of a
    throwaway binary — one timestamped, one not — waits out the window, and
    asserts the timestamped copy still validates while the other reports a
    time-validity failure. Takes -ExpiryWindowMinutes to run. It touches
    nothing in the artifact and deletes the certificate it minted.

.EXAMPLE
    pwsh -File tools/release/verify_signatures.ps1 -Path dist/RackPal-portable
    pwsh -File tools/release/verify_signatures.ps1 -Path dist/RackPal-portable -RequireTrusted
    pwsh -File tools/release/verify_signatures.ps1 -TestExpiry -ExpiryWindowMinutes 3
#>
[CmdletBinding()]
param(
    [string]$Path,
    [string]$ExpectedSubject,
    [switch]$RequireTrusted,
    [switch]$TestExpiry,
    [int]$ExpiryWindowMinutes = 3
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$problems = @()

# ══════════════════════════════════════════════════════════════════════
# CLAUSES 1-3 — against the artifact
# ══════════════════════════════════════════════════════════════════════
if ($Path) {
    if (-not (Test-Path $Path)) { throw "nothing to verify at $Path" }

    Write-Host '== build-side signature gate (DR-006 s11.6.2) =='
    Write-Host "  path : $Path"
    Write-Host ''

    $files = @(
        if (Test-Path $Path -PathType Container) {
            Get-ChildItem $Path -Recurse -File -Include *.exe, *.dll |
                ForEach-Object { $_.FullName }
        } else { (Resolve-Path $Path).Path }
    )
    if ($files.Count -eq 0) { throw "no .exe or .dll under $Path" }

    foreach ($f in $files) {
        $name = Split-Path -Leaf $f
        $sig = Get-AuthenticodeSignature -FilePath $f
        $notes = @()

        # 1 — signed
        if (-not $sig.SignerCertificate) {
            $problems += "$name is NOT SIGNED"
            Write-Host ("  FAIL  {0,-38} unsigned" -f $name)
            continue
        }
        $signerCn = ($sig.SignerCertificate.Subject -split ',')[0]

        # 2 — timestamped. The counter-signature is the artifact property
        #     clause 4 rests on, and it is checkable right now.
        if ($sig.TimeStamperCertificate) {
            $notes += 'timestamped'
        } else {
            $problems += "$name has NO TIMESTAMP -- it will fail the day the certificate expires"
            $notes += 'NO TIMESTAMP'
        }

        # ══════════════════════════════════════════════════════════════
        # 3 — publisher: OURS, OR A THIRD PARTY WHO STANDS ON THEIR OWN
        # ══════════════════════════════════════════════════════════════
        # The first version of this clause demanded [ExpectedSubject] on
        # EVERY binary, and it failed the artifact on Microsoft's three
        # redistributable DLLs — which `sign_artifacts.ps1` deliberately
        # does not re-sign, because replacing a universally-trusted chain
        # with a self-signed one makes the artifact worse. The two scripts
        # disagreed, and the gate was the one that was wrong.
        #
        # The rule that matches the artifact: a binary passes if it is
        # OURS (subject matches) or if it is somebody else's AND their
        # signature validates on its own merits — i.e. chains to a root
        # this machine already trusts, which is what a genuine
        # redistributable does everywhere. What that rejects is the case
        # actually worth rejecting: a binary that is neither ours nor
        # verifiably anybody's, which is how an unexpected DLL of unknown
        # provenance would look sitting in the shipped folder.
        $isOurs = $ExpectedSubject -and
            ($sig.SignerCertificate.Subject -like "*$ExpectedSubject*")
        if ($ExpectedSubject) {
            if ($isOurs) {
                $notes += 'ours'
            } elseif ($sig.Status -eq 'Valid') {
                $notes += 'third party, independently valid'
            } else {
                $problems += "$name is signed by $signerCn -- neither $ExpectedSubject nor a signature that validates on its own ($($sig.Status))"
                $notes += 'UNKNOWN PUBLISHER'
            }
        }

        # -RequireTrusted applies to OUR binaries. A third party's already
        # had to validate to get past clause 3, and demanding it twice
        # would just restate it.
        if ($RequireTrusted -and $isOurs) {
            if ($sig.Status -eq 'Valid') {
                $notes += 'trusted'
            } else {
                $problems += "$name is not trusted on this machine ($($sig.Status): $($sig.StatusMessage))"
                $notes += "NOT TRUSTED ($($sig.Status))"
            }
        } else {
            $notes += $(if ($sig.Status -eq 'Valid') { 'trusted here' } else { 'untrusted here (expected off-GPO)' })
        }

        $ok = -not ($notes -match '^(NO TIMESTAMP|UNKNOWN PUBLISHER|NOT TRUSTED)')
        Write-Host ("  {0}  {1,-38} {2}  [{3}]" -f
            $(if ($ok) { 'ok  ' } else { 'FAIL' }), $name, ($notes -join ', '), $signerCn)
    }
}

# ══════════════════════════════════════════════════════════════════════
# CLAUSE 4 — the experiment canon specifies, run for real
# ══════════════════════════════════════════════════════════════════════
if ($TestExpiry) {
    Write-Host ''
    Write-Host '== clause 4: does a timestamped signature outlive its certificate? =='
    Write-Host "  minting a certificate valid for $ExpiryWindowMinutes minute(s)"

    $work = Join-Path ([System.IO.Path]::GetTempPath()) "rackpal-expiry-$(New-Guid)"
    New-Item -ItemType Directory -Force -Path $work | Out-Null
    $cert = $null
    try {
        # A REAL SIGNED BINARY, not a text file: Authenticode signs PE
        # structures, and a .txt takes a different (subject-interface-
        # package) path whose expiry behaviour would prove nothing about
        # the .exe this gate is actually about. `pwsh.exe` is a PE that is
        # certain to exist wherever this script can run at all.
        $victim = (Get-Process -Id $PID).Path
        $timestamped = Join-Path $work 'timestamped.exe'
        $bare = Join-Path $work 'no-timestamp.exe'
        Copy-Item $victim $timestamped
        Copy-Item $victim $bare

        $cert = New-SelfSignedCertificate `
            -Type CodeSigningCert `
            -Subject 'CN=RackPal expiry probe (transient)' `
            -CertStoreLocation 'Cert:\CurrentUser\My' `
            -KeyUsage DigitalSignature `
            -KeyLength 2048 `
            -HashAlgorithm SHA256 `
            -NotAfter (Get-Date).AddMinutes($ExpiryWindowMinutes)

        $null = Set-AuthenticodeSignature -FilePath $timestamped -Certificate $cert `
            -TimestampServer 'http://timestamp.digicert.com' -HashAlgorithm SHA256
        $null = Set-AuthenticodeSignature -FilePath $bare -Certificate $cert `
            -HashAlgorithm SHA256

        $tsBefore = Get-AuthenticodeSignature -FilePath $timestamped
        if (-not $tsBefore.TimeStamperCertificate) {
            $problems += 'clause 4: the timestamp server did not counter-sign -- cannot run the experiment'
            Write-Host '  FAIL  no counter-signature; is the timestamp server reachable?'
        } else {
            Write-Host "  counter-signed by $((($tsBefore.TimeStamperCertificate.Subject) -split ',')[0])"
            $until = $cert.NotAfter.AddSeconds(20)
            Write-Host "  waiting until $($until.ToString('HH:mm:ss')) for the certificate to lapse..."
            while ((Get-Date) -lt $until) { Start-Sleep -Seconds 5 }

            # The certificate must be OUT OF THE STORE before the check, or
            # the chain engine can still build a path through a cert it can
            # see. Removing it is also what a real expiry looks like from
            # the perspective of a machine that only ever had the .cer.
            Remove-Item "Cert:\CurrentUser\My\$($cert.Thumbprint)" -Force
            $cert = $null

            $tsAfter = Get-AuthenticodeSignature -FilePath $timestamped
            $bareAfter = Get-AuthenticodeSignature -FilePath $bare
            Write-Host "  timestamped copy : $($tsAfter.Status) -- $($tsAfter.StatusMessage)"
            Write-Host "  untimestamped    : $($bareAfter.Status) -- $($bareAfter.StatusMessage)"

            # ══════════════════════════════════════════════════════════
            # CANON'S RECIPE HAS AN UNSTATED PRECONDITION, AND THIS IS IT
            # ══════════════════════════════════════════════════════════
            # DR-006 s11.6.2 gives the experiment as: mint a short-lived
            # certificate, sign two copies, wait, "assert
            # `Get-AuthenticodeSignature` reports `Valid` for the
            # timestamped copy and a time-validity failure for the other".
            #
            # RUN AS WRITTEN, IT IS INCONCLUSIVE — measured, this is not a
            # prediction. A self-signed certificate's root is not trusted
            # on the build machine, so BOTH copies report `UnknownError /
            # terminated in a root certificate which is not trusted`, the
            # chain engine having stopped at the root before it ever
            # reached the time check. The difference clause 4 is about is
            # masked, and neither `Valid` nor `NotTimeValid` appears.
            #
            # Making the recipe work as written needs the probe
            # certificate installed into a trusted ROOT store — a change to
            # the machine's security configuration, for a test. This
            # script will not do that to the machine it runs on.
            #
            # So the verdict is taken from `X509Chain` with an explicit
            # `VerificationTime`, which is the MECHANISM Windows itself
            # applies: a countersigned Authenticode signature is verified
            # as at the countersignature's instant rather than as at now.
            # `AllowUnknownCertificateAuthority` sets the root complaint
            # aside so the TIME status underneath becomes visible — which
            # is the whole question — and nothing is installed anywhere.
            $signer = $tsAfter.SignerCertificate
            $now = Get-Date
            $insideWindow = $signer.NotBefore.AddSeconds(
                [Math]::Max(1, ($signer.NotAfter - $signer.NotBefore).TotalSeconds / 2))

            function Test-ChainTimeValid([datetime]$at) {
                $chain = [System.Security.Cryptography.X509Certificates.X509Chain]::new()
                $chain.ChainPolicy.RevocationMode = 'NoCheck'
                $chain.ChainPolicy.VerificationFlags = 'AllowUnknownCertificateAuthority'
                $chain.ChainPolicy.VerificationTime = $at
                $null = $chain.Build($signer)
                $flags = @()
                foreach ($e in $chain.ChainStatus) { $flags += $e.Status.ToString() }
                return @{
                    NotTimeValid = ($flags -contains 'NotTimeValid')
                    Flags        = $flags
                }
            }

            $atNow = Test-ChainTimeValid $now
            $atStamp = Test-ChainTimeValid $insideWindow

            Write-Host ''
            Write-Host "  certificate expired at : $($signer.NotAfter.ToString('HH:mm:ss'))  (now $($now.ToString('HH:mm:ss')))"
            Write-Host "  chain verified AT NOW           -> NotTimeValid=$($atNow.NotTimeValid)  [$($atNow.Flags -join ', ')]"
            Write-Host "  chain verified AT SIGNING TIME  -> NotTimeValid=$($atStamp.NotTimeValid)  [$($atStamp.Flags -join ', ')]"

            $hasStamp = [bool]$tsAfter.TimeStamperCertificate
            $bareHasStamp = [bool]$bareAfter.TimeStamperCertificate

            if ($signer.NotAfter -ge $now) {
                $problems += 'clause 4 INCONCLUSIVE: the probe certificate had not actually expired when the check ran.'
                Write-Host '  ??    the certificate has not expired yet'
            } elseif (-not $atNow.NotTimeValid) {
                # A check that cannot fail proves nothing. docs/12's
                # VACUOUS mark exists for exactly this and it is reported
                # rather than counted green.
                $problems += 'clause 4 INCONCLUSIVE: an expired certificate did not produce NotTimeValid even at the current instant, so this run cannot tell a working timestamp from a missing one.'
                Write-Host '  ??    inconclusive -- the time check itself did not fire'
            } elseif ($atStamp.NotTimeValid) {
                $problems += 'clause 4 FAILED: the certificate reports NotTimeValid even as at its own validity window. Something is wrong with the probe.'
                Write-Host '  FAIL  time check fires even inside the validity window'
            } elseif (-not $hasStamp) {
                $problems += 'clause 4 FAILED: the timestamped copy carries no counter-signature, so nothing pins its verification time. Every shipped binary would fail the day the certificate expires.'
                Write-Host '  FAIL  no counter-signature on the timestamped copy'
            } elseif ($bareHasStamp) {
                $problems += 'clause 4 INCONCLUSIVE: the control copy also carries a counter-signature, so the two are not being compared.'
                Write-Host '  ??    the control copy was timestamped too'
            } else {
                Write-Host ''
                Write-Host '  ok    an expired certificate fails the time check AS AT NOW and passes it'
                Write-Host '        AS AT SIGNING TIME; the timestamped copy carries the'
                Write-Host '        counter-signature that moves verification to that instant, and'
                Write-Host '        the control copy does not.'
                Write-Host ''
                Write-Host '  WHAT THIS DEMONSTRATES AND WHAT IT MODELS. The time check, the'
                Write-Host '  expiry and the presence/absence of the counter-signature are'
                Write-Host '  OBSERVED. That Windows then verifies at the counter-signed instant'
                Write-Host '  is MODELLED here rather than observed end to end, because observing'
                Write-Host '  it needs the probe root trusted on this machine. To observe it, on a'
                Write-Host '  machine you are willing to change: import the probe .cer into'
                Write-Host '  Cert:\CurrentUser\Root, re-run, and canon s11.6.2 reads literally --'
                Write-Host '  Valid for the timestamped copy, NotTimeValid for the other.'
            }
        }
    } finally {
        if ($cert) {
            Remove-Item "Cert:\CurrentUser\My\$($cert.Thumbprint)" -Force -ErrorAction SilentlyContinue
        }
        Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ══════════════════════════════════════════════════════════════════════
Write-Host ''
if ($problems.Count -gt 0) {
    Write-Host '== FAILED =='
    foreach ($p in $problems) { Write-Host "  - $p" }
    Write-Host "##vso[task.logissue type=error]signature gate: $($problems.Count) problem(s)"
    exit 1
}
Write-Host '== signature gate passed =='
if (-not $RequireTrusted) {
    Write-Host ''
    Write-Host 'NOTE: trust was NOT asserted (-RequireTrusted not given). That is'
    Write-Host 'correct for a build agent. On a target machine that has received'
    Write-Host 'the .cer by GPO, re-run with -RequireTrusted -- an "Unknown'
    Write-Host 'publisher" there is the early warning canon names as the'
    Write-Host "replacement for RISK-07."
}
