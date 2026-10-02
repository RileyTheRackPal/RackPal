// The integrator's logo reaches the PDF (`#590`, DR-030, DR-217).
//
// On a real starter with a logo set: every full-block sheet paints it once,
// upright, 100 x 45 pt at the top right of its title block; the ANSI A
// sheets paint none; and a project with no logo paints no logo.
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as im;
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_export/rackpal_export.dart';
import 'package:test/test.dart';

import 'support/content_stream.dart';

const FontRef _font = FontRef('Jost');

/// 400 x 180, the logo box's own 100 : 45, so a correct fit fills it.
const ProjectLogo _logo = ProjectLogo(
  imageMember: '${kLogoMemberDir}logo.png',
  format: PlanImageFormat.png,
  pixelWidth: 400,
  pixelHeight: 180,
  contentHash: 'sha256:test',
);

Uint8List _logoPng() {
  final image = im.Image(width: 400, height: 180)
    ..clear(im.ColorRgb8(30, 60, 120));
  return Uint8List.fromList(im.encodePng(image));
}

void main() {
  late Uint8List fontBytes;
  setUpAll(() {
    fontBytes = File(
      '../../apps/rackpal/assets/fonts/Jost-Regular.ttf',
    ).readAsBytesSync();
  });

  /// Small Office, with [logo] set through the command a person runs.
  Future<ExportedDocument> export({required bool withLogo}) async {
    final doc =
        (const JsonDocumentCodec().read(
                  File(
                    '../../apps/rackpal/assets/starters/small_office.rppj',
                  ).readAsBytesSync(),
                )
                as Ok<RackDocument>)
            .value;
    if (withLogo) SetProjectLogoCommand.to(doc.info, _logo).apply(doc);
    final result = await buildExportDocument(
      ExportRequest(
        documentJson: const JsonDocumentCodec().write(doc),
        fontBytes: <FontRef, Uint8List>{_font: fontBytes},
        fileName: 'small_office.rppj',
        issuedAt: DateTime.utc(2026, 10),
        members: withLogo
            ? <String, Uint8List>{_logo.imageMember: _logoPng()}
            : const <String, Uint8List>{},
      ),
    );
    return (result as Ok<ExportedDocument>).value;
  }

  /// Per sheet: its id, and the images on it about the logo box's width.
  List<(String, List<RecoveredImage>)> logosBySheet(Uint8List bytes) {
    final cmap = parseToUnicodeCMap(bytes);
    return <(String, List<RecoveredImage>)>[
      for (final body in operatorStreams(bytes))
        if (interpretContentStream(body, toUnicode: cmap) case final page
            when RegExp(r'SHEET NO\.\s+(\S+)').hasMatch(page.allText))
          (
            RegExp(r'SHEET NO\.\s+(\S+)').firstMatch(page.allText)!.group(1)!,
            page.images.where((i) {
              final w = i.topRight.$1 - i.topLeft.$1;
              return (w - kLogoBoxWidth).abs() < 0.5;
            }).toList(),
          ),
    ];
  }

  test('EVERY FULL-BLOCK SHEET paints the logo once, upright, 100 x 45 pt; '
      'THE ANSI A SHEETS paint none', () async {
    final exported = await export(withLogo: true);
    final sheets = logosBySheet(exported.bytes);
    expect(sheets, hasLength(exported.sheetCount));
    final compact = sheets.where((s) => s.$1.startsWith('T6.')).toList();
    expect(compact, isNotEmpty, reason: 'the premise: an A sheet exists');
    for (final (id, logos) in sheets) {
      if (id.startsWith('T6.')) {
        expect(logos, isEmpty, reason: id);
        continue;
      }
      expect(logos, hasLength(1), reason: id);
      final logo = logos.single;
      // UPRIGHT: PDF user space is Y-up, so the top edge is higher.
      expect(logo.topLeft.$2, greaterThan(logo.bottomLeft.$2), reason: id);
      expect(
        logo.topLeft.$2 - logo.bottomLeft.$2,
        closeTo(kLogoBoxHeight, 0.5),
        reason: id,
      );
    }
  });

  test('a project with no logo paints none', () async {
    final exported = await export(withLogo: false);
    for (final (id, logos) in logosBySheet(exported.bytes)) {
      expect(logos, isEmpty, reason: id);
    }
  });
}
