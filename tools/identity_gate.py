#!/usr/bin/env python3
"""The identity gate: DR-257's history stays as DR-257 left it.

Board #1287, under #1286. The rule is DR-258 (canon section 11.257):

    Every commit reachable from HEAD is authored AND committed by the one
    identity DR-257 ruled, and both of its timestamps carry the offset +0000.

    python tools/identity_gate.py              # exits 0 clean, 1 on any other commit
    python tools/identity_gate.py --selftest   # only the planted cases
    python tools/identity_gate.py --ci         # as CI runs it: see PULL REQUESTS

WHY IT EXISTS. DR-257 rewrote 1,698 commits and nothing kept them so. Three
ways back were each one step away on the day it landed: an IDE commit made
before `TZ=UTC0` reaches the IDE's environment, a clone whose repository-local
identity was never set (the machine's global identity is another one), and a
merge from a ref cut before the rewrite, which brings back every old commit at
once. Each lands on `main` silently, and the next push to the public remote
cannot be withdrawn.

WHAT IT CHECKS. Author name, author email, committer name, committer email,
author offset and committer offset, of every commit `git log HEAD` reaches,
merge parents included. It names the identity it ALLOWS and never the ones it
refuses: a list of forbidden names in a tracked file would publish them.

A SHALLOW CLONE IS A FAILURE, never a pass. CI checks out with fetchDepth 1,
and a gate that can see one commit will vouch for history it never read, so
the pipeline step unshallows first with `--filter=tree:0` (commits only;
measured at 3.8 s for the whole history on 2026-11-02). If that step is ever
removed, this says so by failing.

PULL REQUESTS. A PR build checks out `refs/pull/N/merge`, a merge commit Azure
DevOps makes for the build and stamps with the account profile, which is the
identity DR-257 removed. It never reaches `main` (DR-257 section 11.256.2.6:
the service never makes a commit that lands), so under `--ci`, when
BUILD_REASON is PullRequest, HEAD alone is skipped, and only if it is a merge
one of whose parents is SYSTEM_PULLREQUEST_SOURCECOMMITID. Anything else is
checked like every other commit.

WHY IT RUNS A SELF-TEST EVERY TIME. Each planted case is a throwaway repository
with exactly one defect, and the gate must return the expected verdict for
every one before it is allowed to read the real history.

Output is ASCII: the CI console decodes with cp1252.
"""

import os
import pathlib
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

NAME = 'Riley'
EMAIL = 'rileytherackpal@proton.me'
OFFSET = '+0000'

FIELDS = ('author name', 'author email', 'committer name', 'committer email',
          'author offset', 'committer offset')
LIMIT = 20


def ascii_(s):
    return s.encode('ascii', 'replace').decode('ascii')


def git(repo, *args, env=None):
    out = subprocess.run(['git', '-C', repo, *args], capture_output=True, env=env)
    if out.returncode != 0:
        raise ValueError('git %s: %s' % (' '.join(args), ascii_(out.stderr.decode('utf-8', 'replace').strip())))
    return out.stdout.decode('utf-8', 'replace')


def check(repo, skip_pr_merge=False, environ=None):
    """Returns (problems, commits_read). A problem is (sha, subject, [field, ...])."""
    environ = os.environ if environ is None else environ
    if git(repo, 'rev-parse', '--is-shallow-repository').strip() == 'true':
        raise ValueError('the clone is SHALLOW, so the history it would vouch for is not here; '
                         'unshallow it (git fetch --unshallow --filter=tree:0 origin <ref>) first')
    skip = set()
    if skip_pr_merge and environ.get('BUILD_REASON') == 'PullRequest':
        head = git(repo, 'rev-parse', 'HEAD').strip()
        source = environ.get('SYSTEM_PULLREQUEST_SOURCECOMMITID', '').strip()
        parents = git(repo, 'rev-list', '--parents', '-n', '1', 'HEAD').split()[1:]
        if source and head != source and source in parents and len(parents) == 2:
            skip.add(head)
    log = git(repo, 'log', '--date=raw', '--format=%H%x1f%an%x1f%ae%x1f%cn%x1f%ce%x1f%ad%x1f%cd%x1f%s%x1e', 'HEAD')
    problems = []
    read = 0
    for record in log.split('\x1e'):
        record = record.strip('\n')
        if not record:
            continue
        sha, an, ae, cn, ce, ad, cd, subject = record.split('\x1f')
        read += 1
        if sha in skip:
            continue
        got = (an, ae, cn, ce, ad.split(' ')[-1], cd.split(' ')[-1])
        want = (NAME, EMAIL, NAME, EMAIL, OFFSET, OFFSET)
        wrong = [f for f, g, w in zip(FIELDS, got, want) if g != w]
        if wrong:
            problems.append((sha, subject, wrong))
    return problems, read


# --- planted cases ---------------------------------------------------------

def _env(name=NAME, email=EMAIL, offset=OFFSET, cname=None, cemail=None, coffset=None, when=1793600000):
    e = dict(os.environ)
    # Isolate from the machine: a global hook, signing key or identity must not
    # decide what a planted commit carries.
    e.update(GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM='1',
             GIT_AUTHOR_NAME=name, GIT_AUTHOR_EMAIL=email,
             GIT_AUTHOR_DATE='%d %s' % (when, offset),
             GIT_COMMITTER_NAME=cname or name, GIT_COMMITTER_EMAIL=cemail or email,
             GIT_COMMITTER_DATE='%d %s' % (when, coffset or offset))
    return e


def _commit(repo, msg, **kw):
    git(repo, 'commit', '-q', '--allow-empty', '-m', msg, env=_env(**kw))
    return git(repo, 'rev-parse', 'HEAD').strip()


def _repo(tmp, name):
    path = os.path.join(tmp, name)
    git(tmp, 'init', '-q', '-b', 'main', path, env=_env())
    _commit(path, 'root')
    return path


def _planted(tmp):
    """Yields (name, repo, environ, skip_pr_merge, want_pass)."""
    clean = _repo(tmp, 'clean')
    _commit(clean, 'second')
    yield 'every commit carries the identity at +0000', clean, {}, False, True

    for i, (label, kw) in enumerate([
            ('another author name', dict(name='Someone')),
            ('another author email', dict(email='someone@example.invalid')),
            ('another committer, author correct', dict(cname='Someone', cemail='someone@example.invalid')),
            ('an author offset other than +0000', dict(offset='-0500', coffset=OFFSET)),
            ('a committer offset other than +0000', dict(coffset='+0100')),
    ]):
        r = _repo(tmp, 'bad%d' % i)
        _commit(r, 'bad', **kw)
        _commit(r, 'clean on top')
        yield label + ', buried under a clean commit', r, {}, False, False

    # A bad commit reachable only through a merge's SECOND parent: the gate
    # must walk every parent, not the first-parent line a PR history reads as.
    side = _repo(tmp, 'side')
    git(side, 'switch', '-q', '-c', 'topic', env=_env())
    _commit(side, 'bad on a branch', offset='-0400')
    git(side, 'switch', '-q', 'main', env=_env())
    _commit(side, 'main moves')
    git(side, 'merge', '-q', '--no-ff', 'topic', '-m', 'Merge topic', env=_env())
    yield 'a bad commit reachable only through a merge parent', side, {}, False, False

    shallow = os.path.join(tmp, 'shallow')
    # as_uri, not 'file:///' + path: a POSIX temp path already starts with '/'.
    git(tmp, 'clone', '-q', '--depth', '1', pathlib.Path(clean).as_uri(), shallow, env=_env())
    yield 'a shallow clone, which cannot see its history', shallow, {}, False, False

    # A PR build's synthetic merge: made by another identity, parents [target, source].
    pr = _repo(tmp, 'pr')
    git(pr, 'switch', '-q', '-c', 'source', env=_env())
    source = _commit(pr, 'the PR source tip')
    git(pr, 'switch', '-q', 'main', env=_env())
    _commit(pr, 'target moves')
    git(pr, 'merge', '-q', '--no-ff', 'source', '-m', 'Merge pull request 1', env=_env(name='Service', email='svc@example.invalid'))
    as_ci = {'BUILD_REASON': 'PullRequest', 'SYSTEM_PULLREQUEST_SOURCECOMMITID': source}
    yield "a PR build's own merge commit, under --ci", pr, as_ci, True, True
    yield 'the same merge without --ci', pr, as_ci, False, False
    yield 'the same merge on a build that is not a PR', pr, {'BUILD_REASON': 'IndividualCI', 'SYSTEM_PULLREQUEST_SOURCECOMMITID': source}, True, False
    yield 'the same merge when the named source is not its parent', pr, dict(as_ci, SYSTEM_PULLREQUEST_SOURCECOMMITID='0' * 40), True, False

    # The skip is for the service's merge only, never for a bad source tip.
    prbad = _repo(tmp, 'prbad')
    git(prbad, 'switch', '-q', '-c', 'source', env=_env())
    badsource = _commit(prbad, 'a bad source tip', email='someone@example.invalid')
    git(prbad, 'switch', '-q', 'main', env=_env())
    _commit(prbad, 'target moves')
    git(prbad, 'merge', '-q', '--no-ff', 'source', '-m', 'Merge pull request 2', env=_env(name='Service', email='svc@example.invalid'))
    yield 'a PR whose source commit is wrong, under --ci', prbad, {'BUILD_REASON': 'PullRequest', 'SYSTEM_PULLREQUEST_SOURCECOMMITID': badsource}, True, False


def selftest():
    failures = 0
    cases = 0
    with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
        for name, repo, environ, skip, want_pass in _planted(tmp):
            cases += 1
            try:
                problems, _ = check(repo, skip_pr_merge=skip, environ=environ)
                got_pass = not problems
            except ValueError:
                got_pass = False
            if got_pass != want_pass:
                failures += 1
                print('  SELFTEST FAIL  %s: expected %s, got %s'
                      % (name, 'pass' if want_pass else 'fail', 'pass' if got_pass else 'fail'))
    print('self-test: %d planted cases, %d wrong' % (cases, failures))
    return failures == 0


def main(argv):
    try:
        ok = selftest()
    except ValueError as exc:
        print('FAIL - the self-test could not build its planted repositories: %s' % ascii_(str(exc)))
        return 1
    if not ok:
        print('FAIL - the gate cannot tell a planted defect from a clean history, '
              'so its verdict on the real one means nothing.')
        return 1
    if '--selftest' in argv:
        return 0
    try:
        problems, read = check(ROOT, skip_pr_merge='--ci' in argv)
    except ValueError as exc:
        # A HISTORY IT CANNOT READ IS A GATE FAILURE, never a silent pass.
        print('FAIL - %s' % ascii_(str(exc)))
        return 1
    if read == 0:
        print('FAIL - read no commits at all, which is not a history this gate can vouch for.')
        return 1
    if not problems:
        print('PASS - all %d commits reachable from HEAD are %s <%s> at %s (DR-258).'
              % (read, NAME, EMAIL, OFFSET))
        return 0
    print('FAIL - %d of %d commits carry another identity or offset (DR-258):' % (len(problems), read))
    for sha, subject, wrong in problems[:LIMIT]:
        print('  %s  %s  [%s]' % (sha[:10], ascii_(subject[:60]), ', '.join(wrong)))
    if len(problems) > LIMIT:
        print('  ... and %d more' % (len(problems) - LIMIT))
    print()
    print('Unpushed commits are mended in place: set user.name and user.email in this')
    print("repository's own config, then, with TZ=UTC0 in the environment,")
    print("  git rebase -r --exec 'git commit --amend --no-edit --reset-author' <base>")
    print('A commit that is already on a remote is a history rewrite, which is a ruling.')
    print('Thousands at once means an old-history ref was merged: do not push it anywhere.')
    return 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
