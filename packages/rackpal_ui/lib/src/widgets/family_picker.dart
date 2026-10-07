// The signal-family picker, shared by the two surfaces that let a person
// choose one (DR-025 §11.24.5, board #587 and M4-E2 #204).
//
// ════════════════════════════════════════════════════════════════════════
// EXTRACTED, NOT COPIED, AND THAT IS THE WHOLE POINT
// ════════════════════════════════════════════════════════════════════════
// It was private to `structure_editor_screen.dart` until the port grid
// needed the same control for its SIGNAL column. A second copy would have
// been the cheaper edit and the wrong one: this widget carries a MEASURED
// finding (a `DropdownButton`'s menu inherits its button's width, so every
// family label arrived clamped to 84 points) and a RULING (the filter
// narrows and never commits, because DR-025 §11.24.3 forbids inventing a
// family). Two copies of a control that encodes two decisions is two
// places for one of them to be forgotten.
//
// The vocabulary underneath was already shared: `signalFamilyCellGroups`
// and `resolveSignalFamilyCell` live in `rackpal_core` so that the menu
// and the cell cannot drift about how a family is spelled.
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';

/// What the panel says when a filter matches nothing.
///
/// IT NAMES THE RULE RATHER THAN LISTING THE SET. Its enum-backed
/// neighbours can name all nine terminations in a sentence; there are 56
/// families, and a refusal that printed them would be a wall a person
/// scrolls past. The sentence a person needs is not "here are the
/// options", it is "you cannot invent one here", which is DR-025
/// §11.24.3 and RJ-012 in the one place a user meets them.
String familyFilterEmpty(String query) =>
    'No signal family matches "$query". Families come from the catalog '
    'and cannot be created here.';

/// SIZED TO THE LONGEST LABEL RATHER THAN TO THE CELL, which is the whole
/// reason this is not a `DropdownButton`. `AUD·Speaker, constant-voltage
/// 70 / 100 / 25 V` is 45 characters; at `bodySmall` that needs roughly
/// 300, and the rest is the check gutter and the padding.
const double kFamilyPickerWidth = 360;

/// What the filter box says when it is empty.
const String kFamilyFilterHint = 'Filter families';

/// The SERVICE column's control: a menu grouped by domain, with a filter
/// box (DR-025 §11.24.5, board #587).
///
/// **NOT A `DropdownButton`, AND THE REASON IS MEASURED RATHER THAN
/// STYLISTIC.** That widget's menu inherits its BUTTON's width. SERVICE
/// is 76 points, the seeded labels average 22 characters and reach 45,
/// and a throwaway harness put the resulting menu at 116 points wide with
/// every row's text clamped to 84: `AUD·Speaker level, low-Z` and
/// `AUD·Speaker, constant-voltage 70 / 100 / 25 V` both arrive as
/// `AUD·Speaker…`. A `MenuAnchor` sizes to its content, so the menu is
/// allowed to be wider than the cell that opened it.
///
/// **THE THREE ENUM-BACKED CHOICE COLUMNS KEEP THEIR `DropdownButton`**,
/// and that is not an inconsistency left lying about: `PULLED` and `RJ45`
/// fit in 84 points, so they have no problem this control solves, and a
/// filter box over five rough-in statuses would be a search for a list
/// you can already see.
///
/// **THE FILTER NEVER COMMITS, IT ONLY NARROWS.** #587 exists because
/// SERVICE was grouped with MEDIA as "needs a picker, not a text box",
/// and a box that accepted what was typed would put that straight back.
/// Typing changes which rows are visible and nothing else; a family is
/// chosen by clicking a row, and what that row hands back is
/// `signalFamilyCellLabel`'s own spelling.
///
/// **SHARED WITH THE BATCH BAR**, which is why [value] is nullable when a
/// cell's never is: a `Service` always has a family, and a batch bar
/// starts having been asked for nothing.
class FamilyPicker extends StatefulWidget {
  const FamilyPicker({
    required this.groups,
    required this.value,
    required this.hint,
    required this.onPick,
    super.key,
    this.onFocused,
  });

  final List<SignalFamilyCellGroup> groups;

  /// The label showing now, or null when nothing is chosen yet.
  final String? value;

  /// What the button reads when [value] is null.
  final String hint;

  final ValueChanged<String> onPick;

  /// Reported for the caret through a `Focus` rather than through the
  /// tap, so TABBING to the cell reports it too. `_ChoiceCell` does the
  /// same and for the same reason.
  final VoidCallback? onFocused;

  @override
  State<FamilyPicker> createState() => _FamilyPickerState();
}

class _FamilyPickerState extends State<FamilyPicker> {
  final MenuController _menu = MenuController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = widget.value;
    // A LISTENER, NOT A STOP (#949). Without `canRequestFocus: false` this
    // node was a Tab stop of its own, wrapped round the menu button that is
    // the real one, so every signal cell took two presses of Tab: in the
    // port grid, Quick Add, the change-type dialog and the Structure
    // editor alike. `onFocusChange` still fires when the button inside
    // takes focus, which is all this node was ever for; `port_grid.dart`
    // reports its cells' columns the same way, for the same reason.
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (has) {
        if (has) widget.onFocused?.call();
      },
      child: MenuAnchor(
        controller: _menu,
        // ONE PANEL RATHER THAN A LIST OF `MenuItemButton`s, because the
        // filter's text is state and the grouping is layout, and neither
        // survives being flattened into menu items.
        menuChildren: [
          FamilyPickerPanel(
            groups: widget.groups,
            selected: value,
            onPick: (label) {
              _menu.close();
              widget.onPick(label);
            },
          ),
        ],
        builder: (context, controller, child) => InkWell(
          onTap: () =>
              controller.isOpen ? controller.close() : controller.open(),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value ?? widget.hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: value == null
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

/// How tall the list may grow before it scrolls. Eight domain headers and
/// 56 rows do not fit any screen, so this is a scroll viewport and not a
/// budget: the filter box above it is what makes the scroll avoidable.
const double kFamilyPickerMaxHeight = 340;

/// The open menu: a filter box, then one block per domain.
class FamilyPickerPanel extends StatefulWidget {
  const FamilyPickerPanel({
    required this.groups,
    required this.selected,
    required this.onPick,
    super.key,
  });

  final List<SignalFamilyCellGroup> groups;

  /// Ticked in the list, so a person who opened the menu to check what a
  /// run is set to can close it again without reading the cell.
  final String? selected;

  final ValueChanged<String> onPick;

  @override
  State<FamilyPickerPanel> createState() => _FamilyPickerPanelState();
}

class _FamilyPickerPanelState extends State<FamilyPickerPanel> {
  final TextEditingController _filter = TextEditingController();

  /// ITS OWN CONTROLLER, NOT THE PRIMARY ONE. `MenuAnchor` wraps its
  /// children in a `Scrollbar` bound to `PrimaryScrollController`, and a
  /// second bare `SingleChildScrollView` in the same subtree attaches to
  /// it too. That throws "the Scrollbar requires a single ScrollPosition"
  /// mid-layout, and the panel then lays out at its full unconstrained
  /// height rather than at [kFamilyPickerMaxHeight], which puts the rows
  /// off screen where nothing can click them.
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _filter.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _filter.text;
    // MATCHING IS CORE'S, not a `contains` written here. A filter that
    // searched only the printed label would fail on `hbt`, which is the
    // token `@signal=` already accepts, and the product would then have
    // two vocabularies for one fact.
    final kept = [
      for (final group in widget.groups)
        if (group.options.where((o) => o.matches(query)).toList()
            case final options when options.isNotEmpty)
          (group: group, options: options),
    ];
    return SizedBox(
      width: kFamilyPickerWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: TextField(
              key: const ValueKey('service-filter'),
              controller: _filter,
              autofocus: true,
              style: theme.textTheme.bodySmall,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search, size: 16),
                hintText: kFamilyFilterHint,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (kept.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Text(
                familyFilterEmpty(query),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: kFamilyPickerMaxHeight,
              ),
              child: SingleChildScrollView(
                controller: _scroll,
                primary: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final entry in kept) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
                        child: Text(
                          '${entry.group.tagPrefix}  '
                          '${entry.group.domainName}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      // THE ROW PRINTS THE WHOLE LABEL, tag prefix and
                      // all, even though the header above it repeats the
                      // tag. What a row shows is what the cell will show
                      // and what the edit will carry, and a row reading
                      // `HDBaseT (5Play)` under a `VID` header would be a
                      // fourth spelling of the same fact.
                      for (final option in entry.options)
                        InkWell(
                          onTap: () => widget.onPick(option.label),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 18,
                                  child: option.label == widget.selected
                                      ? Icon(
                                          Icons.check,
                                          size: 14,
                                          color: theme.colorScheme.primary,
                                        )
                                      : null,
                                ),
                                Expanded(
                                  child: Text(
                                    option.label,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
