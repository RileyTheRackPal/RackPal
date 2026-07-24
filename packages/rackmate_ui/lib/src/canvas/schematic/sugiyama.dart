// rackmate_ui/src/canvas/schematic/sugiyama.dart — Sugiyama layout algorithm
// implementation (phases 0-3) for hierarchical graph layout.
//
// Phase 0: Cycle breaking - orient edges to form a DAG
// Phase 1: Layer assignment - assign vertices to layers
// Phase 2: Barycentre ordering - order vertices within each layer
// Phase 3: Coordinate assignment - assign x,y coordinates

import 'dart:math' show Random, min, max;

/// A node in the layout graph.
final class LayoutNode {
  LayoutNode(this.id, {this.width = 100.0, this.height = 60.0});
  
  final String id;
  double width;
  double height;
  
  /// Calculated position after layout
  late double x;
  late double y;
  
  /// Layer assignment (phase 1)
  int layer = -1;
}

/// An edge in the layout graph.
final class LayoutEdge {
  LayoutEdge(this.from, this.to);
  
  final String from;
  final String to;
}

/// Result of Sugiyama layout algorithm.
final class SugiyamaResult {
  SugiyamaResult({
    required this.nodes,
    required this.edges,
    required this.layers,
    required this.totalWidth,
    required this.totalHeight,
  });
  
  final List<LayoutNode> nodes;
  final List<LayoutEdge> edges;
  final List<List<String>> layers; // node ids by layer
  final double totalWidth;
  final double totalHeight;
}

/// Sugiyama layout algorithm for hierarchical graph layout.
///
/// Implements phases 0-3:
/// Phase 0: Cycle breaking - orient edges to form a DAG
/// Phase 1: Layer assignment - assign vertices to layers
/// Phase 2: Barycentre ordering - order vertices within each layer
/// Phase 3: Coordinate assignment - assign x,y coordinates
final class SugiyamaLayout {
  SugiyamaLayout({
    this.nodeSpacing = 40.0,
    this.layerSpacing = 60.0,
    this.randomSeed,
  });
  
  /// Horizontal spacing between nodes in same layer
  final double nodeSpacing;
  
  /// Vertical spacing between layers
  final double layerSpacing;
  
  /// Random seed for deterministic cycle breaking
  final int? randomSeed;
  
  /// Run the full Sugiyama layout algorithm.
  SugiyamaResult run(List<LayoutNode> nodes, List<LayoutEdge> edges) {
    // Phase 0: Cycle breaking
    final (dagEdges, _) = _phase0CycleBreak(edges);
    
    // Build adjacency info for phase 1
    final adj = _buildAdjacency(dagEdges);
    
    // Phase 1: Layer assignment
    final layerAssignment = _phase1LayerAssign(nodes, dagEdges, adj);
    
    // Group nodes by layer
    final layers = <List<String>>[];
    for (final node in nodes) {
      final l = layerAssignment[node.id] ?? 0;
      while (layers.length <= l) layers.add([]);
      layers[l].add(node.id);
    }
    
    // Phase 2: Barycentre ordering
    _phase2Barycentre(nodes, dagEdges, layers, adj);
    
    // Phase 3: Coordinate assignment
    _phase3Coordinates(nodes, layers, adj);
    
    // Calculate total bounds
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = -double.infinity;
    double maxY = -double.infinity;
    for (final node in nodes) {
      minX = min(minX, node.x);
      minY = min(minY, node.y);
      maxX = max(maxX, node.x + node.width);
      maxY = max(maxY, node.y + node.height);
    }
    
    return SugiyamaResult(
      nodes: nodes,
      edges: edges, // original edges for reference
      layers: List.from(layers),
      totalWidth: maxX - minX,
      totalHeight: maxY - minY,
    );
  }
  
  /// Phase 0: Cycle breaking using DFS.
  ///
  /// Converts a general graph to a DAG by reversing edges that would create cycles.
  (List<LayoutEdge>, Map<String, bool>) _phase0CycleBreak(List<LayoutEdge> edges) {
    final adj = <String, List<String>>{};
    for (final edge in edges) {
      adj[edge.from] ??= [];
      adj[edge.to] ??= [];
      adj[edge.from]!.add(edge.to);
    }
    
    final visited = <String>{};
    final recStack = <String>{};
    final dagEdges = <LayoutEdge>[];
    final reverseMap = <String, bool>{};
    final random = Random(randomSeed ?? 42);
    
    void dfs(String node) {
      visited.add(node);
      recStack.add(node);
      
      final neighbors = adj[node] ?? [];
      for (final String neighbor in List.from(neighbors)..shuffle(random)) {
        if (!visited.contains(neighbor)) {
          dagEdges.add(LayoutEdge(node, neighbor));
          reverseMap['$node->$neighbor'] = true;
          dfs(neighbor);
        } else if (recStack.contains(neighbor)) {
          // Back edge - would create cycle, so reverse it
          dagEdges.add(LayoutEdge(neighbor, node));
          reverseMap['$neighbor->$node'] = false;
        }
      }
      
      recStack.remove(node);
    }
    
    for (final String node in adj.keys) {
      if (!visited.contains(node)) {
        dfs(node);
      }
    }
    
    return (dagEdges, reverseMap);
  }
  
  /// Phase 1: Layer assignment using longest path algorithm.
  ///
  /// Assigns each vertex to a layer such that all edges point from lower
  /// to higher layers (in the DAG from phase 0).
  Map<String, int> _phase1LayerAssign(
    List<LayoutNode> nodes,
    List<LayoutEdge> edges,
    Map<String, List<String>> adj,
  ) {
    final layer = <String, int>{};
    
    // Topological sort
    final inDegree = <String, int>{};
    for (final node in nodes) {
      inDegree[node.id] = 0;
    }
    for (final edge in edges) {
      inDegree[edge.to] = (inDegree[edge.to] ?? 0) + 1;
    }
    
    final queue = <String>[];
    for (final node in nodes) {
      if ((inDegree[node.id] ?? 0) == 0) {
        queue.add(node.id);
      }
    }
    
     // Longest path from sources
     for (final String node in queue) {
       layer[node] = layer[node] ?? 0;
       final neighbors = adj[node] ?? [];
       for (final String neighbor in neighbors) {
         layer[neighbor] = max(layer[neighbor] ?? 0, layer[node]! + 1);
         final newDegree = (inDegree[neighbor] ?? 0) - 1;
         inDegree[neighbor] = newDegree;
         if (newDegree == 0) {
           queue.add(neighbor);
         }
       }
     }
    
    return layer;
  }
  
  /// Phase 2: Barycentre ordering.
  ///
  /// Orders vertices within each layer to minimize edge crossings using
  /// the barycentre heuristic.
  void _phase2Barycentre(
    List<LayoutNode> nodes,
    List<LayoutEdge> edges,
    List<List<String>> layers,
    Map<String, List<String>> adj,
  ) {
    for (int layerIdx = 0; layerIdx < layers.length; layerIdx++) {
      final layerNodes = layers[layerIdx];
      
      // Calculate barycentre for each node in this layer
      final barycentres = <String, double>{};
      for (final nodeId in layerNodes) {
        final neighbors = adj[nodeId] ?? [];
        if (neighbors.isEmpty) {
          barycentres[nodeId] = 0.5;
          continue;
        }
        
        // Find neighbors' positions
        double sumPos = 0;
        int count = 0;
        for (final neighbor in neighbors) {
          final otherLayer = layers.indexOf(
            layers.firstWhere((l) => l.contains(neighbor)),
          );
          if (otherLayer == -1) continue;
          
          final neighborIdx = layerIdx < otherLayer
              ? _findPositionInLayer(layerNodes, adj[neighbor] ?? [])
              : layerIdx > otherLayer
                  ? layerNodes.indexOf(neighbor)
                  : -1;
          
          if (neighborIdx != -1) {
            sumPos += neighborIdx / (layerNodes.length - 1);
            count++;
          }
        }
        
        barycentres[nodeId] = count > 0 ? sumPos / count : 0.5;
      }
      
      // Sort by barycentre
      layerNodes.sort((a, b) => barycentres[a]!.compareTo(barycentres[b]!));
    }
  }
  
  /// Phase 3: Coordinate assignment.
  ///
  /// Assigns x,y coordinates to vertices based on their layer and ordering.
  void _phase3Coordinates(
    List<LayoutNode> nodes,
    List<List<String>> layers,
    Map<String, List<String>> adj,
  ) {
    // Calculate x positions for each layer
    final layerX = <int, List<double>>{};
    
    for (int layerIdx = 0; layerIdx < layers.length; layerIdx++) {
      final layerNodes = layers[layerIdx];
      final xPositions = <double>[];
      
      // Start from center of total width
      double centerX = (layerNodes.length - 1) * nodeSpacing / 2;
      
      for (int i = 0; i < layerNodes.length; i++) {
        final nodeId = layerNodes[i];
        xPositions.add(centerX - i * nodeSpacing);
        
        final node = nodes.firstWhere((n) => n.id == nodeId);
        node.x = xPositions.last;
        node.y = layerIdx * layerSpacing;
      }
      
      layerX[layerIdx] = xPositions;
    }
  }
  
  /// Build adjacency list from edges.
  Map<String, List<String>> _buildAdjacency(List<LayoutEdge> edges) {
    final adj = <String, List<String>>{};
    
    for (final edge in edges) {
      adj[edge.from] ??= [];
      adj[edge.to] ??= [];
      adj[edge.from]!.add(edge.to);
    }
    
    return adj;
  }
  
  /// Find position of any neighbor in the given layer.
  int _findPositionInLayer(List<String> layerNodes, List<String> neighbors) {
    for (int i = 0; i < layerNodes.length; i++) {
      if (neighbors.contains(layerNodes[i])) {
        return i;
      }
    }
    return -1;
  }
}

/// Extension to find first element matching predicate.
extension on List<String> {
  String? firstWhereOrNull(bool Function(String) predicate) {
    for (final item in this) {
      if (predicate(item)) return item;
    }
    return null;
  }
}