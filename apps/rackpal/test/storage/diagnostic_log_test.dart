// DR-194 (`#939`): the local diagnostic log.
//
// The property that matters most is the one a log is most tempted to
// break: §12.4 says a path, a client name or a site address must never
// reach a log, and an exception's message is where they live. So the
// first case throws a real `FileSystemException`-shaped error carrying a
// client's name in its message and asserts the BYTES ON DISK, not a
// formatter's return value.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rackpal/src/storage/atomic_writer.dart';
import 'package:rackpal/src/storage/diagnostic_log.dart';

import 'fake_file_store.dart';

final p.Context _ctx = p.Context(style: p.Style.windows);
const String _dir = r'C:\Data\RackPal\diagnostics';

enum _Step { promote }

final class _ClientPathError implements Exception {
  const _ClientPathError(this.message);
  final String message;
  @override
  String toString() => 'ClientPathError: $message';
}

DiagnosticLog _log(FakeFileStore fs, {int cap = kDiagnosticLogCapBytes}) =>
    DiagnosticLog(
      fs: fs,
      directory: _dir,
      context: _ctx,
      now: () => DateTime.utc(2026, 9, 23, 12),
      capBytes: cap,
    );

Future<String> _read(FakeFileStore fs, String path) async =>
    utf8.decode(await fs.readBytes(path));

void main() {
  test('a fatal error is its TYPE and its FRAMES, never its message', () async {
    final fs = FakeFileStore();
    final log = _log(fs);
    await log.open();

    const secret = r'C:\Jobs\Smith Residence, 14 Elm Road\smith.rppj';
    try {
      throw const _ClientPathError('could not write $secret');
    } on Object catch (e, st) {
      log.fatal(e, st);
    }
    await log.idle;

    final text = await _read(fs, log.path);
    expect(text, contains('fatal _ClientPathError'));
    expect(text, contains('  #0'), reason: 'the frames are the evidence');
    expect(
      text,
      isNot(contains('Smith')),
      reason: 'a client name in a message must not reach the file (§12.4)',
    );
    expect(text, isNot(contains('Elm Road')));
  });

  test('a file: URI in a frame keeps only its file name', () {
    final frames = diagnosticFramesOf(
      StackTrace.fromString(
        '#0      save (file:///C:/Users/smith/jobs/lib/saver.dart:12:5)\n'
        '#1      main (package:rackpal/main.dart:80:3)\n',
      ),
    );
    expect(frames, [
      '  #0      save (file:…/saver.dart:12:5)',
      '  #1      main (package:rackpal/main.dart:80:3)',
    ]);
  });

  test('a storage event is its code and its typed facts', () async {
    final fs = FakeFileStore();
    final log = _log(fs);
    await log.open();

    log.storage('save_failed', {
      'errno': 5,
      'retried': true,
      'step': _Step.promote,
    });
    await log.idle;

    expect(
      await _read(fs, log.path),
      '2026-09-23T12:00:00.000Z storage save_failed '
      'errno=5 retried=true step=promote\n',
    );
  });

  test('the file never grows past its cap, and keeps the newest', () async {
    final fs = FakeFileStore();
    final log = _log(fs, cap: 2000);
    await log.open();

    for (var i = 0; i < 200; i++) {
      log.storage('tick', {'n': i});
    }
    await log.idle;

    final bytes = await fs.readBytes(log.path);
    expect(bytes.length, lessThanOrEqualTo(2000));
    final text = utf8.decode(bytes);
    expect(text, contains('n=199'), reason: 'the newest record survives');
    expect(text, isNot(contains('n=0\n')), reason: 'the oldest is gone');
  });

  test("opening keeps the last session's log beside this one", () async {
    final fs = FakeFileStore(
      initialFiles: {
        _ctx.join(_dir, kDiagnosticLogName): utf8.encode('last run\n'),
      },
      initialDirectories: {_dir},
    );
    final log = _log(fs);
    await log.open();
    log.storage('opened', const {});
    await log.idle;

    expect(await _read(fs, log.previousPath), 'last run\n');
    expect(await _read(fs, log.path), contains('storage opened'));
  });

  test('a log that cannot write says nothing, and does not throw', () async {
    final fs = FakeFileStore(
      faults: {for (var i = 0; i < 20; i++) i: const StorageOsException(5)},
    );
    final log = _log(fs);
    await log.open();

    expect(
      () => log.fatal(StateError('x'), StackTrace.current),
      returnsNormally,
    );
    await expectLater(log.idle, completes);
  });
}
