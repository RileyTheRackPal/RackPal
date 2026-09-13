// The palette column, and whichever canvas is open beside it (`#885`,
// DR-165 §11.164).
//
// ═══════════════════════════════════════════════════════════════════════
// WHY THIS EXISTS AT ALL: A GESTURE WITH NO PRODUCER
// ═══════════════════════════════════════════════════════════════════════
// docs/15 §6's gesture table opens with *"drag from the device palette or
// staging bin onto the plan: places the device and sets its pin in one
// command"*. Both halves were built and never met.
// `buildPlaceOnPlanCommand` carries the pin ON the placement so one undo
// restores both, and `PlanCanvasScreenState.armPaletteDrag` is public with
// a comment saying why: *"the host that owns a palette hands the armed
// pointer down, and `PLAN-E/5` wires the real one."* `PLAN-E/5` shipped
// the tab and the layout and did not bring the palette, so all three of
// `armPaletteDrag`'s call sites were tests.
//
// This is that host. It wraps **the Rack tab and the Plan tab and no
// other**: the Structure editor places outlets and plates from surfaces of
// its own, and a device palette there would be a control that cannot act
// on anything in view, which is docs/04 §3.4's rule about a control that
// silently does nothing.
//
// ═══════════════════════════════════════════════════════════════════════
// IT HANDS OVER A RESOLVED ROW, NOT A KEY (§11.164.2)
// ═══════════════════════════════════════════════════════════════════════
// A `rowKey` is `source/id@version` and a template id is not (DR-102
// §11.101.4), and the two are different strings that both read as "which
// template". `PlanCanvasScreenState._placeFromPalette` took a `rowKey` and
// passed it straight to `buildPlaceOnPlanCommand` as a **`catalogId`**,
// which resolves nothing for any real row; its three tests pass a bare id,
// so that parameter was never given the value its own name promised.
//
// Handing over the `PlaceableTemplate` makes the wrong call
// unrepresentable, and it leaves the row list with ONE owner. Before this,
// `RackCanvasScreen` held the memo, the index and the lookup; anything
// else wanting a palette would have held a second copy of all three.
//
// ═══════════════════════════════════════════════════════════════════════
// THE SEARCH FIELD'S FOCUS NODE IS LENT DOWN, NOT MOVED (§11.164.3)
// ═══════════════════════════════════════════════════════════════════════
// The insertion caret's activation reads `_canvasFocus.hasFocus ||
// _paletteSearchFocus.hasFocus`, because arming a placement from the
// search box is a placement gesture and the caret must stay lit across the
// hand-off. **That is the canvas's rule about its own caret**, so the
// canvas keeps it and this host lends it the node through [builder]. A
// notifier reporting focus upward, plus a second copy of the rule here,
// would be two things that can disagree about one fact.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/keymap/keymap.dart'
    show FocusPaletteSearchIntent, aTextFieldHasFocus;
import 'package:rackpal_ui/src/palette/device_palette_panel.dart';
import 'package:rackpal_ui/src/widgets/document_memo.dart';

/// docs/04 §1's palette column width.
const double kPaletteColumnWidth = 280;

/// Holds the palette's state for whichever views show a column.
///
/// ═══════════════════════════════════════════════════════════════════════
/// IT LAYS NOTHING OUT, AND THE FIRST VERSION DID (§11.164.5)
/// ═══════════════════════════════════════════════════════════════════════
/// This wrapped its child in a `Row` and drew the column beside it, with a
/// `showColumn` flag for the tabs that have no palette. **That broke every
/// tab switch**, and the mechanism is worth keeping: `TabBarView` is a
/// `PageView`, which positions by PIXEL OFFSET (`index * viewportWidth`).
/// Hiding a 280px column widens the viewport by 280px, so an offset
/// animated for the old width lands between pages: tapping `Schematic`
/// from the Rack tab showed `Structured Wiring`, one page short.
///
/// So the host provides and the TAB BODY places. [PaletteColumn] reads
/// this state through the tree and each view that wants a palette puts one
/// in its own `Row`, which leaves the `TabBarView`'s width constant and
/// makes "which views have a palette" a fact about those views rather than
/// a flag passed down from here.
class PaletteHost extends StatefulWidget {
  const PaletteHost({
    required this.doc,
    required this.onPlace,
    required this.onArmDrag,
    required this.onDismissSearch,
    required this.searchFocus,
    required this.child,
    this.libraries = const [],
    this.unreadableLibraries = const [],
    this.favourites = const <String>{},
    this.draggingRowKey,
    this.onRefuse,
    super.key,
  });

  /// The live document. Rows are memoised on it, so a command that adds a
  /// template moves the palette without a reopen.
  final RackDocument doc;

  /// Libraries on the shelf (`#242`, DR-102 §11.101.3). Compared by
  /// IDENTITY to decide whether the memo is stale, which is exact rather
  /// than a heuristic over lengths: the app builds a fresh list only when
  /// it has actually re-read.
  final List<LoadedLibrary> libraries;

  /// Libraries that would not decode. They contribute no rows and so
  /// cannot be derived from the list above (DR-103 §11.102.7).
  final List<UnreadableLibrary> unreadableLibraries;

  /// The template ids this user has starred (`#245`).
  final Set<String> favourites;

  /// Activated by double-click or `Enter`, with the row that was chosen.
  final void Function(PlaceableTemplate row) onPlace;

  /// docs/04 §3.1 step 1: a plain pointer-down on a row, with the row.
  final void Function(PlaceableTemplate row, PointerDownEvent event) onArmDrag;

  /// `Esc` in the search field. This host clears the query; the callback
  /// is what gives the keyboard back, which only the open canvas can do.
  final VoidCallback onDismissSearch;

  /// Announces a refusal on the host's status line.
  final void Function(String message)? onRefuse;

  /// Which row to dim while it is being dragged (docs/04 §3.1).
  ///
  /// **A LISTENABLE AND NOT A VALUE**, because the canvas is this widget's
  /// CHILD: it learns which row is engaged after this build has run, and a
  /// plain field would be one frame stale for the whole gesture. A canvas
  /// with no palette drag of its own (the plan's, whose header records
  /// that the drag-preview machinery does not fit a floorplan) supplies
  /// nothing and no row ever dims.
  final ValueListenable<String?>? draggingRowKey;

  /// The search field's focus node.
  ///
  /// **OWNED BY THE COMMON ANCESTOR, which is the host's host** (DR-165
  /// §11.164.3). Two widgets need it and neither is the other's parent:
  /// this one to give the field its focus, and the canvas to read
  /// `.hasFocus`, because arming a placement from the search box is a
  /// placement gesture and the caret must stay lit across the hand-off.
  /// A node created HERE would not exist yet when the shell builds the
  /// tab bodies, so the canvas would spend its first frame reading null.
  final FocusNode searchFocus;

  /// Everything that might show a [PaletteColumn], which in the shell is
  /// the whole tab view.
  final Widget child;

  /// The palette's state, for a [PaletteColumn] below this in the tree.
  static PaletteHostState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_PaletteScope>();
    assert(scope != null, 'A PaletteColumn needs a PaletteHost above it.');
    return scope!.state;
  }

  @override
  State<PaletteHost> createState() => PaletteHostState();
}

class PaletteHostState extends State<PaletteHost> {
  final TextEditingController _searchController = TextEditingController();

  /// Memoised on the document's `stateId`, cleared when the shelf is
  /// re-read. Moved here from `RackCanvasScreen` whole: it owned the memo,
  /// the index and the lookup, and a second palette would have held a
  /// second copy of all three.
  final DocumentMemo<List<PlaceableTemplate>> _placeable = DocumentMemo();

  /// The merged rows by `rowKey`, rebuilt whenever the list is.
  ///
  /// **THE PALETTE HANDS BACK A `rowKey` AND THIS IS WHAT RESOLVES IT.**
  /// Since `#242` a template id can name two rows, the document's and a
  /// library's (DR-102 §11.101.4), so an id alone is no longer an answer
  /// to "which row did they click".
  Map<String, PlaceableTemplate> _rowsByKey = const {};

  /// The list [_rowsByKey] was built from, compared by IDENTITY: the memo
  /// hands back the same instance on a hit and a fresh one on a miss, so
  /// this is an exact "is my index stale" test rather than a count.
  List<PlaceableTemplate>? _rowsIndexedFrom;

  @override
  void didUpdateWidget(PaletteHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.libraries, widget.libraries)) _placeable.clear();
  }

  @override
  void dispose() {
    // THE NODE IS NOT DISPOSED HERE: it is the host's host's, and this
    // widget is rebuilt whenever the document is replaced.
    _searchController.dispose();
    super.dispose();
  }

  List<PlaceableTemplate> get _rows {
    final rows = _placeable.of(
      widget.doc,
      () => buildPlaceableTemplates(widget.doc, libraries: widget.libraries),
    );
    // REBUILT WHENEVER THE LIST IS, not memoised separately: two caches
    // over one answer is two things that can disagree, and this one is
    // O(rows) over a list that was just built.
    if (!identical(_rowsIndexedFrom, rows)) {
      _rowsIndexedFrom = rows;
      _rowsByKey = {for (final row in rows) row.rowKey: row};
    }
    return rows;
  }

  /// `/`, from either canvas (§11.164.4).
  ///
  /// **SELECTS THE EXISTING QUERY**, which `RackCanvasScreen` decided and
  /// this inherits verbatim: landing in a field whose content has to be
  /// cleared by hand is how `/` became another way INTO a bad filter, and
  /// during the period when `Backspace` was being eaten by the rack's own
  /// keymap, by hand was not possible. Retargeting the whole query is also
  /// what `/`-to-search means everywhere else it exists: "start a new
  /// search", not "resume editing the last one".
  void focusSearch() {
    widget.searchFocus.requestFocus();
    final text = _searchController.text;
    if (text.isNotEmpty) {
      _searchController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: text.length,
      );
    }
  }

  /// `Esc` inside the filter: empty it and hand the keyboard back.
  ///
  /// Field-local, and deliberately NOT routed through a cancel intent:
  /// those are gated OFF while a text field has focus, precisely so `Esc`
  /// cannot reach across and clear a canvas selection out from under
  /// someone who is typing. Having taken `Esc` away from the canvas here,
  /// the field owes the user something for it.
  void _dismissSearch() {
    _searchController.clear();
    widget.onDismissSearch();
  }

  void _place(String rowKey) {
    final row = _rowsByKey[rowKey];
    if (row == null) return;
    widget.onPlace(row);
  }

  void _armDrag(String rowKey, PointerDownEvent event) {
    // OUT OF THE PALETTE'S OWN ROW, at the version it is offering. The
    // rack screen's version of this read `resolveLatestTemplate(doc, id)`
    // until `#242`, and a library row is not in the document, so the
    // document lookup answered null and a drag from a library row refused
    // to start, silently. The row the palette drew is the answer.
    final row = _rowsByKey[rowKey];
    if (row == null) return;
    widget.onArmDrag(row, event);
  }

  @override
  Widget build(BuildContext context) => Actions(
    // THE INTENT BUBBLES UP TO HERE rather than each canvas holding a
    // handler and a callback down to this state. Both canvases map `/`
    // to `FocusPaletteSearchIntent` from the keymap; this is the only
    // thing in the tree that can service it, because it is the only
    // thing that holds the field.
    actions: <Type, Action<Intent>>{
      FocusPaletteSearchIntent: CallbackAction<FocusPaletteSearchIntent>(
        onInvoke: (_) {
          // WHAT `/` MUST NEVER DO IS FAIL TO TYPE A SLASH INTO A FIELD.
          // `RackCanvasScreen` gated this and the gate travelled with the
          // binding rather than staying behind with the screen that used
          // to own it.
          if (aTextFieldHasFocus()) return null;
          focusSearch();
          return null;
        },
      ),
    },
    child: _PaletteScope(state: this, child: widget.child),
  );

  /// The column itself, built for whichever view asked for one.
  Widget buildColumn(BuildContext context) => SizedBox(
    width: kPaletteColumnWidth,
    child: ValueListenableBuilder<String?>(
      valueListenable: widget.draggingRowKey ?? const _NeverDragging(),
      builder: (context, dragging, _) => DevicePalettePanel(
        // WHAT THE DOCUMENT CAN PLACE, not what this build ships
        // (DR-077 §11.76.1).
        templates: _rows,
        // `#244`, DR-104 §11.103.5. The registries only WIDEN the
        // search: what they add is the vocabulary that is not a
        // substring of the id, `hdbt` being DR-060's own example.
        registries: widget.doc.registries,
        favourites: widget.favourites,
        unreadableLibraries: widget.unreadableLibraries,
        categoryOrder: kCatalogCategoryOrder,
        searchFocusNode: widget.searchFocus,
        searchController: _searchController,
        onDismissSearch: _dismissSearch,
        onRefuse: widget.onRefuse,
        onPlace: _place,
        onArmDrag: _armDrag,
        draggingRowKey: dragging,
      ),
    ),
  );
}

/// Carries [PaletteHostState] down to a [PaletteColumn].
class _PaletteScope extends InheritedWidget {
  const _PaletteScope({required this.state, required super.child});

  final PaletteHostState state;

  /// **ALWAYS, AND `state != old.state` WAS WRONG.** The value carried
  /// here is the `State` OBJECT, which is the same instance for the life
  /// of the host: comparing it answers "was this widget replaced", never
  /// "did anything the column draws change". With that comparison the
  /// column never rebuilt, so a template saved while the canvas was open
  /// did not appear in the palette, which is exactly what `#242`'s cases
  /// are about.
  ///
  /// The host rebuilds only when its own inputs move, so notifying on
  /// every one of those is both correct and cheap.
  @override
  bool updateShouldNotify(_PaletteScope old) => true;
}

/// docs/04 §1's palette column, placed by the view that wants one.
///
/// **A VIEW HAS A PALETTE BECAUSE ITS OWN LAYOUT SAYS SO.** That is the
/// answer to the question `#885` left open, expressed as structure rather
/// than as a flag: the Structure editor places outlets and plates from
/// surfaces of its own, and it simply does not put one of these in its
/// `Row`.
class PaletteColumn extends StatelessWidget {
  const PaletteColumn({super.key});

  @override
  Widget build(BuildContext context) =>
      PaletteHost.of(context).buildColumn(context);
}

/// A listenable that is always null and never fires, for a canvas with no
/// palette drag of its own.
///
/// `const` and shared: it holds no state, so one instance can serve every
/// host, and it never adds a listener to anything that could outlive it.
class _NeverDragging implements ValueListenable<String?> {
  const _NeverDragging();

  @override
  String? get value => null;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
