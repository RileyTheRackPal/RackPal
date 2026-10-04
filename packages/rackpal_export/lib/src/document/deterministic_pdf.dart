// rackpal_export/lib/src/document/deterministic_pdf.dart -- docs/08 §8.4's
// "two exports of an unmodified project differ only in the date field",
// made true of the FILE and not only of the drawing (M6-I5, `#356`).
//
// =====================================================================
// THE PINNED `pdf` WRITES TWO THINGS NOBODY ASKED FOR
// =====================================================================
// `pdf` 3.13.0 puts `sha256(DateTime.now() + Random.secure())` in the
// trailer's `/ID` and the wall clock in the Info dictionary's
// `/CreationDate`, and exposes neither. Until this file the claim was
// narrowed to the drawn content, and a test asserted the files differed so
// the limit stayed visible. Measured on Apartment: two exports at one
// `issuedAt` differ in exactly 125 bytes, all of them inside those two
// tokens.
//
// =====================================================================
// REWRITTEN IN PLACE, AT THE SAME LENGTH
// =====================================================================
// Both tokens have a fixed width (`D:` + fourteen digits + `Z`, and two
// 64-hex strings), so they are overwritten byte for byte: no offset in the
// cross-reference table moves, and the file stays valid without being
// re-serialised. `/CreationDate` becomes the export's own `issuedAt`, the
// one clock §8.4 allows. `/ID` becomes a hash of the file with the ID
// zeroed, which is what an ID is for (ISO 32000 §14.4: computed from the
// file's contents): the same document gives the same ID, a different one
// a different ID.
//
// A FILE THE PATTERNS DO NOT MATCH IS RETURNED UNTOUCHED. A future `pdf`
// that writes either token differently is not broken by this, and
// `export_determinism_test.dart` asserts identical files, so the day the
// format moves is the day that test goes red rather than the day a
// rewrite corrupts a deliverable.
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

final RegExp _creationDate = RegExp(r'/CreationDate\(D:(\d{14})Z\)');
final RegExp _id = RegExp(r'/ID\[<([0-9a-fA-F]{64})><([0-9a-fA-F]{64})>\]');

/// [pdf] with its creation date set to [issuedAt] and its ID derived from
/// its contents, at the same length; [pdf] itself when either token is not
/// found exactly once.
Uint8List deterministicPdfBytes(Uint8List pdf, {required DateTime issuedAt}) {
  // LATIN-1 IS A BYTE-FOR-BYTE VIEW: one char per byte, both ways, so the
  // binary streams between the tokens survive the round trip untouched.
  final text = latin1.decode(pdf);
  final dates = _creationDate.allMatches(text).toList();
  final ids = _id.allMatches(text).toList();
  if (dates.length != 1 || ids.length != 1) return pdf;

  final out = Uint8List.fromList(pdf);
  _overwrite(
    out,
    dates.single.start + '/CreationDate(D:'.length,
    _stamp(issuedAt),
  );

  final id = ids.single;
  final first = id.start + '/ID[<'.length;
  final second = first + 64 + '><'.length;
  final zero = '0' * 64;
  _overwrite(out, first, zero);
  _overwrite(out, second, zero);
  final digest = sha256.convert(out).toString();
  _overwrite(out, first, digest);
  _overwrite(out, second, digest);
  return out;
}

/// `yyyyMMddHHmmss` in UTC, the fourteen digits the token holds.
String _stamp(DateTime at) {
  final u = at.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${u.year.toString().padLeft(4, '0')}${two(u.month)}${two(u.day)}'
      '${two(u.hour)}${two(u.minute)}${two(u.second)}';
}

void _overwrite(Uint8List bytes, int at, String ascii) {
  for (var i = 0; i < ascii.length; i++) {
    bytes[at + i] = ascii.codeUnitAt(i);
  }
}
