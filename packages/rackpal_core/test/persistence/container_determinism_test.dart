// PLAN-B/3: the four things zip does nondeterministically, each asserted
// SEPARATELY, plus CR-117 across a write, a reopen and a second write.
//
// ─────────────────────────────────────────────────────────────────────────
// WHY FOUR ASSERTIONS AND NOT ONE ROUND TRIP
// ─────────────────────────────────────────────────────────────────────────
// A single `write(read(bytes)) == bytes` passes as soon as the writer is
// *self*-consistent, and tells you nothing about WHICH of the four
// sources you actually fixed. Worse, the timestamp one passes for a while
// after you write it, so a green suite is not evidence. Each source
// therefore gets its own test that FAILS if only that knob is removed.
//
// ─────────────────────────────────────────────────────────────────────────
// THE TWO-SECOND TRAP, WHICH THIS FILE FELL INTO ON ITS FIRST RUN
// ─────────────────────────────────────────────────────────────────────────
// The MS-DOS time field a zip stores has TWO-SECOND granularity. The
// first measurement of the wall-clock source used a 1.1 second gap,
// reported "deterministic", and was wrong: both calls had landed in the
// same two-second bucket. Any test of this that waits less than two
// seconds is asserting nothing. The gap below is deliberately longer, and
// it is the reason this file is slower than its neighbours.

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

/// Pretty JSON, so the deflate path has something real to chew on.
final Uint8List _doc = Uint8List.fromList(
  utf8.encode('{\n  "schemaVersion": 4,\n  "id": "abc",\n  "racks": []\n}'),
);

/// Two members, deliberately NOT in sorted order in the source map, and
/// with incompressible-looking content so STORE vs DEFLATE is visible.
Map<String, Uint8List> _members() => <String, Uint8List>{
  'underlays/zzz-level-2.png': Uint8List.fromList(
    List<int>.generate(600, (i) => (i * 37 + 11) % 256),
  ),
  'underlays/aaa-level-1.png': Uint8List.fromList(
    List<int>.generate(400, (i) => (i * 91 + 3) % 256),
  ),
};

/// Every local file header in [zip], as (name, method, extraLen, flags).
List<(String, int, int, int)> _localHeaders(Uint8List zip) {
  final out = <(String, int, int, int)>[];
  var i = 0;
  while (i + 30 <= zip.length &&
      zip[i] == 0x50 &&
      zip[i + 1] == 0x4B &&
      zip[i + 2] == 0x03 &&
      zip[i + 3] == 0x04) {
    final flags = zip[i + 6] | (zip[i + 7] << 8);
    final method = zip[i + 8] | (zip[i + 9] << 8);
    final compLen =
        zip[i + 18] |
        (zip[i + 19] << 8) |
        (zip[i + 20] << 16) |
        (zip[i + 21] << 24);
    final nameLen = zip[i + 26] | (zip[i + 27] << 8);
    final extraLen = zip[i + 28] | (zip[i + 29] << 8);
    out.add((
      utf8.decode(zip.sublist(i + 30, i + 30 + nameLen)),
      method,
      extraLen,
      flags,
    ));
    i += 30 + nameLen + extraLen + compLen;
  }
  return out;
}

/// A newline. Spelled this way because the fixture below is generated
/// through tooling that has already mangled an escaped one once.
final String _nl = String.fromCharCode(10);

void main() {
  group('source 1 of 4: entry ORDER', () {
    test('the same members in a different iteration order write the same '
        'bytes', () {
      final forward = <String, Uint8List>{};
      final reverse = <String, Uint8List>{};
      final src = _members();
      for (final k in src.keys) {
        forward[k] = src[k]!;
      }
      for (final k in src.keys.toList().reversed) {
        reverse[k] = src[k]!;
      }
      expect(forward.keys.toList(), isNot(reverse.keys.toList()));

      expect(
        writeContainerBytes(_doc, forward),
        writeContainerBytes(_doc, reverse),
      );
    });

    test('entries land in sorted order, document.json first', () {
      final zip = writeContainerBytes(_doc, _members());
      final names = _localHeaders(zip).map((h) => h.$1).toList();
      expect(names, [
        kDocumentMember,
        'underlays/aaa-level-1.png',
        'underlays/zzz-level-2.png',
      ]);
      expect(names, orderedEquals(List<String>.from(names)..sort()));
    });

    test('ORDER IS A REAL SOURCE: a hand-built archive in the other order '
        'differs, so the sort above is not decoration', () {
      Uint8List handBuilt(List<String> order) {
        final a = Archive();
        final m = _members();
        for (final name in order) {
          final data = name == kDocumentMember ? _doc : m[name]!;
          final f = ArchiveFile.bytes(name, data);
          if (name != kDocumentMember) f.compression = CompressionType.none;
          a.add(f);
        }
        return ZipEncoder().encodeBytes(
          a,
          level: kContainerDeflateLevel,
          modified: kContainerTimestamp,
        );
      }

      expect(
        handBuilt([
          kDocumentMember,
          'underlays/aaa-level-1.png',
          'underlays/zzz-level-2.png',
        ]),
        isNot(
          handBuilt([
            'underlays/zzz-level-2.png',
            'underlays/aaa-level-1.png',
            kDocumentMember,
          ]),
        ),
      );
    });
  });

  group('source 2 of 4: the WALL CLOCK', () {
    test('two writes more than two seconds apart are byte-identical', () async {
      final first = writeContainerBytes(_doc, _members());
      // OVER TWO SECONDS ON PURPOSE. The DOS time field has two-second
      // granularity, so a shorter wait can put both calls in the same
      // bucket and pass while the writer is reading the clock. See the
      // file header.
      await Future<void>.delayed(const Duration(milliseconds: 2600));
      final second = writeContainerBytes(_doc, _members());

      expect(first, second);
    });

    test('THE CLOCK IS A REAL SOURCE: the same archive written without a '
        'fixed timestamp differs across the same gap', () async {
      Uint8List clockWritten() {
        final a = Archive()..add(ArchiveFile.bytes(kDocumentMember, _doc));
        return ZipEncoder().encodeBytes(a, level: kContainerDeflateLevel);
      }

      final first = clockWritten();
      await Future<void>.delayed(const Duration(milliseconds: 2600));
      final second = clockWritten();

      // If this ever stops failing, the library has started fixing the
      // timestamp itself and `kContainerTimestamp` has become decoration
      // rather than a guarantee. Either way somebody should know.
      expect(
        first,
        isNot(second),
        reason:
            'archive no longer reads the wall clock; re-read the '
            'container header before trusting kContainerTimestamp',
      );
    });
  });

  group('source 3 of 4: COMPRESSION LEVEL', () {
    test('the level is pinned to 9, and the library default is not 9', () {
      expect(kContainerDeflateLevel, DeflateLevel.bestCompression);

      // A REALISTIC BODY, AND THE SIZE IS THE POINT. This assertion first
      // ran against the 55-byte `_doc` above and FAILED: a body that
      // small deflates identically at every level, so a tiny fixture
      // "proves" the level is not a source of nondeterminism. A real
      // `document.json` is hundreds of kilobytes of repetitive
      // pretty-printed JSON, which is exactly where levels diverge, so
      // the fixture is shaped like the thing rather than like a unit.
      final body = Uint8List.fromList(
        utf8.encode(
          List<String>.generate(
            400,
            (i) => '  {"id": "dev-$i", "ru": ${i % 42}, "face": "front"}',
          ).join(',$_nl'),
        ),
      );

      Uint8List at(int? level) {
        final a = Archive()..add(ArchiveFile.bytes(kDocumentMember, body));
        return level == null
            ? ZipEncoder().encodeBytes(a, modified: kContainerTimestamp)
            : ZipEncoder().encodeBytes(
                a,
                level: level,
                modified: kContainerTimestamp,
              );
      }

      // The point of pinning: "leave it alone" is itself a choice, and it
      // is not the one this format made.
      expect(at(null), isNot(at(DeflateLevel.bestCompression)));
      expect(
        at(DeflateLevel.defaultCompression),
        isNot(at(DeflateLevel.bestCompression)),
      );
    });

    test('the JSON member is DEFLATED and binary members are STORED', () {
      final headers = _localHeaders(writeContainerBytes(_doc, _members()));
      final byName = {for (final h in headers) h.$1: h.$2};

      expect(byName[kDocumentMember], 8, reason: 'deflate');
      expect(byName['underlays/aaa-level-1.png'], 0, reason: 'store');
      expect(byName['underlays/zzz-level-2.png'], 0, reason: 'store');
    });

    test("a stored member's bytes appear VERBATIM in the container, which "
        'is what takes deflate out of the round trip for rasters', () {
      final members = _members();
      final needle = members['underlays/aaa-level-1.png']!;
      final zip = writeContainerBytes(_doc, members);

      var found = -1;
      outer:
      for (var i = 0; i + needle.length <= zip.length; i++) {
        for (var j = 0; j < needle.length; j++) {
          if (zip[i + j] != needle[j]) continue outer;
        }
        found = i;
        break;
      }
      expect(found, greaterThanOrEqualTo(0));
    });
  });

  group('source 4 of 4: EXTRA FIELDS', () {
    test('every local header reports an extra-field length of zero', () {
      // Already true of archive 4.0.9, so this GUARDS rather than fixes.
      // A bump that starts emitting a UT (extended timestamp) or Zip64
      // field re-introduces the wall clock through a field nothing here
      // sets, and this is the only thing that would notice.
      final headers = _localHeaders(writeContainerBytes(_doc, _members()));
      expect(headers, hasLength(3));
      for (final h in headers) {
        expect(h.$3, 0, reason: 'extra-field length for ${h.$1}');
      }
    });

    test('the UTF-8 name flag is set and is the only general-purpose bit', () {
      // 0x800 is the language-encoding bit. Anything else appearing here
      // (encryption, a data descriptor) changes the bytes and is worth
      // failing over.
      for (final h in _localHeaders(writeContainerBytes(_doc, _members()))) {
        expect(h.$4, 0x800, reason: 'general-purpose flags for ${h.$1}');
      }
    });
  });

  group('CR-117 on the zip path: a write, a reopen and a second write', () {
    test('the criterion verbatim: three steps, not one round trip', () {
      final members = _members();

      // Write.
      final first = writeContainerBytes(_doc, members);

      // Reopen.
      final reopened = readContainerParts(first);
      expect(reopened, isA<Ok<ContainerParts>>());
      final parts = (reopened as Ok<ContainerParts>).value;

      // A second write, from what the reopen produced and NOT from the
      // originals. This is what catches a writer that is deterministic
      // only when it has just been handed its own inputs.
      final second = writeContainerBytes(parts.documentBytes, parts.members);
      expect(second, first);

      // And once more, because two is a coincidence.
      final third = readContainerParts(second);
      final parts3 = (third as Ok<ContainerParts>).value;
      expect(writeContainerBytes(parts3.documentBytes, parts3.members), first);
    });

    test('the reopen returns the document bytes unchanged', () {
      final zip = writeContainerBytes(_doc, _members());
      final parts = (readContainerParts(zip) as Ok<ContainerParts>).value;
      expect(parts.documentBytes, _doc);
    });

    test('the reopen returns every member unchanged, and no extra one', () {
      final members = _members();
      final zip = writeContainerBytes(_doc, members);
      final parts = (readContainerParts(zip) as Ok<ContainerParts>).value;

      expect(parts.members.keys.toSet(), members.keys.toSet());
      for (final entry in members.entries) {
        expect(parts.members[entry.key], entry.value, reason: entry.key);
      }
      expect(parts.hasMembers, isTrue);
    });
  });
}
