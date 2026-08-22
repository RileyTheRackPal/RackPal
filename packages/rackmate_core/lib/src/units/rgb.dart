import 'package:meta/meta.dart';

/// A colour, stored as four 0-255 channels.
///
/// Two hex conventions are supported, both fixed-width and round-trip
/// exact: [toHex]/`fromHex` for the opaque `#RRGGBB` form used e.g. by
/// `SignalDomainDef.color`, and [toHexArgb] for the alpha-aware
/// `#AARRGGBB` form.
@immutable
final class Rgb {
  const Rgb(this.r, this.g, this.b, {this.a = 255});

  /// Parses either `#RRGGBB` (alpha defaults to opaque) or `#AARRGGBB`.
  /// The leading `#` is optional.
  factory Rgb.fromHex(String hex) {
    final s = hex.startsWith('#') ? hex.substring(1) : hex;
    if (s.length == 6) {
      final v = int.parse(s, radix: 16);
      return Rgb((v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF);
    }
    if (s.length == 8) {
      final v = int.parse(s, radix: 16);
      return Rgb(
        (v >> 16) & 0xFF,
        (v >> 8) & 0xFF,
        v & 0xFF,
        a: (v >> 24) & 0xFF,
      );
    }
    throw FormatException(
      'Rgb.fromHex expects "#RRGGBB" or "#AARRGGBB"',
      hex,
    );
  }

  final int r;
  final int g;
  final int b;
  final int a;

  /// Opaque `#RRGGBB` form.
  String toHex() => '#${_hx(r)}${_hx(g)}${_hx(b)}';

  /// Alpha-aware `#AARRGGBB` form.
  String toHexArgb() => '#${_hx(a)}${_hx(r)}${_hx(g)}${_hx(b)}';

  /// The packed `0xAARRGGBB` form the draw layer speaks.
  ///
  /// `Fill`, `Stroke` and `RackPalette` all carry colour as a packed int,
  /// so a model colour reaching a scene has to be packed somewhere. Here,
  /// once, rather than at each call site: DR-080 put the first one in
  /// `device_layer` and there will be more.
  int get argb => (a << 24) | (r << 16) | (g << 8) | b;

  static String _hx(int v) => v.toRadixString(16).padLeft(2, '0').toUpperCase();

  @override
  bool operator ==(Object other) =>
      other is Rgb &&
      other.r == r &&
      other.g == g &&
      other.b == b &&
      other.a == a;

  @override
  int get hashCode => Object.hash(r, g, b, a);

  @override
  String toString() => 'Rgb(${toHexArgb()})';
}
