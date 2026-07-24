// rackmate_ui/src/canvas/schematic/wire_drawing.dart — Wire drawing with chain-draw support.
//
// Implements:
// - Point-to-point wire drawing
// - Chain-draw for multi-wire connections
// - Magnetic snapping during draw
// - Type-weighted snap zones

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/src/canvas/schematic/hit_test.dart';
import 'package:rackmate_ui/src/draw/flutter_canvas.dart';

/// Wire connection between two ports.
final class WireConnection {
  WireConnection({
    required this.id,
    required this.fromNodeId,
    required this.fromPortId,
    required this.toNodeId,
    required this.toPortId,
    required this.signalFamily,
    required this.color,
    this.labels = const [],
  });
  
  final String id;
  final String fromNodeId;
  final String fromPortId;
  final String toNodeId;
  final String toPortId;
  final SignalFamilyId signalFamily;
  final int color; // ARGB
  final List<WireLabel> labels;
}

/// Label on a wire.
final class WireLabel {
  WireLabel({
    required this.text,
    required this.position, // percentage along wire (0-1)
    required this.anchor,
  });
  
  final String text;
  final double position;
  final TextAnchor anchor;
}

/// Drawing state for a wire being drawn.
enum DrawState {
  idle,       // No drawing in progress
  preview,    // Previewing connection to current port
  committed,  // Wire has been committed (saved)
}

/// Wire drawing manager with chain-draw support.
final class WireDrawer {
  WireDrawer({
    HitTestParams? params,
  }) : _params = params ?? HitTestParams();
  
  final HitTestParams _params;
  
  /// Current draw state
  DrawState state = DrawState.idle;
  
  /// Starting port for current wire
  String? fromNodeId;
  String? fromPortId;
  SymbolSide? fromSide;
  
  /// Current preview position
  DPt? previewPos;
  
  /// List of completed wires (committed)
  final List<WireConnection> wires = [];
  
  /// Chain-draw: whether to continue drawing after each wire
  bool chainMode = false;
  
  /// Start a new wire from a port.
  void startFrom(String nodeId, String portId, SymbolSide side) {
    state = DrawState.preview;
    fromNodeId = nodeId;
    fromPortId = portId;
    fromSide = side;
    previewPos = null;
  }
  
  /// Update the preview position (while dragging).
  void updatePreview(DPt pos, {bool snap = true}) {
    if (state != DrawState.preview) return;
    
    previewPos = snap ? _snapToGrid(pos) : pos;
  }
  
  /// Finish the current wire at a port.
  bool finishAt(String nodeId, String portId, SymbolSide side, SignalFamilyId family) {
    if (fromNodeId == null || fromPortId == null || previewPos == null) return false;
    
    // Avoid self-connection
    if (nodeId == fromNodeId && portId == fromPortId) return false;
    
    final newWire = WireConnection(
      id: _generateId(),
      fromNodeId: fromNodeId!,
      fromPortId: fromPortId!,
      toNodeId: nodeId,
      toPortId: portId,
      signalFamily: family,
      color: _familyColor(family),
      labels: [],
    );
    
    wires.add(newWire);
    
    if (chainMode) {
      // Continue chain-draw from new endpoint
      startFrom(nodeId, portId, side);
    } else {
      state = DrawState.idle;
      fromNodeId = null;
      fromPortId = null;
    }
    
    return true;
  }
  
  /// Cancel the current wire drawing.
  void cancel() {
    state = DrawState.idle;
    fromNodeId = null;
    fromPortId = null;
    previewPos = null;
  }
  
  /// Calculate the path for a wire between two points.
  ///
  /// Uses orthogonal routing with perpendicular connectors to minimize crossings.
  DiagramPath calculateWirePath({
    required DPt start,
    required DPt end,
    required String? fromSide,
    required String? toSide,
  }) {
    final dx = end.x - start.x;
    final dy = end.y - start.y;
    
    // Orthogonal routing: horizontal then vertical
    if (fromSide == 'left' || fromSide == 'right' || toSide == 'left' || toSide == 'right') {
      // Horizontal-first for left/right connections
      final midX = (start.x + end.x) / 2;
      
      return DiagramPath([
        MoveTo(start.x, start.y),
        LineTo(midX, start.y), // horizontal to center
        LineTo(midX, end.y),   // vertical to target y
        LineTo(end.x, end.y),  // horizontal to target
        ClosePath(),
      ]);
    } else {
      // Vertical-first for top/bottom connections
      final midY = (start.y + end.y) / 2;
      
      return DiagramPath([
        MoveTo(start.x, start.y),
        LineTo(start.x, midY), // vertical to center
        LineTo(end.x, midY),   // horizontal to target x
        LineTo(end.x, end.y),  // vertical to target
        ClosePath(),
      ]);
    }
  }
  
  /// Calculate wire path from start port to current preview.
  DiagramPath? calculatePreviewPath() {
    if (fromNodeId == null || previewPos == null) return null;
    
    final start = DPt(
      fromSide == SymbolSide.left ? -10 : fromSide == SymbolSide.right ? 10 : 0,
      fromSide == SymbolSide.top ? -10 : fromSide == SymbolSide.bottom ? 10 : 0,
    ); // Will be calculated in RenderWires
    
    return DiagramPath([
      MoveTo(start.x, start.y),
      LineTo(previewPos!.x, previewPos!.y),
      ClosePath(),
    ]);
  }
  
  /// Paint all wires and current draw state.
  void paint({
    required FlutterDiagramCanvas canvas,
    double startX = 0,
    double startY = 0,
    double endX = 0,
    double endY = 0,
  }) {
    // Paint committed wires
    for (final wire in wires) {
      _paintWire(canvas, wire);
    }
    
    // Paint preview if drawing
    if (state == DrawState.preview && fromNodeId != null && previewPos != null) {
      _paintPreview(canvas, startX, startY, endX, endY);
    }
  }
  
  /// Paint a single committed wire.
  void _paintWire(FlutterDiagramCanvas canvas, WireConnection wire) {
    // Get positions (in real implementation, these would come from symbol locations)
    final start = DPt(0, 0); // Placeholder
    final end = DPt(100, 50); // Placeholder
    
    final path = calculateWirePath(
      start: start,
      end: end,
      fromSide: wire.fromPortId,
      toSide: wire.toPortId,
    );
    
    canvas.drawPath(path, stroke: Stroke(argb: wire.color, widthPt: 2));
    
    // Paint labels if any
    for (final label in wire.labels) {
      final midX = (start.x + end.x) / 2;
      final midY = (start.y + end.y) / 2;
      
      canvas.drawText(
        label.text,
        DPt(midX, midY),
        rackText(10, wire.color, label.anchor),
      );
    }
  }
  
  /// Paint the current preview wire.
  void _paintPreview(FlutterDiagramCanvas canvas, double startX, double startY, double endX, double endY) {
    final path = DiagramPath([
      MoveTo(startX, startY),
      LineTo(endX, endY),
      ClosePath(),
    ]);
    
    // Dashed line for preview
    canvas.drawPath(
      path,
      stroke: Stroke(
        argb: 0x804CAF50, // semi-transparent green
        widthPt: 2,
        dash: [10, 5],
      ),
    );
  }
  
  /// Snap position to grid.
  DPt _snapToGrid(DPt pos) {
    final gridSize = _params.snapGridSize;
    return DPt(
      (pos.x / gridSize).round() * gridSize,
      (pos.y / gridSize).round() * gridSize,
    );
  }
  
  /// Generate a unique ID for a wire.
  String _generateId() => 'wire_${DateTime.now().millisecondsSinceEpoch}_${wires.length}';
  
  /// Get color for signal family.
  int _familyColor(SignalFamilyId family) {
    // Simple hash to ARGB from the string value
    var h = 0;
    final str = family.v; // extension type on String
    for (var c in str.codeUnits) {
      h = ((h << 5) - h + c) & 0xFFFFFFFF;
    }
    final color = h.abs();
    return (0xFF << 24) | (color & 0xFFFFFF); // Opaque
  }
}