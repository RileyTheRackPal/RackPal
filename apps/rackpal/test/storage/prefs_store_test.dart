// prefs.json, and the pure window geometry that decides whether a saved
// rectangle is still reachable.
//
// `validateRestoredBounds` is tested with SYNTHETIC display rectangles —
// no real monitors, no window manager, no Flutter binding — which is the
// entire reason it takes a plain `WindowBounds` rather than `dart:ui`'s
// `Rect`. The case that matters is the unplugged second monitor: a window
// restored to coordinates the user cannot reach is a bug whose only
// remedy, for a non-technical user, is deleting a file they do not know
// exists.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rackpal/src/storage/atomic_writer.dart';
import 'package:rackpal/src/storage/prefs_store.dart';

import 'atomicity.dart';
import 'fake_file_store.dart';

final _windows = p.Context(style: p.Style.windows);
const _dataRoot = r'C:\data';
const _prefs = r'C:\data\prefs.json';

// A common two-monitor setup: a 1920x1080 primary and a portrait
// secondary to its left, whose origin is therefore negative.
const _primary = WindowBounds(left: 0, top: 0, width: 1920, height: 1080);
const _secondary = WindowBounds(
  left: -1080,
  top: -200,
  width: 1080,
  height: 1920,
);

({PrefsStore store, FakeFileStore fs}) _make({Map<String, Uint8List>? files}) {
  final fs = FakeFileStore(
    initialFiles: files,
    initialDirectories: const {'C:', _dataRoot},
  );
  return (
    store: PrefsStore(
      fs: fs,
      writer: AtomicWriter(
        fs: fs,
        queue: SaveQueue(),
        context: _windows,
        delay: (_) async {},
      ),
      dataRoot: _dataRoot,
      context: _windows,
    ),
    fs: fs,
  );
}

void main() {
  group('PrefsStore', () {
    test('a missing file yields defaults, not an error', () async {
      final prefs = await _make().store.load();
      expect(prefs.window, isNull);
      expect(prefs.maximized, isFalse);
      expect(prefs.displayId, isNull);
    });

    test('an unparseable file yields defaults and logs — a preferences '
        'file must never stop the app starting', () async {
      final made = _make(
        files: {_prefs: Uint8List.fromList(utf8.encode('{{{'))},
      );
      expect((await made.store.load()).window, isNull);
    });

    test('round-trips a full set of preferences', () async {
      final made = _make();
      const original = AppPrefs(
        window: WindowBounds(left: 120, top: 64, width: 1440, height: 900),
        maximized: true,
        displayId: r'\\.\DISPLAY2',
        lastSaveDirectory: r'C:\jobs',
      );
      await made.store.save(original);

      final loaded = await made.store.load();
      expect(loaded.window, original.window);
      expect(loaded.maximized, isTrue);
      expect(loaded.displayId, r'\\.\DISPLAY2');
      expect(loaded.lastSaveDirectory, r'C:\jobs');
    });

    group('is written atomically', () {
      // The old test asserted `files.keys == [prefs.json]` and nothing
      // else. That key set is IDENTICAL for an atomic write and for a
      // plain `fs.writeBytes(path, bytes)` — so the AtomicWriter could be
      // removed from `PrefsStore.save` and the suite stayed green, while a
      // crash during a debounced geometry write (which fires on every
      // window move, half a second after the drag stops) went from
      // "the previous good prefs survive" to "prefs.json is truncated" —
      // the exact failure this file's header claims the writer prevents.

      test('prefs.json is never partially written at any instant', () async {
        final made = _make();
        await made.store.save(const AppPrefs(maximized: true));

        expectAtomicWrite(
          made.fs,
          target: _prefs,
          expected: await made.fs.readBytes(_prefs),
          what: 'prefs.json',
        );
        expect(made.fs.state.files.keys, [_prefs]);
      });

      test('and neither is a SECOND save — the geometry debounce writes '
          'over an existing file every time', () async {
        final made = _make();
        await made.store.save(const AppPrefs(maximized: true));
        final previous = await made.fs.readBytes(_prefs);
        made.fs.resetJournal();

        await made.store.save(
          const AppPrefs(
            window: WindowBounds(left: 12, top: 34, width: 1400, height: 900),
          ),
        );

        expectAtomicWrite(
          made.fs,
          target: _prefs,
          previous: previous,
          expected: await made.fs.readBytes(_prefs),
          what: 'prefs.json',
        );
        expect(
          made.fs.state.files.keys,
          [_prefs],
          reason:
              'keepBackup: false, and this fixture can now tell — the '
              'target existed, so step 4 would have run',
        );
      });
    });

    test('the persisted file is versioned', () async {
      final made = _make();
      await made.store.save(const AppPrefs());
      final raw =
          jsonDecode(utf8.decode(await made.fs.readBytes(_prefs)))!
              as Map<String, Object?>;
      expect(raw['version'], kPrefsFormatVersion);
    });

    test(
      'a window block with a zero extent is rejected, not restored',
      () async {
        final made = _make(
          files: {
            _prefs: Uint8List.fromList(
              utf8.encode(
                jsonEncode({
                  'version': 1,
                  'window': {
                    'left': 0,
                    'top': 0,
                    'width': 0,
                    'height': 900,
                    'maximized': false,
                  },
                }),
              ),
            ),
          },
        );
        expect((await made.store.load()).window, isNull);
      },
    );

    test('integers in the JSON are accepted as doubles', () async {
      // jsonEncode writes 1440.0 as 1440.0, but a hand-edited file (or a
      // future writer) may well contain a bare integer.
      final made = _make(
        files: {
          _prefs: Uint8List.fromList(
            utf8.encode(
              jsonEncode({
                'version': 1,
                'window': {
                  'left': 10,
                  'top': 20,
                  'width': 1440,
                  'height': 900,
                  'maximized': false,
                },
              }),
            ),
          ),
        },
      );
      expect(
        (await made.store.load()).window,
        const WindowBounds(left: 10, top: 20, width: 1440, height: 900),
      );
    });
  });

  group('validateRestoredBounds — pure geometry', () {
    test('a window fully inside a display is returned unchanged', () {
      const saved = WindowBounds(
        left: 100,
        top: 100,
        width: 1400,
        height: 900,
      );
      expect(validateRestoredBounds(saved, const [_primary]), saved);
    });

    test('A WINDOW ON AN UNPLUGGED MONITOR RETURNS NULL', () {
      // The caller then centres a default window. Without this the app
      // opens at coordinates the user cannot reach, and there is no
      // in-app way out of it.
      // Entirely within the portrait secondary: right edge at -80, which
      // is off the left of the primary altogether.
      const saved = WindowBounds(
        left: -1080,
        top: 100,
        width: 1000,
        height: 900,
      );
      expect(
        validateRestoredBounds(saved, const [_primary]),
        isNull,
        reason:
            'the secondary display is gone; that rectangle is off '
            'screen',
      );
    });

    test('...but the SAME window is restored while that monitor is '
        'still attached', () {
      const saved = WindowBounds(
        left: -1080,
        top: 100,
        width: 1000,
        height: 900,
      );
      final result = validateRestoredBounds(
        saved,
        const [_primary, _secondary],
      );
      expect(result, isNotNull);
      expect(result!.left, lessThan(0));
    });

    test('a sliver of overlap is not enough to be reachable', () {
      // 50x50 of a window peeking onto the primary is not a title bar the
      // user can grab.
      const saved = WindowBounds(
        left: 1870,
        top: 1030,
        width: 1400,
        height: 900,
      );
      expect(validateRestoredBounds(saved, const [_primary]), isNull);
    });

    test('no displays at all returns null', () {
      const saved = WindowBounds(left: 0, top: 0, width: 1400, height: 900);
      expect(validateRestoredBounds(saved, const []), isNull);
    });

    test('a window smaller than the minimum is clamped UP', () {
      // §9.5: "a rack editor below ~1000 px wide is unusable".
      const saved = WindowBounds(left: 0, top: 0, width: 400, height: 300);
      final result = validateRestoredBounds(saved, const [_primary])!;
      expect(result.width, kMinWindowWidth);
      expect(result.height, kMinWindowHeight);
    });

    test('a display smaller than the minimum gets a window that fills '
        'it', () {
      // A 800x600 projector. Filling it is the least-bad answer and is
      // what every other desktop app does.
      const tiny = WindowBounds(left: 0, top: 0, width: 800, height: 600);
      const saved = WindowBounds(left: 0, top: 0, width: 400, height: 300);
      final result = validateRestoredBounds(saved, const [tiny])!;
      expect(result.width, 800);
      expect(result.height, 600);
    });

    test('a window larger than its display is clamped DOWN and nudged '
        'fully inside', () {
      const saved = WindowBounds(
        left: 200,
        top: 200,
        width: 3000,
        height: 2000,
      );
      final result = validateRestoredBounds(saved, const [_primary])!;
      expect(result.width, 1920);
      expect(result.height, 1080);
      expect(result.left, 0);
      expect(result.top, 0);
    });

    test('a window hanging off the right edge is pulled back in', () {
      const saved = WindowBounds(
        left: 1500,
        top: 500,
        width: 1200,
        height: 800,
      );
      final result = validateRestoredBounds(saved, const [_primary])!;
      expect(result.right, lessThanOrEqualTo(_primary.right));
      expect(result.bottom, lessThanOrEqualTo(_primary.bottom));
      expect(result.width, 1200);
      expect(result.height, 800);
    });

    test('the display with the LARGEST overlap wins', () {
      // A window straddling two monitors belongs to the one it is mostly
      // on, not to whichever happens to be first in the list.
      const saved = WindowBounds(
        left: -900,
        top: 0,
        width: 1000,
        height: 900,
      );
      final result = validateRestoredBounds(
        saved,
        const [_primary, _secondary],
      )!;
      expect(
        result.left,
        lessThan(0),
        reason: 'it is mostly on the secondary, so it stays there',
      );
    });

    test('the minimum window size is the documented one', () {
      expect(kMinWindowWidth, 1000);
      expect(kMinWindowHeight, 720);
    });
  });

  group('WindowBounds', () {
    test('intersectionArea is zero for disjoint rectangles', () {
      const a = WindowBounds(left: 0, top: 0, width: 10, height: 10);
      const b = WindowBounds(left: 100, top: 100, width: 10, height: 10);
      expect(a.intersectionArea(b), 0);
    });

    test('intersectionArea is the overlapping area', () {
      const a = WindowBounds(left: 0, top: 0, width: 10, height: 10);
      const b = WindowBounds(left: 5, top: 5, width: 10, height: 10);
      expect(a.intersectionArea(b), 25);
    });

    test('touching edges do not overlap', () {
      const a = WindowBounds(left: 0, top: 0, width: 10, height: 10);
      const b = WindowBounds(left: 10, top: 0, width: 10, height: 10);
      expect(a.intersectionArea(b), 0);
    });

    test('fromJson rejects non-finite numbers', () {
      expect(
        WindowBounds.fromJson(<String, Object?>{
          'left': double.nan,
          'top': 0,
          'width': 100,
          'height': 100,
        }),
        isNull,
      );
    });
  });
}
