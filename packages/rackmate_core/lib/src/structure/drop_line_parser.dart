// THE DROP DSL — docs/07 §4.3's command mode, parsed. Board M3-C/1 (#147).
//
// ═════════════════════════════════════════════════════════════════════
// WHY THE PARSER IS ITS OWN FILE AND ITS OWN COMMIT
// ═════════════════════════════════════════════════════════════════════
// #147's instruction opens with M1's refutation: "each placement broke
// the repeat loop, and the first re-run failed AGAIN for reasons nothing
// predicted and 2206 tests could not see. 60 drops in 15 minutes is ~15
// seconds per drop INCLUDING thinking."
//
// A parser that needs a `RackDocument` to be tested cannot be tested at
// the speed the loop has to be iterated on. So this file takes TEXT and
// returns STRUCTURE, knows nothing about documents, locations, media
// registries or commands, and every question it cannot answer it hands
// upward rather than guessing. Resolution is the next stage's problem.
//
// ═════════════════════════════════════════════════════════════════════
// THE GRAMMAR, WHICH IS docs/07 §4.3's FOUR LINES AND NOTHING MORE
// ═════════════════════════════════════════════════════════════════════
//
//   Living Room: 4x Cat6, 2x RG6, 2x 16/4, 1x 22/4
//   Attic: 3x Cat6 @service=wifi-ap
//   Exterior: 6x Cat6 @service=camera @status=planned
//   Kitchen: 2x Cat6 + 1x RG6 @outlet="KIT-TV-1"
//
//   line       := location ':' items modifiers?
//   items      := item ((',' | '+') item)*
//   item       := (count ('x' | 'X' | '×'))? mediaToken
//   modifiers  := ('@' key '=' value)*
//   value      := bareWord | '"' anything '"'
//
// ═════════════════════════════════════════════════════════════════════
// `,` AND `+` ARE THE SAME SEPARATOR, AND THAT IS A READING
// ═════════════════════════════════════════════════════════════════════
// docs/07 uses both and never contrasts them. The tempting inference is
// that `+` means "one outlet" and `,` means "separate" — but the line
// that uses `+` ALSO carries `@outlet="KIT-TV-1"`, and §4.3 says it is
// `@outlet=` that "creates or joins one `Outlet`". So the grouping fact
// is already carried explicitly, and giving `+` a second, silent way to
// say it would mean `Kitchen: 2x Cat6 + 1x RG6` and
// `Kitchen: 2x Cat6, 1x RG6` differ by a character nobody documented.
//
// They are separators. If the corpus later wants `+` to group, it is a
// ruling and this comment is where the reader should arrive.
//
// ═════════════════════════════════════════════════════════════════════
// AGGRESSIVE WHERE THE CORPUS IS AGGRESSIVE, STRICT WHERE IT IS NOT
// ═════════════════════════════════════════════════════════════════════
// `docs/catalog/seed-devices.md` §2.3 on the sibling port DSL:
// "Resolution is aggressive and it is the whole point". So `4x`, `4 x`,
// `4X` and `4×` are all one item, a bare `Cat6` with no count is one
// drop, and case and inner spacing are the resolver's problem rather
// than the parser's — media tokens legitimately contain spaces (`quad
// shield`, `cat6 utp`, `spkr 16/2`).
//
// What it will NOT do is guess at a shape: a line with no `:`, a count
// of zero, an empty media token or an unterminated quote is REFUSED with
// a sentence and a column, because docs/04 §3.4 forbids silently doing
// nothing and a bulk-entry surface that drops one item out of nine is
// the worst possible version of that.
import 'package:meta/meta.dart';

/// One `4x Cat6` on a line: how many, and the media name AS TYPED.
///
/// The token is not resolved here and not lower-cased. The resolver
/// needs the original spelling to put in a refusal sentence, and
/// `docs/07` §5.1's synonym table is case-folded at the point of
/// comparison rather than on the way in.
@immutable
final class DropLineItem {
  const DropLineItem({
    required this.count,
    required this.mediaToken,
    required this.column,
  });

  final int count;
  final String mediaToken;

  /// 0-based offset of this item in the source line, for a caret.
  final int column;

  @override
  bool operator ==(Object other) =>
      other is DropLineItem &&
      other.count == count &&
      other.mediaToken == mediaToken &&
      other.column == column;

  @override
  int get hashCode => Object.hash(count, mediaToken, column);

  @override
  String toString() => 'DropLineItem(${count}x $mediaToken @$column)';
}

/// The outcome of [parseDropLine].
sealed class DropLineParse {
  const DropLineParse();
}

/// A line that said nothing: empty, or whitespace, or a `#` comment.
///
/// SEPARATE FROM AN ERROR ON PURPOSE. A paste of six lines with a blank
/// between two of them is a normal thing a person does, and a surface
/// that reported "line 3: expected a location" for it would be training
/// the user to ignore its own error text.
final class DropLineBlank extends DropLineParse {
  const DropLineBlank();
}

/// A line that parsed. Nothing here is resolved against a document.
@immutable
final class DropLineParsed extends DropLineParse {
  const DropLineParsed({
    required this.locationName,
    required this.items,
    this.service,
    this.status,
    this.outletDesignation,
    this.pathwayName,
    this.unknownModifiers = const {},
  });

  /// The text before the `:`, trimmed. Not resolved to a `Location`.
  final String locationName;
  final List<DropLineItem> items;

  /// `@service=`. DR-023 step 1: this outranks the outlet template's tag
  /// when both are present.
  final String? service;

  /// `@status=`, still a raw token — mapping it to `RoughInStatus` is the
  /// resolver's job, because a bad value must refuse with the list of
  /// good ones and this file does not import the model.
  final String? status;

  /// `@outlet="…"`, the OUTLET sense of bundle (CR-016).
  final String? outletDesignation;

  /// `@pathway="…"`, the conduit sense.
  final String? pathwayName;

  /// Modifiers this build does not know, kept rather than dropped.
  ///
  /// The resolver reports them; it does not apply them. A future `@wall=`
  /// should surface as "this build does not understand @wall" and not as
  /// silence, which is the same forward-compat instinct as the `unknown`
  /// map on a persisted entity (DR-019) applied to a text surface.
  final Map<String, String> unknownModifiers;

  /// How many drops this line asks for.
  int get dropCount => items.fold(0, (n, i) => n + i.count);
}

/// A line that could not be read, with a sentence and a caret position.
@immutable
final class DropLineMalformed extends DropLineParse {
  const DropLineMalformed(this.reason, this.column);

  final String reason;

  /// 0-based offset the caret should sit under.
  final int column;
}

const Set<String> _knownModifiers = {
  'service',
  'status',
  'outlet',
  'pathway',
};

/// Parses one line of docs/07 §4.3's command mode.
///
/// Total: never throws, and every failure carries a sentence a person can
/// act on plus the column to put a caret under.
DropLineParse parseDropLine(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty || trimmed.startsWith('#')) return const DropLineBlank();

  final colon = line.indexOf(':');
  if (colon < 0) {
    return DropLineMalformed(
      'A drop line is "Room: 4x Cat6". This one has no colon, so there is '
      'nothing to say where the drops go.',
      line.length,
    );
  }

  final locationName = line.substring(0, colon).trim();
  if (locationName.isEmpty) {
    return const DropLineMalformed(
      'This line needs a room before the colon.',
      0,
    );
  }

  final rest = line.substring(colon + 1);
  final split = _splitModifiers(rest, colon + 1);
  if (split is _ScanFailed) {
    return DropLineMalformed(split.reason, split.column);
  }
  final scan = split as _Scanned;

  final items = <DropLineItem>[];
  for (final piece in _splitItems(scan.itemText, scan.itemOffset)) {
    switch (_parseItem(piece.text, piece.offset)) {
      case _ItemBad(:final error):
        return error;
      case _ItemOk(:final item):
        items.add(item);
    }
  }

  if (items.isEmpty) {
    return DropLineMalformed(
      '$locationName has no drops on it. Add something like "4x Cat6".',
      colon + 1,
    );
  }

  final mods = scan.modifiers;
  return DropLineParsed(
    locationName: locationName,
    items: items,
    service: mods['service'],
    status: mods['status'],
    outletDesignation: mods['outlet'],
    pathwayName: mods['pathway'],
    unknownModifiers: {
      for (final e in mods.entries)
        if (!_knownModifiers.contains(e.key)) e.key: e.value,
    },
  );
}

// ─────────────────────────────────────────────────────────────────────
// SCANNING
// ─────────────────────────────────────────────────────────────────────

sealed class _ScanResult {
  const _ScanResult();
}

final class _Scanned extends _ScanResult {
  const _Scanned(this.itemText, this.itemOffset, this.modifiers);
  final String itemText;
  final int itemOffset;
  final Map<String, String> modifiers;
}

final class _ScanFailed extends _ScanResult {
  const _ScanFailed(this.reason, this.column);
  final String reason;
  final int column;
}

sealed class _ItemResult {
  const _ItemResult();
}

final class _ItemOk extends _ItemResult {
  const _ItemOk(this.item);
  final DropLineItem item;
}

final class _ItemBad extends _ItemResult {
  const _ItemBad(this.error);
  final DropLineMalformed error;
}

/// Splits the text after the colon into its item region and its `@`
/// modifiers, respecting quotes so that `@outlet="A @ B"` stays whole.
_ScanResult _splitModifiers(String rest, int base) {
  final firstAt = _indexOfUnquotedAt(rest);
  if (firstAt < 0) return _Scanned(rest, base, const {});

  final mods = <String, String>{};
  var i = firstAt;
  while (i < rest.length) {
    if (rest[i] != '@') {
      i++;
      continue;
    }
    final eq = rest.indexOf('=', i);
    if (eq < 0) {
      return _ScanFailed(
        'A modifier looks like "@service=camera". This one has no "=".',
        base + i,
      );
    }
    final key = rest.substring(i + 1, eq).trim().toLowerCase();
    if (key.isEmpty) {
      return _ScanFailed('This modifier has no name before its "=".', base + i);
    }

    var j = eq + 1;
    final buf = StringBuffer();
    if (j < rest.length && rest[j] == '"') {
      j++;
      final close = rest.indexOf('"', j);
      if (close < 0) {
        return _ScanFailed(
          'This quoted value is never closed.',
          base + eq + 1,
        );
      }
      buf.write(rest.substring(j, close));
      j = close + 1;
    } else {
      while (j < rest.length && !_isSpace(rest[j]) && rest[j] != '@') {
        buf.write(rest[j]);
        j++;
      }
    }

    final value = buf.toString().trim();
    if (value.isEmpty) {
      return _ScanFailed('"@$key" was given no value.', base + eq);
    }
    mods[key] = value;
    i = j;
  }

  return _Scanned(rest.substring(0, firstAt), base, mods);
}

int _indexOfUnquotedAt(String s) {
  var quoted = false;
  for (var i = 0; i < s.length; i++) {
    if (s[i] == '"') quoted = !quoted;
    if (!quoted && s[i] == '@') return i;
  }
  return -1;
}

bool _isSpace(String c) => c == ' ' || c == '\t';

@immutable
final class _Piece {
  const _Piece(this.text, this.offset);
  final String text;
  final int offset;
}

/// Splits on `,` and `+`, which mean the same thing; see the file header.
List<_Piece> _splitItems(String text, int base) {
  final out = <_Piece>[];
  final buf = StringBuffer();
  var start = 0;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (c == ',' || c == '+') {
      if (buf.toString().trim().isNotEmpty) {
        out.add(_Piece(buf.toString(), base + start));
      }
      buf.clear();
      start = i + 1;
    } else {
      buf.write(c);
    }
  }
  if (buf.toString().trim().isNotEmpty) {
    out.add(_Piece(buf.toString(), base + start));
  }
  return out;
}

final RegExp _countPrefix = RegExp(r'^\s*(\d+)\s*[xX×]\s*');

final RegExp _digitsOnly = RegExp(r'^\d+$');

/// `4x Cat6` → 4 and `Cat6`; a bare `Cat6` → 1 and `Cat6`.
_ItemResult _parseItem(String text, int offset) {
  final lead = text.length - text.trimLeft().length;
  final match = _countPrefix.firstMatch(text);
  if (match == null) {
    final token = text.trim();
    if (token.isEmpty) {
      return _ItemBad(DropLineMalformed('This item is empty.', offset));
    }
    // A COUNT THAT IS ONLY DIGITS is a typo worth catching: `Kitchen: 4`
    // means nothing, and reading it as one drop of a cable called "4"
    // would fail two stages later with a worse sentence.
    if (_digitsOnly.hasMatch(token)) {
      return _ItemBad(
        DropLineMalformed(
          '"$token" is a count with no cable. Write "${token}x Cat6".',
          offset + lead,
        ),
      );
    }
    return _ItemOk(
      DropLineItem(count: 1, mediaToken: token, column: offset + lead),
    );
  }

  final count = int.parse(match.group(1)!);
  if (count == 0) {
    return _ItemBad(
      DropLineMalformed(
        'A count of zero pulls nothing. Remove the item instead.',
        offset + lead,
      ),
    );
  }

  final token = text.substring(match.end).trim();
  if (token.isEmpty) {
    return _ItemBad(
      DropLineMalformed(
        '"$count x" does not say what to pull.',
        offset + lead,
      ),
    );
  }
  return _ItemOk(
    DropLineItem(count: count, mediaToken: token, column: offset + lead),
  );
}
