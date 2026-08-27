// The isolate seam. ONE test spawns a real isolate; the other ~180 tests
// in this layer use the inline pair, because spawning forty isolates
// across a widget-test suite is slow and flaky and none of those forty
// tests is about isolates.
//
// This is the "the isolate actually works, and produces the same bytes"
// proof, and it costs one spawn rather than forty.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal/src/storage/serialization.dart';
import 'package:rackpal_core/rackpal_core.dart';

const _codec = JsonDocumentCodec();
final _fixed = DateTime.utc(2026, 7, 18, 9);

EntityMeta _meta() =>
    EntityMeta(createdAt: _fixed, updatedAt: _fixed, updatedBy: 'seed');

RackDocument _document() {
  final doc = RackDocument(
    id: const Uuid('0190e3c1-0000-7000-8000-000000000000'),
    appVersion: '0.1.0',
    createdAt: _fixed,
    modifiedAt: _fixed,
    meta: _meta(),
    info: ProjectInfo(
      projectName: 'Smith Residence',
      clientName: 'A. Smith',
      siteAddress: Address(line1: '1 Example Way', city: 'Testville'),
    ),
  );
  for (var i = 0; i < 4; i++) {
    final id = Uuid('rack-$i');
    doc.racks[id] = Rack(
      id: id,
      name: 'Rack $i',
      designator: 'RK-$i',
      heightU: 42,
      order: FracIndex('a$i'),
      meta: _meta(),
    );
  }
  return doc;
}

void main() {
  test('THE REAL ISOLATE produces BYTE-IDENTICAL output to the inline '
      'path', () async {
    final tree = _codec.encodeToJsonTree(_document());

    final viaIsolate = await isolateSerializer(tree);
    final viaInline = await inlineSerializer(tree);

    expect(viaIsolate, equals(viaInline));
    // ...and both equal what the whole-pipeline `write` produces, so
    // CR-117's byte property survives the off-thread route.
    expect(viaIsolate, equals(_codec.write(_document())));
  });

  test('the real isolate DESERIALIZER agrees with the inline one', () async {
    final bytes = _codec.write(_document());

    final viaIsolate = await isolateDeserializer(bytes);
    final viaInline = await inlineDeserializer(bytes);

    expect(viaIsolate, isA<Ok<JsonMap>>());
    expect(viaInline, isA<Ok<JsonMap>>());
    expect(
      jsonEncode((viaIsolate as Ok<JsonMap>).value),
      jsonEncode((viaInline as Ok<JsonMap>).value),
    );
  });

  test('an Err crosses the isolate boundary as a VALUE, not as a thrown '
      'exception', () async {
    // `parseDocumentJsonTree` never throws (CR-093), and both its Ok and
    // its Err payloads are plain data — which is exactly what makes them
    // safe to send. A design that threw across the boundary would depend
    // on the exception type being sendable, which is not a property
    // anyone verified for every error this can produce.
    final zip = Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 1, 2]);
    final result = await isolateDeserializer(zip);
    expect(result, isA<Err<JsonMap>>());
    expect(
      (result as Err<JsonMap>).error,
      isA<UnsupportedZipContainerError>(),
    );
  });

  test('the import-hardening limits still apply on the isolate path', () async {
    final bomb = Uint8List.fromList(
      utf8.encode('${'[' * 100000}1${']' * 100000}'),
    );
    final result = await isolateDeserializer(bomb);
    expect(
      (result as Err<JsonMap>).error,
      isA<JsonTooDeeplyNestedError>(),
      reason:
          'the depth guard runs INSIDE the isolate, before jsonDecode '
          '— otherwise the stack overflow kills the isolate and the '
          'failure arrives as an opaque death rather than a sentence',
    );
  });
}
