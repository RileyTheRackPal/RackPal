// The `Isolate.run` seam (AC-006, CR-099). Two typedefs, two production
// implementations, and — in tests — an inline pair plus a gated one.
//
// ==================================================================
// WHY THE TREE AND NOT THE DOCUMENT CROSSES THE BOUNDARY
// ==================================================================
// The obvious spelling is `Isolate.run(() => codec.write(doc))`. It is
// wrong, and the reason it is wrong is subtle enough that someone WILL
// try to "simplify" it back — so it is written down at the seam rather
// than left to be rediscovered.
//
// That closure captures the LIVE, MUTABLE `RackDocument` graph. Dart does
// not document at what instant a captured object graph is serialized for
// transfer. So a user edit racing the spawn may be half-included: some
// entities copied before the edit, some after. That is a TORN SNAPSHOT —
// a file on disk that never corresponded to any state the document was
// actually in — and no test can reliably catch it, because it depends on
// scheduler timing.
//
// The two-phase split makes the snapshot explicit instead:
//
//   final capturedStateId = controller.doc.stateId;      // <- no await
//   final tree = codec.encodeToJsonTree(doc);            // <- no await
//   final bytes = await serializer(tree);                //    between
//
// `encodeToJsonTree` is synchronous, so nothing can interleave with it.
// What crosses the isolate boundary afterwards is plain
// Map/List/String/int/bool/null, which needs no property of the 30-class
// document graph to be true. `capturedStateId` is what
// `markSavedAt` receives, so the dirty flag clears for the state that was
// actually written and not for whatever the user has typed since.
//
// DO NOT COLLAPSE THIS BACK INTO ONE CALL.
import 'dart:isolate';
import 'dart:typed_data';

import 'package:rackpal_core/rackpal_core.dart';

/// Plain JSON tree in, canonical bytes out.
typedef Serializer = Future<Uint8List> Function(JsonMap tree);

/// Bytes in, plain JSON tree out — with the zip sniff and both
/// import-hardening limits already applied, so the `Err` cases are values
/// the caller branches on rather than exceptions crossing the boundary.
typedef Deserializer = Future<Outcome<JsonMap>> Function(Uint8List bytes);

/// PRODUCTION serializer: the expensive half (deep key sort, JSON encode,
/// UTF-8) off the UI thread.
Future<Uint8List> isolateSerializer(JsonMap tree) =>
    Isolate.run(() => encodeJsonTreeBytes(tree));

/// PRODUCTION deserializer.
Future<Outcome<JsonMap>> isolateDeserializer(Uint8List bytes) =>
    Isolate.run(() => parseDocumentJsonTree(bytes));

/// Synchronous serializer for tests.
///
/// Spawning forty isolates across a widget-test suite is slow and flaky,
/// and none of those forty tests is about isolates. Exactly ONE test
/// exercises [isolateSerializer] and asserts it produces byte-identical
/// output to this — that is the "the isolate really works" proof, and it
/// costs one spawn instead of forty.
Future<Uint8List> inlineSerializer(JsonMap tree) async =>
    encodeJsonTreeBytes(tree);

/// Synchronous deserializer for tests. See [inlineSerializer].
Future<Outcome<JsonMap>> inlineDeserializer(Uint8List bytes) async =>
    parseDocumentJsonTree(bytes);
