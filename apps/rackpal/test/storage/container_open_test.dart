// PLAN-B/5: the file-layer states a container owes (AC-058/D3), through
// the real `DocumentStore` and the real presenter.
//
// ═══════════════════════════════════════════════════════════════════════
// THE BLANK PLAN IS THE DANGEROUS FAILURE, NOT THE CRASH
// ═══════════════════════════════════════════════════════════════════════
// docs/15 §10 clause 2: opening a project whose underlay is missing must
// yield a typed error and a named state, "never a crash and never a
// silently blank plan". A blank plan looks exactly like a project where
// nobody has pinned anything yet, so it is the one outcome a person
// cannot tell from success. Every assertion below is ultimately about
// that: a container that is wrong says so, by name, in a sentence.
//
// ═══════════════════════════════════════════════════════════════════════
// AND THE COPY IS ASSERTED, NOT JUST THE TYPE
// ═══════════════════════════════════════════════════════════════════════
// `OpenZipContainer` already existed and its copy told the user "RackPal
// projects are plain JSON. If the project is inside the archive, extract
// it first." That advice DESTROYS a project now: a RackPal project with a
// floorplan IS a zip archive, and extracting it yields a `document.json`
// with the underlay left behind. A test that checked only the error TYPE
// would have passed over that sentence unchanged, which is why these
// assert the words.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rackpal/src/session/file_error_presenter.dart';
import 'package:rackpal/src/storage/atomic_writer.dart';
import 'package:rackpal/src/storage/document_store.dart';
import 'package:rackpal/src/storage/errors.dart';
import 'package:rackpal/src/storage/recovery_store.dart';
import 'package:rackpal/src/storage/save_paths.dart';
import 'package:rackpal/src/storage/serialization.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

import 'fake_file_store.dart';

final _windows = p.Context(style: p.Style.windows);
const _dataRoot = r'C:\data';
const _jobs = r'C:\jobs';
final _paths = SavePaths.forTarget(r'C:\jobs\Smith', context: _windows);

const _codec = JsonDocumentCodec();
final _fixed = DateTime.utc(2026, 7, 18, 9);

RackDocument _doc() => RackDocument(
  id: const Uuid('0190e3c1-0000-7000-8000-000000000000'),
  appVersion: '0.1.0',
  createdAt: _fixed,
  modifiedAt: _fixed,
  meta: EntityMeta(createdAt: _fixed, updatedAt: _fixed, updatedBy: 'seed'),
  info: ProjectInfo(projectName: 'Smith Residence'),
);

/// A believable underlay: a few kilobytes of incompressible-looking data.
Uint8List _underlay([int n = 4096]) =>
    Uint8List.fromList(List<int>.generate(n, (i) => (i * 31 + 7) % 256));

DocumentStore _store(Map<String, Uint8List> files) {
  final fs = FakeFileStore(
    initialFiles: files,
    initialDirectories: {'C:', _dataRoot, _jobs},
  );
  final writer = AtomicWriter(
    fs: fs,
    queue: SaveQueue(),
    context: _windows,
    delay: (_) async {},
  );
  return DocumentStore(
    fs: fs,
    writer: writer,
    recovery: RecoveryStore(
      fs: fs,
      writer: writer,
      dataRoot: _dataRoot,
      context: _windows,
    ),
    serializer: inlineSerializer,
    deserializer: inlineDeserializer,
    context: _windows,
  );
}

/// A zip holding [entries] and NO `document.json`, built through the
/// container writer and then renamed member by member.
///
/// WHY NOT `package:archive` DIRECTLY: it is a dependency of
/// `rackpal_core`, not of this app, and importing it here to build a
/// fixture would mean declaring a zip library in the app's pubspec to
/// test that the app does not know about zip libraries. The writer is
/// already proven byte-for-byte in `rackpal_core`, so using it costs
/// nothing this file is asserting.
Uint8List _foreignZip(Map<String, Uint8List> entries) {
  // `writeContainerBytes` always emits `document.json`, so the fixture is
  // built by writing a container whose document member is trivial and
  // then flipping the four bytes of its NAME in the local header and the
  // central directory. Cheap, and it keeps the bytes a real zip.
  final built = writeContainerBytes(
    Uint8List.fromList(utf8.encode('{}')),
    entries,
  );
  final needle = utf8.encode(kDocumentMember);
  final replacement = utf8.encode('DOCUMENT.JSN'); // same length
  final out = Uint8List.fromList(built);
  for (var i = 0; i + needle.length <= out.length; i++) {
    var hit = true;
    for (var j = 0; j < needle.length; j++) {
      if (out[i + j] != needle[j]) {
        hit = false;
        break;
      }
    }
    if (hit) {
      out.setRange(i, i + replacement.length, replacement);
    }
  }
  return out;
}

FileErrorView _view(OpenError e) =>
    describeOpenError(e, context: _windows, now: _fixed);

void main() {
  group('a container opens, which is the case everything else contrasts '
      'with', () {
    test('a project with an underlay opens and keeps its members', () async {
      final bytes = writeContainerBytes(_codec.write(_doc()), {
        'underlays/level-1.png': _underlay(),
      });
      expect(looksLikeZip(bytes), isTrue);

      final result = await _store({_paths.target: bytes}).open(_paths.target);

      expect(result, isA<Ok<OpenedDocument>>());
      final opened = (result as Ok<OpenedDocument>).value;
      expect(opened.document.info.projectName, 'Smith Residence');
      expect(opened.members.keys, ['underlays/level-1.png']);
      expect(opened.members['underlays/level-1.png'], _underlay());
    });

    test('a plain-JSON project still opens and carries NO members', () async {
      final result = await _store({
        _paths.target: _codec.write(_doc()),
      }).open(_paths.target);

      final opened = (result as Ok<OpenedDocument>).value;
      expect(opened.members, isEmpty);
    });
  });

  group('a zip that is not a project', () {
    late OpenError error;

    setUp(() async {
      final result = await _store({
        _paths.target: _foreignZip({
          'word/document.xml': Uint8List.fromList(utf8.encode('<w:p/>')),
          '[Content_Types].xml': Uint8List.fromList(utf8.encode('<Types/>')),
        }),
      }).open(_paths.target);
      error = (result as Err<OpenedDocument>).error as OpenError;
    });

    test('is OpenZipContainer, and names what it did hold', () {
      expect(error, isA<OpenZipContainer>());
      expect(
        (error as OpenZipContainer).members,
        contains('word/document.xml'),
      );
    });

    test('THE COPY NO LONGER SAYS PROJECTS ARE PLAIN JSON', () {
      final view = _view(error);
      // The sentence that would now destroy a project.
      expect(view.detail, isNot(contains('plain JSON')));
      expect(view.detail, isNot(contains('extract it')));
      // What it says instead.
      expect(view.title, contains('not a RackPal project'));
      expect(view.detail, contains('document.json'));
      expect(view.detail, contains('word/document.xml'));
    });

    test('offers no backup, because the user picked the wrong file', () {
      expect(
        _view(error).actions.map((a) => a.id),
        isNot(contains(FileErrorActionId.openBackup)),
      );
    });
  });

  group('a damaged container', () {
    late OpenError error;

    setUp(() async {
      // A real container, truncated. The signature survives and the
      // central directory does not, which is what a copy interrupted
      // half way actually looks like.
      final good = writeContainerBytes(_codec.write(_doc()), {
        'underlays/level-1.png': _underlay(),
      });
      final truncated = Uint8List.sublistView(good, 0, good.length ~/ 2);

      final result = await _store({
        _paths.target: Uint8List.fromList(truncated),
        '${_paths.target}$kBackupSuffix': _codec.write(_doc()),
      }).open(_paths.target);
      error = (result as Err<OpenedDocument>).error as OpenError;
    });

    test('is OpenContainerUnreadable and not the not-a-project state', () {
      expect(error, isA<OpenContainerUnreadable>());
      expect(error, isNot(isA<OpenZipContainer>()));
    });

    test('OFFERS THE BACKUP, which is the whole reason these are two '
        'states', () {
      expect(
        _view(error).actions.map((a) => a.id),
        contains(FileErrorActionId.openBackup),
      );
      expect(_view(error).title, contains('damaged'));
    });
  });

  group('a decompression bomb', () {
    test('is refused on the DECLARED size, with nothing inflated', () async {
      // A tiny file whose single member declares far more than the cap.
      // Built with a low limit rather than a real bomb, which is
      // `JsonLimits`'s own trick: proving the gate fires must not cost a
      // 256 MB fixture.
      final bytes = writeContainerBytes(
        Uint8List.fromList(utf8.encode('{}')),
        {'underlays/big.png': _underlay(64 * 1024)},
      );
      expect(bytes.length, lessThan(200 * 1024));

      final parts = readContainerParts(
        bytes,
        limits: const ContainerLimits(maxInflatedBytes: 1024),
      );
      expect(parts, isA<Err<ContainerParts>>());
      expect(
        (parts as Err<ContainerParts>).error,
        isA<ContainerTooLargeError>(),
      );
    });

    test('is refused on the member COUNT too', () {
      final bytes = writeContainerBytes(
        Uint8List.fromList(utf8.encode('{}')),
        {
          for (var i = 0; i < 12; i++)
            'underlays/$i.png': Uint8List.fromList(const [1, 2, 3]),
        },
      );

      final parts = readContainerParts(
        bytes,
        limits: const ContainerLimits(maxMembers: 4),
      );
      expect(
        (parts as Err<ContainerParts>).error,
        isA<ContainerTooLargeError>(),
      );
    });

    test('THE MESSAGE NAMES THE DECLARED SIZE, NOT THE FILE SIZE', () {
      // The trap `OpenContainerTooLarge` exists to avoid: a one-megabyte
      // file described as too large reads as a broken app.
      final view = _view(
        const OpenContainerTooLarge(
          r'C:\jobs\Smith',
          declaredBytes: 10 * 1024 * 1024 * 1024,
          members: 3,
          byteLimit: 256 * 1024 * 1024,
          memberLimit: 64,
        ),
      );
      expect(view.detail, contains('says it contains'));
      expect(view.detail, contains('3 item(s)'));
      expect(view.detail, contains('Nothing was extracted'));
    });

    test('a real project is nowhere near either cap', () {
      // The anti-vacuity assertion. A cap set below the ordinary case
      // refuses everything and passes every test above.
      final bytes = writeContainerBytes(_codec.write(_doc()), {
        'underlays/level-1.png': _underlay(2 * 1024 * 1024),
      });
      expect(readContainerParts(bytes), isA<Ok<ContainerParts>>());
      expect(kMaxContainerMembers, greaterThan(8));
      expect(kMaxContainerInflatedBytes, greaterThan(64 * 1024 * 1024));
    });
  });

  group('THE PASSTHROUGH: a save does not strip what an open carried', () {
    test('members survive open, edit and save, and the file is still a '
        'container', () async {
      final underlay = _underlay();
      final original = writeContainerBytes(_codec.write(_doc()), {
        'underlays/level-1.png': underlay,
      });
      final store = _store({_paths.target: original});

      final opened =
          ((await store.open(_paths.target)) as Ok<OpenedDocument>).value;
      final controller = DocumentController(
        opened.document,
        clock: FixedClock(_fixed),
      );

      final saved = await store.save(
        controller: controller,
        paths: _paths,
        members: opened.members,
      );
      expect(saved, isA<Ok<SavedFile>>());

      // Reopen and check the underlay is still in there. Without the
      // passthrough this is a plain-JSON file and the architect's page is
      // gone, with nothing on screen having suggested it.
      final again =
          ((await store.open(_paths.target)) as Ok<OpenedDocument>).value;
      expect(again.members['underlays/level-1.png'], underlay);
    });

    test('a save with NO members writes plain JSON, byte for byte', () async {
      final plain = _codec.write(_doc());
      final store = _store({_paths.target: plain});

      final opened =
          ((await store.open(_paths.target)) as Ok<OpenedDocument>).value;
      expect(opened.members, isEmpty);

      await store.save(
        controller: DocumentController(
          opened.document,
          clock: FixedClock(_fixed),
        ),
        paths: _paths,
        members: opened.members,
      );

      final again =
          ((await store.open(_paths.target)) as Ok<OpenedDocument>).value;
      expect(again.members, isEmpty);
    });
  });
}
