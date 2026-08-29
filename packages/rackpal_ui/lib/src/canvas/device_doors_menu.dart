// packages/rackpal_ui/lib/src/canvas/device_doors_menu.dart
//
// CR-054's three doors, as the context menu docs/06 §8.2 specifies.
//
// ─────────────────────────────────────────────────────────────────────────
// THIS IS THE FIRST RIGHT-CLICK IN THE PRODUCT
// ─────────────────────────────────────────────────────────────────────────
// `onSecondaryTap` occurred ZERO times in `rackpal_ui` and `rackpal_app`
// before this file. So §8.2's "right-clicking a placed device offers exactly
// three edit paths" was not a menu waiting to be filled in; the gesture did
// not exist, and the secondary button was being routed into `beginDrag` like
// any other, which armed a marquee on empty canvas and a MOVE on a device.
// CR-102 already reserved it: "right-drag is reserved for the context menu,
// which is a platform expectation on desktop". `CanvasIntentDetector` now
// consumes it instead.
//
// ─────────────────────────────────────────────────────────────────────────
// THE COPY IS docs/06 §8.2's, NOT MINE
// ─────────────────────────────────────────────────────────────────────────
// The spec writes each badge out in full, naming the device and counting the
// others. Paraphrasing it here would put two versions of one sentence in the
// product and the corpus, and this repository has a practice about writing
// on-screen copy in corpus dialect rather than in the spec's own words.
//
// The ZERO case is mine, because §8.2's examples all have others: a template
// placed once has no blast radius to reassure anybody about, and "0 other
// devices use this template and will not change" invites the reader to
// wonder which ones do.
//
// ─────────────────────────────────────────────────────────────────────────
// WHAT EACH DOOR DOES FROM HERE
// ─────────────────────────────────────────────────────────────────────────
// Door 1 selects the device, which is all it needs to do: the override
// section renders for a single selection already (DR-098 §11.97.5). Door 2
// routes to the Device Manager and is refused when a draft is dirty
// (DR-099 §11.98.4). Door 3 mints a template id and runs
// `ForkTemplateFromDeviceCommand`.
//
// A FOURTH VERB IS DELETED AND MUST NOT REAPPEAR (CR-054): "Detach
// instance" produces a device with no lineage, and door 3 covers the case
// with better provenance.

import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';

/// Which door the user chose.
enum DeviceDoor {
  /// Writes typed `DeviceOverrides`; the template is untouched.
  thisDeviceOnly,

  /// Forks the template `version + 1`.
  editTemplate,

  /// Mints a new `templateId` seeded from the snapshot plus overrides.
  forkToNew,
}

/// docs/06 §8.2's scope sentence for [door], naming [designator] and
/// counting the [others] that share its template.
///
/// Returned as data rather than drawn here, because door 1's badge is drawn
/// by the inspector section and doors 2 and 3 by their own surfaces, and one
/// sentence with three renderers is how the three drift apart.
String deviceDoorScopeText({
  required DeviceDoor door,
  required String designator,
  required int others,
  required String templateName,
}) => switch (door) {
  DeviceDoor.thisDeviceOnly =>
    others == 0
        ? 'Editing $designator only. No other device uses this template.'
        : others == 1
        ? 'Editing $designator only. 1 other device uses this template '
              'and will not change.'
        : 'Editing $designator only. $others other devices use this '
              'template and will not change.',
  DeviceDoor.editTemplate =>
    "Editing template '$templateName'. Used by ${others + 1} "
        '${others == 0 ? 'device' : 'devices'}.',
  DeviceDoor.forkToNew => '$designator will use a new independent template.',
};

/// Shows the three doors at [globalPosition] and returns the chosen one.
///
/// EVERY DOOR IS ALWAYS OFFERED, including on a device whose snapshot does
/// not resolve. A menu that hides a row teaches nothing; door 3 refuses with
/// a sentence naming the designator and the missing template
/// (`buildForkTemplateFromDevice`), which is a refusal the user can act on.
Future<DeviceDoor?> showDeviceDoorsMenu({
  required BuildContext context,
  required Offset globalPosition,
  required String designator,
}) {
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  return showMenu<DeviceDoor>(
    context: context,
    position: RelativeRect.fromRect(
      globalPosition & Size.zero,
      Offset.zero & overlay.size,
    ),
    items: <PopupMenuEntry<DeviceDoor>>[
      PopupMenuItem<DeviceDoor>(
        enabled: false,
        height: 32,
        child: Text(
          designator,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem<DeviceDoor>(
        value: DeviceDoor.thisDeviceOnly,
        child: Text('Edit this device only'),
      ),
      const PopupMenuItem<DeviceDoor>(
        value: DeviceDoor.editTemplate,
        child: Text('Edit the template…'),
      ),
      const PopupMenuItem<DeviceDoor>(
        value: DeviceDoor.forkToNew,
        child: Text('Fork to a new template'),
      ),
    ],
  );
}

/// The template's display name for door 2's sentence, or a stand-in when the
/// snapshot does not resolve.
String templateNameFor(RackDocument doc, DeviceInstance device) {
  final ref = device.templateRef;
  final snapshot =
      doc.templates[templateSnapshotKey(
        ref.templateId,
        ref.version,
      )];
  final name = snapshot?.body.displayName;
  // NOT A DASH. This is a fallback inside a sentence, not a schedule cell,
  // and G4's unknown mark reads as punctuation mid-prose. The id is a fact
  // the document holds and is more use than an em dash.
  return (name == null || name.isEmpty) ? ref.templateId.v : name;
}
