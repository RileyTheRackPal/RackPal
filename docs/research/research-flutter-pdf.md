I'll research this thoroughly. Let me start by loading the web tools and searching in parallel.I'll research this thoroughly. Let me fan out searches across all seven topic areas in parallel.Let me fetch the actual package pages and API docs for concrete versions and API surfaces.Now let me dig into the most important part, the shared-renderer abstraction, plus the remaining topics.Let me examine the source-level APIs: CustomPaint, PdfPageFormat, TableHelper, and font handling.# PDF generation from Flutter, deep technical research for RackPal

Researched July 2026. Versions verified against pub.dev on the date of writing.

---

## 0. TL;DR / decisions I'd make

| Question | Answer |
|---|---|
| Library | `pdf` **3.13.0** + `printing` **5.15.0** (DavBfr). No real competitor at this price (Apache-2.0). |
| Shared renderer | **No off-the-shelf abstraction exists.** Write ~250 lines: a *display list* (`sealed class DiagramOp`) + two interpreters (`dart:ui Canvas`, `PdfGraphics`). Details in §2; this is the load-bearing section. |
| Raster fallback | Don't. 11×17 @300dpi = 3300×5100 px = **64 MiB RGBA**, exceeds the 4096px GPU texture cap on many devices, and kills text selection. Math in §2.9. |
| Sheet size | ANSI B (11×17, `792×1224 pt`) landscape for diagrams; ANSI A portrait for the schedule. **`PdfPageFormat` ships neither: you construct them.** §3. |
| Multi-sheet strategy | Partition by **net/subsystem with off-sheet connectors**, not geometric tiling. §3.3. |
| Save on desktop | `file_selector` (first-party) over `file_picker`. §6. |
| Isolates | `Isolate.run()`, but **pre-load all fonts/images to `Uint8List` on the main isolate**: `rootBundle` and plugins are unreachable from a background isolate. §7.1. |

---

## 1. The `pdf` and `printing` packages

### 1.1 Versions and constraints

| Package | Version | Notes |
|---|---|---|
| [`pdf`](https://pub.dev/packages/pdf) | **3.13.0** | Pure Dart, no Flutter dep. Apache-2.0. **Min Dart SDK raised to 3.12.0 in 3.13.0**: you're on 3.12.2, fine. |
| [`printing`](https://pub.dev/packages/printing) | **5.15.0** | Flutter plugin. Android/iOS/macOS/Windows/Linux/web. |
| [`path_drawing`](https://pub.dev/packages/path_drawing) | ^1.0.1 | Needed for dashed lines *on the Flutter side*, see §2.6. |
| [`file_selector`](https://pub.dev/packages/file_selector) | current | Save dialogs, §6. |

Recent changelog ([full](https://pub.dev/packages/pdf/changelog)), relevant entries:

- **3.13.0**: `PdfException` added across PDF classes; SVG path parser hardened against malformed docs; XML dep bump; min SDK 3.12.0.
- **3.12.0**, **table layout performance improvements** (confirms `IntrinsicColumnWidth` was a hotspot, §4.2); bounding-box-from-children fix; CMYK + Adobe APP14 JPEG; compound glyph offset fix; vector_math 2.2.0.
- **3.11.2**: custom fonts in SVGs; PDF/A-3b; **`MultiPage.maxPages` validation fixed in release builds**; text-style/cell-content replacement helpers.
- **3.11.0**: **saving in an isolate when available**; `NewPage` gained `freeSpace`.

### 1.2 The widget layout system

Deliberately a Flutter mimic, in a separate namespace, always `import 'package:pdf/widgets.dart' as pw;`. It is *not* Flutter widgets: no `BuildContext`, no state, no `Key`, single synchronous layout pass.

```dart
import 'package:pdf/pdf.dart';           // PdfColor, PdfPageFormat, PdfGraphics, PdfPoint
import 'package:pdf/widgets.dart' as pw; // the widget layer

final doc = pw.Document(
  title: 'RackPal — Rack 1 Interconnect',
  author: 'RackPal',
  creator: 'RackPal 1.0',
  subject: 'A/V rack wiring plan',
);

doc.addPage(pw.Page(
  pageFormat: PdfPageFormat.a4,
  build: (pw.Context context) => pw.Center(child: pw.Text('Hello')),
));
```

**`pw.Page`**: one fixed page, content clipped if it overflows.
**`pw.MultiPage`**: flows a `List<Widget>` across pages. Verified constructor params:

```dart
pw.MultiPage({
  PageTheme? pageTheme,
  PdfPageFormat? pageFormat,
  required BuildListCallback build,   // List<Widget> Function(Context)
  BuildCallback? header,              // Widget Function(Context)
  BuildCallback? footer,
  EdgeInsets? margin,
  CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start,
  MainAxisAlignment mainAxisAlignment  = MainAxisAlignment.start,
  int maxPages = 20,                  // ← raise this, see §4.4
  PageOrientation? orientation,
  TextDirection? textDirection,
})
```

**Splitting rule (the thing that bites everyone):** most widgets are *inseparable*; they must fit entirely on one page or they push a new page. Only **spanning widgets** split across a page boundary: `pw.Flex`, `pw.Column`, `pw.Partition`, `pw.Table`, `pw.Wrap`, `pw.GridView`. Wrap a giant `pw.Container` around your schedule and you'll get `Widget won't fit into the page as its height (823.4) exceeds a page height (728.5)` ([#114](https://github.com/DavBfr/dart_pdf/issues/114)).

**Page numbers** come from `pw.Context`, which exposes `document` (`PdfDocument`), `page` (`PdfPage`), `canvas` (`PdfGraphics`), `pageNumber` (`int`), `pagesCount` (`int`), `pageLabel` (`String`, read/write). `pagesCount` is only correct on the *final* layout pass, `MultiPage` lays out twice for exactly this reason:

```dart
footer: (ctx) => pw.Row(
  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
  children: [
    pw.Text('RackPal — Smith Residence'),
    pw.Text('SHEET ${ctx.pageNumber} OF ${ctx.pagesCount}'),
  ],
),
```

`pw.Header` and `pw.Footer` also exist as *styled convenience widgets* (title + decoration), distinct from the `header:`/`footer:` callbacks. Don't confuse them.

### 1.3 Custom page formats and landscape

`PdfPageFormat`, verified source:

```dart
const PdfPageFormat(double width, double height, {
  double marginTop = 0.0, double marginBottom = 0.0,
  double marginLeft = 0.0, double marginRight = 0.0,
  double? marginAll,
});

static const point = 1.0;
static const inch  = 72.0;
static const cm    = inch / 2.54;   // 28.346…
static const mm    = inch / 25.4;   // 2.8346…
static const dp    = 72.0 / 150.0;  // Flutter logical pixel

PdfPageFormat get landscape => width >= height ? this : copyWith(width: height, height: width);
PdfPageFormat get portrait  => height >= width ? this : copyWith(width: height, height: width);
```

Ships only: `a3, a4, a5, a6, letter, legal, roll57, roll80, standard (=a4), undefined`. **No ANSI B/C/D/E, no ARCH, no A2/A1/A0.** Define them (§3.1).

Properties: `width`, `height`, `availableWidth`, `availableHeight`, `dimension`/`availableDimension` (→ `PdfPoint`). Methods: `copyWith`, `applyMargin`, `landscape`, `portrait`.

### 1.4 Fonts: and why Helvetica fails

The 14 standard Type1 fonts (Helvetica ×4, Times ×4, Courier ×4, Symbol, ZapfDingbats) are **not embedded**, zero file-size cost, but they are single-byte **WinAnsiEncoding**. Any codepoint outside Latin-1 throws:

```
Exception: Helvetica has no Unicode support see https://github.com/DavBfr/dart_pdf/wiki/Fonts-Management
```

This is the single most-reported issue in the repo ([#76](https://github.com/DavBfr/dart_pdf/issues/76), [#196](https://github.com/DavBfr/dart_pdf/issues/196), [#252](https://github.com/DavBfr/dart_pdf/issues/252), [#384](https://github.com/DavBfr/dart_pdf/issues/384), [#405](https://github.com/DavBfr/dart_pdf/issues/405), [#810](https://github.com/DavBfr/dart_pdf/issues/810), [#1538](https://github.com/DavBfr/dart_pdf/issues/1538)).

**For RackPal this is not theoretical.** A/V documentation routinely contains `Ω` (speaker impedance), `°` (temperature/angle), `±`, `µ`, `→`, `×`, `≈`, `—` (em dash), `“ ”` smart quotes pasted from a proposal, and client names with accents. **Never ship default Helvetica.**

Two routes:

```dart
// A) Bundled TTF asset — deterministic, offline, reproducible. RECOMMENDED.
final base = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Regular.ttf'));
final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-SemiBold.ttf'));
final mono = pw.Font.ttf(await rootBundle.load('assets/fonts/JetBrainsMono-Regular.ttf'));

// B) printing's Google Fonts — network fetch, in-memory cache by default
final base = await PdfGoogleFonts.interRegular();
final emoji = await PdfGoogleFonts.notoColorEmoji();
```

Route B does a **network round-trip**, which means it cannot run inside a background isolate and will fail offline, a real problem for a rack-room laptop with no Wi-Fi. Use route A. (`PdfGoogleFonts` caching is overridable by extending `PdfBaseCache` for on-disk persistence, but bundling is simpler.)

Apply document-wide:

```dart
final theme = pw.ThemeData.withFont(
  base: base, bold: bold, italic: italic, boldItalic: boldItalic,
  fontFallback: [mono, symbols],   // per-glyph fallback chain
);
doc.addPage(pw.MultiPage(theme: theme, /* or pageTheme: pw.PageTheme(theme: theme) */ ...));
```

`fontFallback` is per-glyph and is your safety net for stray symbols. Set it even when you think you don't need it.

**Subsetting:** dart_pdf subsets TrueType fonts to used glyphs, so a full Inter (~300 KB) contributes only a few KB. Mono + sans + bold ≈ 15–40 KB total in a typical rack drawing. Fine.

---

## 2. Vector output and the shared-renderer question

> **This is the most important section. Direct answer first:**
> **There is no existing package, interface, or documented pattern that lets one body of drawing code target both `dart:ui Canvas` and `PdfGraphics`.** I searched pub.dev, the dart_pdf repo, and community discussion. dart_pdf ships no Canvas-compatible facade. Syncfusion's `PdfGraphics` is a *different, incompatible* API (and commercially licensed). The only real answers are (a) write a ~250-line adapter yourself, (b) route through SVG, or (c) rasterise. **(a) is correct for RackMate**, and it is genuinely small. Below is the design.

### 2.1 The raw PDF drawing API

`PdfGraphics` ([API](https://pub.dev/documentation/pdf/latest/pdf/PdfGraphics-class.html)), verified signatures:

```dart
// Path construction (STATEFUL — builds a current path on the context)
void moveTo(double x, double y);
void lineTo(double x, double y);
void curveTo(double x1, double y1, double x2, double y2, double x3, double y3); // cubic Bézier
void closePath();

// Shape shorthands (append to current path)
void drawLine(double x1, double y1, double x2, double y2);
void drawRect(double x, double y, double w, double h);          // (x,y) = BOTTOM-left
void drawEllipse(double x, double y, double r1, double r2, {bool clockwise = true});
void drawShape(String d);                                        // ← SVG path 'd' string!
void drawImage(PdfImage img, double x, double y, [double? w, double? h]);
void drawString(PdfFont font, double size, String s, double x, double y, {...});

// Painting the built path
void fillPath({bool evenOdd = false});
void strokePath({bool close = false});
void clipPath({bool evenOdd = false, bool end = true});

// Graphics state
void setStrokeColor(PdfColor? color);
void setFillColor(PdfColor? color);
void setLineWidth(double width);
void setLineDashPattern([List<num> array = const <num>[], int phase = 0]);
void setLineCap(PdfLineCap cap);
void setLineJoin(PdfLineJoin join);
void setTransform(Matrix4 t);
void saveContext();
void restoreContext();
```

Two things worth flagging immediately:

- **`drawShape(String d)` accepts an SVG path data string.** This is an escape hatch, any geometry you can express as SVG `d` you can emit in one call. Useful for connector symbols and arrowheads defined once as path strings shared with the on-screen renderer.
- **`setTransform` is misnamed.** It emits the PDF `cm` operator, which **concatenates** with the current transformation matrix. It behaves like `Canvas.transform()`, not like an absolute set. Bracket it with `saveContext`/`restoreContext`.

### 2.2 The API mismatch: what an adapter must reconcile

| Concern | `dart:ui Canvas` | `PdfGraphics` | Adapter burden |
|---|---|---|---|
| Origin | top-left, **Y down** | bottom-left, **Y up** | Convert. §2.5 |
| Paint model | immutable `Paint` passed per call | **stateful** setters then `strokePath()` | Adapter owns state |
| Path model | build `Path`, then `drawPath(path, paint)` | stateful `moveTo`/`lineTo` then `fillPath()` | Adapter replays |
| Fill **and** stroke | one `Paint`, two passes | build path **twice**, or `fillPath` then re-build | Adapter duplicates |
| Rect anchor | `Rect` = top-left + size | `drawRect` y = **bottom** edge | `y' = H - top - height` |
| **Dashes** | **none: dart:ui has no dash support** | native `setLineDashPattern` | Synthesize on Flutter side. §2.6 |
| Text | `TextPainter` (shaping, wrapping) | `drawString` (no wrap, baseline origin) | Constrain to single-line. §2.7 |
| Colors | `ui.Color` (ARGB int) | `PdfColor` (4× double 0…1) | `PdfColor.fromInt(argb)` |
| Save/restore | `save()` / `restore()` | `saveContext()` / `restoreContext()` (`q`/`Q`) | 1:1 |
| Blend/shaders | full | `PdfGraphicState(opacity:)` only, no shaders | **Don't use gradients in the diagram.** |

That last row is a genuine design constraint: **restrict your diagram visual language to flat fills, strokes, dashes, and text.** No gradients, no shadows, no blurs. This is not a hardship, it's exactly the schematic aesthetic you want, and it makes the two backends agree perfectly.

### 2.3 Recommended architecture: display list + two interpreters

Don't hand a `DiagramCanvas` to your layout code directly. Instead have the renderer produce an **immutable display list**, then walk it with backend-specific interpreters. This costs one extra indirection and buys four things you need anyway:

1. **`bounds`**: you cannot compute scale-to-fit or tile counts without the diagram's true extent (§3).
2. **Hit-testing**: the editor needs to know what's under the cursor; a geometric op list gives you this for free.
3. **Golden tests on pure data**: assert on the op list with no Flutter binding, no PDF, no pixels. Enormous testability win.
4. **A third backend later** (SVG export, DXF, a web canvas) costs one file.

```
RackProject (model)
        │  buildScene(project, style)      ← ONE renderer, pure Dart, no dart:ui, no pdf
        ▼
   DiagramScene { List<DiagramOp> ops; Box bounds; List<HitRegion> hits; }
        │
        ├──► FlutterDiagramCanvas  (dart:ui Canvas)  → CustomPainter → screen
        ├──► PdfDiagramCanvas      (PdfGraphics)     → pw.CustomPaint → PDF
        └──► SvgDiagramCanvas      (StringBuffer)    → optional
```

### 2.4 Code sketch

**Value types: no `dart:ui`, no `pdf` imports.** This matters: your stated roadmap includes cloud sync, and if you ever want *server-side* export, `dart:ui` types would strand the renderer in Flutter. Ten lines of `Pt`/`Box` buys you a headless exporter later.

```dart
// diagram/geometry.dart  — pure Dart
class Pt  { final double x, y; const Pt(this.x, this.y); }
class Box { final double left, top, width, height; const Box(...);
            double get right => left + width; double get bottom => top + height; }

// diagram/style.dart — pure Dart
enum CableType { rca, hdmi, network, ir, rs232, coax, spdif, toslink, speaker, power, other }
enum FontRef { body, bold, mono }
enum TextAnchor { topLeft, topCenter, centerLeft, center, centerRight, baselineLeft }

class StrokeSpec {
  final int argb;               // 0xAARRGGBB
  final double width;           // in points
  final List<double>? dash;     // null => solid
  final bool scaleInvariant;    // keep hairline width under scale-to-fit (§3.2)
  const StrokeSpec(...);
}
class FillSpec { final int argb; const FillSpec(this.argb); }
class TextSpec {
  final double size; final int argb; final FontRef font;
  final TextAnchor anchor; final double rotation;   // radians, CW in screen space
  const TextSpec(...);
}
```

**The interface. Coordinates are ALWAYS top-left origin, Y-down, 1 unit = 1 PDF point = 1/72".** Adopting PDF points as your diagram unit means zero conversion on export and a natural 1:1 default zoom on screen.

```dart
// diagram/canvas.dart — pure Dart
abstract interface class DiagramCanvas {
  void save();
  void restore();
  void translate(double dx, double dy);
  void scale(double sx, double sy);
  void rotate(double radians);
  void clipRect(Box r);

  void drawLine(Pt a, Pt b, StrokeSpec s);
  void drawPolyline(List<Pt> pts, StrokeSpec s);          // orthogonal traces
  void drawRect(Box r, {FillSpec? fill, StrokeSpec? stroke});
  void drawRRect(Box r, double radius, {FillSpec? fill, StrokeSpec? stroke});
  void drawCircle(Pt c, double r, {FillSpec? fill, StrokeSpec? stroke});
  void drawSvgPath(String d, {FillSpec? fill, StrokeSpec? stroke}); // symbols
  void drawText(String s, Pt at, TextSpec spec);
  Pt   measureText(String s, TextSpec spec);
}
```

`drawSvgPath` is deliberate: `PdfGraphics.drawShape(d)` is native, and `path_drawing`'s `parseSvgPathData(d)` gives you a `ui.Path` on the Flutter side. Define every connector symbol (RCA, XLR, RJ45, HDMI, IEC, binding post) once as a `d` string constant and both backends render it identically. That single decision eliminates most of the duplication risk.

**The display list:**

```dart
sealed class DiagramOp { void replay(DiagramCanvas c); }

final class OpLine extends DiagramOp {
  final Pt a, b; final StrokeSpec s;
  const OpLine(this.a, this.b, this.s);
  @override void replay(DiagramCanvas c) => c.drawLine(a, b, s);
}
final class OpRect extends DiagramOp {
  final Box r; final FillSpec? fill; final StrokeSpec? stroke;
  @override void replay(DiagramCanvas c) => c.drawRect(r, fill: fill, stroke: stroke);
}
// … OpPolyline, OpText, OpSvgPath, OpSave, OpRestore, OpTranslate, OpScale, OpClip

class DiagramScene {
  final List<DiagramOp> ops;
  final Box bounds;                 // drives scale-to-fit and tiling
  final List<HitRegion> hits;       // drives editor selection
  const DiagramScene(this.ops, this.bounds, this.hits);
  void replay(DiagramCanvas c) { for (final op in ops) op.replay(c); }
}
```

**Flutter backend:**

```dart
// diagram/backends/flutter_canvas.dart
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import 'package:path_drawing/path_drawing.dart';

class FlutterDiagramCanvas implements DiagramCanvas {
  FlutterDiagramCanvas(this._c, {this.strokeScale = 1.0});
  final ui.Canvas _c;
  final double strokeScale;   // for scaleInvariant strokes, pass 1/k

  ui.Paint _strokePaint(StrokeSpec s) => ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..color = ui.Color(s.argb)
    ..strokeWidth = s.scaleInvariant ? s.width * strokeScale : s.width
    ..strokeCap = ui.StrokeCap.butt
    ..strokeJoin = ui.StrokeJoin.miter
    ..isAntiAlias = true;

  @override
  void drawLine(Pt a, Pt b, StrokeSpec s) {
    if (s.dash == null) {
      _c.drawLine(ui.Offset(a.x, a.y), ui.Offset(b.x, b.y), _strokePaint(s));
      return;
    }
    // dart:ui has NO dash support — synthesize it.
    final p = ui.Path()..moveTo(a.x, a.y)..lineTo(b.x, b.y);
    _c.drawPath(
      dashPath(p, dashArray: CircularIntervalList<double>(s.dash!)),
      _strokePaint(s),
    );
  }

  @override
  void drawText(String t, Pt at, TextSpec sp) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: TextStyle(
        fontFamily: _familyFor(sp.font),   // MUST be the same TTF as the PDF — §2.7
        fontSize: sp.size, color: ui.Color(sp.argb), height: 1.0)),
      textDirection: TextDirection.ltr,
    )..layout();
    final o = _anchorOffset(sp.anchor, tp.width, tp.height);
    _c..save()..translate(at.x, at.y)..rotate(sp.rotation);
    tp.paint(_c, ui.Offset(o.x, o.y));
    _c.restore();
  }
  // … remainder mechanical
}
```

**PDF backend:**

```dart
// diagram/backends/pdf_canvas.dart
import 'package:pdf/pdf.dart';

class PdfDiagramCanvas implements DiagramCanvas {
  PdfDiagramCanvas(this._g, this._h, this._fonts);
  final PdfGraphics _g;
  final double _h;                       // height of the *drawing box*, not the page — see §2.5
  final Map<FontRef, PdfFont> _fonts;

  double _y(double y) => _h - y;         // Y-down → PDF Y-up
  static PdfColor _col(int argb) => PdfColor.fromInt(argb);

  void _applyStroke(StrokeSpec s) {
    _g..setStrokeColor(_col(s.argb))
      ..setLineWidth(s.width)
      ..setLineCap(PdfLineCap.butt)
      ..setLineJoin(PdfLineJoin.miter)
      ..setLineDashPattern(s.dash ?? const <num>[]);   // [] restores solid
  }

  @override
  void drawLine(Pt a, Pt b, StrokeSpec s) {
    _g.saveContext();
    _applyStroke(s);
    _g..drawLine(a.x, _y(a.y), b.x, _y(b.y))..strokePath();
    _g.restoreContext();
  }

  @override
  void drawRect(Box r, {FillSpec? fill, StrokeSpec? stroke}) {
    final yb = _y(r.top) - r.height;     // PDF drawRect wants the BOTTOM edge
    if (fill != null) {
      _g..saveContext()..setFillColor(_col(fill.argb))
        ..drawRect(r.left, yb, r.width, r.height)..fillPath()..restoreContext();
    }
    if (stroke != null) {
      _g.saveContext(); _applyStroke(stroke);
      _g..drawRect(r.left, yb, r.width, r.height)..strokePath()..restoreContext();
    }
  }

  @override
  void drawText(String t, Pt at, TextSpec sp) {
    final f = _fonts[sp.font]!;
    final m = f.stringMetrics(t) * sp.size;   // ← verify signature, see §2.7
    final o = _anchorOffset(sp.anchor, m.width, m.maxHeight);
    _g.saveContext();
    _g.setFillColor(_col(sp.argb));
    if (sp.rotation != 0) {
      final mat = Matrix4.identity()
        ..translateByDouble(at.x, _y(at.y), 0, 1)
        ..rotateZ(-sp.rotation);             // note sign: PDF Y-up inverts rotation sense
      _g.setTransform(mat);
      _g.drawString(f, sp.size, t, o.x, -o.y - m.descent);
    } else {
      _g.drawString(f, sp.size, t, at.x + o.x, _y(at.y + o.y) - m.descent);
    }
    _g.restoreContext();
  }
}
```

**Wiring it into the document:**

```dart
final painterFn = (PdfGraphics g, PdfPoint size) {
  scene.replay(PdfDiagramCanvas(g, size.y, fonts));   // size.y — critical, see below
};

doc.addPage(pw.Page(
  pageFormat: ansiB.landscape,
  build: (ctx) => pw.CustomPaint(size: PdfPoint(w, h), painter: painterFn),
));
```

### 2.5 The coordinate system: and a non-obvious `pw.CustomPaint` gotcha

Verified `CustomPaint` typedef:

```dart
typedef CustomPainter = Function(PdfGraphics canvas, PdfPoint size);

class CustomPaint extends SingleChildWidget {
  CustomPaint({this.painter, this.foregroundPainter, this.size = PdfPoint.zero, Widget? child});
}
```

From the widget's `paint()` source:

```dart
final mat = Matrix4.identity();
mat.translateByDouble(box!.left, box!.bottom, 0, 1);
context.canvas..saveContext()..setTransform(mat);
// painter(canvas, size) …  child …  foregroundPainter(canvas, size)
context.canvas.restoreContext();
```

**⚠️ The canvas is already translated to the widget box's bottom-left, and the origin inside your painter is that corner: not the page corner.** Therefore the `_h` you pass to `PdfDiagramCanvas` for the Y-flip must be **`size.y` (the widget's height)**, not the page height. Getting this wrong produces a diagram that is silently offset vertically by the margin, one of those bugs that eats an afternoon.

**Two flip strategies:**

- **Per-coordinate `_y()` (shown above): recommended.** ~10 lines, no global transform, and critically **text stays upright automatically**.
- **Global flip:** `setTransform(Matrix4.identity()..translate(0, h)..scale(1, -1, 1))` once, then emit Y-down coordinates verbatim. Cleaner for arbitrary geometry, **but every `drawString` renders mirrored**. You must counter-flip locally around each text run (`saveContext` → `setTransform(translate(x,y) * scale(1,-1))` → `drawString(0,0)` → `restoreContext`). For a label-dense schematic that's a lot of extra q/Q pairs and a lot of places to get wrong.

Given a rack diagram is dominated by axis-aligned rects, orthogonal polylines, and horizontal labels, **take the per-coordinate route.**

### 2.6 The dash gotcha

`PdfGraphics.setLineDashPattern([3, 2], 0)` is native and cheap. **`dart:ui Canvas` has no dashing whatsoever.** If you don't handle this, your dashed cable types (a natural way to encode, say, "planned vs. existing" or IR vs. RS-232) render solid on screen and dashed in the PDF, a screen/print mismatch that will get reported as a bug.

Fix: `path_drawing`'s `dashPath(Path, dashArray: CircularIntervalList<double>([...]))` in the Flutter backend, as shown. It re-synthesises the path on every paint, so for a diagram with hundreds of dashed segments, cache the dashed `ui.Path` per unique (geometry, dash) pair. Note also that dash *phase* semantics differ slightly (PDF's `phase` is an offset into the pattern; `dashPath` restarts per sub-path), if perfect parity matters, keep phase at 0.

### 2.7 Text metrics parity

`PdfGraphics.drawString` does **no wrapping and no shaping**: one line, baseline origin. Measurement is via `PdfFont.stringMetrics(String)` → `PdfFontMetrics` (`left, top, right, bottom, ascent, descent, advanceWidth, leftBearing`), in **em units**, so multiply by `fontSize`. There is no `TextPainter` equivalent ([#378](https://github.com/DavBfr/dart_pdf/issues/378)).

> ⚠️ **Verify** the exact `stringMetrics` signature and whether the `* fontSize` operator overload exists in 3.13.0 before relying on it — the API docs confirm `PdfFontMetrics` and its fields, but I did not read the operator definitions directly.

**The parity rule: bundle the same TTF file and register it to Flutter *and* load it into `pw.Font.ttf`.** Same file, same glyph advances, metrics agree to within rounding. If you use a system font on screen and a different one in the PDF, every label's measured width differs and your leader lines, callout boxes, and collision avoidance will disagree between screen and print.

```yaml
# pubspec.yaml
flutter:
  fonts:
    - family: RackBody
      fonts:
        - asset: assets/fonts/Inter-Regular.ttf
        - asset: assets/fonts/Inter-SemiBold.ttf
          weight: 600
    - family: RackMono
      fonts:
        - asset: assets/fonts/JetBrainsMono-Regular.ttf
  assets:
    - assets/fonts/     # ← also declare as assets so rootBundle.load() works for pw.Font.ttf
```

That last line is easy to miss: declaring under `fonts:` makes it available to Flutter's text engine but **not** to `rootBundle.load()`. You need both entries.

A monospace font for reference designators, port numbers, and cable IDs is worth it, column alignment in a schematic reads far better, and it matches the electronics-schematic aesthetic you're after.

### 2.8 Alternative: SVG as the intermediate representation

`pw.SvgImage(svg: svgString)` renders SVG as **true vector** in the PDF; `flutter_svg` / `vector_graphics` renders the same string on screen. One renderer (emit SVG), zero adapter code, stays vector end-to-end.

**Good for export. Bad as your editing path.** An interactive editor needs hit-testing, selection highlight, drag feedback, and partial repaint, none of which an opaque SVG string gives you. You'd end up maintaining a parallel geometry model for interaction anyway, which is exactly the duplication you're trying to avoid. Also, dart_pdf's SVG parser supports a *subset* of SVG 1.1 (3.13.0's changelog notes ongoing hardening of the path parser against malformed documents), so you'd be testing against two different SVG implementations.

**Where it does earn its place:** as a *third* backend off the display list (`SvgDiagramCanvas implements DiagramCanvas` writing to a `StringBuffer`), giving you SVG export for free, genuinely useful for CI folks who want to drop the diagram into a proposal or a Visio/Illustrator workflow. ~120 lines on top of an architecture you already have.

### 2.9 Alternative: raster: and the DPI math for why not

`RepaintBoundary` → `RenderRepaintBoundary.toImage(pixelRatio:)` → PNG → `pw.MemoryImage`.

**Run the numbers for an 11×17 sheet at 300 dpi:**

| | px | Mpx | RGBA bytes |
|---|---|---|---|
| ANSI A (8.5×11) @300 | 2550 × 3300 | 8.4 | 33.7 MB |
| **ANSI B (11×17) @300** | **3300 × 5100** | **16.8** | **67.3 MB (64.2 MiB)** |
| ANSI B @600 (laser native) | 6600 × 10200 | 67.3 | 269 MB |
| ANSI D (22×34) @300 | 6600 × 10200 | 67.3 | 269 MB |

- PDF user space = 1/72". An 11×17 page = **792 × 1224 pt**. To hit 300 dpi you need `pixelRatio = 300/72 = 4.167`.
- The decoded `ui.Image` is 64 MiB; PNG encoding needs a second buffer → **peak ~135 MB for one sheet.** Multiply by a multi-sheet set.
- **5100 px exceeds the 4096 max texture dimension** on a large installed base of GPUs (older Intel iGPUs, many Android devices). Flutter silently clamps or fails; this is exactly [flutter/flutter#118024](https://github.com/flutter/flutter/issues/118024), [#116957](https://github.com/flutter/flutter/issues/116957), and [#21269](https://github.com/flutter/flutter/issues/21269). You get a quietly downscaled, blurry sheet with no error.
- **6 pt schematic text at 300 dpi is 25 px tall** and antialiased into mush. Vector text is resolution-independent and stays sharp at any zoom in the viewer and at any RIP resolution.
- **You lose text selection, search, and copy.** An integrator handing a wiring schedule to a subcontractor who can't `Ctrl+F` for a cable ID is a materially worse deliverable. Same for anyone pulling port labels into a spreadsheet.
- **File size:** vector rack diagram ≈ 80–400 KB. 300 dpi PNG-in-PDF ≈ 3–15 MB *per sheet*.

**Conclusion: raster is disqualified for the primary deliverable.** Keep `RepaintBoundary` only for a low-res thumbnail (project browser tile, or a "key plan" inset, see §3.3), where 1× is plenty.

---

## 3. Fitting a large diagram onto pages

### 3.1 Sheet sizes you'll have to define yourself

```dart
// diagram/sheets.dart
const _in = PdfPageFormat.inch;

// ANSI / ASME Y14.1
const ansiA = PdfPageFormat(8.5 * _in, 11 * _in, marginAll: 0.5 * _in);   // 612 × 792
const ansiB = PdfPageFormat(11  * _in, 17 * _in, marginAll: 0.5 * _in);   // 792 × 1224  ← tabloid
const ansiC = PdfPageFormat(17  * _in, 22 * _in, marginAll: 0.5 * _in);   // 1224 × 1584
const ansiD = PdfPageFormat(22  * _in, 34 * _in, marginAll: 0.5 * _in);   // 1584 × 2448
const ansiE = PdfPageFormat(34  * _in, 44 * _in, marginAll: 0.5 * _in);   // 2448 × 3168

// ARCH
const archB = PdfPageFormat(12 * _in, 18 * _in, marginAll: 0.5 * _in);    // 864 × 1296
const archC = PdfPageFormat(18 * _in, 24 * _in, marginAll: 0.5 * _in);    // 1296 × 1728
const archD = PdfPageFormat(24 * _in, 36 * _in, marginAll: 0.5 * _in);    // 1728 × 2592

// ISO (a3/a4 ship; larger don't)
const isoA2 = PdfPageFormat(420 * PdfPageFormat.mm, 594 * PdfPageFormat.mm, marginAll: 10 * PdfPageFormat.mm);
const isoA1 = PdfPageFormat(594 * PdfPageFormat.mm, 841 * PdfPageFormat.mm, marginAll: 10 * PdfPageFormat.mm);
```

**Recommendation for RackPal:** default to **ANSI B (11×17) landscape** for diagram sheets and **ANSI A portrait** for the schedule, with the sheet size user-selectable per export. Rationale: 11×17 is the largest size that comes out of a common office MFP, plots cheaply anywhere, **folds exactly to letter** for a job binder, and is the de facto residential-CI documentation size. ANSI D/ARCH D matter only for commercial jobs going to a plotter. Offer ISO A3/A2 for non-US users, same reasoning, A3 is the 11×17 analogue.

Note the rack elevation is a different shape problem: 45 RU × 1.75"/RU = **78.75 inches tall**. At 1:8 it's ~9.8", fits ANSI B portrait comfortably. Elevations want portrait; interconnect diagrams want landscape. Let them differ within one document (`pw.Page` takes a per-page `pageFormat`).

### 3.2 Scale-to-fit

```dart
void paintFitted(DiagramCanvas c, DiagramScene s, Box avail) {
  final k = math.min(avail.width / s.bounds.width, avail.height / s.bounds.height);
  c.save();
  c.translate(
    avail.left + (avail.width  - s.bounds.width  * k) / 2 - s.bounds.left * k,
    avail.top  + (avail.height - s.bounds.height * k) / 2 - s.bounds.top  * k,
  );
  c.scale(k, k);
  s.replay(c);
  c.restore();
}
```

**Two things to get right:**

- **Line weights scale too.** A 0.5 pt hairline at k=0.3 becomes 0.15 pt, below what most RIPs and many screens render meaningfully, and it looks anemic. This is what the `scaleInvariant` flag on `StrokeSpec` is for: the backend divides by `k` so borders and hairlines hold a floor (~0.25 pt / 0.35 mm is the usual minimum). Cable runs *should* scale; the drawing border and grid should not.
- **Text scales too, and below ~5 pt it's unreadable in print.** Compute `k` first, then if `k * minTextSize < 5.0`, refuse to fit on one sheet and go to multi-sheet. Make this the *automatic* trigger for tiling rather than a user decision, the user's actual question is "is it legible", not "how many sheets".

### 3.3 Multi-sheet: how professional drawing sets actually do it

Per **ASME Y14.1** (drawing sizes/format) and **Y14.100** (engineering drawing practices):

- Match lines between adjacent sheets **must align exactly**; feature lines terminate at the match line.
- The **total sheet count appears on sheet 1 only**; subsequent sheets carry only their own number. (Though "SHEET n OF m" everywhere is now near-universal and friendlier, `pagesCount` gives it to you free.)
- Zone grid on the border: letters **A–D** down the vertical edges, numbers **1–8** across the horizontal, so anything can be referenced as "zone C4".

**Geometric tiling:**

```dart
final scale = chosenScale;                       // e.g. 1:8 for elevations
final tileW = sheet.availableWidth  / scale;     // diagram units per sheet
final tileH = sheet.availableHeight / scale;
final overlap = 0.5 * PdfPageFormat.inch / scale;   // 0.5" overlap band
final cols = ((scene.bounds.width  - overlap) / (tileW - overlap)).ceil();
final rows = ((scene.bounds.height - overlap) / (tileH - overlap)).ceil();

for (var r = 0; r < rows; r++) {
  for (var col = 0; col < cols; col++) {
    final win = Box(bounds.left + col * (tileW - overlap),
                    bounds.top  + r   * (tileH - overlap), tileW, tileH);
    doc.addPage(pw.Page(
      pageFormat: sheet,
      pageTheme: sheetTheme,                     // border + title block, §5
      build: (ctx) => pw.CustomPaint(
        size: PdfPoint(sheet.availableWidth, sheet.availableHeight),
        painter: (g, size) {
          final c = PdfDiagramCanvas(g, size.y, fonts);
          c..save()..clipRect(Box(0, 0, size.x, size.y))
           ..scale(scale, scale)..translate(-win.left, -win.top);
          scene.replay(c);
          c.restore();
          drawMatchLines(c, win, col, r, cols, rows);   // "MATCH LINE — SEE SHEET n"
          drawKeyPlan(c, scene.bounds, win, size);      // thumbnail w/ current tile highlighted
        },
      ),
    ));
  }
}
```

The **key plan** (a small outline of the whole diagram in the corner of every sheet with the current tile hatched) is what makes a tiled set navigable. It's cheap: replay the scene at tiny scale into a 1.5" box with stroke-only specs, or use the low-res raster thumbnail (this is the one legitimate use for `RepaintBoundary`).

**But for RackPal, geometric tiling is usually the wrong answer.**

You've said the wiring planner takes inspiration from schematics and netlists. **Real schematic capture tools (Altium, KiCad, OrCAD) do not tile geometrically: they partition by subsystem and use off-sheet connectors.** That is a much better fit for a wiring plan:

- Sheet 1, **rack elevation(s)**, reference designators assigned.
- Sheet 2, **video nets** (HDMI, coax/RG6).
- Sheet 3, **audio nets** (analog RCA, S/PDIF, TOSLINK, speaker level).
- Sheet 4, **control & network** (RJ45, IR, RS-232).
- Sheet 5, **power** (UPS, sequencer, IEC runs).
- Sheet 6, **Structure** device: all structured-wiring home runs to the rest of the building.
- Sheet 7+, **wiring schedule** table.

A net leaving a sheet gets the classic **off-sheet connector**: a pentagon/flag symbol carrying the net name and a `→ SHEET 4, ZONE B3` reference, with a matching flag on the destination sheet pointing back. The cable-type colour coding then becomes a *per-sheet* organising principle rather than a rainbow, and each sheet is legible at full scale with no shrinking at all.

This also maps naturally onto your colour-coding requirement and onto how an installer actually works, they pull all the Cat6 in one pass, then all the speaker wire. **Offer both**, default to net-partitioned, and let geometric tiling be the fallback for a single enormous interconnect the user insists on seeing whole.

---

## 4. Long tables: the wiring schedule

### 4.1 The basic shape

`TableHelper.fromTextArray`, verified full signature (29 params, only `data` required):

```dart
static Table fromTextArray({
  Context? context,
  required List<List<dynamic>> data,
  EdgeInsetsGeometry cellPadding = const EdgeInsets.all(5),
  double cellHeight = 0,
  AlignmentGeometry cellAlignment = Alignment.topLeft,
  Map<int, AlignmentGeometry>? cellAlignments,
  TextStyle? cellStyle,
  TextStyle? oddCellStyle,
  OnCellFormat? cellFormat,
  OnCellDecoration? cellDecoration,
  int headerCount = 1,
  List<dynamic>? headers,
  EdgeInsetsGeometry? headerPadding,
  double? headerHeight,
  AlignmentGeometry headerAlignment = Alignment.center,
  Map<int, AlignmentGeometry>? headerAlignments,
  TextStyle? headerStyle,
  OnCellFormat? headerFormat,
  TableBorder? border = const TableBorder(...),
  Map<int, TableColumnWidth>? columnWidths,
  TableColumnWidth defaultColumnWidth = const IntrinsicColumnWidth(),
  TableWidth tableWidth = TableWidth.max,
  BoxDecoration? headerDecoration,
  BoxDecoration? headerCellDecoration,
  BoxDecoration? rowDecoration,
  BoxDecoration? oddRowDecoration,
  TextDirection? headerDirection,
  TextDirection? tableDirection,
  OnCell? cellBuilder,
  OnCellTextStyle? textStyleBuilder,
})
```

```dart
doc.addPage(pw.MultiPage(
  pageFormat: ansiA,
  pageTheme: schedulePageTheme,
  maxPages: 500,                                     // ← §4.4
  header: (ctx) => sheetHeader(ctx, 'WIRING SCHEDULE'),
  footer: (ctx) => pw.Align(alignment: pw.Alignment.centerRight,
      child: pw.Text('SHEET ${ctx.pageNumber} OF ${ctx.pagesCount}',
                     style: const pw.TextStyle(fontSize: 8))),
  build: (ctx) => [
    pw.TableHelper.fromTextArray(
      context: ctx,
      headerCount: 1,
      headers: const ['CABLE ID','TYPE','FROM DEV','FROM PORT','TO DEV','TO PORT','LEN','NOTES'],
      data: rows,                                    // List<List<String>>
      border: pw.TableBorder.all(width: 0.4, color: PdfColors.grey600),
      headerStyle: pw.TextStyle(font: bold, fontSize: 8, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF37474F)),
      cellStyle: pw.TextStyle(font: mono, fontSize: 8),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF2F4F6)), // zebra
      cellHeight: 14,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      cellAlignments: {0: pw.Alignment.centerLeft, 6: pw.Alignment.centerRight},
      // per-cell colour swatch keyed to cable type — ties the schedule to the diagram
      cellDecoration: (col, data, row) => col == 1
          ? pw.BoxDecoration(color: cableTypeColor(rows[row][1]))
          : const pw.BoxDecoration(),
      columnWidths: const {
        0: pw.FixedColumnWidth(52),  1: pw.FixedColumnWidth(46),
        2: pw.FlexColumnWidth(2),    3: pw.FlexColumnWidth(1.2),
        4: pw.FlexColumnWidth(2),    5: pw.FlexColumnWidth(1.2),
        6: pw.FixedColumnWidth(34),  7: pw.FlexColumnWidth(2),
      },
    ),
  ],
));
```

`cellDecoration` giving you a per-cell colour swatch is the neat trick here: the TYPE column becomes a colour chip matching the diagram's cable colour, so the schedule and the drawing are visually cross-referenced without a separate legend lookup.

### 4.2 Column widths: the #1 performance trap

**`defaultColumnWidth` is `IntrinsicColumnWidth()`.** Intrinsic sizing measures *every cell in every row* to derive column widths, O(rows × cols) text measurement, before layout even begins. On a 2,000-row wiring schedule this is the dominant cost and will freeze the UI for seconds. The 3.12.0 changelog's "table layout performance enhancements" confirms this was a known hotspot upstream.

**Always specify `columnWidths` explicitly with `FixedColumnWidth` / `FlexColumnWidth`.** Never let a long schedule fall through to intrinsic. See also [#174](https://github.com/DavBfr/dart_pdf/issues/174).

### 4.3 Header repetition across pages

`Table` is a spanning widget; `headerCount` tells it how many leading rows to repeat at the top of each page fragment. Combined with `MultiPage.header` (the *sheet* header) you get both a sheet banner and a repeated column header.

> ⚠️ **Verify this empirically** with a 3-page schedule before committing. The docs describe `headerCount` and confirm `Table` is a spanning widget, but I did not find explicit confirmation of automatic per-page header repetition in 3.13.0. Cheap to test; expensive to discover late.

### 4.4 Page-break pitfalls

- **`maxPages` defaults to 20.** Exceeding it throws `This widget created more than 20 pages. This may be an issue in the widget or the document.`, one of the most-filed issues in the repo ([#128](https://github.com/DavBfr/dart_pdf/issues/128), [#145](https://github.com/DavBfr/dart_pdf/issues/145), [#290](https://github.com/DavBfr/dart_pdf/issues/290), [#461](https://github.com/DavBfr/dart_pdf/issues/461)). **Set it explicitly.** Note a documentation inconsistency: `MultiPage`'s docs say it's not checked in release builds, while the 3.11.2 changelog says release-build validation was *fixed*. Assume it **is** enforced in release on 3.13.0 and set a real value.
- **Long unbroken tokens don't wrap and can vanish.** A `Text` containing a word wider than its constraint overflows the box ([#349](https://github.com/DavBfr/dart_pdf/issues/349)) or disappears entirely when too wide ([#518](https://github.com/DavBfr/dart_pdf/issues/518), [#397](https://github.com/DavBfr/dart_pdf/issues/397)). **This will hit you**: device model strings, long cable IDs like `RACK1-HDMI-OUT-07-TO-DISPLAY-MSTR-BR`, and installer notes are exactly this shape. Mitigate by inserting soft break opportunities before measuring:
  ```dart
  String breakable(String s) => s.replaceAllMapped(
      RegExp(r'[-_/.:]'), (m) => '${m[0]}\u200B');   // ZWSP after separators
  ```
  and/or hard-truncate with an ellipsis you compute yourself from `stringMetrics`.
- **Nested tables inside `MultiPage`** are a common source of runaway pagination. Keep the schedule a single flat table.
- Use `pw.NewPage()` for explicit breaks between sections; 3.11.0 added `freeSpace` to it for conditional breaks ("start a new page unless ≥ N points remain").

---

## 5. Title blocks, borders, revision blocks, sheet numbering

There is no built-in. Build it as a **page theme background**, which is the clean approach, it draws on *every* page automatically, including pages `MultiPage` creates by overflow, so your schedule's page 7 gets the same border as your diagram's page 1 with no extra code.

```dart
final sheetTheme = pw.PageTheme(
  pageFormat: ansiB.landscape,
  theme: theme,
  margin: const pw.EdgeInsets.fromLTRB(36, 24, 24, 24),   // wide left edge for binding
  buildBackground: (pw.Context ctx) => pw.FullPage(
    ignoreMargins: true,                                   // ← draw into the margin area
    child: pw.CustomPaint(
      painter: (PdfGraphics g, PdfPoint size) {
        final c = PdfDiagramCanvas(g, size.y, fonts);
        drawDrawingBorder(c, size);        // double rule, 0.5" inset
        drawZoneGrid(c, size);             // A–D vertical, 1–8 horizontal
        drawTitleBlock(c, size, meta, ctx.pageNumber, ctx.pagesCount);
        drawRevisionBlock(c, size, meta.revisions);
      },
    ),
  ),
);
```

Key APIs: **`pw.PageTheme(buildBackground:, buildForeground:)`** (both `BuildCallback`) and **`pw.FullPage(ignoreMargins: true)`**: the latter is what lets you paint into the margin region where the border and title block live.

> ⚠️ **Verify** `PageTheme.buildBackground`/`buildForeground` param names against 3.13.0's API docs — I'm confident they exist but did not fetch that page directly.

A conventional title block in the bottom-right, ~7" × 2" on ANSI B:

```
┌──────────────────────────────────────────────────────────────┐
│ SMITH RESIDENCE — MASTER EQUIPMENT RACK                      │
│ 1428 Alder Ct, Portland OR                                   │
├───────────────┬──────────────┬───────────────┬───────────────┤
│ DRAWN   J.S.  │ SCALE  1:8   │ SIZE  B       │ REV  C        │
│ CHECKED —     │ DATE 2026-07 │ PROJ  25-1183 │ SHEET 3 OF 7  │
├───────────────┴──────────────┴───────────────┴───────────────┤
│ RACK INTERCONNECT — VIDEO NETS          DWG  25-1183-E03     │
└──────────────────────────────────────────────────────────────┘
```

Revision block above it, growing upward, newest-first: `REV | DATE | DESCRIPTION | BY`. Since your data model already has stable UUIDs and change-tracking-friendly structure, the revision block can be **generated from project history** rather than hand-entered, that's a differentiator worth building. A CI firm re-issuing a rack drawing after a change order gets an accurate revision history for free.

Also set the PDF metadata (`pw.Document(title:, author:, subject:, keywords:, creator:)`), it populates Acrobat's Document Properties and makes the file findable in a document management system.

---

## 6. Saving and sharing across platforms

### 6.1 Recommendation

**`file_selector` over `file_picker`.** `file_selector` is maintained by the Flutter team in `flutter/packages`, is federated, and is pure platform-channel. `file_picker` is third-party, bundles more native code, and has had desktop save regressions, e.g. [`saveFile` silently not saving on Linux](https://github.com/miguelpruivo/flutter_file_picker/issues/1907). For a desktop-first app, take the first-party option.

```dart
import 'package:file_selector/file_selector.dart';

Future<void> exportPdf(Uint8List bytes, String suggested) async {
  const group = XTypeGroup(label: 'PDF', extensions: ['pdf'], mimeTypes: ['application/pdf']);
  final loc = await getSaveLocation(
    suggestedName: suggested,                 // 'Smith-Rack1-2026-07-18.pdf'
    acceptedTypeGroups: const [group],
  );
  if (loc == null) return;                    // user cancelled
  await XFile.fromData(bytes, mimeType: 'application/pdf', name: suggested).saveTo(loc.path);
}
```

Note the two-step shape: `getSaveLocation()` returns a `FileSaveLocation`, and you write via `XFile.saveTo()`. `file_picker`'s `saveFile()` returns just a path string. The `file_selector` split is more explicit and works uniformly.

### 6.2 Per-platform matrix

| Target | Save to disk | Print | Share |
|---|---|---|---|
| **Windows/macOS/Linux** | `file_selector.getSaveLocation` + `XFile.saveTo` | `Printing.layoutPdf` | `Printing.sharePdf` (macOS good; Win/Linux weaker) |
| **iOS/Android** | `Printing.sharePdf` (share sheet), or `path_provider` + `share_plus` | `Printing.layoutPdf` | `Printing.sharePdf` |
| **Web** | `Printing.sharePdf` → browser download, or anchor+base64 | `Printing.layoutPdf` → browser print | download |

Verified `Printing` static methods:

```dart
static Future<bool> layoutPdf({
  required LayoutCallback onLayout,          // FutureOr<Uint8List> Function(PdfPageFormat)
  String name = 'Document',
  PdfPageFormat format = PdfPageFormat.standard,
  bool dynamicLayout = true,
  bool usePrinterSettings = false,
  OutputType outputType = OutputType.generic,
  bool forceCustomPrintPaper = false,
  bool windowsModernDialog = false,
});

static Future<bool> sharePdf({
  required Uint8List bytes,
  String filename = 'document.pdf',
  Rect? bounds,                              // ← REQUIRED in practice on iPad
  String? subject, String? body, List<String>? emails,
});

static Future<List<Printer>> listPrinters();
static Future<Printer?>      pickPrinter({required BuildContext context, Rect? bounds, String? title});
static FutureOr<bool>        directPrintPdf({required Printer printer, required LayoutCallback onLayout, ...});
static Future<Uint8List>     convertHtml({required String html, String? baseUrl, PdfPageFormat format = PdfPageFormat.standard});
static Future<PrintingInfo>  info();
static Stream<PdfRaster>     raster(Uint8List document, {List<int>? pages, double dpi = PdfPageFormat.inch});
```

**Gotchas:**

- **`sharePdf(bounds:)` on iPad.** iOS anchors the share popover to a rect; omit `bounds` and it misplaces or throws. Pass the originating widget's global rect. Relevant to your mobile read-only review mode.
- **`dynamicLayout: true`** means `onLayout` is called *again* whenever the user changes paper size in the print dialog. Your callback must actually honour the `PdfPageFormat` it receives, which your scale-to-fit code already does. Set `false` if you want to force your chosen sheet size.
- **`Printing.raster` and `PdfPreview` need pdfium** on Windows/Linux; the plugin's CMake downloads binaries at build time. First `flutter build windows` on a fresh machine or a locked-down CI runner will fail without network access. Budget for it and consider vendoring.
- **`forceCustomPrintPaper` / `windowsModernDialog`** are relevant to you: an 11×17 custom size on Windows often needs `forceCustomPrintPaper: true` to reach the driver correctly.
- **`usePrinterSettings: true`** takes paper size from the driver instead of your `format`, usually *not* what you want for a drawing set with a specific sheet size.
- `path_provider` is for **temp scratch only** on desktop. Never silently write a user's deliverable to `getApplicationDocumentsDirectory()`, always show a save dialog.
- **Web:** `dart:io` is unavailable; `Printing.sharePdf` triggers a download. The raw anchor route from the README also works:
  ```dart
  web.HTMLAnchorElement()
    ..href = 'data:application/pdf;base64,${base64.encode(bytes)}'
    ..setAttribute('download', filename)
    ..click();
  ```
  For a large multi-sheet PDF prefer a `Blob` URL over a data URL, data URLs hit browser length limits.

**In-app preview** before saving is worth the small cost, `PdfPreview(build: (format) => generate(format))` gives you a paginated preview with hot-reload during development, plus built-in print/share/save actions and custom `PdfPreviewAction`s.

---

## 7. Known bugs and limitations to design around

### 7.1 Jank and isolates: the important one

`doc.save()` blocks the UI thread; so does building a large widget tree. 3.11.0 added "saving in an isolate when available", but that covers only the serialization step, not layout. For a multi-sheet drawing set, run **the entire generation** off-thread ([#442](https://github.com/DavBfr/dart_pdf/issues/442), [#1114](https://github.com/DavBfr/dart_pdf/issues/1114), [#1528](https://github.com/DavBfr/dart_pdf/issues/1528)).

**⚠️ The critical constraint: a background isolate has no access to `rootBundle`, no plugins, no platform channels, and no `BuildContext`.** Load every font and image to `Uint8List` on the main isolate first, then pass plain bytes into the isolate. This is *the* thing people get wrong.

```dart
// Main isolate: gather everything Flutter-dependent
final assets = ExportAssets(
  bodyTtf: (await rootBundle.load('assets/fonts/Inter-Regular.ttf')).buffer.asUint8List(),
  boldTtf: (await rootBundle.load('assets/fonts/Inter-SemiBold.ttf')).buffer.asUint8List(),
  monoTtf: (await rootBundle.load('assets/fonts/JetBrainsMono-Regular.ttf')).buffer.asUint8List(),
);

// Background: pure Dart only — model, scene builder, PdfDiagramCanvas, pdf package
final bytes = await Isolate.run(() => _buildDocument(projectJson, assets, sheetSpec));
```

This works **only if your renderer has no `dart:ui` dependency**, which is exactly why §2.4 defines its own `Pt`/`Box` instead of using `ui.Offset`/`ui.Rect`. The isolate requirement and the future server-side-export requirement point at the same architectural decision. Make it once, up front; retrofitting it later means touching every drawing call site.

`Isolate.run()` (Dart 2.19+) needs the closure and its captured values to be sendable, plain data, no live objects. Serialize the project to JSON or use a deeply-immutable model. Note also [#43623](https://github.com/flutter/flutter/issues/43623): repeated `compute()` calls can leak; prefer `Isolate.run()` per export over a long-lived pool.

### 7.2 Memory and file size

- Large docs with many images crash on `save()` ([#432](https://github.com/DavBfr/dart_pdf/issues/432)); PDFs balloon from unoptimized raster ([#527](https://github.com/DavBfr/dart_pdf/issues/527)). **Mostly irrelevant to you if you stay vector**, which is another argument for §2.
- If you do embed a raster (a client logo in the title block), pre-scale it to its final size × 2 and use JPEG for photos / PNG for line art. Don't hand a 4000px logo to a 0.75" title-block slot.
- Content stream size: wrapping every primitive in `saveContext`/`restoreContext` emits a `q`/`Q` pair per op. For a diagram with 10k ops that's measurable bloat. Optimize later with a small graphics-state cache that only emits setters when the state actually changes:
  ```dart
  StrokeSpec? _lastStroke;
  void _applyStroke(StrokeSpec s) {
    if (s == _lastStroke) return;             // needs value equality on StrokeSpec
    _g..setStrokeColor(_col(s.argb))..setLineWidth(s.width)
      ..setLineDashPattern(s.dash ?? const <num>[]);
    _lastStroke = s;
  }
  ```
  Sort the display list by style before emission and this collapses dramatically. Premature for v1; keep the hook.

### 7.3 Text

- No `TextPainter` equivalent; measure with `PdfFont.stringMetrics` (§2.7).
- Long-token overflow/disappearance (§4.4).
- `TextOverflow` / `maxLines` support in `pw.Text` is partial compared to Flutter's, don't assume parity.
- **RTL:** `textDirection` exists on `MultiPage`, `Table`, and `TableHelper`, and there is bidi handling, but complex-script shaping (Arabic ligature forms, Indic conjuncts) is imperfect, dart_pdf does not run a full HarfBuzz-class shaper. Low priority for RackPal; note it if you localize.

### 7.4 Other

- **`setTransform` concatenates** (PDF `cm`), despite the name. Always bracket with save/restore.
- **`pw.CustomPaint` pre-translates to the box's bottom-left**: use `size.y`, not page height, for your Y-flip (§2.5).
- **Web first-run slowness** ([#748](https://github.com/DavBfr/dart_pdf/issues/748)), font/wasm warmup makes the first generation dramatically slower. Pre-warm on app idle if you ship web.
- **Native libs and 16 KB memory pages** ([#1872](https://github.com/DavBfr/dart_pdf/issues/1872)), affects `printing`'s bundled pdfium on newer Android. Only relevant to your mobile review mode's preview.
- **Nested spanning widgets** inside `MultiPage` are the usual cause of runaway pagination. Keep page-level structure flat.

---

## 8. Suggested file layout

```
lib/
  model/                    # RackProject, Device, Port, Connection, CableType — pure Dart
  diagram/
    geometry.dart           # Pt, Box  (NO dart:ui)
    style.dart              # StrokeSpec, FillSpec, TextSpec, cable palette
    canvas.dart             # abstract interface DiagramCanvas
    ops.dart                # sealed DiagramOp + DiagramScene
    scene_builder.dart      # buildScene(project, style) -> DiagramScene   ← THE renderer
    symbols.dart            # SVG 'd' strings for connector symbols
    hit_test.dart           # walks DiagramScene.hits
    backends/
      flutter_canvas.dart   # dart:ui        (Flutter only)
      pdf_canvas.dart       # PdfGraphics    (pure Dart — isolate-safe)
      svg_canvas.dart       # optional export
  export/
    sheets.dart             # ANSI/ARCH/ISO PdfPageFormat constants
    title_block.dart        # border, zone grid, title + revision blocks
    schedule_table.dart     # TableHelper wiring
    layout.dart             # scale-to-fit, net partitioning, tiling, match lines
    document.dart           # assembles pw.Document; runs in Isolate.run()
  ui/
    diagram_view.dart       # CustomPainter -> FlutterDiagramCanvas
```

**Everything under `diagram/` except `backends/flutter_canvas.dart` must be importable without Flutter.** Enforce it with a lint or a test that imports `scene_builder.dart` from a `dart test` (not `flutter test`) target, if it compiles headless, your isolate export and your future server-side export both work. That one guardrail protects the whole architecture.

---

## Sources

- [pdf | Dart package (3.13.0)](https://pub.dev/packages/pdf) · [changelog](https://pub.dev/packages/pdf/changelog) · [README](https://github.com/DavBfr/dart_pdf/blob/master/pdf/README.md)
- [printing | Flutter package (5.15.0)](https://pub.dev/packages/printing) · [API index](https://pub.dev/documentation/printing/latest/)
- [PdfGraphics class](https://pub.dev/documentation/pdf/latest/pdf/PdfGraphics-class.html) · [PdfPageFormat](https://pub.dev/documentation/pdf/latest/pdf/PdfPageFormat-class.html) · [PdfFontMetrics](https://pub.dev/documentation/pdf/latest/pdf/PdfFontMetrics-class.html)
- [MultiPage class](https://pub.dev/documentation/pdf/latest/widgets/MultiPage-class.html) · [Context class](https://pub.dev/documentation/pdf/latest/widgets/Context-class.html) · [CustomPainter typedef](https://pub.dev/documentation/pdf/latest/widgets/CustomPainter.html) · [CustomPaint class](https://pub.dev/documentation/pdf/latest/widgets/CustomPaint-class.html)
- [dart_pdf Fonts Management wiki](https://github.com/DavBfr/dart_pdf/wiki/Fonts-Management)
- Issues: [#76](https://github.com/DavBfr/dart_pdf/issues/76)/[#405](https://github.com/DavBfr/dart_pdf/issues/405)/[#810](https://github.com/DavBfr/dart_pdf/issues/810) Helvetica Unicode · [#114](https://github.com/DavBfr/dart_pdf/issues/114) page fit · [#128](https://github.com/DavBfr/dart_pdf/issues/128)/[#145](https://github.com/DavBfr/dart_pdf/issues/145)/[#290](https://github.com/DavBfr/dart_pdf/issues/290)/[#461](https://github.com/DavBfr/dart_pdf/issues/461) maxPages · [#174](https://github.com/DavBfr/dart_pdf/issues/174) columnWidths · [#349](https://github.com/DavBfr/dart_pdf/issues/349)/[#397](https://github.com/DavBfr/dart_pdf/issues/397)/[#518](https://github.com/DavBfr/dart_pdf/issues/518) text overflow · [#378](https://github.com/DavBfr/dart_pdf/issues/378) TextPainter · [#432](https://github.com/DavBfr/dart_pdf/issues/432)/[#527](https://github.com/DavBfr/dart_pdf/issues/527) memory/size · [#442](https://github.com/DavBfr/dart_pdf/issues/442)/[#1114](https://github.com/DavBfr/dart_pdf/issues/1114)/[#1528](https://github.com/DavBfr/dart_pdf/issues/1528) isolates · [#748](https://github.com/DavBfr/dart_pdf/issues/748) web warmup · [#1872](https://github.com/DavBfr/dart_pdf/issues/1872) 16KB pages
- [RenderRepaintBoundary.toImage](https://api.flutter.dev/flutter/rendering/RenderRepaintBoundary/toImage.html) · flutter/flutter [#118024](https://github.com/flutter/flutter/issues/118024), [#116957](https://github.com/flutter/flutter/issues/116957), [#21269](https://github.com/flutter/flutter/issues/21269), [#43623](https://github.com/flutter/flutter/issues/43623)
- [file_selector](https://pub.dev/packages/file_selector) · [file_picker](https://pub.dev/packages/file_picker) · [file_picker #1907 Linux saveFile](https://github.com/miguelpruivo/flutter_file_picker/issues/1907) · [path_drawing](https://pub.dev/packages/path_drawing)
- [ANSI/ASME Y14.1 drawing sizes](https://www.engineeringtoolbox.com/paper-drawing-sizes-d_140.html) · [ASME Y14.5 / Y14.100](https://blog.ansi.org/ansi/what-are-the-asme-y14-5-and-asme-y14-100-standards/) · [USACE MVD CAD Standard (match lines, ANSI D borders)](https://www.mvd.usace.army.mil/portals/52/docs/mvd-cad-std-40.pdf) · [Hanford HNF-64101 drawing prep standards](https://hmis.hanford.gov/files.cfm/HNF-64101_-_Rev_00.pdf)
- [Flutter: Concurrency and isolates](https://docs.flutter.dev/perf/isolates)

**Three items I flagged as unverified: cheap to confirm, expensive to discover late:** (1) `PdfFont.stringMetrics` exact signature and the `* fontSize` operator; (2) automatic per-page header repetition via `Table.headerCount`; (3) `PageTheme.buildBackground`/`buildForeground` param names on 3.13.0.