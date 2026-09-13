// The palette column and a canvas, composed the way `AppShell` composes
// them (`#885`, DR-165 §11.164).
//
// ═══════════════════════════════════════════════════════════════════════
// WHY A TEST FILE HOLDS A COMPOSITION, AND WHAT THAT DOES NOT PROVE
// ═══════════════════════════════════════════════════════════════════════
// `RackCanvasScreen` owned the only `DevicePalettePanel` in the tree until
// `#885`, so every case that typed in the filter, double-clicked a row or
// dragged one onto the rails got the palette for free by pumping the
// screen. The palette is `PaletteHost`'s now, and `rackpal_ui` cannot
// import the app, so the composition has to be written here for those
// cases to keep meaning what they meant.
//
// **THIS IS NOT EVIDENCE THAT THE SHELL MOUNTS IT.** A helper that mirrors
// a host is the shape `.okf/practices/a-surface-tested-alone-has-no-host.md`
// was written about: two files agreeing with each other while the product
// does something else. What closes that gap is `apps/rackpal/test`, where
// the real `AppShell` is pumped and the palette is found on the tabs it
// belongs on and absent from the rest. Keep both.
//
// ═══════════════════════════════════════════════════════════════════════
// IT LISTENS TO `controller.changes`, WHICH IS THE SHELL'S OWN MECHANISM
// ═══════════════════════════════════════════════════════════════════════
// The palette is a projection of the document, and the host is now the
// canvas's PARENT: a `setState` inside the canvas no longer rebuilds it.
// In the app the chain is `DocumentController.changes` to
// `DocumentSession` to the shell's `setState`, which is why saving a
// template while the canvas is open moves the palette. This subscribes to
// the first link of that same chain rather than inventing a second one.
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

/// Builds the canvas, given what the host lends it.
///
/// **THE KEY IS HANDED OVER TOO, AND THAT IS NOT CEREMONY.** The host
/// reaches the canvas through a `GlobalObjectKey` on the controller,
/// exactly as `AppShell` does, so a canvas built without it is a canvas
/// the palette cannot arm. Passing it in makes forgetting it a compile
/// error rather than a drag that silently never lifts, which is how the
/// first version of this helper failed.
typedef CanvasWithPaletteBuilder =
    Widget Function(
      GlobalKey<RackCanvasScreenState> key,
      FocusNode searchFocus,
      ValueNotifier<String?> dragRow,
    );

class RackWithPalette extends StatefulWidget {
  const RackWithPalette({
    required this.controller,
    required this.canvas,
    this.libraries = const [],
    this.unreadableLibraries = const [],
    this.favourites = const <String>{},
    this.onRefuse,
    super.key,
  });

  final DocumentController controller;
  final CanvasWithPaletteBuilder canvas;
  final List<LoadedLibrary> libraries;
  final List<UnreadableLibrary> unreadableLibraries;
  final Set<String> favourites;
  final void Function(String message)? onRefuse;

  @override
  State<RackWithPalette> createState() => _RackWithPaletteState();
}

class _RackWithPaletteState extends State<RackWithPalette> {
  final ValueNotifier<String?> _dragRow = ValueNotifier<String?>(null);

  /// A `GlobalObjectKey` on the controller, exactly as the shell keys the
  /// rack tab, so `onPlace` and `onArmDrag` reach the live canvas.
  GlobalObjectKey<RackCanvasScreenState> get _key =>
      GlobalObjectKey<RackCanvasScreenState>(widget.controller);

  @override
  void initState() {
    super.initState();
    widget.controller.changes.addListener(_onDocumentChanged);
  }

  @override
  void dispose() {
    widget.controller.changes.removeListener(_onDocumentChanged);
    _dragRow.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onDocumentChanged() {
    if (mounted) setState(() {});
  }

  final FocusNode _searchFocus = FocusNode(debugLabel: 'paletteSearch');

  @override
  Widget build(BuildContext context) => PaletteHost(
    doc: widget.controller.doc,
    libraries: widget.libraries,
    unreadableLibraries: widget.unreadableLibraries,
    favourites: widget.favourites,
    draggingRowKey: _dragRow,
    onRefuse: widget.onRefuse ?? (m) => _key.currentState?.showStatus(m),
    onPlace: (row) => _key.currentState?.placeFromPalette(row),
    onArmDrag: (row, event) => _key.currentState?.armPaletteDrag(row, event),
    onDismissSearch: () => _key.currentState?.focusCanvas(),
    searchFocus: _searchFocus,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PaletteColumn(),
        const VerticalDivider(width: 1),
        Expanded(child: widget.canvas(_key, _searchFocus, _dragRow)),
      ],
    ),
  );
}
