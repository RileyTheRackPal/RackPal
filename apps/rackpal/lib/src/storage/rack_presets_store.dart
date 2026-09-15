// `rack_presets.json`: your rack presets and the seeded ones you have
// hidden, kept per machine beside `prefs.json` (#561, DR-176 §11.175.3).
//
// A COPY OF `PrefsStore`'S SHAPE, ON PURPOSE. Both are convenience files
// under the data root, both must never stop the app starting, and both hold
// a live copy that more than one surface writes: the rack inspector saves a
// preset, and Preferences renames, deletes and hides them. So the live
// value lives HERE, behind [current], for the reason `PrefsStore.current`
// gives: two writers doing load-modify-write against stale copies revert
// each other, and `session_layering_test.dart` RULE 15 fails on a public
// field only a test writes.
import 'dart:convert';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:rackpal/src/storage/atomic_writer.dart';
import 'package:rackpal/src/storage/file_store.dart';
import 'package:rackpal/src/storage/save_paths.dart';
import 'package:rackpal/src/storage/storage_log.dart';
import 'package:rackpal_core/rackpal_core.dart'
    show UserRackPresets, userRackPresetsFromJson, userRackPresetsToJson;

/// The file name inside the data root.
const String kRackPresetsFileName = 'rack_presets.json';

/// Reads and writes `rack_presets.json`.
final class RackPresetsStore {
  RackPresetsStore({
    required this.fs,
    required this.writer,
    required String dataRoot,
    p.Context? context,
  }) : context = context ?? p.context,
       path = (context ?? p.context).join(dataRoot, kRackPresetsFileName);

  final FileStore fs;
  final AtomicWriter writer;
  final p.Context context;

  /// The full path of `rack_presets.json`.
  final String path;

  /// What [load] last read or [save] last wrote, whichever happened more
  /// recently. See the file header on why the live value lives here.
  UserRackPresets get current => _current;
  UserRackPresets _current = const UserRackPresets();

  /// Loads the file, falling back to no presets and nothing hidden when it
  /// is missing or unreadable. A single unreadable preset inside a readable
  /// file is skipped by `userRackPresetsFromJson`, not here.
  Future<UserRackPresets> load() async {
    try {
      if (!await fs.exists(path)) return _current = const UserRackPresets();
      return _current = userRackPresetsFromJson(
        jsonDecode(utf8.decode(await fs.readBytes(path))),
      );
      // No presets is always a usable answer; refusing to start over a
      // corrupt presets file would not be.
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      logStorageEvent('rack_presets_unreadable');
      return _current = const UserRackPresets();
    }
  }

  /// Persists [value] atomically.
  ///
  /// [current] IS UPDATED EVEN IF THE WRITE FAILS, on `PrefsStore.save`'s
  /// reasoning: the write's `Outcome` is discarded, so the honest in-memory
  /// answer is what this process last decided. The caller that must tell
  /// the user a save did not stick is the one that made the change, and it
  /// reads the file back rather than trusting this.
  Future<void> save(UserRackPresets value) async {
    _current = value;
    final json = const JsonEncoder.withIndent(
      '  ',
    ).convert(userRackPresetsToJson(value));
    await writer.write(
      paths: SavePaths.forExactTarget(path, context: context),
      bytes: Uint8List.fromList(utf8.encode(json)),
      keepBackup: false,
    );
  }
}
