// The clone dialog (SFE-C1, SFE-C2; DR-122, DR-243, DR-244).
//
// ═══════════════════════════════════════════════════════════════════════
// THE PARENT FIRST, AND THEN ALWAYS IN VIEW
// ═══════════════════════════════════════════════════════════════════════
// Every field a clone inherits comes from its parent: domain, direction,
// topology, glyph and the starting connector. A person who has forgotten
// which parent they picked cannot reason about any of those, so the
// dialog asks for the parent before anything else and then keeps it in a
// banner above the form for as long as the dialog is open (SFE-C1).
//
// ═══════════════════════════════════════════════════════════════════════
// EVERY OPTION DRAWN AS IT PRINTS, THE TAKEN ONES TOO
// ═══════════════════════════════════════════════════════════════════════
// The user chose the full grid with taken options dimmed (2026-10-07):
// DR-243's menu, one row per dash class and one column per shipped
// weight, every swatch in the GREY a mono laser prints the domain's hue
// at (`greyscaleOf`), because AC-054 is about a greyscale print and a
// swatch that only reads in colour is the thing PAL-1 exists to prevent
// (SFE-C2). A taken option can still be selected, and selecting it shows
// the sentence naming the family it collides with: hiding it would leave
// a person wondering where their choice went.
//
// NOTHING HERE DECIDES ANYTHING. The menu, the verdicts, the sentence, the
// parents and the connectors are all read from `clone_signal_family.dart`,
// beside the builder that applies the same ones, and a core test holds
// every option's drawn verdict to the command's. The dialog returns the
// command and the caller puts it on the undo stack.
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/widgets/family_picker.dart';

/// Keys a test can find the dialog's controls by.
const Key kCloneNameFieldKey = Key('clone-family-name');
const Key kCloneTagFieldKey = Key('clone-family-tag');
const Key kCloneConnectorKey = Key('clone-family-connector');
const Key kCloneSubmitKey = Key('clone-family-submit');
const Key kCloneReasonKey = Key('clone-family-reason');
const Key kCloneFreeKey = Key('clone-family-free');
const Key kCloneExhaustedKey = Key('clone-family-exhausted');
const Key kCloneParentBannerKey = Key('clone-family-parent');

/// The key of one swatch in the grid.
Key cloneSwatchKey(List<int> dash, int weight) =>
    ValueKey('clone-swatch-${dash.join(',')}@$weight');

/// Points to logical pixels in the swatch, so a 0.7 pt line is visible on
/// screen. The RATIOS are what matter and they are kept exactly.
const double _kSwatchScale = 2.5;

/// Opens the dialog over [doc]; the command to apply, or null if cancelled.
Future<CloneSignalFamilyCommand?> showCloneFamilyDialog(
  BuildContext context, {
  required RackDocument doc,
}) => showDialog<CloneSignalFamilyCommand>(
  context: context,
  builder: (context) => CloneFamilyDialog(doc: doc),
);

/// Public so a widget test can pump it without a navigator round trip.
class CloneFamilyDialog extends StatefulWidget {
  const CloneFamilyDialog({required this.doc, super.key});

  final RackDocument doc;

  @override
  State<CloneFamilyDialog> createState() => _CloneFamilyDialogState();
}

class _CloneFamilyDialogState extends State<CloneFamilyDialog> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _tag = TextEditingController();
  SignalFamilyDef? _parent;
  ConnectorTypeId? _connector;
  Pal1Option? _picked;
  String? _refusal;

  @override
  void dispose() {
    _name.dispose();
    _tag.dispose();
    super.dispose();
  }

  void _pickParent(String label) {
    final registries = cloneableFamilies(widget.doc);
    for (final group in signalFamilyCellGroups(registries)) {
      for (final option in group.options) {
        if (option.label == label) {
          setState(() {
            _parent = registries.signalFamilies[option.id];
            _connector = _parent?.defaultConnector;
            _picked = null;
            _refusal = null;
          });
          return;
        }
      }
    }
  }

  bool get _ready =>
      _parent != null &&
      _name.text.trim().isNotEmpty &&
      _tag.text.trim().isNotEmpty &&
      (_picked?.isFree ?? false);

  void _submit() {
    final parent = _parent;
    final picked = _picked;
    if (parent == null || picked == null) return;
    switch (buildCloneSignalFamily(
      widget.doc,
      parent: parent.id,
      displayName: _name.text,
      shortTag: _tag.text,
      dashPermille: picked.dashPermille,
      weightPermille: picked.weightPermille,
      connector: _connector,
    )) {
      case CloneSignalFamilyReady(:final command):
        Navigator.of(context).pop(command);
      case CloneSignalFamilyRefused(:final reason):
        setState(() => _refusal = reason);
    }
  }

  @override
  Widget build(BuildContext context) {
    final parent = _parent;
    return AlertDialog(
      title: Text(
        parent == null
            ? 'Clone a family: pick one to start from'
            : 'Clone a family',
      ),
      content: SizedBox(
        width: 640,
        height: 560,
        child: parent == null
            ? FamilyPickerPanel(
                groups: signalFamilyCellGroups(cloneableFamilies(widget.doc)),
                selected: null,
                onPick: _pickParent,
              )
            : _form(context, parent),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (parent != null)
          FilledButton(
            key: kCloneSubmitKey,
            onPressed: _ready ? _submit : null,
            child: const Text('Clone'),
          ),
      ],
    );
  }

  Widget _form(BuildContext context, SignalFamilyDef parent) {
    final theme = Theme.of(context);
    final domain = cloneDomain(widget.doc, parent.domain);
    final room = cloneHeadroom(widget.doc, parent.domain);
    final picked = _picked;
    final reason =
        _refusal ??
        (picked == null || picked.isFree
            ? null
            : cloneCollisionSentence(widget.doc, picked.blockers));
    final form = ListView(
      children: [
        _ParentBanner(
          key: kCloneParentBannerKey,
          parent: parent,
          domainName: domain?.displayName ?? parent.domain.v,
          onChange: () => setState(() {
            _parent = null;
            _picked = null;
            _refusal = null;
          }),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                key: kCloneNameFieldKey,
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Vantage',
                ),
                onChanged: (_) => setState(() => _refusal = null),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                key: kCloneTagFieldKey,
                controller: _tag,
                decoration: const InputDecoration(
                  labelText: 'Short tag',
                  hintText: 'VNT',
                ),
                onChanged: (_) => setState(() => _refusal = null),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownMenu<ConnectorTypeId>(
          key: kCloneConnectorKey,
          label: const Text('Default connector'),
          width: 400,
          enableFilter: true,
          initialSelection: _connector,
          dropdownMenuEntries: [
            for (final c in cloneConnectorTypes(widget.doc))
              DropdownMenuEntry(value: c.id, label: c.displayName),
          ],
          onSelected: (v) => setState(() {
            _connector = v;
            _refusal = null;
          }),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            "Starts as ${parent.displayName}'s. It is what a new port of "
            'this family is given, and every port can still change its own.',
            style: theme.textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 16),
        Text('Line', style: theme.textTheme.titleSmall),
        Text(
          'Shown in the grey it prints. Dimmed lines are taken; pick one '
          'to see what by.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        if (room == null || domain == null)
          Text('This project has no ${parent.domain.v} domain to draw in.')
        else if (room.isExhausted)
          Text(
            'Every line on the menu is taken in ${domain.displayName}. '
            'Nothing more can be told apart in this domain.',
            key: kCloneExhaustedKey,
            style: TextStyle(color: theme.colorScheme.error),
          )
        else
          _LineGrid(
            room: room,
            menu: cloneMenu(),
            ink: Color(greyscaleOf(domain.color.argb)),
            picked: picked,
            onPick: (o) => setState(() {
              _picked = o;
              _refusal = null;
            }),
          ),
      ],
    );
    // THE VERDICT IS PINNED BELOW THE LIST, NOT AT ITS FOOT. It sat under
    // the grid inside the scrolling list until the widget test found it
    // was not even BUILT after tapping a swatch: the grid is thirteen rows
    // tall, so a person tapping a line near the top read nothing about
    // why it was taken. Out here it is in view whatever row was tapped.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: form),
        const Divider(height: 16),
        SizedBox(
          height: 40,
          child: reason != null
              ? Text(
                  reason,
                  key: kCloneReasonKey,
                  style: TextStyle(color: theme.colorScheme.error),
                )
              : picked != null
              ? Text(
                  'Free: ${picked.dashClass} at '
                  '${_weightLabel(picked.weightPermille)}.',
                  key: kCloneFreeKey,
                  style: theme.textTheme.bodySmall,
                )
              : Text(
                  'Pick a line.',
                  style: theme.textTheme.bodySmall,
                ),
        ),
      ],
    );
  }
}

String _weightLabel(int permille) => '${(permille / 1000).toStringAsFixed(2)}×';

/// The parent, held in view for the life of the form (SFE-C1).
class _ParentBanner extends StatelessWidget {
  const _ParentBanner({
    required this.parent,
    required this.domainName,
    required this.onChange,
    super.key,
  });

  final SignalFamilyDef parent;
  final String domainName;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Clone of ${parent.displayName} (${parent.id.v})',
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    // WHAT IS LOCKED, SAID WHERE IT IS DECIDED. DR-244
                    // keeps these three because they are copied into every
                    // port made with the family.
                    'Kept from it: $domainName, '
                    '${parent.defaultDirection.name}, '
                    '${parent.defaultTopology.name}.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onChange, child: const Text('Change')),
          ],
        ),
      ),
    );
  }
}

/// DR-243's menu as a grid, every option drawn as it prints (SFE-C2).
class _LineGrid extends StatelessWidget {
  const _LineGrid({
    required this.room,
    required this.menu,
    required this.ink,
    required this.picked,
    required this.onPick,
  });

  final Pal1Headroom room;
  final Pal1Vocabulary menu;
  final Color ink;
  final Pal1Option? picked;
  final ValueChanged<Pal1Option> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Pal1Option at(List<int> dash, int weight) => room.options.firstWhere(
      (o) =>
          o.weightPermille == weight &&
          o.dashPermille.join(',') == dash.join(','),
    );
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const {0: FixedColumnWidth(120)},
      children: [
        TableRow(
          children: [
            const SizedBox(),
            for (final w in menu.weights)
              Center(
                child: Text(_weightLabel(w), style: theme.textTheme.labelSmall),
              ),
          ],
        ),
        for (final dash in menu.dashes)
          TableRow(
            children: [
              Text(
                '${Pal1DashClass.of(dash)}',
                style: theme.textTheme.bodySmall,
              ),
              for (final w in menu.weights)
                _Swatch(
                  option: at(dash, w),
                  ink: ink,
                  // BY VALUE, NOT `identical`: the headroom is recomputed
                  // on every build, so the option a person picked is never
                  // the same OBJECT as the one drawn next frame, and the
                  // highlight never showed until a test asked for it.
                  selected:
                      picked != null &&
                      picked!.weightPermille == w &&
                      picked!.dashPermille.join(',') == dash.join(','),
                  onTap: () => onPick(at(dash, w)),
                ),
            ],
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  _Swatch({
    required this.option,
    required this.ink,
    required this.selected,
    required this.onTap,
  }) : super(key: cloneSwatchKey(option.dashPermille, option.weightPermille));

  final Pal1Option option;
  final Color ink;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label:
          '${option.dashClass} at ${_weightLabel(option.weightPermille)}, '
          '${option.isFree ? 'free' : 'taken'}',
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 30,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Opacity(
            opacity: option.isFree ? 1 : 0.25,
            child: CustomPaint(
              painter: _LinePainter(
                dash: option.dashPermille,
                weightPermille: option.weightPermille,
                ink: ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One line at its dash and weight, scaled for the screen.
class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.dash,
    required this.weightPermille,
    required this.ink,
  });

  final List<int> dash;
  final int weightPermille;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ink
      ..strokeWidth =
          kSignalBaseWeightPt * weightPermille / 1000 * _kSwatchScale;
    final y = size.height / 2;
    const left = 6.0;
    final right = size.width - 6;
    if (dash.isEmpty) {
      canvas.drawLine(Offset(left, y), Offset(right, y), paint);
      return;
    }
    var x = left;
    var i = 0;
    while (x < right) {
      final len = dash[i % dash.length] / 1000 * _kSwatchScale;
      final end = (x + len).clamp(left, right);
      if (i.isEven) canvas.drawLine(Offset(x, y), Offset(end, y), paint);
      x += len;
      i++;
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.dash.join(',') != dash.join(',') ||
      old.weightPermille != weightPermille ||
      old.ink != ink;
}

// ═══════════════════════════════════════════════════════════════════════
// CHANGE LINE (SFE-C7, DR-245 §11.244.4)
// ═══════════════════════════════════════════════════════════════════════
// The fix a PAL-1 clash points to: the same grid, judged as the family
// itself so the line it is giving up never blocks it, and the current
// line marked when it opens. The command restyles every cable of the
// family, which is what fixes how they print.

/// The submit button of the change-line dialog, so a test can find it.
const Key kChangeLineSubmitKey = Key('change-line-submit');

/// Opens the change-line dialog for the clone [family]; the command to
/// apply, or null if cancelled.
Future<SetCloneLineCommand?> showChangeLineDialog(
  BuildContext context, {
  required RackDocument doc,
  required SignalFamilyDef family,
}) => showDialog<SetCloneLineCommand>(
  context: context,
  builder: (context) => ChangeLineDialog(doc: doc, family: family),
);

/// Public so a widget test can pump it without a navigator round trip.
class ChangeLineDialog extends StatefulWidget {
  const ChangeLineDialog({required this.doc, required this.family, super.key});

  final RackDocument doc;
  final SignalFamilyDef family;

  @override
  State<ChangeLineDialog> createState() => _ChangeLineDialogState();
}

class _ChangeLineDialogState extends State<ChangeLineDialog> {
  Pal1Option? _picked;
  String? _refusal;

  bool _isCurrent(Pal1Option o) =>
      o.dashPermille.join(',') ==
          (widget.family.dashOverride ?? const []).join(',') &&
      o.weightPermille == widget.family.lineWeightPermilleOverride;

  @override
  void initState() {
    super.initState();
    final room = cloneHeadroom(
      widget.doc,
      widget.family.domain,
      changing: widget.family.id,
    );
    _picked = room?.options.where(_isCurrent).firstOrNull;
  }

  void _submit() {
    final picked = _picked;
    if (picked == null) return;
    switch (buildChangeCloneLine(
      widget.doc,
      family: widget.family.id,
      dashPermille: picked.dashPermille,
      weightPermille: picked.weightPermille,
    )) {
      case ChangeCloneLineReady(:final command):
        Navigator.of(context).pop(command);
      case ChangeCloneLineRefused(:final reason):
        setState(() => _refusal = reason);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final family = widget.family;
    final domain = cloneDomain(widget.doc, family.domain);
    final room = cloneHeadroom(
      widget.doc,
      family.domain,
      changing: family.id,
    );
    final picked = _picked;
    final current = picked != null && _isCurrent(picked);
    final reason =
        _refusal ??
        (picked == null || picked.isFree
            ? null
            : cloneCollisionSentence(widget.doc, picked.blockers));
    return AlertDialog(
      title: Text('Change line: ${family.displayName}'),
      content: SizedBox(
        width: 640,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Every ${family.displayName} cable is redrawn on the line you '
              'pick. Dimmed lines are taken; pick one to see what by.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: room == null || domain == null
                  ? Text('This project has no ${family.domain.v} domain.')
                  : SingleChildScrollView(
                      child: _LineGrid(
                        room: room,
                        menu: cloneMenu(),
                        ink: Color(greyscaleOf(domain.color.argb)),
                        picked: picked,
                        onPick: (o) => setState(() {
                          _picked = o;
                          _refusal = null;
                        }),
                      ),
                    ),
            ),
            const Divider(height: 16),
            SizedBox(
              height: 40,
              child: reason != null
                  ? Text(
                      reason,
                      key: kCloneReasonKey,
                      style: TextStyle(color: theme.colorScheme.error),
                    )
                  : Text(
                      current
                          ? 'This is its line now.'
                          : picked == null
                          ? 'Pick a line.'
                          : 'Free: ${picked.dashClass} at '
                                '${_weightLabel(picked.weightPermille)}.',
                      key: kCloneFreeKey,
                      style: theme.textTheme.bodySmall,
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: kChangeLineSubmitKey,
          onPressed: picked != null && picked.isFree && !current
              ? _submit
              : null,
          child: const Text('Change'),
        ),
      ],
    );
  }
}
