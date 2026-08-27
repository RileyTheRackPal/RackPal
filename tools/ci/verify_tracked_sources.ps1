<#
.SYNOPSIS
    Fail if any Dart source under a package's lib/ is missing from git --
    i.e. if the tree compiles here but a fresh clone would not.

.DESCRIPTION
    WHY THIS EXISTS. The barrel `packages/rackpal_core/lib/rackpal_core.dart`
    was committed carrying `export 'src/commands/rack_commands.dart';` while
    that file was never added to the index. Every local command stayed green:
    the file is right there on disk, so `flutter analyze` resolved it and all
    five suites passed. A clone of that same commit gets an `export` of a
    URI that does not exist -- an analyzer ERROR in rackpal_core and a
    compile failure in every package that imports the barrel. The pipeline
    checks out clean on purpose, so run 1 would have gone red for a reason
    invisible in the working tree.

    THIS IS THE ONE FAILURE CLASS `run_local.ps1` OTHERWISE CANNOT SPEAK
    ABOUT. Its header already says so about `.gitattributes`; this is the
    same shape -- "green here, red on a clone" -- and it is cheap to
    mechanise, so it is mechanised rather than remembered.

    NOT A TEST FILE, DELIBERATELY. A `flutter test` case asserting "nothing
    under lib/ is untracked" would be red for the whole life of every
    feature branch, which trains people to ignore it. This is a pre-commit /
    pre-push gate: run it on the changeset you are about to commit, and let
    it tell you whether the commit is complete.

    WHAT IT DOES NOT PROVE. That the clone COMPILES -- only that no lib/
    source is missing from it. A file that is tracked but stale, a
    `.gitattributes` defect, or a missing asset are all outside it. The
    clean-checkout job in azure-pipelines.yml is the only thing that proves
    the whole claim.

.PARAMETER RepoRoot
    Defaults to the repository root two levels above this script.

.PARAMETER IncludeStaged
    Treat files that are staged but not yet committed as present. Useful
    when running from a pre-commit hook, where `git ls-files` alone would
    not yet see a newly `git add`-ed file. Off by default: the default
    question is "would a clone of HEAD-plus-this-worktree compile", and
    `git ls-files` answers it for both tracked and staged content.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
    [switch]$IncludeStaged
)

$ErrorActionPreference = 'Stop'

Push-Location $RepoRoot
try {
    # `--others --exclude-standard` is exactly "untracked and not ignored",
    # which is the set a clone would not receive. `-- '*/lib/*.dart'` keeps
    # this to SHIPPED source: an untracked test file cannot break a clone's
    # compile of the app, and an untracked scratch file in build/ is
    # gitignored and therefore not listed at all.
    $untracked = @(
        git ls-files --others --exclude-standard -- '*/lib/*.dart' |
            Where-Object { $_ }
    )
} finally {
    Pop-Location
}

if ($untracked.Count -eq 0) {
    Write-Host 'verify_tracked_sources: every lib/ Dart source is known to git.'
    exit 0
}

Write-Host "##vso[task.logissue type=error]verify_tracked_sources: $($untracked.Count) Dart source file(s) under a lib/ directory are UNTRACKED. A clone of this commit would not receive them, so it would not compile -- while every local command stays green, because the files are on this disk."
foreach ($path in $untracked) {
    Write-Host "  untracked: $path"
}
Write-Host ''
Write-Host 'Either `git add` them as part of this commit, or delete them. Splitting a changeset so that a barrel export lands without the file it names is the specific defect this gate exists to catch.'
exit 1
