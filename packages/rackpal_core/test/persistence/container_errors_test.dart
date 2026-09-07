// PLAN-B/5, the core half: what `readContainerParts` refuses, and why the
// two refusals are two.
//
// ═══════════════════════════════════════════════════════════════════════
// THE MEASUREMENT THAT SHAPED THIS FILE
// ═══════════════════════════════════════════════════════════════════════
// `ZipDecoder.decodeBytes` DOES NOT THROW on a truncated archive. It
// reads the central directory, which lives at the end of the file, so a
// truncated one simply has none and it returns an EMPTY archive. Measured
// at six truncation points and on a file that was nothing but the four
// signature bytes: zero throws, zero entries, every time.
//
// That is the difference between this file existing and a shipped shell.
// Written from the assumption instead, "damaged" would have been the
// exception arm, nothing would ever have reached it, and every truncated
// project would have been reported as "not a RackPal project" and refused
// the `.bak` that would have rescued it. The tests below therefore assert
// the EMPTY case, and the exception case is not pretended to be the
// common one.

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

Uint8List _bytes(String s) => Uint8List.fromList(utf8.encode(s));

Uint8List _zip(Map<String, Uint8List> entries) {
  final a = Archive();
  for (final e in entries.entries) {
    a.add(ArchiveFile.bytes(e.key, e.value));
  }
  return ZipEncoder().encodeBytes(a);
}

Object _errorOf(Outcome<ContainerParts> o) => (o as Err<ContainerParts>).error;

void main() {
  group('a truncated container is DAMAGED, not "not a project"', () {
    late Uint8List good;

    setUp(() {
      good = writeContainerBytes(_bytes('{"schemaVersion": 4}'), {
        'underlays/level-1.png': Uint8List.fromList(
          List<int>.generate(4096, (i) => i % 256),
        ),
      });
    });

    test('every truncation point reports ContainerUnreadableError', () {
      // The six points the spike measured, asserted rather than recalled.
      for (final fraction in [0.1, 0.25, 0.5, 0.75, 0.9, 0.99]) {
        final cut = Uint8List.fromList(
          good.sublist(0, (good.length * fraction).round()),
        );
        expect(
          _errorOf(readContainerParts(cut)),
          isA<ContainerUnreadableError>(),
          reason: 'truncated to $fraction',
        );
      }
    });

    test('a file that is ONLY the signature is damaged too', () {
      expect(
        _errorOf(readContainerParts(Uint8List.fromList(kZipMagicBytes))),
        isA<ContainerUnreadableError>(),
      );
    });

    test('the message says what an empty archive means, because "no '
        'entries" alone explains nothing', () {
      final cut = Uint8List.fromList(good.sublist(0, good.length ~/ 2));
      expect(
        _errorOf(readContainerParts(cut)).toString(),
        contains('truncated'),
      );
    });

    test('and the intact original is fine, which is what makes the above '
        'about truncation rather than about the writer', () {
      expect(readContainerParts(good), isA<Ok<ContainerParts>>());
    });
  });

  group('a readable archive with no document.json is NOT a project', () {
    test('it reports ContainerMissingDocumentError and lists what it '
        'held', () {
      final error = _errorOf(
        readContainerParts(
          _zip({
            'word/document.xml': _bytes('<w:p/>'),
            '[Content_Types].xml': _bytes('<Types/>'),
          }),
        ),
      );

      expect(error, isA<ContainerMissingDocumentError>());
      expect(
        (error as ContainerMissingDocumentError).members,
        containsAll(<String>['word/document.xml', '[Content_Types].xml']),
      );
    });

    test('THE TWO REFUSALS ARE DIFFERENT TYPES, which is the whole point '
        'of measuring the truncation case', () {
      final damaged = _errorOf(
        readContainerParts(Uint8List.fromList(kZipMagicBytes)),
      );
      final foreign = _errorOf(
        readContainerParts(_zip({'a.txt': _bytes('hello')})),
      );
      expect(damaged.runtimeType, isNot(foreign.runtimeType));
    });

    test('a member merely NAMED like the document does not count', () {
      // `underlays/document.json` is not `document.json`. A prefix or
      // suffix match here would open a foreign archive as a project.
      expect(
        _errorOf(
          readContainerParts(
            _zip({'underlays/document.json': _bytes('{}')}),
          ),
        ),
        isA<ContainerMissingDocumentError>(),
      );
    });
  });

  group('the bomb caps refuse before inflating', () {
    test('the member count is checked, and the error names both limits', () {
      final error = _errorOf(
        readContainerParts(
          _zip({
            for (var i = 0; i < 10; i++) 'underlays/$i.png': _bytes('x'),
          }),
          limits: const ContainerLimits(maxMembers: 3),
        ),
      );

      expect(error, isA<ContainerTooLargeError>());
      final e = error as ContainerTooLargeError;
      expect(e.memberLimit, 3);
      expect(e.members, greaterThan(3));
      expect(e.toString(), contains('member'));
    });

    test('the declared size is checked', () {
      final error = _errorOf(
        readContainerParts(
          _zip({
            kDocumentMember: _bytes('{}'),
            'underlays/a.png': Uint8List(50000),
          }),
          limits: const ContainerLimits(maxInflatedBytes: 1000),
        ),
      );
      expect(error, isA<ContainerTooLargeError>());
      expect((error as ContainerTooLargeError).byteLimit, 1000);
    });

    test('THE CAPS ARE NOT SET BELOW THE ORDINARY CASE, which is the way '
        'a size gate passes every test and refuses every user', () {
      final ordinary = writeContainerBytes(_bytes('{"schemaVersion": 4}'), {
        'underlays/level-1.png': Uint8List(2 * 1024 * 1024),
        'underlays/level-2.png': Uint8List(2 * 1024 * 1024),
      });
      expect(readContainerParts(ordinary), isA<Ok<ContainerParts>>());
    });

    test('the defaults leave room for a full-size document plus pages', () {
      expect(kMaxContainerInflatedBytes, greaterThan(kMaxDocumentBytes));
      expect(kMaxContainerMembers, greaterThanOrEqualTo(16));
    });
  });

  group('a non-zip file is not treated as a container at all', () {
    test('plain JSON comes back as the document half, unexamined', () {
      final json = _bytes('{"schemaVersion": 4, "id": "x"}');
      final parts = (readContainerParts(json) as Ok<ContainerParts>).value;
      expect(identical(parts.documentBytes, json), isTrue);
      expect(parts.members, isEmpty);
      expect(parts.hasMembers, isFalse);
    });

    test('so does a file too short to hold the signature', () {
      final tiny = Uint8List.fromList(const [0x50, 0x4B]);
      final parts = (readContainerParts(tiny) as Ok<ContainerParts>).value;
      expect(parts.documentBytes, tiny);
    });

    test('an EMPTY file belongs to the JSON parser, not to this one', () {
      // Deliberately NOT refused here. `checkJsonLimits` and the decoder
      // downstream own "that is not a document"; this layer only owns
      // "that is not a container", and a layer that refuses things twice
      // gives the user two different sentences for one fault.
      final parts =
          (readContainerParts(Uint8List(0)) as Ok<ContainerParts>).value;
      expect(parts.documentBytes, isEmpty);
    });
  });
}
