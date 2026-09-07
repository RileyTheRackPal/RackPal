// THE INSTRUMENT FOR "byte-identical display list".
//
// M2's exit criterion is a byte property — "same input ⇒ BYTE-IDENTICAL
// display list" (docs/09, docs/12 §5.1) — and a `DiagramOp` has no `==`, so
// `expect(a.ops, b.ops)` compares object identities and passes for two
// scenes that differ everywhere. This turns a display list into one string,
// so equality of the string IS equality of every emitted number.
//
// TWO PROPERTIES IT HAS TO HAVE, and neither is free:
//
//   1. EXHAUSTIVE. The switch below is over the SEALED `DiagramOp`
//      hierarchy with no `default`, so adding an op type is a COMPILE ERROR
//      here rather than a silent hole in the determinism suite. That is the
//      whole reason it is a switch and not a `toString()`.
//   2. LOSSLESS ON THE NUMBERS. Every coordinate, every colour, every
//      stroke flag and every text style field is written out. A digest that
//      recorded only op TYPES would pass while every symbol moved.
//
// `double.toString()` is used deliberately: Dart's shortest-round-trip
// formatting is injective for finite doubles, so two different doubles can
// never produce the same text, and the same double always produces the same
// text. A fixed-precision format would round two nearby positions together
// and hide exactly the drift this is looking for.

import 'package:rackpal_core/rackpal_core.dart';

/// A canonical, lossless, comparable rendering of [ops].
String digestOps(List<DiagramOp> ops) {
  final out = StringBuffer();
  for (var i = 0; i < ops.length; i++) {
    out
      ..write(i)
      ..write(' ')
      ..write(_op(ops[i]))
      ..write('\n');
  }
  return out.toString();
}

/// The whole scene — ops, bounds, hit regions, fragment ranges and the
/// legibility floor. `DiagramScene.bounds` drives PDF scale-to-fit and
/// `hits` drives selection, so a layout that moved without moving an op
/// would still be a changed drawing.
String digestScene(DiagramScene scene) {
  final out = StringBuffer()
    ..write('bounds ')
    ..write(_box(scene.bounds))
    ..write('\nminText ')
    ..write(scene.minTextSizePt)
    ..write('\n');
  final keys = scene.fragments.keys.toList()..sort();
  for (final key in keys) {
    final range = scene.fragments[key]!;
    out
      ..write('fragment ')
      ..write(key)
      ..write(' ')
      ..write(range.start)
      ..write('..')
      ..write(range.end)
      ..write('\n');
  }
  for (final hit in scene.hits) {
    out
      ..write('hit ')
      ..write(hit.entityId)
      ..write('#')
      ..write(hit.partKey ?? '')
      ..write(' ')
      ..write(_box(hit.bounds))
      ..write('\n');
  }
  out.write(digestOps(scene.ops));
  return out.toString();
}

String _op(DiagramOp op) => switch (op) {
  OpSave() => 'save',
  OpRestore() => 'restore',
  OpTransform(:final m) => 'transform ${m.storage.join(',')}',
  OpClipRect(:final r) => 'clipRect ${_box(r)}',
  OpClipPath(:final p, :final rule) => 'clipPath ${_path(p)} ${rule.name}',
  OpLine(:final a, :final b, :final s) =>
    'line ${_pt(a)} ${_pt(b)} ${_stroke(s)}',
  OpPolyline(:final pts, :final s, :final close) =>
    'polyline ${pts.map(_pt).join('|')} ${_stroke(s)} $close',
  OpPath(:final p, :final fill, :final stroke) =>
    'path ${_path(p)} ${_fill(fill)} ${_stroke(stroke)}',
  OpRect(:final r, :final fill, :final stroke) =>
    'rect ${_box(r)} ${_fill(fill)} ${_stroke(stroke)}',
  OpRoundRect(:final r, :final radii, :final fill, :final stroke) =>
    'roundRect ${_box(r)} ${radii.rh},${radii.rv} '
        '${_fill(fill)} ${_stroke(stroke)}',
  OpCircle(:final center, :final radius, :final fill, :final stroke) =>
    'circle ${_pt(center)} $radius ${_fill(fill)} ${_stroke(stroke)}',
  OpEllipse(:final center, :final rx, :final ry, :final fill, :final stroke) =>
    'ellipse ${_pt(center)} $rx $ry ${_fill(fill)} ${_stroke(stroke)}',
  OpText(:final text, :final at, :final style) =>
    'text ${_escape(text)} ${_pt(at)} ${_style(style)}',
  // LOSSLESS MEANS THE REFERENCE, NOT THE PIXELS, and here that is the
  // whole property rather than a shortcut. `OpImage` carries an `ImageRef`
  // precisely so a display list stays cheap to compare (see `ops.dart`),
  // so digesting the member name, the format and the intrinsic size IS
  // digesting everything the op holds. Two scenes naming the same member
  // at the same rect ARE the same drawing instruction; whether the bytes
  // behind that member changed is the container's question and CR-117's,
  // not this instrument's.
  OpImage(:final image, :final dst) =>
    'image ${_escape(image.member)} ${image.format.name} '
        '${image.pixelWidth}x${image.pixelHeight} ${_box(dst)}',
};

String _pt(DPt p) => '${p.x},${p.y}';

String _box(DBox b) => '${b.left},${b.top},${b.right},${b.bottom}';

String _path(DiagramPath p) => p.commands
    .map(
      (c) => switch (c) {
        MoveTo(:final x, :final y) => 'M$x,$y',
        LineTo(:final x, :final y) => 'L$x,$y',
        CubicTo(
          :final x1,
          :final y1,
          :final x2,
          :final y2,
          :final x3,
          :final y3,
        ) =>
          'C$x1,$y1,$x2,$y2,$x3,$y3',
        ClosePath() => 'Z',
      },
    )
    .join();

String _fill(Fill? f) => f == null ? '-' : 'f${f.argb}';

String _stroke(Stroke? s) => s == null
    ? '-'
    : 's${s.argb},${s.widthPt},${s.dash?.join(':') ?? ''},${s.dashPhase},'
          '${s.cap.name},${s.join.name},${s.miterLimit},'
          '${s.scaleWithGeometry},${s.hairlineFloor}';

String _style(TextStyleSpec t) =>
    '${t.font.family},${t.font.bold},${t.sizePt},${t.letterSpacing},'
    '${t.argb},${t.rotationRad},${t.anchor.name}';

/// Newlines would break the one-op-per-line framing; nothing else can.
String _escape(String text) => text.replaceAll('\n', r'\n');
