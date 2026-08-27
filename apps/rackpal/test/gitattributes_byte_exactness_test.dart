// THE BYTES ON DISK AND THE BYTES A FRESH CLONE GETS.
//
// ==================================================================
// WHY THIS FILE EXISTS
// ==================================================================
// CR-117 is `write(read(bytes)) == bytes`, and `starter_assets_test.dart`
// asserts it over the four starter projects READ OFF THE DISK THEY SHIP
// ON. That test is only as strong as the guarantee that the bytes on this
// disk are the bytes that were committed.
//
// `.gitattributes` did not give that guarantee. It pinned `*.json` — which
// covers the codec fixtures — and everything else fell through to
// `* text=auto` with `eol` unspecified, so on Windows it checks out with
// whatever `core.autocrlf` says. The four starters are
// `assets/starters/*.rmpj`, matched no rule, and were UNTRACKED: the
// moment they were committed, the next clone on a Windows machine would
// have received them CRLF-normalised and the byte-exact suite would have
// failed on a clean checkout while staying green for everyone who already
// had the tree. That exact failure — CRLF normalisation breaking CR-117 —
// has already happened once during this stage.
//
// THE FIX IS ONE LINE IN `.gitattributes`. THIS FILE IS THE REASON THE
// NEXT ONE CANNOT BE FORGOTTEN. It derives the set of extensions that
// need protecting from what is ACTUALLY SITTING in the byte-exact roots,
// not from a list somebody has to remember to extend, so a fixture in a
// new format fails here on the day it is added rather than on somebody
// else's machine six weeks later.
//
// A SOURCE GATE, and labelled as one, in the same family as
// `storage_layering_test.dart` RULE 7. Its measured limit: it reads
// `.gitattributes` and the working tree. It cannot perform a clone, so it
// proves the RULE is present and correct, not that git obeyed it — which
// is why `git check-attr` is consulted as a cross-check whenever git can
// be run at all (see the last test in the first group).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// The repository root, from the app directory tests run in.
const String kRepoRoot = '../..';

/// DIRECTORIES OF COMMITTED ARTIFACTS WHOSE EXACT BYTES A SUITE DEPENDS
/// ON, repo-relative.
///
/// This is a list, and a list is what the sibling
/// `registry_claim_test.dart` was rebuilt to stop depending on — so it is
/// worth saying why one is right here and wrong there. There, the list was
/// of keys the WINDOWS SHELL writes: someone else's data, unbounded, and
/// unmeasurable from this repository. Here it is a list of directories in
/// this repository, which we create deliberately and can see. The thing
/// that actually drifts — a fixture in a NEW FORMAT landing in one of
/// them — is not listed anywhere: the extensions are read off the disk.
///
/// `assets/starters` is the one that has actually bitten. The fixture
/// directory is included because it is a committed artifact of a format
/// defined by its bytes, and the cost of protecting it is one line;
/// `byte_roundtrip_test.dart` happens to rewrite its own before comparing,
/// and `migration_corpus_test.dart` happens to parse rather than
/// byte-compare, so neither would fail on a CRLF checkout TODAY. The day
/// one of them is compared as bytes — which is exactly what a golden
/// corpus is for — nobody should have to remember this.
///
/// **`test/fixtures` LEFT THIS LIST WHEN ITS CONTENTS WERE DELETED**
/// (docs/12 §4.12). It held three copies of `a_empty_project`,
/// `b_rack_and_device` and `c_fuller_project` under the PRE-RENAME
/// extension `.rackpal.json`, referenced by nothing: the real ones live
/// at `packages/rackpal_core/test/fixtures` under `.rmpj.json`, because
/// `byte_roundtrip_test.dart` and `codec_split_test.dart` read the
/// package-relative path. **The vacuity guard below is what forced this
/// edit rather than letting the root sit empty in the list**, which is the
/// guard doing exactly its job: it says "either it moved — update
/// kByteExactRoots — or the goldens are gone", and here the first was
/// true.
const List<String> kByteExactRoots = <String>[
  'apps/rackpal/assets/starters',
  'packages/rackpal_core/test/fixtures',
];

/// The check-out states in which the committed bytes survive verbatim.
///
/// `lf` is `text eol=lf`: normalised in the repository and written back as
/// LF on every platform. `binary` is `-text` (which the `binary` macro
/// sets): git never touches the content at all.
const Set<String> kByteSafeResolutions = <String>{'lf', 'binary'};

/// Directories that never contain committed content, skipped when the
/// whole tree is swept. `build/` matters most: `flutter test` copies every
/// declared asset into `build/unit_test_assets/`, so a sweep that did not
/// skip it would report the same four starters again from a path no clone
/// ever sees.
const List<String> kNotCommitted = <String>[
  '/.git/',
  '/build/',
  '/.dart_tool/',
  '/ephemeral/',
  '/.plugin_symlinks/',
  // NESTED WORKTREES. `git worktree add` puts a whole second checkout
  // under `.claude/worktrees/`, and a sweep from the repo root walks
  // straight into it — reporting every file twice from a path no clone
  // has, and (before the pruning walk below) dying inside its build
  // artifacts. Nothing under `.claude/` is committed: `git ls-files
  // .claude` is empty and `.git/info/exclude` already lists
  // `.claude/worktrees/`.
  '/.claude/',
];

// ======================================================================
// A `.gitattributes` READER
// ======================================================================
// Enough of the format to answer the only question this file asks: for a
// given path, what does the LAST matching line say about `text` and `eol`?
//
// A DELIBERATE SUBSET, stated rather than glossed: pattern negation
// (`!pattern`), attribute macros other than `binary`, and per-directory
// `.gitattributes` files are not implemented, because this repository has
// none of them and a half-implemented `!` would be worse than an absent
// one. The `git check-attr` cross-check below is what catches this
// resolver drifting away from real git, including into any of those.

/// One `.gitattributes` line: a pattern and the attributes it sets.
typedef AttributeRule = ({String pattern, Map<String, String> attributes});

/// Parses `.gitattributes` text into rules, in file order.
List<AttributeRule> parseGitAttributes(String text) {
  final rules = <AttributeRule>[];
  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final tokens = line.split(RegExp(r'\s+'));
    if (tokens.length < 2) continue;
    final attributes = <String, String>{};
    for (final token in tokens.skip(1)) {
      if (token == 'binary') {
        // The macro. `-text -diff -merge`; only `text` is load-bearing
        // here, and unsetting it is what makes the bytes untouchable.
        attributes['text'] = 'unset';
      } else if (token.startsWith('-')) {
        attributes[token.substring(1)] = 'unset';
      } else if (token.startsWith('!')) {
        attributes[token.substring(1)] = 'unspecified';
      } else if (token.contains('=')) {
        final i = token.indexOf('=');
        attributes[token.substring(0, i)] = token.substring(i + 1);
      } else {
        attributes[token] = 'set';
      }
    }
    rules.add((pattern: tokens.first, attributes: attributes));
  }
  return rules;
}

/// Whether [pattern] matches the repo-relative [path], gitattributes-style:
/// a pattern with no slash matches the BASENAME at any depth, one with a
/// slash is anchored to the repository root and its `*` does not cross a
/// separator.
bool patternMatches(String pattern, String path) {
  final anchored = pattern.contains('/');
  final subject = anchored ? path : p.basename(path);
  final glob = anchored ? pattern.replaceFirst(RegExp('^/'), '') : pattern;
  final buffer = StringBuffer('^');
  for (final rune in glob.runes) {
    final ch = String.fromCharCode(rune);
    if (ch == '*') {
      buffer.write(anchored ? '[^/]*' : '.*');
    } else if (ch == '?') {
      buffer.write(anchored ? '[^/]' : '.');
    } else {
      buffer.write(RegExp.escape(ch));
    }
  }
  buffer.write(r'$');
  return RegExp(buffer.toString()).hasMatch(subject);
}

/// How [path] comes out of a checkout under [rules]:
///
///  * `binary` — git never rewrites the content;
///  * `lf` / `crlf` — pinned to that ending on every platform;
///  * `platform` — normalised in the repository, written back as whatever
///    the local `core.autocrlf` says. THIS IS THE DEFECT: on Windows it is
///    CRLF, and a byte-exact golden checked out that way is a different
///    file from the one that was committed;
///  * `unspecified` — no rule matched at all, which behaves the same way
///    and is how the four starters were sitting.
String resolveCheckout(List<AttributeRule> rules, String path) {
  var text = 'unspecified';
  var eol = 'unspecified';
  for (final rule in rules) {
    if (!patternMatches(rule.pattern, path)) continue;
    final t = rule.attributes['text'];
    if (t != null) text = t;
    final e = rule.attributes['eol'];
    if (e != null) eol = e;
  }
  if (text == 'unset') return 'binary';
  // `eol` implies `text`, so it wins wherever it is set.
  if (eol == 'lf' || eol == 'crlf') return eol;
  if (text == 'set' || text == 'auto') return 'platform';
  return 'unspecified';
}

// ======================================================================
// THE TREE
// ======================================================================

List<File> _filesUnder(String repoRelative) {
  final directory = Directory(p.join(kRepoRoot, repoRelative));
  if (!directory.existsSync()) return const <File>[];
  return _walk(directory);
}

/// Every file in the repository that a clone would receive, best effort.
List<File> _allCommittedFiles() => _walk(Directory(kRepoRoot));

/// Every file under [root], PRUNING a skipped directory DURING the walk
/// instead of filtering it out afterwards.
///
/// `listSync(recursive: true)` cannot be used here, and the reason is a
/// real failure rather than a preference. It enumerates EAGERLY, so it
/// descends into `windows/flutter/ephemeral/.plugin_symlinks/` — symlinks
/// into the pub cache, whose plugins carry macOS example projects with
/// paths long enough to cross Windows' 260-character `MAX_PATH` — and
/// throws `PathNotFoundException` for the whole sweep BEFORE [_isSkipped]
/// is ever consulted. `/ephemeral/` and `/.plugin_symlinks/` were already
/// in [kNotCommitted]; the filter simply never got the chance to apply,
/// because a post-hoc `.where` cannot prevent a traversal that has already
/// happened.
///
/// A DIRECTORY THAT CANNOT BE LISTED IS SKIPPED, NOT FATAL. The sweep's
/// own docstring calls itself "best effort", and the alternative is what
/// this function replaces: one unreadable path anywhere under the root
/// takes down a gate that is checking something else entirely. The files
/// this test actually asserts on are committed content, which is readable
/// by construction.
List<File> _walk(Directory root) {
  final files = <File>[];
  final pending = <Directory>[root];

  while (pending.isNotEmpty) {
    final List<FileSystemEntity> entries;
    try {
      entries = pending.removeLast().listSync();
    } on FileSystemException {
      // Unreadable, vanished mid-walk, or past MAX_PATH. Not this gate's
      // question — see the docstring.
      continue;
    }

    for (final entry in entries) {
      final path = _repoPath(entry);
      if (entry is Directory) {
        // The trailing slash matters: [kNotCommitted]'s segments are
        // written as `/build/`, and a bare directory path ends without
        // one, so `/apps/rackpal/build` would not match `/build/`.
        if (!_isSkipped('$path/')) pending.add(entry);
      } else if (entry is File && !_isSkipped(path)) {
        files.add(entry);
      }
    }
  }
  return files.toList(growable: false);
}

bool _isSkipped(String repoPath) =>
    kNotCommitted.any((segment) => '/$repoPath'.contains(segment));

/// A file's path relative to the repository root, with forward slashes —
/// the spelling `.gitattributes` patterns are written against.
String _repoPath(FileSystemEntity file) {
  final absolute = p.normalize(file.absolute.path);
  final root = p.normalize(Directory(kRepoRoot).absolute.path);
  return p.relative(absolute, from: root).replaceAll(r'\', '/');
}

List<AttributeRule> _rules() {
  final file = File(p.join(kRepoRoot, '.gitattributes'));
  expect(
    file.existsSync(),
    isTrue,
    reason:
        'run from the app root; $kRepoRoot/.gitattributes is the whole '
        'subject of this file',
  );
  return parseGitAttributes(file.readAsStringSync());
}

/// The suggestion printed on failure. Naming the line to add is the
/// difference between a gate that gets fixed and a gate that gets deleted.
String _fixFor(String extension) =>
    'add `*$extension  text eol=lf` to .gitattributes (or `*$extension  '
    'binary` if the format is genuinely not diffable — see the header of '
    '.gitattributes for why the goldens are not)';

void main() {
  late final List<AttributeRule> rules;
  late final List<File> byteExact;

  setUpAll(() {
    rules = _rules();
    byteExact = <File>[
      for (final root in kByteExactRoots) ..._filesUnder(root),
    ];
  });

  test('the rule is not vacuous — the roots exist and hold files', () {
    // Without this, deleting a fixture directory (or moving the roots)
    // makes every assertion below pass over an empty set, which is the
    // cheapest way to make a gate like this stop meaning anything.
    for (final root in kByteExactRoots) {
      expect(
        _filesUnder(root),
        isNotEmpty,
        reason:
            '$root holds no files. Either it moved — update '
            'kByteExactRoots — or the goldens are gone, in which case '
            'CR-117 has nothing left to assert against.',
      );
    }
    expect(byteExact.length, greaterThanOrEqualTo(8));
    expect(rules, isNotEmpty);
  });

  test('every byte-exact artifact survives a checkout unchanged', () {
    // THE RULE. Note what is derived and what is declared: the roots are
    // declared, the EXTENSIONS are read off the disk. A `.rmproj` golden
    // dropped into assets/starters tomorrow fails here without anybody
    // having edited this file.
    final unprotected = <String>[];
    for (final file in byteExact) {
      final path = _repoPath(file);
      final resolution = resolveCheckout(rules, path);
      if (!kByteSafeResolutions.contains(resolution)) {
        unprotected.add(
          '$path — resolves to "$resolution"; '
          '${_fixFor(p.extension(path))}',
        );
      }
    }
    expect(
      unprotected,
      isEmpty,
      reason:
          'these files are compared BYTE FOR BYTE by the suite, and '
          '.gitattributes does not pin how they come out of a checkout. On '
          'a Windows clone with core.autocrlf=true they arrive '
          'CRLF-normalised, which is a different file from the one that '
          'was committed, and CR-117 fails on a clean checkout while '
          'staying green for everyone who already had the '
          'tree:\n${unprotected.join('\n')}',
    );
  });

  test('...and so does every file elsewhere that shares their format', () {
    // A golden is not safe because of where it lives. This catches the
    // same artifact placed outside a declared root, and a later rule in
    // .gitattributes that un-pins one of these extensions for a subtree.
    final extensions = byteExact
        .map((f) => p.extension(_repoPath(f)))
        .where((e) => e.isNotEmpty)
        .toSet();
    expect(extensions, isNotEmpty);

    final unprotected = <String>[];
    for (final file in _allCommittedFiles()) {
      final path = _repoPath(file);
      if (!extensions.contains(p.extension(path))) continue;
      final resolution = resolveCheckout(rules, path);
      if (!kByteSafeResolutions.contains(resolution)) {
        unprotected.add('$path — resolves to "$resolution"');
      }
    }
    expect(
      unprotected,
      isEmpty,
      reason:
          'a file in a byte-defined format (${extensions.join(', ')}) is '
          'not pinned to an exact checkout:\n${unprotected.join('\n')}',
    );
  });

  test('the committed bytes contain no CR, so `eol=lf` is exact', () {
    // WHY THIS IS ASSERTED RATHER THAN ASSUMED, and why it decides the
    // eol=lf-versus-binary question. `text eol=lf` normalises CRLF to LF
    // going INTO the repository as well as coming out; if a golden ever
    // legitimately contained a raw CR, that would corrupt it on commit and
    // `binary` would be the only safe marking. It cannot: the canonical
    // JSON writer escapes control characters, so a CR inside a string
    // value is written as the two ASCII bytes `\r`. This measures that
    // rather than trusting it.
    final withCr = <String>[];
    for (final file in byteExact) {
      final bytes = file.readAsBytesSync();
      final count = bytes.where((b) => b == 0x0D).length;
      if (count > 0) withCr.add('${_repoPath(file)} — $count CR bytes');
    }
    expect(
      withCr,
      isEmpty,
      reason:
          'a byte-exact golden holds raw CR bytes. `text eol=lf` would '
          'rewrite them on the way into the repository and the file would '
          'be corrupted at commit time — mark it `binary` instead, and say '
          'so in .gitattributes:\n${withCr.join('\n')}',
    );
  });

  test('the reader above agrees with real git', () {
    // THE CROSS-CHECK. Everything else here is this file's own reading of
    // `.gitattributes`; git is the only authority on what a clone actually
    // does. If git cannot be run, that is reported rather than passed
    // over — a cross-check that silently evaporates is worse than none,
    // because the suite still reads as though it happened.
    final paths = byteExact.map(_repoPath).toList(growable: false);
    final ProcessResult result;
    try {
      result = Process.runSync(
        'git',
        ['check-attr', 'text', 'eol', '--', ...paths],
        workingDirectory: kRepoRoot,
      );
    } on ProcessException catch (error) {
      markTestSkipped(
        'git could not be run, so the resolver in this file '
        'is unverified against the real thing: $error',
      );
      return;
    }
    if (result.exitCode != 0) {
      markTestSkipped(
        'git check-attr failed (exit ${result.exitCode}), so '
        'the resolver in this file is unverified against the real thing: '
        '${result.stderr}',
      );
      return;
    }

    // `<path>: <attribute>: <value>`, one line per path per attribute.
    final gitText = <String, String>{};
    final gitEol = <String, String>{};
    for (final line in (result.stdout as String).split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final attributeAt = trimmed.lastIndexOf(': ', trimmed.length - 1);
      final valueStart = attributeAt + 2;
      final head = trimmed.substring(0, attributeAt);
      final value = trimmed.substring(valueStart);
      final split = head.lastIndexOf(': ');
      final path = head.substring(0, split).replaceAll(r'\', '/');
      final attribute = head.substring(split + 2);
      if (attribute == 'text') gitText[path] = value;
      if (attribute == 'eol') gitEol[path] = value;
    }
    expect(
      gitText,
      isNotEmpty,
      reason: 'git check-attr produced nothing to compare against',
    );

    final disagreements = <String>[];
    for (final path in paths) {
      final text = gitText[path];
      final eol = gitEol[path];
      if (text == null || eol == null) {
        disagreements.add('$path — git said nothing about it');
        continue;
      }
      final fromGit = _resolutionFromGit(text, eol);
      final fromHere = resolveCheckout(rules, path);
      if (fromGit != fromHere) {
        disagreements.add(
          '$path — git says "$fromGit" (text: $text, eol: $eol), this file '
          'says "$fromHere"',
        );
      }
    }
    expect(
      disagreements,
      isEmpty,
      reason:
          'the `.gitattributes` reader in this file has drifted away from '
          'git, so every other assertion here is checking the wrong '
          'thing:\n${disagreements.join('\n')}',
    );
  });

  // ======================================================================
  // GUARDS THE GUARD
  // ======================================================================
  // Every assertion above passes over the real tree, so none of them shows
  // that it CAN fail. These drive the resolver with attribute files that
  // are not in the repository — including the exact one this task was
  // raised against.
  group('the rule itself can fail', () {
    const starter = 'apps/rackpal/assets/starters/apartment.rmpj';
    const shipping = '''
* text=auto
*.dart   text eol=lf
*.json   text eol=lf
*.rmpj  text eol=lf
*.png    binary
''';

    test('the shipping .gitattributes protects the starters', () {
      expect(resolveCheckout(parseGitAttributes(shipping), starter), 'lf');
    });

    test('THE DEFECT: no rule for .rmpj falls through to text=auto', () {
      // Verbatim the state this task was raised against: `*.json` pinned,
      // the starters matching nothing but `* text=auto`. `git check-attr`
      // reported exactly this — "text: auto, eol: unspecified".
      const before = '''
* text=auto
*.dart   text eol=lf
*.json   text eol=lf
*.png    binary
''';
      expect(resolveCheckout(parseGitAttributes(before), starter), 'platform');
      expect(
        resolveCheckout(parseGitAttributes(before), 'a/b/fixture.json'),
        'lf',
      );
    });

    test('...and so does `text` without an `eol`', () {
      // The near miss. `text` alone normalises going in and checks out
      // per core.autocrlf coming back — CRLF on a default Windows install.
      const halfDone = '* text=auto\n*.rmpj  text\n';
      expect(
        resolveCheckout(parseGitAttributes(halfDone), starter),
        'platform',
      );
    });

    test('...and an empty attributes file protects nothing', () {
      expect(resolveCheckout(parseGitAttributes(''), starter), 'unspecified');
      expect(
        kByteSafeResolutions.contains('unspecified'),
        isFalse,
        reason: 'an unmatched path is the state the starters were in',
      );
    });

    test('a later line wins, which is how a subtree gets un-pinned', () {
      // NOTE THE PATH: `assets/*` would NOT reach this file, because `*`
      // does not cross a separator in an anchored pattern. Getting that
      // wrong is how a reader talks themselves into believing a subtree is
      // covered when it is not.
      const unpinned = '$shipping\napps/rackpal/assets/starters/* -text\n';
      // `-text` is byte-safe, so this particular override is benign...
      expect(resolveCheckout(parseGitAttributes(unpinned), starter), 'binary');
      expect(
        resolveCheckout(
          parseGitAttributes('$shipping\napps/rackpal/assets/* -text\n'),
          starter,
        ),
        'lf',
        reason: '`assets/*` does not reach `assets/starters/x.rmpj`',
      );
      // ...but this one is not, and last-match-wins is why it has to be
      // the whole file that is read and not the first hit.
      const clobbered = '$shipping\n*.rmpj  text eol=crlf\n';
      expect(resolveCheckout(parseGitAttributes(clobbered), starter), 'crlf');
      expect(kByteSafeResolutions.contains('crlf'), isFalse);
    });

    test('`binary` is read as the macro it is', () {
      const binary = '* text=auto\n*.rmpj  binary\n';
      expect(resolveCheckout(parseGitAttributes(binary), starter), 'binary');
    });

    test('a slashless pattern matches at any depth; an anchored one does '
        'not', () {
      expect(patternMatches('*.rmpj', 'deep/nested/x.rmpj'), isTrue);
      expect(patternMatches('*.rmpj', 'x.rmpj'), isTrue);
      expect(patternMatches('assets/*.rmpj', 'assets/x.rmpj'), isTrue);
      expect(
        patternMatches('assets/*.rmpj', 'apps/assets/x.rmpj'),
        isFalse,
        reason: 'a pattern with a slash is anchored to the repository root',
      );
      expect(
        patternMatches('assets/*.rmpj', 'assets/deep/x.rmpj'),
        isFalse,
        reason: '`*` does not cross a separator in an anchored pattern',
      );
      expect(patternMatches('*.json', 'x.rmpj'), isFalse);
    });

    test('comments and blank lines are not rules', () {
      const noisy = '''
# *.rmpj  text eol=lf
   # indented, still a comment

* text=auto
''';
      expect(resolveCheckout(parseGitAttributes(noisy), starter), 'platform');
    });
  });
}

/// `git check-attr`'s two answers, folded into the same vocabulary
/// [resolveCheckout] speaks.
String _resolutionFromGit(String text, String eol) {
  if (text == 'unset') return 'binary';
  if (eol == 'lf' || eol == 'crlf') return eol;
  if (text == 'set' || text == 'auto') return 'platform';
  return 'unspecified';
}
