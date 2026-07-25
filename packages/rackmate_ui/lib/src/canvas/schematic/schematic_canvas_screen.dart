// rackmate_ui/src/canvas/schematic/schematic_canvas_screen.dart — Main schematic canvas widget.
//
// Integrates:
// - Symbol rendering with device body, header band, and pins on edges
// - Port hit-testing with magnetic snapping
// - Wire drawing with chain-draw functionality

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart' show WidgetsBinding;
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/src/canvas/schematic/hit_test.dart';
import 'package:rackmate_ui/src/canvas/schematic/symbol.dart';
import 'package:rackmate_ui/src/canvas/schematic/wire_drawing.dart';
import 'package:rackmate_ui/src/draw/flutter_canvas.dart';

/// Toolbar controls for schematic canvas.
final class SchematicToolbar extends StatelessWidget {
  const SchematicToolbar({
    super.key,
    required this.wireDrawer,
    required this.onChainModeChanged,
    required this.onNewWirePressed,
    required this.domainFilter,
    required this.onDomainFilterChanged,
  });

  final WireDrawer wireDrawer;
  final VoidCallback onChainModeChanged;
  final VoidCallback onNewWirePressed;
  final String domainFilter;
  final ValueChanged<String?> onDomainFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Chain mode toggle
          IconButton(
            icon: Icon(
              wireDrawer.chainMode ? Icons.link : Icons.link_off,
              color: wireDrawer.chainMode ? Colors.green : null,
            ),
            tooltip: wireDrawer.chainMode
                ? 'Chain mode: ON'
                : 'Chain mode: OFF',
            onPressed: onChainModeChanged,
          ),
          // New wire button
          ElevatedButton.icon(
            icon: const Icon(Icons.add_link),
            label: const Text('New Wire'),
            onPressed: onNewWirePressed,
          ),
          const SizedBox(width: 16),
          // Domain filter dropdown
          Expanded(
            child: DropdownButton<String?>(
              value: domainFilter.isEmpty ? null : domainFilter,
              hint: const Text('Filter by Net'),
              items: [
                DropdownMenuItem(value: '', child: const Text('All Nets')),
                DropdownMenuItem(value: 'power', child: const Text('Power')),
                DropdownMenuItem(value: 'signal', child: const Text('Signal')),
              ],
              onChanged: onDomainFilterChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// Schematic canvas widget with automatic layout.
final class SchematicCanvasScreen extends StatefulWidget {
  const SchematicCanvasScreen({
    super.key,
    required this.scene,
    required this.rackId,
    required this.measurer,
    required this.wireDrawer,
    required this.schematicHitTest,
    this.onSymbolsReady,
  });

  final DiagramScene scene;
  final String rackId;
  final TextMeasurer measurer;
  final WireDrawer wireDrawer;
  final SchematicHitTest? schematicHitTest;
  final void Function(List<RenderedSymbol>)? onSymbolsReady;

  @override
  State<SchematicCanvasScreen> createState() => _SchematicCanvasScreenState();
}

final class _SchematicCanvasScreenState extends State<SchematicCanvasScreen> {
  // Auto-layout state
  final List<RenderedSymbol> _symbols = [];
  final List<WireConnection> _wires = [];

  // Input handling state
  String? _draggableNodeId;
  bool _isDraggingNode = false;

  @override
  void initState() {
    super.initState();

    // Auto-layout symbols on next frame to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) => _autolayoutSymbols());
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Run layout on all devices in the scene.
  void _autolayoutSymbols() {
    // Create default placeholder symbols - real template integration comes later
    final gridSize = 180.0;

    // Always create at least one symbol for testing
    if (widget.scene.fragments.isEmpty) {
      // Clear existing symbols before adding new ones
      _symbols.clear();

      final sidePorts = <SymbolSide, List<SymbolPort>>{
        SymbolSide.left: [],
        SymbolSide.right: [],
        SymbolSide.top: [],
        SymbolSide.bottom: [],
      };

      // Add some dummy ports for testing
      sidePorts[SymbolSide.left]?.add(
        SymbolPort(
          id: 'in1',
          side: SymbolSide.left,
          offset: 20.0,
          size: 8.0,
          direction: PortDirection.sink,
          family: SignalFamilyId('power'),
        ),
      );

      sidePorts[SymbolSide.right]?.add(
        SymbolPort(
          id: 'out1',
          side: SymbolSide.right,
          offset: 20.0,
          size: 8.0,
          direction: PortDirection.source,
          family: SignalFamilyId('signal'),
        ),
      );

      final symbol = RenderedSymbol(
        id: 'default-device-1',
        bodyRect: DBox.fromLtwh(50, 50, 140.0, 80.0),
        headerHeight: 24.0,
        ports: sidePorts,
      );

      _symbols.add(symbol);

      // Notify parent that symbols are ready
      widget.onSymbolsReady?.call(_symbols);
      return;
    }

    var col = 0;
    var row = 0;

    for (final fragmentId in widget.scene.fragments.keys) {
      if (!fragmentId.startsWith('rack-')) {
        // Create a simple placeholder symbol with dummy ports
        final sidePorts = <SymbolSide, List<SymbolPort>>{
          SymbolSide.left: [],
          SymbolSide.right: [],
          SymbolSide.top: [],
          SymbolSide.bottom: [],
        };

        // Add some dummy ports for testing
        sidePorts[SymbolSide.left]?.add(
          SymbolPort(
            id: 'in1',
            side: SymbolSide.left,
            offset: 20.0,
            size: 8.0,
            direction: PortDirection.sink,
            family: SignalFamilyId('power'),
          ),
        );

        sidePorts[SymbolSide.right]?.add(
          SymbolPort(
            id: 'out1',
            side: SymbolSide.right,
            offset: 20.0,
            size: 8.0,
            direction: PortDirection.source,
            family: SignalFamilyId('signal'),
          ),
        );

        final symbol = RenderedSymbol(
          id: fragmentId,
          bodyRect: DBox.fromLtwh(
            col * gridSize + 50,
            row * gridSize + 50,
            140.0,
            80.0,
          ),
          headerHeight: 24.0,
          ports: sidePorts,
        );

        _symbols.add(symbol);

        if (col >= 3) {
          col = 0;
          row++;
        } else {
          col++;
        }
      }
    }

    // Notify parent that symbols are ready
    widget.onSymbolsReady?.call(_symbols);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      behavior: HitTestBehavior.translucent,
      child: LayoutBuilder(
        builder: (context, constraints) => CustomSingleChildLayout(
          delegate: _SchematicLayoutDelegate(),
          child: Stack(
            children: [
              _SchematicCanvasRenderObjectWidget(
                scene: widget.scene,
                rackId: widget.rackId,
                measurer: widget.measurer,
                symbols: _symbols,
                wires: _wires,
                wireDrawer: widget.wireDrawer,
                schematicHitTest: widget.schematicHitTest,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    final scenePos = offsetToDpt(event.position);
    final hitTest = widget.schematicHitTest;

    // Check for port hit
    if (hitTest != null) {
      final result = hitTest.testPoint(scenePos);

      if (result.hit == SchematicHitType.port &&
          result.nodeId != null &&
          result.portId != null) {
        // Start wire drawing from this port
        widget.wireDrawer.startFrom(
          result.nodeId!,
          result.portId!,
          result.side!,
        );

        setState(() {});
      } else if (result.hit == SchematicHitType.node && result.nodeId != null) {
        // Start dragging this node
        _draggableNodeId = result.nodeId;
        _isDraggingNode = true;

        setState(() {});
      }
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final scenePos = offsetToDpt(event.position);

    if (_isDraggingNode && _draggableNodeId != null) {
      // Update node position
      for (final symbol in _symbols) {
        if (symbol.id == _draggableNodeId) {
          symbol.bodyRect = DBox.fromLtwh(
            scenePos.x,
            scenePos.y,
            symbol.bodyRect.width,
            symbol.bodyRect.height,
          );
          break;
        }
      }
    } else if (widget.wireDrawer.state == DrawState.preview &&
        widget.wireDrawer.fromNodeId != null) {
      // Update wire preview
      widget.wireDrawer.updatePreview(scenePos, snap: true);
    }

    setState(() {});
  }

  void _handlePointerUp(PointerUpEvent event) {
    final scenePos = offsetToDpt(event.position);

    if (_isDraggingNode && _draggableNodeId != null) {
      // Finish dragging
      _isDraggingNode = false;
      _draggableNodeId = null;

      setState(() {});
    } else if (widget.wireDrawer.state == DrawState.preview &&
        widget.wireDrawer.fromNodeId != null) {
      // Check if ended on a port
      final result = widget.schematicHitTest?.testPoint(scenePos);

      if (result?.hit == SchematicHitType.port &&
          result?.nodeId != null &&
          result?.portId != null) {
        // Finish wire connection
        widget.wireDrawer.finishAt(
          result!.nodeId!,
          result.portId!,
          result.side!,
          SignalFamilyId('default'),
        );
      } else {
        // Cancel - wire not connected
        widget.wireDrawer.cancel();
      }
    }

    setState(() {});
  }
}

/// Convert Flutter Offset to DPt.
DPt offsetToDpt(Offset offset) => DPt(offset.dx, offset.dy);

/// Layout delegate for schematic canvas.
final class _SchematicLayoutDelegate extends SingleChildLayoutDelegate {
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    // Allow child to be any size up to constraints
    return constraints;
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    return Offset.zero;
  }

  @override
  bool shouldRelayout(_SchematicLayoutDelegate oldDelegate) => false;
}

/// Render object widget for schematic canvas.
final class _SchematicCanvasRenderObjectWidget
    extends SingleChildRenderObjectWidget {
  const _SchematicCanvasRenderObjectWidget({
    required this.scene,
    required this.rackId,
    required this.measurer,
    required this.symbols,
    required this.wires,
    required this.wireDrawer,
    required this.schematicHitTest,
  });

  final DiagramScene scene;
  final String rackId;
  final TextMeasurer measurer;
  final List<RenderedSymbol> symbols;
  final List<WireConnection> wires;
  final WireDrawer wireDrawer;
  final SchematicHitTest? schematicHitTest;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSchematicCanvas(
        scene: scene,
        rackId: rackId,
        measurer: measurer,
        symbols: symbols,
        wires: wires,
        wireDrawer: wireDrawer,
        schematicHitTest: schematicHitTest,
      );

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    final object = renderObject as _RenderSchematicCanvas;
    object
      ..scene = scene
      ..rackId = rackId
      ..measurer = measurer
      ..symbols = symbols
      ..wires = wires
      ..wireDrawer = wireDrawer
      .._schematicHitTest = schematicHitTest;
  }
}

/// Render object for schematic canvas.
final class _RenderSchematicCanvas extends RenderBox {
  _RenderSchematicCanvas({
    required DiagramScene scene,
    required String rackId,
    required TextMeasurer measurer,
    required List<RenderedSymbol> symbols,
    required List<WireConnection> wires,
    required WireDrawer wireDrawer,
    required SchematicHitTest? schematicHitTest,
  }) : _scene = scene,
       _rackId = rackId,
       _measurer = measurer,
       _symbols = symbols,
       _wires = wires,
       _wireDrawer = wireDrawer,
       _schematicHitTest = schematicHitTest;

  DiagramScene _scene;
  String _rackId;
  TextMeasurer _measurer;

  List<RenderedSymbol> _symbols;
  List<WireConnection> _wires;
  WireDrawer _wireDrawer;
  SchematicHitTest? _schematicHitTest;

  DiagramScene get scene => _scene;
  set scene(DiagramScene value) {
    if (_scene == value) return;
    _scene = value;
    markNeedsLayout();
  }

  String get rackId => _rackId;
  set rackId(String value) {
    if (_rackId == value) return;
    _rackId = value;
    markNeedsLayout();
  }

  TextMeasurer get measurer => _measurer;
  set measurer(TextMeasurer value) {
    if (_measurer == value) return;
    _measurer = value;
    markNeedsPaint();
  }

  List<RenderedSymbol> get symbols => _symbols;
  set symbols(List<RenderedSymbol> value) {
    if (identical(_symbols, value)) return;
    _symbols = value;
    markNeedsLayout();
  }

  List<WireConnection> get wires => _wires;
  set wires(List<WireConnection> value) {
    if (_wires == value) return;
    _wires = value;
    markNeedsPaint();
  }

  WireDrawer get wireDrawer => _wireDrawer;
  set wireDrawer(WireDrawer value) {
    if (identical(_wireDrawer, value)) return;
    _wireDrawer = value;
    markNeedsLayout();
  }

  SchematicHitTest? get schematicHitTest => _schematicHitTest;
  set schematicHitTest(SchematicHitTest? value) {
    if (_schematicHitTest == value) return;
    _schematicHitTest = value;
    markNeedsPaint();
  }

  @override
  bool get isRepaintBoundary => false;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;

    for (final symbol in _symbols) {
      final rect = symbol.bodyRect;
      minX = _min(minX, rect.left);
      minY = _min(minY, rect.top);
      maxX = _max(maxX, rect.right);
      maxY = _max(maxY, rect.bottom);
    }

    return Size(
      constraints.constrainWidth(
        (maxX - minX + 100).isNaN ? 400 : maxX - minX + 100,
      ),
      constraints.constrainHeight(
        (maxY - minY + 100).isNaN ? 300 : maxY - minY + 100,
      ),
    );
  }

  @override
  void performLayout() {
    size = constraints.biggest;
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final scenePos = DPt(position.dx, position.dy);

    // Always add self to receive pointer events
    result.add(BoxHitTestEntry(this, position));

    return true; // Allow all pointer events through to this render object
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = FlutterDiagramCanvas(
      context.canvas,
      measurer: _measurer,
    );

    // Paint background
    canvas.drawRect(
      DBox.fromLtwh(0, 0, size.width, size.height),
      fill: Fill(0xFFFFFFFF),
    );

    // Paint symbols
    for (final symbol in _symbols) {
      SymbolBuilder().paint(
        canvas: canvas,
        symbol: symbol,
        bounds: DBox.fromLtwh(0, 0, size.width, size.height),
        palette: SchematicPalette(),
        xOffset: offset.dx,
        yOffset: offset.dy,
      );
    }

    // Paint wires
    if (_wireDrawer.wires.isNotEmpty) {
      for (final wire in _wireDrawer.wires) {
        _paintWire(canvas, wire, offset);
      }
    }

    // Paint preview wire
    if (_wireDrawer.state == DrawState.preview &&
        _wireDrawer.fromNodeId != null &&
        _wireDrawer.previewPos != null) {
      final startPos = _getPortPosition(
        _wireDrawer.fromNodeId!,
        _wireDrawer.fromPortId!,
      );
      final endPos = _wireDrawer.previewPos!;

      if (startPos == null) return;

      canvas.drawPath(
        DiagramPath([
          MoveTo(startPos.x, startPos.y),
          LineTo(endPos.x, endPos.y),
          const ClosePath(),
        ]),
        stroke: Stroke(argb: 0x804CAF50, widthPt: 2, dash: const [10, 5]),
      );
    }
  }

  void _paintWire(
    FlutterDiagramCanvas canvas,
    WireConnection wire,
    Offset offset,
  ) {
    final start = _getPortPosition(wire.fromNodeId, wire.fromPortId);
    final end = _getPortPosition(wire.toNodeId, wire.toPortId);

    if (start == null || end == null) return;

    final path = DiagramPath([
      MoveTo(start.x, start.y),
      LineTo(end.x, end.y),
      const ClosePath(),
    ]);

    canvas.drawPath(path, stroke: Stroke(argb: wire.color, widthPt: 2));
  }

  DPt? _getPortPosition(String nodeId, String portId) {
    for (final symbol in _symbols) {
      if (symbol.id == nodeId) {
        for (final entry in symbol.ports.entries) {
          final side = entry.key;
          final ports = entry.value;
          for (final port in ports) {
            if (port.id == portId) {
              // Calculate position based on side
              final double x, y;
              switch (side) {
                case SymbolSide.left:
                  x = symbol.bodyRect.left - port.size / 2;
                  y = symbol.bodyRect.top + symbol.headerHeight + port.offset;
                  return DPt(x, y);
                case SymbolSide.right:
                  x = symbol.bodyRect.right + port.size / 2;
                  y = symbol.bodyRect.top + symbol.headerHeight + port.offset;
                  return DPt(x, y);
                case SymbolSide.top:
                  x = symbol.bodyRect.left + port.offset;
                  y = symbol.bodyRect.top - port.size / 2;
                  return DPt(x, y);
                case SymbolSide.bottom:
                  x = symbol.bodyRect.left + port.offset;
                  y = symbol.bodyRect.bottom + port.size / 2;
                  return DPt(x, y);
              }
            }
          }
        }
      }
    }
    return null;
  }
}

/// Simple layout node for placeholder auto-layout.
final class _LayoutNode {
  _LayoutNode({
    required this.id,
    required this.width,
    required this.height,
  });

  final String id;
  final double width;
  final double height;
}

// Helper functions
double _min(double a, double b) => a < b ? a : b;
double _max(double a, double b) => a > b ? a : b;
