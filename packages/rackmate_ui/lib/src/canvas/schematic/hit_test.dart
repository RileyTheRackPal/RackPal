// rackmate_ui/src/canvas/schematic/hit_test.dart — Hit testing for schematic canvas.
//
// Port hit-testing and magnetic snapping support.

import 'dart:math' show sqrt;

import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/src/canvas/schematic/symbol.dart';
import 'package:rackmate_ui/src/draw/flutter_canvas.dart';

/// Hit test result from a point query on the schematic canvas.
final class SchematicHitResult {
  SchematicHitResult({
    this.type = SchematicHitType.none,
    this.nodeId,
    this.portId,
    this.side,
  });
  
  final SchematicHitType type;
  final String? nodeId;
  final String? portId;
  final SymbolSide? side;
}

/// Types of hits that can occur on the schematic canvas.
enum SchematicHitType {
  none,      // No hit
  node,      // Device body
  port,      // Port circle (hit-test zone)
  snap,      // Snap-to-grid position
}

/// Hit test parameters.
final class HitTestParams {
  HitTestParams({
    this.portHitTolerance = 15.0,
    this.snapGridSize = 20.0,
  });
  
  /// Radius around ports to consider a hit (in screen pixels)
  final double portHitTolerance;
  
  /// Grid size for magnetic snapping
  final double snapGridSize;
}

/// Hit test result with snap info.
final class HitTestResult {
  HitTestResult({
    this.hit = SchematicHitType.none,
    this.position,
    this.snapPosition,
    this.nodeId,
    this.portId,
    this.side,
  });
  
  final SchematicHitType hit;
  final DPt? position; // exact hit point
  final DPt? snapPosition; // snapped position (if magnetic)
  final String? nodeId;
  final String? portId;
  final SymbolSide? side;
}

/// Port matcher for finding compatible connection targets.
final class PortMatcher {
  PortMatcher({
    this.currentFamily,
    this.currentDirection,
  });
  
  final SignalFamilyId? currentFamily;
  final PortDirection? currentDirection;
  
  /// Check if a port is a valid connection target.
  bool matches(PortDef target) {
    // Must be in same signal family
    if (currentFamily != null && target.signalFamily != currentFamily) {
      return false;
    }
    
    // Direction compatibility check
    if (currentDirection != null) {
      switch (currentDirection!) {
        case PortDirection.source:
          if (target.direction == PortDirection.sink ||
              target.direction == PortDirection.passive) {
            return true;
          }
        case PortDirection.sink:
          if (target.direction == PortDirection.source ||
              target.direction == PortDirection.passive) {
            return true;
          }
        case PortDirection.bidirectional:
        case PortDirection.busNode:
        case PortDirection.passive:
          // Bidirectional can connect to anything
          return true;
      }
    }
    
    return false;
  }
}

/// Schematic hit test manager.
final class SchematicHitTest {
  SchematicHitTest({
    required this.symbols,
    required this.params,
  });
  
  final List<RenderedSymbol> symbols;
  final HitTestParams params;
  
  /// Test a point against all symbols and ports.
  HitTestResult testPoint(DPt point) {
    // First check for snap positions (grid alignment)
    final snapped = _snapToGrid(point);
    
    // Check port hits
    for (final symbol in symbols) {
      for (final entry in symbol.ports.entries) {
        for (final port in entry.value) {
          final pos = _portPosition(symbol, port);
          if (_distance(pos, point) < params.portHitTolerance) {
            return HitTestResult(
              hit: SchematicHitType.port,
              position: pos,
              snapPosition: snapped,
              nodeId: symbol.id,
              portId: port.id,
              side: entry.key,
            );
          }
        }
      }
      
      // Check body hits
      if (symbol.bodyRect.contains(point)) {
        return HitTestResult(
          hit: SchematicHitType.node,
          position: point,
          snapPosition: snapped,
          nodeId: symbol.id,
        );
      }
    }
    
    // No hit - return snap position as cursor hint
    return HitTestResult(
      hit: SchematicHitType.snap,
      position: point,
      snapPosition: snapped,
    );
  }
  
  /// Find the closest compatible port to a given position.
  HitTestResult findBestTarget(DPt fromPos, String fromNodeId, SignalFamilyId family) {
    var bestDist = double.infinity;
    var bestResult = HitTestResult();
    
    for (final symbol in symbols) {
      if (symbol.id == fromNodeId) continue; // Skip source node
      
      for (final entry in symbol.ports.entries) {
        for (final port in entry.value) {
          // TODO: Implement PortMatcher integration
          final target = _mockPortDef(port, entry.key);
          
          final pos = _portPosition(symbol, port);
          final dist = _distance(pos, fromPos);
          
          if (dist < bestDist && dist <= params.portHitTolerance * 2) {
            bestDist = dist;
            bestResult = HitTestResult(
              hit: SchematicHitType.port,
              position: pos,
              snapPosition: _snapToGrid(pos),
              nodeId: symbol.id,
              portId: port.id,
              side: entry.key,
            );
          }
        }
      }
    }
    
    return bestResult;
  }
  
  /// Calculate snapped position on grid.
  DPt _snapToGrid(DPt point) {
    final x = (point.x / params.snapGridSize).round() * params.snapGridSize;
    final y = (point.y / params.snapGridSize).round() * params.snapGridSize;
    return DPt(x, y);
  }
  
  /// Get screen position of a port.
  DPt _portPosition(RenderedSymbol symbol, SymbolPort port) {
    final body = symbol.bodyRect;
    
    switch (port.side) {
      case SymbolSide.left:
        return DPt(body.left - port.size / 2, body.top + symbol.headerHeight + port.offset);
      case SymbolSide.right:
        return DPt(body.right + port.size / 2, body.top + symbol.headerHeight + port.offset);
      case SymbolSide.top:
        return DPt(body.left + port.offset, body.top - port.size / 2);
      case SymbolSide.bottom:
        return DPt(body.left + port.offset, body.bottom + port.size / 2);
    }
  }
  
  /// Calculate Euclidean distance between two points.
  double _distance(DPt a, DPt b) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    return sqrt(dx * dx + dy * dy);
  }
  
   /// Create a mock PortDef for testing compatibility.
   PortDef _mockPortDef(SymbolPort port, SymbolSide side) {
     // Direction is determined by side (left=source, right=sink, etc.)
     final direction = switch (side) {
       SymbolSide.left => PortDirection.source,
       SymbolSide.right => PortDirection.sink,
       _ => PortDirection.bidirectional,
     };
     
     return PortDef(
       key: PortKey(port.id),
       label: '',
       connector: const ConnectorTypeId('mock'),
       signalFamily: port.family,
       face: Face.front,
       position: PanelPosition(ruOffset: 0, xTwelfth: 0, xFineNm: Len(0), yFineNm: Len(0)),
       order: FracIndex('a0'),
       direction: direction,
     );
   }
}

/// Extension on DPt for distance calculations.
extension DPointExt on DPt {
  double distanceTo(DPt other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return sqrt(dx * dx + dy * dy);
  }
}
