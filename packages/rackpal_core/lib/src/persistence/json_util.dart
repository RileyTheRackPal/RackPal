// Low-level JSON plumbing shared by json_codec.dart and migrations.dart:
// canonical (sorted, pretty-printed) encoding, the one DateTime <-> String
// convention, the "omit null rather than write it" helper, and safe
// Object?-to-typed casts that fail with a message naming the field
// instead of a bare TypeError.
import 'dart:convert';

typedef JsonMap = Map<String, Object?>;

/// Recursively sorts every [Map]'s keys — including inside nested
/// `unknown` passthrough maps and maps nested in lists — so the final
/// encoding is deterministic. This is the ENTIRE mechanism behind
/// CR-117's byte round trip: every map built while encoding a document
/// may be assembled in whatever order is convenient; this function runs
/// exactly once, immediately before the final `JsonEncoder` pass, and is
/// the only thing that actually has to get key order right.
Object? deepSortKeys(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((k) => k as String).toList()..sort();
    final sorted = <String, Object?>{};
    for (final key in keys) {
      sorted[key] = deepSortKeys(value[key]);
    }
    return sorted;
  }
  if (value is List) {
    return [for (final element in value) deepSortKeys(element)];
  }
  return value;
}

/// Encodes [root] as the canonical pretty-printed, key-sorted UTF-8 JSON
/// this package's file format requires (2-space indent, CR-091). [root]
/// must already be a tree of plain `Map<String, Object?>` / `List` /
/// `String` / `int` / `bool` / `null` — no custom `toJson()` resolution
/// happens here, by design, so every persisted value is visibly
/// accounted for in json_codec.dart.
List<int> encodeCanonicalJsonBytes(Object? root) {
  final sorted = deepSortKeys(root);
  final text = const JsonEncoder.withIndent('  ').convert(sorted);
  return utf8.encode(text);
}

/// The one canonical `DateTime` <-> `String` mapping used for every
/// timestamp in the format (UTC, microsecond precision — EntityMeta's
/// documented contract). Always via [DateTime.toUtc] first so a value
/// built in any timezone still renders identically on every encode.
String encodeDateTime(DateTime value) => value.toUtc().toIso8601String();

DateTime decodeDateTime(String raw) => DateTime.parse(raw).toUtc();

/// Sets `map[key] = value` only when [value] is non-null — the format's
/// "absent key, never an explicit null" rule for nullable fields
/// (CR-114, G4). Never call this for a non-nullable field: those always
/// write, even when the value is a "falsy" default like `0`/`false`/`''`,
/// because the omission rule is about null-ness, not defaults.
void putIfNotNull(JsonMap map, String key, Object? value) {
  if (value != null) {
    map[key] = value;
  }
}

// --- Safe extraction helpers -----------------------------------------
//
// jsonDecode hands back Object?/Map<String, dynamic>/List<dynamic>; these
// centralise the casts with a context string in the error so a malformed
// file fails with a message naming the offending field rather than a bare
// TypeError several stack frames removed from anything useful.

JsonMap asJsonMap(Object? value, String context) {
  if (value is Map) {
    return value.map((k, v) => MapEntry(k as String, v));
  }
  throw FormatException('Expected a JSON object for $context, got: $value');
}

List<Object?> asJsonList(Object? value, String context) {
  if (value is List) return value;
  throw FormatException('Expected a JSON array for $context, got: $value');
}

String asStr(Object? value, String context) {
  if (value is String) return value;
  throw FormatException('Expected a string for $context, got: $value');
}

String? asStrOrNull(Object? value, String context) =>
    value == null ? null : asStr(value, context);

int asInt(Object? value, String context) {
  if (value is int) return value;
  throw FormatException('Expected an int for $context, got: $value');
}

int? asIntOrNull(Object? value, String context) =>
    value == null ? null : asInt(value, context);

bool asBool(Object? value, String context) {
  if (value is bool) return value;
  throw FormatException('Expected a bool for $context, got: $value');
}

bool? asBoolOrNull(Object? value, String context) =>
    value == null ? null : asBool(value, context);

/// Decodes `json[key]` via [decode] when present, `null` otherwise — the
/// generic shape of every nullable nested-object field (`siteAddress`,
/// `network`, `poeActual`, `test`, `structureOrigin`, ...).
T? decodeNullableObject<T>(
  JsonMap json,
  String key,
  String context,
  T Function(JsonMap) decode,
) {
  final raw = json[key];
  if (raw == null) return null;
  return decode(asJsonMap(raw, context));
}

/// Decodes a JSON array of objects via [decode] — the generic shape of
/// every `List<SomeEntity>` field (`services`, `conductors`, `banks`,
/// `ports`, ...).
List<T> decodeObjectList<T>(
  Object? value,
  String context,
  T Function(JsonMap) decode,
) {
  final list = asJsonList(value, context);
  return [
    for (var i = 0; i < list.length; i++)
      decode(asJsonMap(list[i], '$context[$i]')),
  ];
}
