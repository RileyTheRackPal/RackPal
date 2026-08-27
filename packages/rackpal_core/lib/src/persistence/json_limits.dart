// Import hardening (docs/03-architecture.md §9.5: "Import hardening
// applies to every import path: JSON depth and size limits").
//
// WHY THIS LIVES IN CORE AND NOT IN THE APP. Core's contract is
// bytes <-> document; this file is bytes in, verdict out. It opens no
// file, joins no path and names no directory, so it stays inside the
// pure-Dart boundary (D1) while being the thing every read path — file,
// and one day a blob store or an HTTP body — must run first.
//
// WHY A HAND-WRITTEN DEPTH SCAN — with the reasoning corrected against
// what was actually MEASURED on this machine, because the obvious story
// is wrong and the real one is worse.
//
// The obvious story is "jsonDecode overflows the stack on deep input".
// It does not. Measured: `jsonDecode` parsed 1 000 000 nested objects
// without complaint. Dart's JSON parser is iterative.
//
// The danger is on the WRITE side, one save later, and being delayed is
// what makes it nastier:
//
//   * a deeply-nested map this reader does not model SURVIVES into
//     `RackDocument.unknown`, because the format's forward-compat rule
//     (G4) is to preserve unknown fields and re-emit them;
//   * the next `write()` runs `deepSortKeys` and `JsonEncoder`, both of
//     which ARE recursive. Measured: both threw `StackOverflowError` at
//     10 000 levels of nesting;
//   * `StackOverflowError` is an `Error`, not an `Exception`, so the
//     `on Exception catch` guards throughout this package walk straight
//     past it — and `DocumentCodec.write` is documented as non-fallible
//     and catches nothing at all. In production that Error escapes the
//     serializer isolate and the user's SAVE dies, unexplained, on a file
//     they opened successfully an hour earlier.
//
// So this cap is not protecting the parser. It refuses, at OPEN time and
// with a sentence the user can act on, a document that would otherwise
// detonate at SAVE time inside an isolate. Checking before `jsonDecode`
// rather than after is simply cheaper — a scan that stops at the first
// offending bracket never allocates the tree at all.
//
// `json_limits_test.dart`'s "THE FAILURE THE DEPTH CAP ACTUALLY
// PREVENTS" group is those three measurements, written down so a future
// Dart release that changes any of them fails here rather than in the
// field.
//
// SCANNING RAW BYTES IS SAFE FOR UTF-8. Every byte of a multi-byte UTF-8
// sequence has its high bit set (>= 0x80), so a `{`, `[`, `"` or `\`
// byte can only ever be that ASCII character and never a fragment of
// some other code point. The scan therefore needs no decode pass, which
// also means a 64 MB file is rejected for size before anything allocates
// a 64 MB String.
import 'dart:typed_data';

import 'package:rackpal_core/src/util/outcome.dart';

/// ~100x the AC-006 ~600 KB budget and ~20x the 3 MB hard cap
/// (docs/03-architecture.md §11.1). Deliberately generous: this limit
/// exists to stop a hostile or mistaken file from exhausting memory, not
/// to enforce the performance budget, which has its own (soft) gates.
const int kMaxDocumentBytes = 64 * 1024 * 1024;

/// The real format's deepest nesting is about 8 (`root` / `document` /
/// `devices` / one uuid key / `placement` / ...). 64 leaves a full order
/// of magnitude of headroom for a future schema while sitting two orders
/// of magnitude BELOW the ~10 000 at which the recursive encoder was
/// measured to overflow.
const int kMaxJsonDepth = 64;

/// The two import-hardening caps, injectable so a test can prove the
/// gate fires without building a 64 MB fixture.
final class JsonLimits {
  const JsonLimits({
    this.maxBytes = kMaxDocumentBytes,
    this.maxDepth = kMaxJsonDepth,
  });

  /// Refuse a document larger than this many bytes.
  final int maxBytes;

  /// Refuse a document whose JSON nests deeper than this.
  final int maxDepth;
}

/// The candidate document exceeds [JsonLimits.maxBytes].
final class DocumentTooLargeError implements Exception {
  const DocumentTooLargeError({required this.bytes, required this.limit});

  final int bytes;
  final int limit;

  @override
  String toString() =>
      'DocumentTooLargeError: $bytes bytes exceeds the $limit byte limit.';
}

/// The candidate document nests deeper than [JsonLimits.maxDepth].
///
/// [depth] is the depth at which the scan gave up, which is
/// `limit + 1` — the scan stops at the first offending bracket rather
/// than reading the rest of a file it has already refused. It is
/// reported anyway so the error is self-describing.
final class JsonTooDeeplyNestedError implements Exception {
  const JsonTooDeeplyNestedError({required this.depth, required this.limit});

  final int depth;
  final int limit;

  @override
  String toString() =>
      'JsonTooDeeplyNestedError: nesting reached depth $depth, which '
      'exceeds the $limit level limit.';
}

const int _quote = 0x22; // "
const int _backslash = 0x5C; // \
const int _openBrace = 0x7B; // {
const int _closeBrace = 0x7D; // }
const int _openBracket = 0x5B; // [
const int _closeBracket = 0x5D; // ]

/// Runs both import-hardening caps over [bytes], BEFORE any `jsonDecode`.
///
/// Never throws (CR-093). Returns `Ok(null)` when [bytes] is within
/// limits, or `Err` carrying [DocumentTooLargeError] /
/// [JsonTooDeeplyNestedError].
Outcome<void> checkJsonLimits(
  Uint8List bytes, {
  JsonLimits limits = const JsonLimits(),
}) {
  if (bytes.length > limits.maxBytes) {
    return Err(
      DocumentTooLargeError(bytes: bytes.length, limit: limits.maxBytes),
    );
  }
  final depth = scanMaxJsonDepth(bytes, stopAt: limits.maxDepth + 1);
  if (depth > limits.maxDepth) {
    return Err(
      JsonTooDeeplyNestedError(depth: depth, limit: limits.maxDepth),
    );
  }
  return const Ok<void>(null);
}

/// The maximum `{`/`[` nesting depth in [bytes], counting only brackets
/// OUTSIDE string literals and honouring backslash escapes — so
/// `{"a": "}}}}"}` is depth 1, not depth 1 followed by four spurious
/// closes.
///
/// Stops and returns as soon as the depth reaches [stopAt], so a
/// pathological file costs only as many bytes as it takes to prove it is
/// pathological. Pass `null` to scan the whole input.
///
/// Unbalanced input is not this function's problem — `jsonDecode` is the
/// authority on well-formedness and reports it properly. A stray `}` in
/// malformed JSON simply drives the running depth negative, which is
/// clamped to 0 so it cannot mask a subsequent real nesting run.
int scanMaxJsonDepth(Uint8List bytes, {int? stopAt}) {
  var depth = 0;
  var maxDepth = 0;
  var inString = false;
  var escaped = false;

  for (var i = 0; i < bytes.length; i++) {
    final b = bytes[i];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (b == _backslash) {
        escaped = true;
      } else if (b == _quote) {
        inString = false;
      }
      continue;
    }
    if (b == _quote) {
      inString = true;
    } else if (b == _openBrace || b == _openBracket) {
      depth++;
      if (depth > maxDepth) {
        maxDepth = depth;
        if (stopAt != null && maxDepth >= stopAt) return maxDepth;
      }
    } else if (b == _closeBrace || b == _closeBracket) {
      if (depth > 0) depth--;
    }
  }
  return maxDepth;
}
