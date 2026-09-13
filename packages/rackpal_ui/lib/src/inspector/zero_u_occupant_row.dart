// One device mounted in a 0U channel, under that channel in the rack
// inspector (`#876`, DR-163 §11.162.1).
//
// ═══════════════════════════════════════════════════════════════════════
// IT WAS GOING TO BE ON THE SELECTED DEVICE, AND THAT COULD NOT BE REACHED
// ═══════════════════════════════════════════════════════════════════════
// AC-044 says a 0U occupant is "created and edited from the inspector
// (channel, start U, span)", and the device inspector is where every other
// device property is edited, so that is where this was built first.
//
// **A 0U OCCUPANT CANNOT BE SELECTED.** `scene_builder.dart` reads
// `if (placement is! RailPlacement) continue;`, so a 0U PDU is never in
// the elevation's scene, is never hit-tested, and nothing can select it.
// AC-044's other half, "renders as a plain bar", was never built either.
// A section on the device inspector would therefore have been a surface
// nothing could open: exactly the defect `#872` exists to catch, in the
// ticket closing `#872`'s own last row.
//
// So the fields moved here, under the channel, where the rack inspector
// reaches them with `Ctrl+Alt+U` and nothing selected. Settled by the user
// on 2026-09-13 once the scene builder's line was measured.
//
// ═══════════════════════════════════════════════════════════════════════
// IT ASKS FOR A START U AND THE MODEL STORES A `Len`
// ═══════════════════════════════════════════════════════════════════════
// `zeroUStartUOf` / `zeroUOffsetFor` in core do the conversion, because it
// has to know the span is INCLUSIVE and 1-based (CR-025) and a widget
// doing that arithmetic would be a second place that knows it.
//
// ═══════════════════════════════════════════════════════════════════════
// THE HOST PLANS, BECAUSE THE EDIT IS SIGNED
// ═══════════════════════════════════════════════════════════════════════
// `planSetZeroUPosition` takes a `now` and an `actor`, and `#879` is the
// reason this hands over three plain values: a surface that invented
// either would write a signature that is not the person's, and the
// mutation that blanked the shell's actor in that ticket survived because
// nothing asserted where it came from.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/inspector/add_zero_u_channel_dialog.dart'
    show zeroUSideLabel;

/// Stable handles for tests, per device.
String zeroUStartKeyFor(Uuid deviceId) => 'zero-u-start-${deviceId.v}';
String zeroUChannelKeyFor(Uuid deviceId) => 'zero-u-channel-${deviceId.v}';

/// A stable handle for the occupant's span field (`#883`, DR-166).
String zeroUSpanKeyFor(Uuid deviceId) => 'zero-u-span-${deviceId.v}';

/// `PDU-1` with its start U, and a channel picker when there is a choice.
class ZeroUOccupantRow extends StatefulWidget {
  const ZeroUOccupantRow({
    required this.device,
    required this.channel,
    required this.channels,
    required this.onMove,
    required this.onResize,
    super.key,
  });

  final DeviceInstance device;

  /// The channel this device is currently in.
  final ZeroUChannel channel;

  /// Every channel on the rack, for the picker. One channel means no
  /// picker: a control that cannot change anything is one to read past.
  final List<ZeroUChannel> channels;

  /// Asks the host to move the device to a channel at a start U.
  final void Function(Uuid deviceId, String channelId, int startU) onMove;

  /// Sets how many U this occupant runs, or clears it to UNKNOWN
  /// (`#883`, DR-166 §11.165.1). This is AC-044's third inspector field,
  /// and `#876` could not build it because the model had nowhere to put
  /// a span.
  ///
  /// **NULL IS AN EDIT**, not a no-op: somebody who does not know how
  /// long a PDU is must be able to say so, and the elevation then draws
  /// the hollow stub rather than a bar it cannot support.
  final void Function(Uuid deviceId, int? spanU) onResize;

  @override
  State<ZeroUOccupantRow> createState() => _ZeroUOccupantRowState();
}

class _ZeroUOccupantRowState extends State<ZeroUOccupantRow> {
  final TextEditingController _start = TextEditingController();
  final FocusNode _focus = FocusNode();
  final TextEditingController _span = TextEditingController();
  final FocusNode _spanFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
    _spanFocus.addListener(_onSpanFocusChange);
    _syncFromModel();
  }

  @override
  void didUpdateWidget(ZeroUOccupantRow old) {
    super.didUpdateWidget(old);
    // RE-SYNC WHILE UNFOCUSED, which is `_InspectorTextField`'s rule and
    // its reason: an undo changes the document without touching this
    // buffer, so without it the field keeps showing the value the person
    // just took back.
    if (!_focus.hasFocus && !_spanFocus.hasFocus) _syncFromModel();
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocusChange)
      ..dispose();
    _start.dispose();
    _spanFocus
      ..removeListener(_onSpanFocusChange)
      ..dispose();
    _span.dispose();
    super.dispose();
  }

  ZeroUPlacement? get _placement {
    final p = widget.device.placement;
    return p is ZeroUPlacement ? p : null;
  }

  void _syncFromModel() {
    final p = _placement;
    _start.text = p == null
        ? ''
        : '${zeroUStartUOf(widget.channel, p.offsetFromChannelStart)}';
    // AN EMPTY FIELD IS THE UNKNOWN (G4, CR-114). It is not a zero and it
    // is not a placeholder: the file does not record a length, the
    // elevation draws a hollow stub, and this box is where that is fixed.
    final span = p?.spanAlongChannel;
    _span.text = span == null ? '' : '${span.nm ~/ kRackUnit.nm}';
  }

  void _onSpanFocusChange() {
    if (_spanFocus.hasFocus) return;
    _commitSpan();
  }

  void _commitSpan() {
    final p = _placement;
    if (p == null) return;
    final text = _span.text.trim();
    final typed = text.isEmpty ? null : int.tryParse(text);
    if (text.isNotEmpty && typed == null) {
      _syncFromModel();
      return;
    }
    // ALREADY THERE IS NOT AN EDIT, on the start field's reasoning: a
    // commit-on-blur field fires every time focus leaves it, and an undo
    // entry that changes nothing is `#863`'s shape arriving through a
    // text box.
    final current = p.spanAlongChannel;
    final currentU = current == null ? null : current.nm ~/ kRackUnit.nm;
    if (currentU == typed) return;
    widget.onResize(widget.device.id, typed);
  }

  void _onFocusChange() {
    if (_focus.hasFocus) return;
    _commit();
  }

  void _commit() {
    final p = _placement;
    final typed = int.tryParse(_start.text.trim());
    if (p == null || typed == null) {
      _syncFromModel();
      return;
    }
    // ALREADY THERE IS NOT AN EDIT. A commit-on-blur field fires every
    // time focus leaves it, so without this every click away from an
    // untouched field would push an undo entry that changed nothing,
    // which is `#863`'s shape arriving through a text box.
    if (zeroUStartUOf(widget.channel, p.offsetFromChannelStart) == typed) {
      return;
    }
    widget.onMove(widget.device.id, p.channelId, typed);
  }

  @override
  Widget build(BuildContext context) {
    final placement = _placement;
    if (placement == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.device.designator, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Row(
            children: [
              SizedBox(
                width: 92,
                child: TextField(
                  key: ValueKey(zeroUStartKeyFor(widget.device.id)),
                  controller: _start,
                  focusNode: _focus,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Start U',
                    isDense: true,
                  ),
                  // ENTER UNFOCUSES AND THE LISTENER COMMITS, rather than
                  // committing here as well. Both fired in the first
                  // draft, so Enter asked the host to move the device
                  // TWICE: invisible in the product, because the first
                  // move updates the document and the guard above
                  // swallows the second, and back the moment an edit is
                  // REFUSED. One path in, one commit.
                  onSubmitted: (_) => _focus.unfocus(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 92,
                child: TextField(
                  key: ValueKey(zeroUSpanKeyFor(widget.device.id)),
                  controller: _span,
                  focusNode: _spanFocus,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Span U',
                    // WHAT AN EMPTY BOX MEANS, said rather than left to be
                    // inferred. G4's rule is that an unknown is reported,
                    // and a blank field with no hint reads as a value
                    // nobody has typed yet rather than as a fact about
                    // the document.
                    hintText: 'unknown',
                    isDense: true,
                  ),
                  onSubmitted: (_) => _spanFocus.unfocus(),
                ),
              ),
            ],
          ),
          // ═════════════════════════════════════════════════════════════
          // THE CHANNEL PICKER GETS ITS OWN LINE SINCE `#883`
          // ═════════════════════════════════════════════════════════════
          // It sat beside the fields, and AC-044's third one (Span U)
          // made three controls where the inspector is 320 px wide: the
          // dropdown overflowed by 65 px, which a case caught rather than
          // a person. Two numbers read as a pair anyway, and the channel
          // is a different question from where along it the device sits.
          if (widget.channels.length > 1) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(zeroUChannelKeyFor(widget.device.id)),
                    initialValue: placement.channelId,
                    decoration: const InputDecoration(
                      labelText: 'Channel',
                      isDense: true,
                    ),
                    items: [
                      for (final c in widget.channels)
                        DropdownMenuItem(
                          value: c.id,
                          child: Text(
                            c.name.isEmpty ? zeroUSideLabel(c.side) : c.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (id) {
                      if (id == null || id == placement.channelId) return;
                      // THE U IS KEPT, NOT THE OFFSET. Two channels can
                      // start at different Us, and carrying the raw `Len`
                      // across would move the device while the person was
                      // choosing which rail it hangs on.
                      widget.onMove(
                        widget.device.id,
                        id,
                        zeroUStartUOf(
                          widget.channel,
                          placement.offsetFromChannelStart,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
