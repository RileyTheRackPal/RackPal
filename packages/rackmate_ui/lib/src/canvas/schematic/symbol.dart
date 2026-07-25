// rackmate_ui/src/canvas/schematic/symbol.dart — Symbol rendering for schematic canvas.
//
// Renders device symbols with:
// - Device body (rect)
// - Header band for name/designator
// - Ports on edges (left/right/top/bottom)

import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/src/draw/flutter_canvas.dart';

/// Port position on a symbol edge.
final class SymbolPort {
  SymbolPort({
    required this.id,
    required this.side,
    required this.offset, // distance from corner
    required this.size,
    required this.direction, // source/sink/bidirectional
    required this.family, // signal family id
  });

  final String id;
  final SymbolSide side;
  final double offset;
  final double size;
  final PortDirection direction;
  final SignalFamilyId family;
}

/// Rendered symbol with ports and body.
class RenderedSymbol {
  RenderedSymbol({
    required this.id,
    required this.bodyRect, // device body rectangle
    required this.headerHeight, // header band height
    required this.ports, // ports on each side
  });

  final String id;
  DBox bodyRect;
  final double headerHeight;
  final Map<SymbolSide, List<SymbolPort>> ports;
}

/// Simple color palette for schematic rendering.
final class SchematicPalette {
  const SchematicPalette({
    this.headerFill = 0xFFE8E8E8,
    this.deviceStroke = 0xFF333333,
    this.deviceFill = 0xFFFFFFFF,
    this.portStroke = 0xFF333333,
    this.wireColor = 0xFF4CAF50,
    this.deviceDesignator = 0xFF333333, // text color for device name
  });

  final int headerFill;
  final int deviceStroke;
  final int deviceFill;
  final int portStroke;
  final int wireColor;
  final int deviceDesignator;
}

/// Symbol builder for schematic rendering.
final class SymbolBuilder {
  /// Create a rendered symbol from template data.
  RenderedSymbol buildFromTemplate({
    required String deviceId,
    required TemplateBody template,
    required Map<String, PortDef> ports,
    required double bodyWidth,
    required double headerHeight,
    required double portSize,
  }) {
    final sidePorts = <SymbolSide, List<SymbolPort>>{
      SymbolSide.left: [],
      SymbolSide.right: [],
      SymbolSide.top: [],
      SymbolSide.bottom: [],
    };

    // Distribute ports on edges based on their direction
    for (final port in ports.values) {
      final side = _getDefaultSideForPort(port);
      final offset = _calculatePortOffset(
        side,
        sidePorts[side]!.length,
        portSize,
      );

      sidePorts[side]?.add(
        SymbolPort(
          id: port.key.v,
          side: side,
          offset: offset,
          size: portSize,
          direction: port.direction,
          family: port.signalFamily,
        ),
      );
    }

    // Calculate total height including header and ports
    final maxTop = _maxOffset(sidePorts[SymbolSide.top] ?? []);
    final maxBottom = _maxOffset(sidePorts[SymbolSide.bottom] ?? []);
    final bodyHeight = headerHeight + 2 * portSize + maxTop + maxBottom;

    return RenderedSymbol(
      id: deviceId,
      bodyRect: DBox.fromLtwh(0, 0, bodyWidth, bodyHeight),
      headerHeight: headerHeight,
      ports: sidePorts,
    );
  }

  /// Paint the rendered symbol to a canvas.
  void paint({
    required FlutterDiagramCanvas canvas,
    required RenderedSymbol symbol,
    required DBox bounds,
    required SchematicPalette palette,
    double xOffset = 0,
    double yOffset = 0,
  }) {
    final bodyRect = _translateBox(symbol.bodyRect, xOffset, yOffset);

    // Header band
    final headerRect = DBox.fromLtwh(
      bodyRect.left,
      bodyRect.top,
      bodyRect.width,
      symbol.headerHeight,
    );
    // Header band - use deviceFill for header background
    canvas.drawRect(headerRect, fill: Fill(palette.deviceFill));

    // Device body outline
    canvas.drawRect(
      bodyRect,
      stroke: Stroke(argb: palette.deviceStroke, widthPt: 1),
    );

    // Paint ports on each side
    for (final entry in symbol.ports.entries) {
      final side = entry.key;
      final ports = entry.value;

      for (final port in ports) {
        _paintPort(
          canvas: canvas,
          symbol: symbol,
          port: port,
          side: side,
          bodyRect: bodyRect,
          palette: palette,
          xOffset: xOffset,
          yOffset: yOffset,
        );
      }
    }
  }

  /// Paint a single port.
  void _paintPort({
    required FlutterDiagramCanvas canvas,
    required RenderedSymbol symbol,
    required SymbolPort port,
    required SymbolSide side,
    required DBox bodyRect,
    required SchematicPalette palette,
    required double xOffset,
    required double yOffset,
  }) {
    final DBox portRect;

    switch (side) {
      case SymbolSide.left:
        portRect = DBox.fromLtwh(
          bodyRect.left - port.size / 2,
          bodyRect.top + symbol.headerHeight + port.offset,
          port.size,
          port.size,
        );
      case SymbolSide.right:
        portRect = DBox.fromLtwh(
          bodyRect.right - port.size / 2,
          bodyRect.top + symbol.headerHeight + port.offset,
          port.size,
          port.size,
        );
      case SymbolSide.top:
        portRect = DBox.fromLtwh(
          bodyRect.left + port.offset,
          bodyRect.top - port.size / 2,
          port.size,
          port.size,
        );
      case SymbolSide.bottom:
        portRect = DBox.fromLtwh(
          bodyRect.left + port.offset,
          bodyRect.bottom - port.size / 2,
          port.size,
          port.size,
        );
    }

    // Port circle
    final cx = portRect.left + portRect.width / 2;
    final cy = portRect.top + portRect.height / 2;
    canvas.drawCircle(
      DPt(cx, cy),
      port.size / 2,
      stroke: Stroke(argb: palette.deviceStroke, widthPt: 1),
    );

    // Direction indicator (triangle)
    canvas.save();
    canvas.translate(cx, cy);
    final angle = _sideAngle(side);
    canvas.rotate(angle);
    final triSize = port.size * 0.3;
    final path = DiagramPath([
      MoveTo(-triSize / 2, -triSize / 2),
      LineTo(triSize / 2, 0),
      LineTo(-triSize / 2, triSize / 2),
      const ClosePath(),
    ]);
    canvas.drawPath(path, fill: Fill(palette.deviceFill));
    canvas.restore();

    // Port label
    final anchor = _labelAnchor(side);
    canvas.drawText(
      'P${port.id}',
      DPt(
        cx +
            (side == SymbolSide.left
                ? -10
                : side == SymbolSide.right
                ? 5
                : 0),
        cy +
            (side == SymbolSide.top
                ? -10
                : side == SymbolSide.bottom
                ? 5
                : 0),
      ),
      rackText(8, palette.deviceDesignator, anchor),
    );
  }

  /// Get default side for a port based on direction.
  SymbolSide _getDefaultSideForPort(PortDef port) {
    switch (port.direction) {
      case PortDirection.source:
        return SymbolSide.left;
      case PortDirection.sink:
        return SymbolSide.right;
      case PortDirection.bidirectional:
      case PortDirection.busNode:
      case PortDirection.passive:
        return SymbolSide.top;
    }
  }

  /// Calculate port offset based on index and side.
  double _calculatePortOffset(SymbolSide side, int index, double spacing) {
    const baseOffset = 10.0;
    return baseOffset + index * spacing;
  }

  /// Get maximum offset from a list of ports.
  double _maxOffset(List<SymbolPort> ports) {
    if (ports.isEmpty) return 0;
    return ports.map((p) => p.offset).reduce((a, b) => a > b ? a : b);
  }

  /// Get rotation angle for direction indicator on a side.
  double _sideAngle(SymbolSide side) {
    const pi = 3.1415926535897932;
    switch (side) {
      case SymbolSide.left:
        return 0; // pointing right
      case SymbolSide.right:
        return pi; // pointing left
      case SymbolSide.top:
        return -pi / 2; // pointing down
      case SymbolSide.bottom:
        return pi / 2; // pointing up
    }
  }

  /// Get text anchor for port labels.
  TextAnchor _labelAnchor(SymbolSide side) {
    switch (side) {
      case SymbolSide.left:
        return TextAnchor.midRight;
      case SymbolSide.right:
        return TextAnchor.midLeft;
      case SymbolSide.top:
        return TextAnchor.bottomCenter;
      case SymbolSide.bottom:
        return TextAnchor.topCenter;
    }
  }
}

/// Helper functions.
DBox _translateBox(DBox box, double dx, double dy) => DBox.fromLtwh(
  box.left + dx,
  box.top + dy,
  box.width,
  box.height,
);

/// Extension on SymbolSide for string conversion.
extension SymbolSideExt on SymbolSide {
  String toShortString() {
    switch (this) {
      case SymbolSide.left:
        return 'left';
      case SymbolSide.right:
        return 'right';
      case SymbolSide.top:
        return 'top';
      case SymbolSide.bottom:
        return 'bottom';
    }
  }
}

/// Extension on DPt for distance calculations.
extension DPointExt on DPt {
  double distanceTo(DPt other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return _sqrt(dx * dx + dy * dy);
  }

  static double _sqrt(double x) => x >= 0 ? _sqrtNewton(x) : double.nan;
  static double _sqrtNewton(double x) {
    if (x == 0) return 0;
    var root = x;
    for (var i = 0; i < 10; i++) {
      root = (root + x / root) / 2;
    }
    return root;
  }
}
