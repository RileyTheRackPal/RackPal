// rackpal_core/src/derived/template_usage.dart — pure Dart.
//
// How many placed devices stand behind one template, and how many of them
// are not the one you are editing.
//
// ─────────────────────────────────────────────────────────────────────────
// WHY THIS IS DERIVED AND NOT A WIDGET'S ARITHMETIC
// ─────────────────────────────────────────────────────────────────────────
// The number exists for CR-054's three scope badges (DR-098 §11.97.5).
// Door 1 is amber and says how many other devices share this template and
// will NOT change; door 2 is blue and says how many WILL when the template
// forks; door 3 is green and rebinds this instance alone. Those are three
// readings of one count, and if each door computes its own they agree only
// until somebody changes what "shares" means.
//
// It matters more than a badge usually would, because the badge is the
// only thing standing between a user and the wrong door. "Edit this device
// only" and "edit the template" are one menu row apart and their blast
// radii differ by the whole project.
//
// ─────────────────────────────────────────────────────────────────────────
// COUNTED BY templateId, NOT BY templateId@version
// ─────────────────────────────────────────────────────────────────────────
// A device is pinned to the snapshot version it was placed at (CR-050), so
// two instances of the same template can sit at different versions. For
// door 1 that distinction does not exist: the edit touches this instance
// and nothing else, so every other instance of the template is untouched
// whatever version it holds, and a count that split by version would
// understate what the badge is reassuring the user about.
//
// Door 2 will need the version-sensitive count, because a fork moves only
// the instances that opt in (AC-041). That is `#231`'s to add, beside this
// one and reading the same field.

import 'package:rackpal_core/src/model/device_instance.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// The newest version of [templateId] that any device in [doc] is placed
/// from, and how many devices stand on exactly that version, or null when
/// none are (DR-202 §11.201.2).
///
/// **THE VERSION-SENSITIVE COUNT THE HEADER SAID DOOR 2 WOULD NEED**, and
/// it is the builder's change class that needed it first. That verdict is
/// about devices already placed, so it compares the draft against the body
/// those devices resolve to, and a template nothing stands on has no
/// verdict to give. The NEWEST placed version is the baseline because it
/// is the one a later migration would start from; instances on older
/// versions are already a fork behind whatever this save does.
({int version, int count})? newestPlacedTemplateVersion(
  RackDocument doc,
  TemplateId templateId,
) {
  var version = 0;
  var count = 0;
  for (final d in doc.devices.values) {
    final ref = d.templateRef;
    if (ref.templateId != templateId) continue;
    if (ref.version > version) {
      version = ref.version;
      count = 1;
    } else if (ref.version == version) {
      count++;
    }
  }
  return count == 0 ? null : (version: version, count: count);
}

/// Every device in [doc] standing on template [templateId], including any
/// device you may be about to edit.
///
/// Tombstoned devices are not a concept here: `RemoveDeviceCommand` takes
/// the device out of `doc.devices`, so anything still in the map is placed.
int countDevicesOnTemplate(RackDocument doc, TemplateId templateId) {
  var n = 0;
  for (final d in doc.devices.values) {
    if (d.templateRef.templateId == templateId) n++;
  }
  return n;
}

/// The number door 1's amber badge prints: how many devices share
/// [device]'s template and will **not** change when this instance is
/// edited.
///
/// Zero is a real and common answer, and the caller must say something
/// different for it rather than printing "0 others": a template placed
/// once has no blast radius to reassure anybody about, and a badge reading
/// "0 other devices are unaffected" invites the reader to wonder which
/// ones were.
int countOtherDevicesOnTemplate(RackDocument doc, DeviceInstance device) {
  final total = countDevicesOnTemplate(doc, device.templateRef.templateId);
  // Guard rather than `total - 1`: this is called with a device that is
  // expected to be in the document, and if a caller ever passes one that
  // is not, `-1` is a worse answer than 0 and prints just as happily.
  return total > 0 ? total - 1 : 0;
}
