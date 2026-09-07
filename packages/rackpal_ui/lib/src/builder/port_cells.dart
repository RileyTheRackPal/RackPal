// The port grid's CELL CONTROLS, extracted from `port_grid.dart` at
// M4-F11 (board `#703`).
//
// ═══════════════════════════════════════════════════════════════════════
// WHY THEY MOVED, AND WHY IT HAD TO HAPPEN BEFORE THE FEATURE
// ═══════════════════════════════════════════════════════════════════════
// M4-F2 shipped the batch inspector as a READ surface, and `#703` recorded
// exactly why setting a field from it was not built with the rest: every
// control here was private to the grid and bound to ONE port's value, and
// **"mixed" is not a value**, so none of them could represent the state
// the dock exists to show. That is a refactor rather than a feature and
// it was filed rather than rushed.
//
// ═══════════════════════════════════════════════════════════════════════
// THE MIXED STATE IS ONE PARAMETER: SHOW THIS, HOLD NOTHING
// ═══════════════════════════════════════════════════════════════════════
// `mixedLabel` non-null means the selection disagrees. A control in that
// state renders DR-063's `Mixed (N values)` and carries NO value, which
// makes docs/06 §4.6's safety property ("left untouched unless explicitly
// set") structural rather than remembered:
//
//  * the menus hold `null` and fire `onPick` only from an actual pick, so
//    building one, focusing it and tabbing away cannot write;
//  * [PortTextCell] seeds its controller EMPTY and its commit compares
//    against what it was seeded with, so a focus-and-blur is equal to the
//    seed and returns early.
//
// **THAT IS THE TRAP `#703` NAMED**: "a control seeded from mixed that
// fires its `onChanged` during construction, or on focus, writes the dash
// back across N rows". `port_batch_test.dart` proves the CORE cannot
// express that write; these two mechanisms are why the widget cannot
// manufacture one.
//
// ONE CONSEQUENCE, STATED RATHER THAN DISCOVERED: from a MIXED text cell
// there is no way to write "clear this across all of them", because an
// emptied box equals the empty seed. Clearing is available per row in the
// grid, and inventing a second gesture for it here would be a control
// whose blank means two things.
//
// ═══════════════════════════════════════════════════════════════════════
// PUBLIC, AND ONLY TO TWO CALLERS
// ═══════════════════════════════════════════════════════════════════════
// `port_grid.dart` and `batch_inspector.dart`. They are not exported from
// the package barrel: a third caller would be a surface drawing a port
// cell outside the builder, which is a design question and not an import.
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/widgets/family_picker.dart';

/// A cell holding a whole number.
///
/// KEEPS WHAT WAS TYPED WHEN IT DOES NOT PARSE, rather than silently
/// reverting. `9,600` and `9600 baud` are things a person types, and a box
/// that empties itself when they tab away tells them nothing about which
/// of the two the app disliked. Nothing is written until it parses; an
/// empty box writes UNKNOWN.
class PortNumberCell extends StatelessWidget {
  const PortNumberCell({
    required this.value,
    required this.onCommit,
    this.hint,
    this.mixedLabel,
    super.key,
  });

  final int? value;
  final ValueChanged<int?> onCommit;
  final String? hint;

  /// See [PortTextCell.mixedLabel]; forwarded unchanged.
  final String? mixedLabel;

  @override
  Widget build(BuildContext context) => PortTextCell(
    value: value?.toString(),
    hint: hint,
    mixedLabel: mixedLabel,
    onCommit: (typed) {
      final text = typed.trim();
      if (text.isEmpty) {
        onCommit(null);
        return;
      }
      final parsed = int.tryParse(text);
      if (parsed != null) onCommit(parsed);
    },
  );
}

/// A closed set that also accepts "nobody has said" (G4).
///
/// THE UNKNOWN ROW IS FIRST AND IS ALWAYS OFFERED. Every one of these
/// fields is nullable in the model because absent means unknown, so a menu
/// a person cannot get back out of would make the first pick permanent.
class PortNullableChoiceCell<T extends Enum> extends StatelessWidget {
  const PortNullableChoiceCell({
    required this.value,
    required this.options,
    required this.label,
    required this.onPick,
    this.mixedLabel,
    super.key,
  });

  final T? value;
  final List<T> options;
  final String Function(T value) label;
  final ValueChanged<T?> onPick;

  /// See [PortChoiceCell.mixedLabel]; forwarded unchanged.
  final String? mixedLabel;

  @override
  Widget build(BuildContext context) => PortChoiceCell<T?>(
    value: value,
    options: [null, ...options],
    label: (v) => v == null ? kUnknownCell : label(v),
    onPick: onPick,
    mixedLabel: mixedLabel,
  );
}

/// A `bool?` cell: yes, no, or nobody has said.
///
/// A DROPDOWN AND NOT A CHECKBOX, and that is G4 rather than taste. A
/// checkbox has two states, so an unmeasured port would have to render as
/// a no, which is a measurement nobody took.
class PortTriStateCell extends StatelessWidget {
  const PortTriStateCell({
    required this.value,
    required this.onPick,
    this.mixedLabel,
    super.key,
  });

  final bool? value;
  final ValueChanged<bool?> onPick;

  /// See [PortChoiceCell.mixedLabel]; forwarded unchanged.
  final String? mixedLabel;

  @override
  Widget build(BuildContext context) => PortChoiceCell<bool?>(
    value: value,
    options: const [null, true, false],
    label: (v) => portTriStateLabel(value: v),
    onPick: onPick,
    mixedLabel: mixedLabel,
  );
}

/// A cell nothing writes through: derived, or not applicable here.
class PortReadOnlyCell extends StatelessWidget {
  const PortReadOnlyCell({required this.value, this.tooltip, super.key});

  final String? value;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        value ?? kUnknownCell,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
    final message = tooltip;
    return message == null ? text : Tooltip(message: message, child: text);
  }
}

/// A cell a person types into.
///
/// COMMITS ON BLUR AND ON ENTER, never per keystroke. That is docs/06
/// §4.6's rule and it is also why the port commands do not coalesce: one
/// committed value is one edit. Tab moves right through the row because
/// the cells are in reading order.
///
/// ENTER ALSO MOVES DOWN, which M4-E deferred to M4-F and M4-F0 (`#695`)
/// now owns. It is Flutter's own directional traversal rather than a
/// registry of focus nodes keyed by row and column: the cells are laid out
/// in a grid, so "the nearest focusable below" already means "the same
/// column, next row", and a registry would have to be kept in step with a
/// virtualised list that builds and discards rows as it scrolls.
///
/// The one thing that costs: a row far enough off screen not to be built
/// has no node to move to, so Enter on the last VISIBLE row stops there.
/// Typing down a column keeps the next row inside the sliver's cache
/// extent, which is the case this is for.
class PortTextCell extends StatefulWidget {
  const PortTextCell({
    required this.value,
    required this.onCommit,
    this.hint,
    this.automatic = false,
    this.mixedLabel,
    super.key,
  });

  final String? value;
  final ValueChanged<String> onCommit;

  /// Shown greyed inside an EMPTY box only, which is the distinction M4-D
  /// had to be told twice: an example that stays under a filled field
  /// reads as a second value.
  final String? hint;

  /// Drawn italic and dimmed: a value this editor derived rather than one
  /// the author chose.
  final bool automatic;

  /// DR-063's reading when the selection disagrees, or null for the
  /// ordinary case.
  ///
  /// **THE BOX STARTS EMPTY AND THE LABEL IS THE HINT**, which is what
  /// makes "left untouched unless explicitly set" structural: `_commit`
  /// compares against what the controller was SEEDED with, so a focus and
  /// a blur with nothing typed is equal to the seed and returns early.
  /// The cost, stated in this file's header: from a mixed cell there is
  /// no way to express "clear it across all of them".
  final String? mixedLabel;

  @override
  State<PortTextCell> createState() => PortTextCellState();
}

class PortTextCellState extends State<PortTextCell> {
  late final TextEditingController _text = TextEditingController(
    text: _seed,
  );

  /// What the box was filled with, and therefore what "untouched" means.
  String get _seed => widget.mixedLabel == null ? (widget.value ?? '') : '';
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(PortTextCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // THE MODEL WINS, EXCEPT WHILE SOMEBODY IS TYPING IN THIS BOX. An
    // undo, or a key following a label typed one cell to the right,
    // changes the stored value under a cell that is not focused, and the
    // cell must follow. Overwriting a FOCUSED cell would delete what the
    // person is halfway through typing. M4-D shipped without this and
    // undo looked like a button that did nothing.
    if (widget.value != oldWidget.value && !_focus.hasFocus) {
      _text.text = _seed;
    }
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocusChange)
      ..dispose();
    _text.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focus.hasFocus) _commit();
  }

  void _commit() {
    if (_text.text == _seed) return;
    widget.onCommit(_text.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: _text,
      focusNode: _focus,
      style: theme.textTheme.bodySmall?.copyWith(
        fontStyle: widget.automatic ? FontStyle.italic : null,
        color: widget.automatic
            ? theme.colorScheme.onSurfaceVariant
            : theme.colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        // THE DASH, and not an empty box. An empty cell says nothing
        // about whether anybody has looked at this field; the dash is
        // what the equipment list and every schedule print for a fact
        // nobody has supplied.
        hintText: widget.mixedLabel ?? widget.hint ?? kUnknownCell,
        hintStyle: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      // ═══════════════════════════════════════════════════════════════
      // THE MOVE IS HERE AND NOT IN `onSubmitted`, WHICH IS TOO LATE
      // ═══════════════════════════════════════════════════════════════
      // `EditableText` calls `onEditingComplete` first and, when it is
      // null, its default for a `done` action is to UNFOCUS the field.
      // Only then does `onSubmitted` run. So a move written there has
      // nothing to move from: the commit lands, focus is already gone,
      // and directional traversal has no origin. Written that way first,
      // and the route test below is what found it, because the second
      // line of text went into the same cell as the first.
      //
      // COMMIT BEFORE MOVING, because the last row has nowhere to go and
      // must still write what was typed. The blur a successful move
      // causes calls `_commit` again and it returns early, so this costs
      // one command rather than two.
      onEditingComplete: () {
        _commit();
        FocusScope.of(context).focusInDirection(TraversalDirection.down);
      },
      onSubmitted: (_) => _commit(),
    );
  }
}

/// A cell whose column has a short closed set of answers.
///
/// A `DropdownButton` HERE AND A MENU FOR CONNECTOR AND SIGNAL, and the
/// difference is measured rather than stylistic: this widget's menu
/// inherits its BUTTON's width, which is fine for `Bidirectional` in a
/// 116-point column and is not fine for `AUD·Speaker, constant-voltage 70
/// / 100 / 25 V`. See `family_picker.dart`.
class PortChoiceCell<T> extends StatelessWidget {
  const PortChoiceCell({
    required this.value,
    required this.options,
    required this.label,
    required this.onPick,
    this.mixedLabel,
    super.key,
  });

  final T value;
  final List<T> options;
  final String Function(T value) label;
  final ValueChanged<T> onPick;

  /// DR-063's reading when the selection disagrees, or null for the
  /// ordinary case. Non-null makes this hold NO value: the button shows
  /// the label as a hint and `onPick` can only fire from a real pick, so
  /// building it, focusing it and tabbing away cannot write.
  final String? mixedLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: mixedLabel == null ? value : null,
        hint: mixedLabel == null
            ? null
            : Text(
                mixedLabel!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
        isDense: true,
        isExpanded: true,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
        items: [
          for (final option in options)
            // THE UNKNOWN ROW IS DROPPED WHILE MIXED, and that is not a
            // tidy-up. `null` is a real item in most of these menus (G4:
            // absent means unknown), so a mixed control passing
            // `value: null` would MATCH it and display `—` instead of the
            // hint, which is the exact confusion DR-063 exists to end. No
            // item matches now, so the hint shows.
            //
            // THE COST, and it is the text cell's cost again: from a mixed
            // menu there is no way to say "set them all to unknown". That
            // is available per row in the grid, and offering it here would
            // mean a control whose blank means two things.
            if (!(mixedLabel != null && option == null))
              DropdownMenuItem<T>(
                value: option,
                child: Text(
                  label(option),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
        ],
        onChanged: (v) {
          if (v is T) onPick(v);
        },
      ),
    );
  }
}

/// The CONNECTOR cell: a menu sized to its content, for the SIGNAL
/// column's measured reason.
///
/// THE CURRENT VALUE IS ALWAYS IN THE MENU, even when the registry does
/// not hold it. A `DropdownButton` asserts that exactly one item matches
/// its value, and M3-L found what that costs: a document naming something
/// no menu offers takes the WHOLE table down rather than misbehaving in
/// one cell. A `MenuAnchor` has no such assertion, and an unset port (a
/// brand-new row names no connector at all) still has a menu to pick from,
/// which read-only degradation would deny it.
class PortConnectorCell extends StatelessWidget {
  const PortConnectorCell({
    required this.registries,
    required this.value,
    required this.onPick,
    this.mixedLabel,
    super.key,
  });

  final Registries registries;
  final ConnectorTypeId value;
  final ValueChanged<ConnectorTypeId> onPick;

  /// DR-063's reading when the selection disagrees. A menu holds no
  /// value in that state and fires only from a pick.
  final String? mixedLabel;

  @override
  Widget build(BuildContext context) {
    final options = [...registries.connectorTypes.values]
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    return PortMenuCell(
      text: mixedLabel ?? portConnectorText(registries, value),
      hint: 'Connector',
      entries: [
        for (final def in options) (def.id.v, def.displayName),
      ],
      selected: mixedLabel == null ? value.v : null,
      onPick: (id) => onPick(ConnectorTypeId(id)),
    );
  }
}

/// The SIGNAL cell, on the Structure editor's own picker.
///
/// THE SAME WIDGET, NOT A SECOND ONE. `family_picker.dart` carries the
/// measurement that rejected a `DropdownButton` and the ruling that its
/// filter narrows without ever committing (DR-025 §11.24.3: an
/// unresolved value never invents a family). A copy here would be a
/// second place for one of those to be forgotten.
class PortFamilyCell extends StatelessWidget {
  const PortFamilyCell({
    required this.registries,
    required this.value,
    required this.onPick,
    this.mixedLabel,
    super.key,
  });

  final Registries registries;
  final SignalFamilyId value;
  final ValueChanged<SignalFamilyId> onPick;

  /// DR-063's reading when the selection disagrees. `FamilyPicker` takes
  /// a `String?` for exactly this shape already: null is "nothing chosen
  /// yet" and its filter never commits an unresolved value (DR-025).
  final String? mixedLabel;

  @override
  Widget build(BuildContext context) => FamilyPicker(
    groups: signalFamilyCellGroups(registries),
    value: mixedLabel ?? portFamilyText(registries, value),
    hint: 'Signal',
    onPick: (label) {
      final picked = resolveSignalFamilyCell(registries, label);
      if (picked != null) onPick(picked);
    },
  );
}

/// The ACCEPTS cell: the grid's ONLY multi-select (DR-081 §11.80.2, built
/// at DR-134 §11.133).
///
/// ══════════════════════════════════════════════════════════════════════
/// THE CELL SHAPE IS THE DELIVERABLE, WHICH IS DR-081's OWN SENTENCE
/// ══════════════════════════════════════════════════════════════════════
/// Every other cell in this grid holds one value: it commits, closes, and
/// moves on. This one holds a SET, so three things differ and each is a
/// decision rather than an accident.
///
///   * **The menu does not close on a pick.** Choosing a second family is
///     the ordinary case, and a menu that shut after the first would make
///     a two-entry list cost two round trips through a filter box.
///   * **The tick is a checkbox, not a check ICON.** [PortMenuCell] draws
///     a transparent `Icons.check` beside the one selected entry, which
///     reads as "this is the value". A box that can be empty or full
///     reads as "these are on", which is what a set is.
///   * **Empty prints a sentence, not the dash.** `—` is G4's unknown and
///     this is not one: an untouched list is the author saying the port
///     adds nothing to its own family. `kAcceptsOwnFamilyOnly` is core's
///     spelling of that and this widget does not invent a second.
///
/// **THE FILTER BOX IS `FamilyPicker`'s, FOR ITS MEASURED REASON.** 57
/// families is a wall to scroll and the labels reach 45 characters, which
/// is the measurement that put `family_picker.dart` on a `MenuAnchor`
/// instead of a `DropdownButton`. The same numbers apply here, so the
/// same width does.
///
/// **IT NARROWS AND NEVER COMMITS**, which is DR-025 §11.24.3 one control
/// over: typing into the filter can only hide rows, and a family enters
/// the set by being ticked. A filter that committed its top match would
/// let `hdmi` choose whichever HDMI generation sorted first.
class PortAcceptsCell extends StatefulWidget {
  const PortAcceptsCell({
    required this.registries,
    required this.value,
    required this.onChanged,
    this.mixedLabel,
    super.key,
  });

  final Registries registries;
  final List<SignalFamilyId> value;
  final ValueChanged<List<SignalFamilyId>> onChanged;

  /// M4-F11's one parameter, unchanged in shape: what to print when the
  /// selected rows disagree. Null means they agree and [value] is theirs.
  ///
  /// **A MIXED SELECTION SHOWS NO TICKS**, which the batch dock arranges
  /// by passing an empty [value] alongside this label. Pre-ticking one
  /// row's set would draw it as the answer for all of them.
  ///
  /// **AND A BATCH WRITE REPLACES RATHER THAN ADDS**, like every other
  /// column: `buildBatchWrite` puts the value it is given on every
  /// selected port. §4.6's "left untouched unless explicitly set" is
  /// about which COLUMNS a batch touches, not about merging within one.
  final String? mixedLabel;

  @override
  State<PortAcceptsCell> createState() => PortAcceptsCellState();
}

class PortAcceptsCellState extends State<PortAcceptsCell> {
  final MenuController _menu = MenuController();
  final TextEditingController _filter = TextEditingController();

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  void _toggle(SignalFamilyId id) {
    final next = [...widget.value];
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = normaliseMediaToken(_filter.text.trim());
    final groups = signalFamilyCellGroups(widget.registries);
    final visible = <SignalFamilyCellGroup, List<SignalFamilyCellOption>>{};
    for (final group in groups) {
      final options = [
        for (final option in group.options)
          if (query.isEmpty || option.matches(query)) option,
      ];
      if (options.isNotEmpty) visible[group] = options;
    }
    final text =
        widget.mixedLabel ??
        acceptedFamiliesCellText(widget.registries, widget.value);

    return MenuAnchor(
      controller: _menu,
      menuChildren: [
        SizedBox(
          width: kFamilyPickerWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: TextField(
                  controller: _filter,
                  autofocus: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    hintText: kFamilyFilterHint,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: kFamilyPickerMaxHeight,
                ),
                // `primary: false`, WHICH IS NOT A STYLE CHOICE. Without
                // it this scroll view adopts the `PrimaryScrollController`
                // that the port grid's own vertical list is already using,
                // and the framework throws the moment the menu opens over
                // a grid with a visible scrollbar: "attached to more than
                // one ScrollPosition". A menu is not the page's scroll
                // view and must never claim to be.
                child: SingleChildScrollView(
                  primary: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (visible.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            familyFilterEmpty(_filter.text.trim()),
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      for (final entry in visible.entries) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
                          child: Text(
                            entry.key.domainName,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        for (final option in entry.value)
                          // A `MenuItemButton` would close the menu on
                          // every pick, which is the one behaviour this
                          // control exists not to have.
                          CheckboxListTile(
                            key: ValueKey('accepts-${option.id.v}'),
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: widget.value.contains(option.id),
                            title: Text(
                              option.label,
                              style: theme.textTheme.bodySmall,
                            ),
                            onChanged: (_) => _toggle(option.id),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      builder: (context, controller, child) => InkWell(
        onTap: () {
          if (controller.isOpen) {
            controller.close();
          } else {
            _filter.clear();
            controller.open();
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    // THE EMPTY STATEMENT IS DRAWN LIKE AN AUTOMATIC
                    // VALUE, not like an unknown: it is true, the author
                    // did not type it, and `DESIG` already spells that
                    // state this way.
                    color: widget.value.isEmpty && widget.mixedLabel == null
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_drop_down,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A menu of `(value, label)` pairs, wider than the cell that opened it.
class PortMenuCell extends StatefulWidget {
  const PortMenuCell({
    required this.text,
    required this.hint,
    required this.entries,
    required this.selected,
    required this.onPick,
    super.key,
  });

  final String? text;
  final String hint;
  final List<(String, String)> entries;

  /// The entry to tick, or null when nothing is chosen. NULLABLE SINCE
  /// M4-F11: a mixed selection holds no value, and a sentinel string
  /// would be a value that ticks whichever entry happened to equal it.
  final String? selected;
  final ValueChanged<String> onPick;

  @override
  State<PortMenuCell> createState() => PortMenuCellState();
}

class PortMenuCellState extends State<PortMenuCell> {
  final MenuController _menu = MenuController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MenuAnchor(
      controller: _menu,
      menuChildren: [
        SizedBox(
          width: kFamilyPickerWidth,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: kFamilyPickerMaxHeight,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (id, label) in widget.entries)
                    MenuItemButton(
                      onPressed: () {
                        _menu.close();
                        widget.onPick(id);
                      },
                      leadingIcon: Icon(
                        Icons.check,
                        size: 16,
                        color: id == widget.selected
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                      ),
                      child: Text(label),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
      builder: (context, controller, child) => InkWell(
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.text ?? kUnknownCell,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: widget.text == null
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_drop_down,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
