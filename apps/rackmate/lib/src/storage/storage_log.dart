// §12.4 forbids logging file paths, client names or project addresses. A
// storage layer's natural instinct is to log the path on every failure —
// it is the single most useful thing to have, and it is exactly the thing
// a recovery-file path leaks (a project name IS a client's name, and a
// directory IS often a site address).
//
// So the rule is enforced BY TYPE rather than by remembering. The facts
// map takes `int`, `bool` and `Enum` values and nothing else; there is no
// overload that accepts a `String`, so `logStorageEvent('save_failed',
// {'path': paths.target})` does not compile. A failure logs
// `save_failed {errno: 5, step: 3, dirDepth: 6, nameLen: 14, bytes:
// 601233}` — enough to diagnose, structurally incapable of identifying
// anyone.
//
// Error DIALOGS show the full path, because that is the user's own screen
// and not a log file. The two are different surfaces with different rules.
import 'package:path/path.dart' as p;

/// The value types a storage log fact may take. Deliberately does not
/// include `String`.
typedef StorageFact = Object;

/// A sink for structured storage events. `package:logging` (§10.1) is
/// wired to this in a later pass; the interface exists now so nothing in
/// this layer has to reach for `print` in the meantime (there is a test
/// enforcing that too).
typedef StorageLogSink = void Function(String code, Map<String, Object> facts);

StorageLogSink? _sink;

/// Installs the process-wide sink. Passing `null` silences logging, which
/// is the default under test.
void setStorageLogSink(StorageLogSink? sink) => _sink = sink;

/// Records one structured storage event.
///
/// [facts] values MUST be `int`, `bool` or `Enum`. That is asserted at
/// runtime as well as documented, because a `Map<String, Object>` will
/// happily accept a String at a call site the analyzer has already
/// widened — and a redaction rule that only holds when everyone
/// remembers is not a rule.
void logStorageEvent(String code, [Map<String, Object> facts = const {}]) {
  assert(
    facts.values.every((v) => v is int || v is bool || v is Enum),
    'storage log facts must be int/bool/Enum only (§12.4): a String here '
    'is how a client name or a site address reaches a log file. Derive a '
    'number from it instead — see pathShape().',
  );
  _sink?.call(code, facts);
}

/// The diagnosable SHAPE of a path, with the path itself discarded.
///
/// This is what a call site reaches for when it wants to log "where" —
/// and it is deliberately lossy. Directory depth and name length are
/// enough to recognise "the user is saving into a very deep OneDrive
/// tree" or "the file name is one character short of MAX_PATH"; neither
/// can be turned back into a name.
Map<String, Object> pathShape(String path, {required p.Context context}) {
  final name = context.basename(path);
  return <String, Object>{
    'dirDepth': context.split(context.dirname(path)).length,
    'nameLen': name.length,
    'pathLen': path.length,
    'isAbsolute': context.isAbsolute(path),
  };
}
