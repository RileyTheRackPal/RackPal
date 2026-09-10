// rackpal_core/src/persistence/container.dart — the `.rmpj` envelope.
//
// DR-019 §11.18.2(1): **`.rmpj` is plain pretty JSON when the document has
// no binary member, and a zip container when it has one.** The
// `PK\x03\x04` sniff `codec.dart` has carried since M0 becomes the
// discriminator it was always shaped to be, and CR-091's single-file
// property survives: a project is still one file you can email, and the
// floorplan travels inside it.
//
// ═══════════════════════════════════════════════════════════════════════
// THIS IS AN ENVELOPE, NOT A SECOND CODEC, AND THAT IS A MEASUREMENT
// ═══════════════════════════════════════════════════════════════════════
// `codec.dart`'s header predicted the container would arrive as a second
// `DocumentCodec` implementation. Censused before building it:
// `DocumentCodec.read` has exactly two callers in the whole tree and
// NEITHER IS THE APP'S OPEN PATH. `DocumentStore` reads through a
// `Deserializer` (`Isolate.run(parseDocumentJsonTree)`) and writes through
// `encodeToJsonTree` plus a serializer, deliberately, for the two-phase
// snapshot split that `apps/rackpal/lib/src/storage/serialization.dart`
// spends forty lines justifying. A container behind `DocumentCodec` would
// have been unreachable from the one gesture that opens a project.
//
// So the split is the other way round: this file turns a file's BYTES
// into "the document JSON plus its binary members", and hands the JSON
// half to the pipeline that already exists. DR-019's *"one encoder serves
// both"* falls out of that rather than being maintained by hand, because
// there is still exactly one JSON encoder and this file never calls it.
//
// ═══════════════════════════════════════════════════════════════════════
// ZIP IS NONDETERMINISTIC BY DEFAULT AND CR-117 IS THE HARD PART
// ═══════════════════════════════════════════════════════════════════════
// DR-019 §11.18.2(2) names four sources: entry order, modification
// timestamps, compression level and extra fields. **Measured against
// archive 4.0.9 rather than assumed, and it is three plus one:**
//
//   1. ENTRY ORDER is real. Two archives with the same members in a
//      different order produce different bytes. Fixed by sorting on the
//      member name.
//   2. TIMESTAMPS are real. Two `encodeBytes` calls five seconds apart
//      differ. Fixed by [kContainerTimestamp].
//      **A TEST FOR THIS THAT WAITS UNDER TWO SECONDS PASSES BY LUCK**:
//      the DOS time field has two-second granularity, so the first
//      measurement of this was a false negative until the gap was
//      widened. `container_determinism_test.dart` says so where it
//      matters.
//   3. COMPRESSION LEVEL is real, and the library default is neither 6
//      nor 9 (it is `bestSpeed`), so "leave it alone" is itself a choice
//      that a library bump can change underneath. Pinned explicitly.
//   4. EXTRA FIELDS are **already absent** in archive 4.0.9: every local
//      header this writes reports an extra-field length of zero. So there
//      is nothing to fix and something to GUARD, which is a different
//      job: the test asserts zero rather than the writer suppressing
//      them, so the day a bump starts emitting a UT or Zip64 field the
//      build fails instead of the round-trip quietly breaking.
//
// ═══════════════════════════════════════════════════════════════════════
// EVERY MEMBER IS DEFLATED, INCLUDING THE RASTERS (DR-137)
// ═══════════════════════════════════════════════════════════════════════
// THIS BLOCK SAID THE OPPOSITE UNTIL 2026-09-07, in four confident
// sentences, and measurement against the first real plan set this project
// was ever given falsified two of them.
//
// It read: *"A PNG or JPEG is already compressed; deflating it again buys
// ~nothing and costs real time at level 9 on a multi-megabyte
// architectural page."* Both halves are wrong for the input this product
// actually receives.
//
//   * **BUYS ~NOTHING: FALSE.** All 18 sheets of an ARCH D permit set
//     deflate, from 7.0% to 34.3%, mean 16.0%. **The FLOOR PLANS deflate
//     BEST**, the first-floor plan at 34.3%, because a floor plan is
//     mostly white and JPEG's entropy coding leaves that redundancy on
//     the table. The dense structural-notes sheets deflate worst.
//   * **COSTS REAL TIME: FALSE.** At this container's existing level
//     (`bestCompression`, 9) that floor plan (286,197 bytes) deflates in
//     **6.2 ms**. All 18 sheets at once is ~230 ms, and AC-006 §5 already
//     moved save to `Isolate.run`. The old sentence named level 9 as the
//     expensive case and it is the one measured here.
//
// **THE MISTAKE GENERALISES AND IT IS NOT ABOUT ZIP.** "Already-compressed
// rasters do not deflate" is a true statement about PHOTOGRAPHS and a
// false one about LINE ART ON WHITE. The rule was imported from the domain
// where it holds into the domain where it does not, and read as
// self-evident in both.
//
// ONE ARGUMENT FOR STORING SURVIVED, AND IT IS ANSWERED RATHER THAN
// IGNORED: storing made the underlay's bytes appear VERBATIM, so CR-117
// on the zip path did not depend on the deflate implementation
// reproducing the largest member exactly. **That exposure is not new.**
// `document.json` has been deflated in this same container since PLAN-B,
// so a dependency bump that moved the deflate stream already broke the
// round-trip; this widens an existing surface rather than opening one, and
// `container_identity_test.dart` fails loudly on the day it moves.
//
// A FOURTH REASON WAS ALSO GIVEN AND ARGUED FOR NOTHING: *"the file opens
// in any zip tool with the architect's original page inside it."* Every
// zip tool inflates a deflated entry, so that sentence was true either
// way and decided nothing. It is recorded because a reason that does not
// discriminate is worse than no reason: it makes a list look longer.
//
// ═══════════════════════════════════════════════════════════════════════
// A ZIP IS A DECOMPRESSION-BOMB SURFACE AND THIS FORMAT NOW HAS ONE
// ═══════════════════════════════════════════════════════════════════════
// DR-015 §11.15.4 chose a single JSON file for `.rmda` precisely because
// "the zip buys only a decompression-bomb surface". DR-019 buys that
// surface here deliberately, so this file owes the bound that ruling
// avoided needing.
//
// AC-058/D8's rule is BOUND IT BEFORE YOU READ IT, and the existing caps
// cannot do it: `checkJsonLimits` runs on `document.json`'s bytes, which
// only exist AFTER the inflate. A one-megabyte `.rmpj` whose member
// declares ten gigabytes would exhaust memory before any of them ran.
//
// So [readContainerParts] checks the central directory first, where every
// entry's uncompressed size is declared and nothing has been inflated
// yet. WHAT THAT DOES AND DOES NOT COVER, stated rather than implied: it
// refuses the classic bomb outright, because a bomb has to declare its
// size to be inflatable. It does NOT cover a header that LIES about its
// size, so the read loop also keeps a running total of what actually came
// out and stops at the first member that breaks it. That costs one bad
// member's memory and no more, which is the best a streaming-free reader
// can promise, and saying so beats implying the first check is the whole
// answer.
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:rackpal_core/src/persistence/codec.dart';
import 'package:rackpal_core/src/persistence/json_limits.dart';
import 'package:rackpal_core/src/util/outcome.dart';

/// The member every `.rmpj` container holds, at the root.
///
/// Its bytes are **byte-for-byte what the plain-JSON path would have
/// written** (DR-019 §11.18.2(2)), which is what makes the two shapes one
/// format rather than two.
const String kDocumentMember = 'document.json';

/// The directory prefix underlay members live under, `underlays/<id>.png`
/// (docs/15 §2).
const String kUnderlayMemberDir = 'underlays/';

/// The directory prefix a rendered underlay's SOURCE PDF lives under,
/// `sources/<id>.pdf` (DR-153 §11.152.6).
///
/// Its own prefix rather than a sibling in `underlays/`, because the two
/// hold different things: one is what the sheet draws and the other is
/// what it was drawn FROM. A reader listing the container can tell them
/// apart without opening either.
const String kPlanSourceMemberDir = 'sources/';

/// The constant every entry's modification time is written with.
///
/// The MS-DOS epoch, which is the conventional reproducible-build choice
/// and the earliest value the zip time field can express: a smaller one
/// would be silently clamped, which is a determinism bug that looks like
/// a working constant.
final DateTime kContainerTimestamp = DateTime.utc(1980);

/// The deflate level every compressed member is written at.
///
/// Pinned rather than defaulted. `archive`'s own default is `bestSpeed`
/// and differs byte-for-byte from both 6 and 9, so accepting the default
/// would make this project's file format a function of a dependency's
/// unstated preference.
const int kContainerDeflateLevel = DeflateLevel.bestCompression;

/// The most entries a `.rmpj` container may hold.
///
/// A project is one `document.json` plus one underlay per floor. Sixty
/// four is an order of magnitude past the largest building anybody has
/// described, and small enough that a zip of a photo library is refused
/// on the count alone, before its sizes are even added up.
const int kMaxContainerMembers = 64;

/// The most total uncompressed bytes a `.rmpj` container may declare.
///
/// Four times [kMaxDocumentBytes], which is the room a 64 MB document
/// plus several architectural pages needs, and far below the ratios a
/// bomb depends on: the classic 42.zip declares petabytes.
const int kMaxContainerInflatedBytes = 4 * kMaxDocumentBytes;

/// The two container caps, injectable so a test can prove they fire
/// without building a fixture the size of the cap. That is `JsonLimits`'s
/// own reason, one layer out.
final class ContainerLimits {
  const ContainerLimits({
    this.maxMembers = kMaxContainerMembers,
    this.maxInflatedBytes = kMaxContainerInflatedBytes,
  });

  /// Refuse an archive declaring more entries than this.
  final int maxMembers;

  /// Refuse an archive whose entries declare more total uncompressed
  /// bytes than this.
  final int maxInflatedBytes;
}

/// The archive declares more members, or more inflated bytes, than
/// [ContainerLimits] allows.
///
/// Its own error rather than [DocumentTooLargeError] because the number
/// that matters is what the file CLAIMS it will become and not what it
/// currently weighs. A message conflating the two sends somebody looking
/// at a one-megabyte file wondering why it is too large.
final class ContainerTooLargeError implements Exception {
  const ContainerTooLargeError({
    required this.members,
    required this.declaredBytes,
    required this.memberLimit,
    required this.byteLimit,
  });

  final int members;
  final int declaredBytes;
  final int memberLimit;
  final int byteLimit;

  @override
  String toString() =>
      'ContainerTooLargeError: the archive declares $members member(s) and '
      '$declaredBytes uncompressed bytes, against limits of $memberLimit '
      'and $byteLimit.';
}

/// A `.rmpj` file's bytes, split into the two halves the rest of the
/// persistence layer deals in.
final class ContainerParts {
  const ContainerParts({required this.documentBytes, required this.members});

  /// The plain-JSON document bytes, whichever shape they arrived in.
  final Uint8List documentBytes;

  /// The binary members that travelled with it, keyed by member path and
  /// **excluding** [kDocumentMember]. Empty for a plain-JSON file, which
  /// is every file this project has written to date.
  final Map<String, Uint8List> members;

  /// True when the bytes were a zip container carrying at least one
  /// binary member.
  bool get hasMembers => members.isNotEmpty;
}

/// The bytes sniffed as a zip and yielded no usable archive.
///
/// Distinct from [ContainerMissingDocumentError] because they are
/// different sentences AND different remedies to a user: this one is
/// "the archive is damaged", which is when a `.bak` is worth offering,
/// and that one is "the archive is fine and is not a project", which is
/// when offering one would be noise.
///
/// ═══════════════════════════════════════════════════════════════════════
/// A TRUNCATED ZIP DOES NOT THROW. IT DECODES TO NOTHING.
/// ═══════════════════════════════════════════════════════════════════════
/// Measured against archive 4.0.9 rather than assumed, because the
/// assumption was wrong and would have shipped this state with no
/// producer at all. `ZipDecoder.decodeBytes` reads the central directory,
/// which lives at the END of the file, so a truncated archive simply has
/// none: it returns an EMPTY `Archive` and throws nothing. Cut at 10%,
/// 25%, 50%, 75%, 90% and 99%, all six decoded "successfully" with zero
/// entries, as did a file that was nothing but the four signature bytes.
///
/// **So ZERO ENTRIES is the signature of damage, and the thrown-exception
/// arm below is the belt-and-braces one rather than the main path.** Had
/// this been written from the exception, every truncated project would
/// have reported "this is not a RackPal project" and been refused the
/// backup that would have rescued it.
final class ContainerUnreadableError implements Exception {
  const ContainerUnreadableError(this.detail);

  /// What went wrong, in a form the file-layer copy can show.
  final String detail;

  @override
  String toString() =>
      'ContainerUnreadableError: the file begins with the ZIP signature '
      'but yielded no usable archive ($detail).';
}

/// A readable zip with no [kDocumentMember] at its root.
///
/// Every zip is a candidate `.rmpj` now that the sniff is a branch, so
/// this is the state a `.docx`, a `.zip` of holiday photographs and a
/// truncated project all land in.
final class ContainerMissingDocumentError implements Exception {
  const ContainerMissingDocumentError(this.members);

  /// The member names that WERE present, so the message can say what the
  /// file appears to be instead of only what it is not.
  final List<String> members;

  @override
  String toString() =>
      'ContainerMissingDocumentError: this zip archive has no '
      '"$kDocumentMember" at its root, so it is not a RackPal project. '
      'It holds ${members.length} member(s).';
}

/// Splits a `.rmpj` file's [bytes] into its document JSON and its binary
/// members.
///
/// **Never throws** (CR-093): a foreign zip, a truncated archive and a
/// member that will not decompress all come back as an [Err].
///
/// A file that does not sniff as a zip is returned unchanged as the
/// document half with no members, so **the plain path costs one four-byte
/// comparison and no copy**, which is what keeps this safe to put in front
/// of every open.
Outcome<ContainerParts> readContainerParts(
  Uint8List bytes, {
  ContainerLimits limits = const ContainerLimits(),
}) {
  if (!looksLikeZip(bytes)) {
    return Ok(ContainerParts(documentBytes: bytes, members: const {}));
  }

  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
    // `on Object`, NOT `on Exception`, for `parseDocumentJsonTree`'s
    // reason one layer out: a truncated central directory can raise a
    // `RangeError`, which is an Error, and an Error escaping here reaches
    // the user as Ctrl+O doing nothing at all.
  } on Object catch (e) {
    return Err(ContainerUnreadableError(e.toString()));
  }

  // AN EMPTY ARCHIVE IS A DAMAGED ONE. See
  // [ContainerUnreadableError]: this is the arm a truncated project
  // actually takes, and the exception above is the one it does not.
  if (archive.isEmpty) {
    return const Err(
      ContainerUnreadableError(
        'the archive contains no entries, which is what a file truncated '
        'before its central directory looks like',
      ),
    );
  }

  // ---- BOUND IT BEFORE READING IT (AC-058/D8). ------------------------
  // Every number here comes from the central directory, so this runs with
  // nothing inflated and no member-sized allocation made.
  var declared = 0;
  var count = 0;
  for (final file in archive) {
    if (!file.isFile) continue;
    count++;
    declared += file.size;
    if (count > limits.maxMembers || declared > limits.maxInflatedBytes) {
      return Err(
        ContainerTooLargeError(
          members: count,
          declaredBytes: declared,
          memberLimit: limits.maxMembers,
          byteLimit: limits.maxInflatedBytes,
        ),
      );
    }
  }

  Uint8List? documentBytes;
  final members = <String, Uint8List>{};
  var inflated = 0;
  try {
    for (final file in archive) {
      if (!file.isFile) continue;
      final content = file.readBytes();
      if (content == null) continue;
      // A HEADER CAN LIE, so the running total is over what actually came
      // out. Checked after each member rather than at the end, so a bomb
      // costs one member's memory instead of the whole archive's.
      inflated += content.length;
      if (inflated > limits.maxInflatedBytes) {
        return Err(
          ContainerTooLargeError(
            members: count,
            declaredBytes: inflated,
            memberLimit: limits.maxMembers,
            byteLimit: limits.maxInflatedBytes,
          ),
        );
      }
      final data = Uint8List.fromList(content);
      if (file.name == kDocumentMember) {
        documentBytes = data;
      } else {
        members[file.name] = data;
      }
    }
  } on Object catch (e) {
    return Err(ContainerUnreadableError(e.toString()));
  }

  if (documentBytes == null) {
    return Err(
      ContainerMissingDocumentError(archive.map((f) => f.name).toList()),
    );
  }
  return Ok(
    ContainerParts(
      documentBytes: documentBytes,
      members: Map.unmodifiable(members),
    ),
  );
}

/// Wraps [documentBytes] and [members] into the bytes of a `.rmpj` file.
///
/// **Returns [documentBytes] UNCHANGED when [members] is empty**, which is
/// DR-019 §11.18.2(1)'s *"a document with no underlay writes bytes
/// identical to today's"* expressed as an identity rather than as a
/// promise. Every existing project file, every golden and all four
/// starters take this arm, and `container_identity_test.dart`
/// proves it over the checked-in corpus rather than over a fixture.
///
/// Not fallible, matching `DocumentCodec.write`: it only ever runs over
/// bytes and members this package produced.
Uint8List writeContainerBytes(
  Uint8List documentBytes,
  Map<String, Uint8List> members,
) {
  if (members.isEmpty) return documentBytes;

  final archive = Archive();
  // ENTRY ORDER IS ONE OF THE FOUR. Sorted by member name, so the same
  // members in any iteration order produce the same file. `document.json`
  // sorts before `underlays/` anyway; the sort is what makes that a
  // guarantee rather than a coincidence of the alphabet.
  final names = <String>[kDocumentMember, ...members.keys]..sort();
  for (final name in names) {
    final data = name == kDocumentMember ? documentBytes : members[name]!;
    // NO PER-MEMBER COMPRESSION OVERRIDE (DR-137). Every entry takes
    // `kContainerDeflateLevel`, including the rasters. The old arm set
    // `CompressionType.none` for anything that was not `document.json`,
    // on a size claim that measurement disproved. See the file header.
    archive.add(ArchiveFile.bytes(name, data));
  }

  return ZipEncoder().encodeBytes(
    archive,
    level: kContainerDeflateLevel,
    modified: kContainerTimestamp,
  );
}
