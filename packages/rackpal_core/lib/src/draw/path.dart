// docs/08-pdf-export.md §8.3: "There is no drawSvgPath. Authored
// connector-symbol d strings are parsed once, at catalog load, by
// DiagramPath.fromSvg(String d), and both backends then draw the
// resulting DiagramPath through drawPath." A backend that parses SVG
// strings itself is a backend that can disagree with the other one —
// exactly what CR-086 exists to prevent — so all parsing happens here,
// once, and both `PdfDiagramCanvas`/`FlutterDiagramCanvas` only ever see
// the already-parsed [PathCommand] list.

import 'package:meta/meta.dart';
import 'package:rackpal_core/src/draw/geometry.dart';

/// One verb in a [DiagramPath]. Coordinates are diagram-space doubles
/// (see `geometry.dart`'s file header) and, for relative SVG commands,
/// already resolved to ABSOLUTE coordinates by [DiagramPath.fromSvg] — a
/// `DiagramPath`'s commands are always absolute, regardless of how the
/// source `d` string spelled them.
sealed class PathCommand {
  const PathCommand();
}

/// `M`/`m` — move the current point without drawing.
@immutable
final class MoveTo extends PathCommand {
  const MoveTo(this.x, this.y);

  final double x;
  final double y;

  @override
  bool operator ==(Object other) =>
      other is MoveTo && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(MoveTo, x, y);

  @override
  String toString() => 'MoveTo($x, $y)';
}

/// `L`/`l` — a straight line from the current point.
@immutable
final class LineTo extends PathCommand {
  const LineTo(this.x, this.y);

  final double x;
  final double y;

  @override
  bool operator ==(Object other) =>
      other is LineTo && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(LineTo, x, y);

  @override
  String toString() => 'LineTo($x, $y)';
}

/// `C`/`c` — a cubic Bezier from the current point, through control
/// points `(x1,y1)`/`(x2,y2)`, ending at `(x3,y3)`. Needed for
/// `drawRoundRect`'s kappa corners (docs/08-pdf-export.md §7.7's note:
/// "Kappa is 0.5522847498307933 on both sides").
@immutable
final class CubicTo extends PathCommand {
  const CubicTo(this.x1, this.y1, this.x2, this.y2, this.x3, this.y3);

  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final double x3;
  final double y3;

  @override
  bool operator ==(Object other) =>
      other is CubicTo &&
      other.x1 == x1 &&
      other.y1 == y1 &&
      other.x2 == x2 &&
      other.y2 == y2 &&
      other.x3 == x3 &&
      other.y3 == y3;

  @override
  int get hashCode => Object.hash(CubicTo, x1, y1, x2, y2, x3, y3);

  @override
  String toString() => 'CubicTo($x1, $y1, $x2, $y2, $x3, $y3)';
}

/// `Z`/`z` — close the current subpath back to its starting point.
@immutable
final class ClosePath extends PathCommand {
  const ClosePath();

  @override
  bool operator ==(Object other) => other is ClosePath;

  @override
  int get hashCode => (ClosePath).hashCode;

  @override
  String toString() => 'ClosePath()';
}

/// The kappa constant for approximating a quarter circle with a cubic
/// Bezier — used by scene-builder code (not this file) when constructing
/// rounded-corner `DiagramPath`s. Recorded here, next to `CubicTo`,
/// because it is the reason `CubicTo` exists at all in a v1 that
/// otherwise draws only straight-edged furniture.
const double kappa = 0.5522847498307933;

/// A parsed, backend-agnostic vector path: a flat list of [PathCommand]s.
///
/// The interface never parses `d` strings (docs/08-pdf-export.md §7.3/§8.3
/// — "There is no drawSvgPath"); [DiagramPath.fromSvg] is the ONE parse
/// site, run once at catalog load.
@immutable
final class DiagramPath {
  const DiagramPath(this.commands);

  /// Parses the subset of the SVG path mini-language this project's
  /// connector-symbol glyphs need.
  ///
  /// SUPPORTED, absolute and relative (M1 scope, per the task that wrote
  /// this file):
  ///  - `M`/`m` — moveto
  ///  - `L`/`l` — lineto
  ///  - `C`/`c` — cubic Bezier
  ///  - `Z`/`z` — closepath
  ///
  /// Implicit repetition of the last command's argument group (e.g.
  /// `"M0 0 10 10"` meaning `M0 0` then an implicit `L10 10`, per the SVG
  /// spec's own semantics for `M`/`L`/`C`) IS supported, since hand- and
  /// tool-authored path data routinely uses it.
  ///
  /// NOT supported, and deliberately out of M1 scope: elliptical arcs
  /// (`A`/`a`), quadratic Beziers (`Q`/`q`, `T`/`t`), and the
  /// horizontal/vertical/smooth-cubic shorthands (`H`/`h`, `V`/`v`,
  /// `S`/`s`). Connector glyphs that need those can wait.
  ///
  /// Fails LOUDLY: any unsupported command letter, or malformed/missing
  /// numeric arguments, throws a [FormatException] naming exactly what
  /// was wrong. A silently mis-parsed connector glyph is a much worse bug
  /// than a loud parse failure — it would ship as a wrong-looking symbol
  /// nobody notices in code review.
  factory DiagramPath.fromSvg(String d) {
    final tokens = _tokenize(d);
    final commands = <PathCommand>[];

    var i = 0;
    String? cmd;
    var curX = 0.0;
    var curY = 0.0;
    var startX = 0.0;
    var startY = 0.0;

    double nextNumber(String what) {
      if (i >= tokens.length) {
        throw FormatException(
          'DiagramPath.fromSvg: ran out of input reading $what',
          d,
        );
      }
      final token = tokens[i];
      final value = double.tryParse(token);
      if (value == null) {
        throw FormatException(
          'DiagramPath.fromSvg: expected a number reading $what, got '
          '"$token"',
          d,
        );
      }
      i++;
      return value;
    }

    while (i < tokens.length) {
      final token = tokens[i];
      final isCommandLetter = _letterPattern.hasMatch(token);
      if (isCommandLetter) {
        if (!_supportedCommands.contains(token)) {
          throw FormatException(
            'DiagramPath.fromSvg: unsupported path command "$token" — '
            'only M/m, L/l, C/c, Z/z are implemented (arcs, quadratic '
            'curves and the H/V/S shorthands are out of scope for M1)',
            d,
          );
        }
        cmd = token;
        i++;
      } else if (cmd == null) {
        throw FormatException(
          'DiagramPath.fromSvg: path data must start with a command '
          'letter, got "$token"',
          d,
        );
      }
      // else: no letter consumed this iteration — reuse `cmd` for an
      // implicit repeat of the previous command's argument group.

      switch (cmd) {
        case 'M':
        case 'm':
          final relative = cmd == 'm';
          var x = nextNumber('moveto x');
          var y = nextNumber('moveto y');
          if (relative) {
            x += curX;
            y += curY;
          }
          commands.add(MoveTo(x, y));
          curX = x;
          curY = y;
          startX = x;
          startY = y;
          // SVG semantics: further coordinate pairs after a moveto's
          // first pair are implicit linetos (relative stays relative).
          cmd = relative ? 'l' : 'L';
        case 'L':
        case 'l':
          final relative = cmd == 'l';
          var x = nextNumber('lineto x');
          var y = nextNumber('lineto y');
          if (relative) {
            x += curX;
            y += curY;
          }
          commands.add(LineTo(x, y));
          curX = x;
          curY = y;
        case 'C':
        case 'c':
          final relative = cmd == 'c';
          var x1 = nextNumber('cubic x1');
          var y1 = nextNumber('cubic y1');
          var x2 = nextNumber('cubic x2');
          var y2 = nextNumber('cubic y2');
          var x3 = nextNumber('cubic x3');
          var y3 = nextNumber('cubic y3');
          if (relative) {
            x1 += curX;
            y1 += curY;
            x2 += curX;
            y2 += curY;
            x3 += curX;
            y3 += curY;
          }
          commands.add(CubicTo(x1, y1, x2, y2, x3, y3));
          curX = x3;
          curY = y3;
        case 'Z':
        case 'z':
          commands.add(const ClosePath());
          curX = startX;
          curY = startY;
        default:
          // Unreachable: `cmd` is only ever assigned a supported letter
          // above, but kept as a loud failure rather than a silent no-op
          // in case that invariant is ever broken by a future edit.
          throw FormatException(
            'DiagramPath.fromSvg: internal error — unhandled command '
            '"$cmd"',
            d,
          );
      }
    }

    return DiagramPath(commands);
  }

  static final _letterPattern = RegExp(r'^[A-Za-z]$');
  static const _supportedCommands = {'M', 'm', 'L', 'l', 'C', 'c', 'Z', 'z'};

  // Command letters and numbers (incl. signed/decimal/exponent forms) as
  // one token stream; `allMatches` skips whitespace/commas between tokens
  // for free.
  static final _tokenPattern = RegExp(
    r'[A-Za-z]|[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?',
  );

  static List<String> _tokenize(String d) =>
      _tokenPattern.allMatches(d).map((m) => m[0]!).toList();

  final List<PathCommand> commands;

  /// The bounding box of every coordinate referenced by [commands].
  ///
  /// This is a CONSERVATIVE bound for cubic segments — it includes the
  /// control points, not just the curve's true extremum, which is a
  /// superset of the tight bound. That is deliberately good enough for
  /// `BoundsCanvas` (docs/03-architecture.md §7.2), which is not built in
  /// this stage; tightening it to the exact Bezier extrema can happen
  /// later without changing this method's contract.
  DBox get bounds {
    if (commands.isEmpty) {
      throw StateError('DiagramPath.bounds: path has no commands');
    }
    double? minX;
    double? minY;
    double? maxX;
    double? maxY;
    void consider(double x, double y) {
      minX = minX == null || x < minX! ? x : minX;
      minY = minY == null || y < minY! ? y : minY;
      maxX = maxX == null || x > maxX! ? x : maxX;
      maxY = maxY == null || y > maxY! ? y : maxY;
    }

    for (final command in commands) {
      switch (command) {
        case MoveTo(:final x, :final y):
          consider(x, y);
        case LineTo(:final x, :final y):
          consider(x, y);
        case CubicTo(
          :final x1,
          :final y1,
          :final x2,
          :final y2,
          :final x3,
          :final y3,
        ):
          consider(x1, y1);
          consider(x2, y2);
          consider(x3, y3);
        case ClosePath():
          break;
      }
    }
    return DBox.fromCorners(DPt(minX!, minY!), DPt(maxX!, maxY!));
  }
}
