// rackpal_core/src/structure/csv_mapping.dart — pure Dart.
//
// WHERE EACH SOURCE COLUMN GOES. Board M3-F/6 (#652), docs/07 §5.1.
//
// ═════════════════════════════════════════════════════════════════════
// THIS IS THE MODEL THE MANUAL ASSIGN STEP BINDS TO
// ═════════════════════════════════════════════════════════════════════
// docs/07 §5.1: "Every source header appears in a column-mapping sheet
// with RackPal's guess and a dropdown to correct it." [CsvMapping] is
// that sheet's state. It is immutable and [CsvMapping.withAssignment]
// returns a new one, so the surface can re-render a preview against any
// candidate mapping without committing to it, which is what makes the
// one-dialog live preview possible.
//
// ═════════════════════════════════════════════════════════════════════
// THERE IS NO "IGNORE THIS COLUMN", AND THAT IS A DECISION
// ═════════════════════════════════════════════════════════════════════
// A dropdown offering "discard" is the obvious third option and it is
// refused. §5.1 is unconditional: unmapped columns "are preserved into
// the row's `unknown` map and surfaced as optional grid columns, user
// data is never discarded (canon §4.2, forward-compat)". The `unknown`
// map is the forward-compatibility mechanism the whole document format
// is built on; a kept column costs one key in it.
//
// What discarding buys is one fewer optional grid column. What it costs
// is a way to lose a column that a RE-IMPORT CANNOT RECOVER, because
// §5.3's dedup updates the rows it matches and never restores a field
// nobody imported. An operator who does not want to look at a column
// can not look at it. If a shop genuinely needs the option, it is a
// ruling and this comment is where the reader should arrive.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/model/registries.dart';
import 'package:rackpal_core/src/structure/csv_header_map.dart';
import 'package:rackpal_core/src/structure/csv_reader.dart';
import 'package:rackpal_core/src/structure/drop_line_planner.dart'
    show resolveMediaToken;
import 'package:rackpal_core/src/units/ids.dart';

/// What one source column's values become.
sealed class CsvColumnAssignment {
  const CsvColumnAssignment();
}

/// The column feeds one of §5.1's canonical targets.
@immutable
final class CsvColumnMapped extends CsvColumnAssignment {
  const CsvColumnMapped(this.target);
  final CsvColumnTarget target;

  @override
  bool operator ==(Object other) =>
      other is CsvColumnMapped && other.target == target;

  @override
  int get hashCode => target.hashCode;
}

/// WIDE SHAPE ONLY: the column's cells are how many of one cable the
/// row's room gets.
///
/// Not a [CsvColumnMapped] to [CsvColumnTarget.media], and the
/// difference is the whole of what "wide" means. A long sheet's media
/// column says which cable THIS ROW is; a wide sheet's media column says
/// how many of one cable this row's ROOM gets, so one row becomes
/// several drops of several types.
@immutable
final class CsvColumnMediaCount extends CsvColumnAssignment {
  const CsvColumnMediaCount(this.media);
  final MediaTypeId media;

  @override
  bool operator ==(Object other) =>
      other is CsvColumnMediaCount && other.media == media;

  @override
  int get hashCode => media.hashCode;
}

/// The column is preserved into each row's `unknown` map under
/// [CsvMapping.unknownKeyFor].
///
/// THE DEFAULT, and the only thing that happens to a column no target
/// claims. See this file's header for why there is no third option.
@immutable
final class CsvColumnKept extends CsvColumnAssignment {
  const CsvColumnKept();

  @override
  bool operator ==(Object other) => other is CsvColumnKept;

  @override
  int get hashCode => 0;
}

/// What is wrong with a mapping.
enum CsvMappingProblemKind {
  /// Two columns claim one canonical target. BLOCKING.
  duplicateTarget,

  /// §5.1's `Req.` column is not satisfied. BLOCKING.
  missingRequired,

  /// A `qty` column in a wide sheet. NOT blocking: the counts are the
  /// cells of the media columns, so this one has nothing to multiply and
  /// is preserved rather than obeyed.
  quantityInWideShape,
}

@immutable
final class CsvMappingProblem {
  const CsvMappingProblem({
    required this.kind,
    required this.message,
    this.columns = const [],
  });

  final CsvMappingProblemKind kind;

  /// One sentence, already written for a human.
  final String message;

  /// Source column indexes this is about, so the sheet can mark the
  /// rows a person has to touch.
  final List<int> columns;

  /// Whether the import may proceed with this outstanding.
  ///
  /// **A BLOCKING MAPPING PROBLEM IS NOT "FAIL-FAST".** §5.3's rule is
  /// that no ROW is rejected, and it is kept: nothing has been parsed
  /// away and every cell is still on screen. A sheet with no room
  /// column has not said where anything goes, and the fix is one
  /// dropdown in the surface already open.
  bool get blocks => kind != CsvMappingProblemKind.quantityInWideShape;
}

/// One assignment per source column, plus the shape they were chosen
/// for.
@immutable
final class CsvMapping {
  const CsvMapping({
    required this.headers,
    required this.assignments,
    required this.shape,
  });

  /// RackPal's guess for every column, per docs/07 §5.1.
  ///
  /// The guess is [matchCsvHeader] and nothing else. It never widens the
  /// table, never falls back to a substring and never learns; a header
  /// the table does not carry becomes [CsvColumnKept], which is the
  /// manual assign step's whole input (RJ-004).
  factory CsvMapping.guess({
    required CsvTable table,
    required CsvShapeDetection detection,
    required Registries registries,
  }) {
    final wide = detection.shape == CsvShape.wide;
    final mediaColumns = wide ? detection.mediaColumns.toSet() : const <int>{};
    final claimed = <CsvColumnTarget>{};
    final out = <CsvColumnAssignment>[];

    for (var n = 0; n < table.headers.length; n++) {
      if (mediaColumns.contains(n)) {
        final def = resolveMediaToken(registries, table.headers[n]);
        // Non-null by construction: `detectCsvShape` put this index in
        // `mediaColumns` because the same resolver answered for it.
        out.add(
          def == null ? const CsvColumnKept() : CsvColumnMediaCount(def.id),
        );
        continue;
      }
      final target = matchCsvHeader(table.headers[n]);
      // FIRST COLUMN WINS A CONTESTED TARGET, and the loser becomes a
      // kept column rather than a silent overwrite. Two headers reading
      // `Notes` is a real export; guessing both onto one field would
      // make the second quietly win, which is the outcome the mapping
      // sheet exists to make visible.
      if (target == null || claimed.contains(target)) {
        out.add(const CsvColumnKept());
        continue;
      }
      claimed.add(target);
      out.add(CsvColumnMapped(target));
    }

    return CsvMapping(
      headers: List.unmodifiable(table.headers),
      assignments: List.unmodifiable(out),
      shape: detection.shape,
    );
  }

  /// Source headers, as typed, parallel to [assignments].
  final List<String> headers;

  final List<CsvColumnAssignment> assignments;

  final CsvShape shape;

  /// The same mapping with one column reassigned.
  ///
  /// **DOES NOT UNCLAIM THE TARGET FROM WHOEVER HELD IT**, deliberately.
  /// Silently demoting the other column to kept would move a row of the
  /// sheet the operator was not looking at. The conflict is reported by
  /// [problems] instead, which is the surface's to show and theirs to
  /// resolve.
  CsvMapping withAssignment(int column, CsvColumnAssignment assignment) {
    final next = List<CsvColumnAssignment>.of(assignments);
    next[column] = assignment;
    return CsvMapping(
      headers: headers,
      assignments: List.unmodifiable(next),
      shape: shape,
    );
  }

  /// The same mapping read as the other shape, with the guess redone for
  /// the columns whose meaning depends on it.
  CsvMapping asShape(
    CsvShape other, {
    required CsvTable table,
    required Registries registries,
  }) {
    if (other == shape) return this;
    return CsvMapping.guess(
      table: table,
      detection: other == CsvShape.wide
          ? CsvShapeDetection(
              shape: CsvShape.wide,
              mediaColumns: [
                for (var n = 0; n < headers.length; n++)
                  if (resolveMediaToken(registries, headers[n]) != null) n,
              ],
              reason: 'Chosen by hand.',
            )
          : const CsvShapeDetection(
              shape: CsvShape.long,
              mediaColumns: [],
              reason: 'Chosen by hand.',
            ),
      registries: registries,
    );
  }

  /// The single column feeding [target], or null.
  ///
  /// Null when no column claims it AND when more than one does, because
  /// a reader that took the first of two would be resolving a conflict
  /// [problems] has already declared blocking.
  int? columnFor(CsvColumnTarget target) {
    final matches = [
      for (var n = 0; n < assignments.length; n++)
        if (assignments[n] case CsvColumnMapped(
          target: final t,
        ) when t == target)
          n,
    ];
    return matches.length == 1 ? matches.single : null;
  }

  /// Every wide-shape cable column, in source order.
  List<({int column, MediaTypeId media})> get mediaCountColumns => [
    for (var n = 0; n < assignments.length; n++)
      if (assignments[n] case CsvColumnMediaCount(:final media))
        (column: n, media: media),
  ];

  /// Every column preserved into `unknown`, in source order.
  List<int> get keptColumns => [
    for (var n = 0; n < assignments.length; n++)
      if (assignments[n] is CsvColumnKept) n,
  ];

  /// The `unknown` map key column [column] writes under.
  ///
  /// **THE HEADER, MADE UNIQUE AND NEVER EMPTY.** Two columns both
  /// reading `Notes` would otherwise collide in one map and the second
  /// would win silently, and a blank header would write under `''`. Both
  /// are resolved by appending the 1-based column number, and only for
  /// the columns that need it, so an ordinary sheet's keys are exactly
  /// its headers. The rule is deterministic because CR-117 compares
  /// bytes and a key chosen by iteration order would not round-trip.
  String unknownKeyFor(int column) {
    final raw = headers[column].trim();
    if (raw.isEmpty) return 'column ${column + 1}';
    final firstWithThisHeader = headers.indexWhere((h) => h.trim() == raw);
    return firstWithThisHeader == column ? raw : '$raw (${column + 1})';
  }

  /// §5.1's `Req.` column for [shape].
  ///
  /// `media` is required in the LONG shape only: a wide sheet carries
  /// media in its headers, which is what makes it a different shape
  /// rather than a different parser.
  Set<CsvColumnTarget> get requiredTargets => shape == CsvShape.wide
      ? const {CsvColumnTarget.location}
      : kRequiredLongShapeTargets;

  /// Everything wrong with this mapping, in a stable order.
  List<CsvMappingProblem> get problems {
    final out = <CsvMappingProblem>[];

    final byTarget = <CsvColumnTarget, List<int>>{};
    for (var n = 0; n < assignments.length; n++) {
      if (assignments[n] case CsvColumnMapped(:final target)) {
        (byTarget[target] ??= []).add(n);
      }
    }

    for (final target in CsvColumnTarget.values) {
      final columns = byTarget[target];
      if (columns == null || columns.length < 2) continue;
      final names = columns.map((n) => '"${headers[n]}"').join(' and ');
      out.add(
        CsvMappingProblem(
          kind: CsvMappingProblemKind.duplicateTarget,
          message:
              '$names both map to ${target.name}. Pick one; the other '
              'can be kept as an extra column.',
          columns: columns,
        ),
      );
    }

    for (final target in requiredTargets) {
      if (byTarget[target] != null) continue;
      out.add(
        CsvMappingProblem(
          kind: CsvMappingProblemKind.missingRequired,
          message:
              'No column says ${target.name}, and an import cannot '
              'proceed without one.',
        ),
      );
    }

    if (shape == CsvShape.wide) {
      final qty = byTarget[CsvColumnTarget.qty];
      if (qty != null) {
        out.add(
          CsvMappingProblem(
            kind: CsvMappingProblemKind.quantityInWideShape,
            message:
                '"${headers[qty.first]}" is a quantity, but in this '
                'shape the cable columns already carry the counts. It will '
                'be kept as an extra column instead.',
            columns: qty,
          ),
        );
      }
    }

    return out;
  }

  /// Whether an import may be planned from this mapping.
  bool get isComplete => !problems.any((p) => p.blocks);
}
