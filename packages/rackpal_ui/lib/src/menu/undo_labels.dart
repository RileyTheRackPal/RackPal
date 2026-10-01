// What the Edit menu says (`#874`, DR-159 §11.158.6, docs/03 §13.3).
//
// ═══════════════════════════════════════════════════════════════════════
// THE SPEC IS FROM M0 AND THE SURFACE ARRIVED AT DR-159
// ═══════════════════════════════════════════════════════════════════════
// docs/03-architecture.md §13.3: *"commands expose a `LabelKey` enum plus
// arguments and `rackpal_ui` maps key to localized string. The Edit menu
// shows a localized 'Undo Move device'; the log shows the stable enum
// name."* `Command.label`'s own doc says the same thing from core's side.
//
// **`LabelKey` HAS 101 VALUES AND MANY OF THEM EXIST ONLY BECAUSE OF THIS
// MENU.** `commitPortSort` is its own value rather than `reorderPorts`
// because *"'Undo Reorder' in front of somebody who has just been through
// a confirm dialog names the wrong act"*. `clearRoomEstimate` is separate
// from `setRoomEstimate` because the opposite act must not be named.
// `drawRoomOutline` and `reshapeRoomOutline` are ONE command with two
// labels chosen at apply time, because *"'Undo Reshape Room' in front of
// somebody who has just drawn their first outline names an act they did
// not perform"*. Every one of those arguments was written against a menu
// that did not exist.
//
// ═══════════════════════════════════════════════════════════════════════
// EXPLICIT AND GATED, NOT DERIVED (§11.158.7)
// ═══════════════════════════════════════════════════════════════════════
// De-camel-casing the enum name is one line and would read
// *"Remove Template From Project"*. It is worse than useless for exactly
// the values above, whose whole point is that the obvious wording names
// the wrong act.
//
// So this map is written out, and `undo_labels_test.dart` fails when a
// `LabelKey` value has no entry. **NOT A FALLBACK**: a default is a hole
// a future `LabelKey` falls into silently, which is the argument DR-156
// §11.155.1 already made about a defaulted `applied` getter.
//
// ═══════════════════════════════════════════════════════════════════════
// IT IS NOT LOCALIZED, AND SAYING SO IS THE POINT
// ═══════════════════════════════════════════════════════════════════════
// §13.3 also asks for `AppLocalizations` from the first commit with one
// locale and `l10n.yaml` in CI. **Neither exists in this tree.** These are
// English strings in a `const Map`, and the localisation half of that
// paragraph stays owed. A menu built against half a specification has to
// record which half, or the next reader takes the built half as the whole.
//
// ═══════════════════════════════════════════════════════════════════════
// SENTENCE CASE, AND A NOUN PHRASE RATHER THAN AN IMPERATIVE
// ═══════════════════════════════════════════════════════════════════════
// The menu renders `Undo ${label}`, so each entry has to read after that
// word. "Undo Move device" is §13.3's own example and fixes the shape:
// the verb is capitalised because it starts the phrase, the object is not
// because it is not a proper noun, and nothing ends in a full stop.
import 'package:meta/meta.dart';
import 'package:rackpal_core/rackpal_core.dart';

/// What the Edit menu prints after `Undo` or `Redo`, per command kind.
///
/// Every [LabelKey] value has an entry and a test proves it. See the file
/// header for why there is no fallback.
const Map<LabelKey, String> kUndoLabels = <LabelKey, String>{
  // ── devices and racks ───────────────────────────────────────────────
  LabelKey.addDevice: 'Add device',
  LabelKey.removeDevice: 'Delete device',
  LabelKey.moveDevice: 'Move device',
  LabelKey.stageDevice: 'Send to Staging Bin',
  LabelKey.returnFromStaging: 'Return from Staging Bin',
  LabelKey.setDeviceWidth: 'Set device width',
  LabelKey.setMountNote: 'Set mounting note',
  LabelKey.insertRemedyDevice: 'Insert device',
  LabelKey.setRackHeight: 'Set rack height',
  LabelKey.setRackProperty: 'Edit rack',
  LabelKey.setRackLabel: 'Rename rack',
  LabelKey.compactRack: 'Compact rack',
  LabelKey.resizeRack: 'Resize rack',
  LabelKey.applyRackPreset: 'Apply rack preset',
  LabelKey.addRack: 'Add rack',
  LabelKey.addZeroUChannel: 'Add 0U channel',
  LabelKey.removeZeroUChannel: 'Remove 0U channel',
  LabelKey.setZeroUPosition: 'Move 0U device',
  LabelKey.setZeroUSpan: 'Resize 0U device',

  // ── links, ports and the schematic ──────────────────────────────────
  LabelKey.addLink: 'Add cable',
  LabelKey.removeLink: 'Delete cable',
  LabelKey.connectPorts: 'Connect',
  LabelKey.atomicConnect: 'Connect',
  LabelKey.multiDraw: 'Connect bank',
  LabelKey.splitSet: 'Split set',
  LabelKey.groupAsSet: 'Group as set',
  LabelKey.ungroupSet: 'Ungroup set',
  LabelKey.bindEndpoint: 'Land cable',
  LabelKey.moveEndpoint: 'Move cable end',
  LabelKey.unlandEndpoint: 'Unland cable',
  LabelKey.declareInlineAdapter: 'Declare adapter',
  LabelKey.setLinkJacketColor: 'Set jacket colour',
  LabelKey.setLinkPulledJacketColor: 'Set pulled jacket colour',
  LabelKey.setLinkClass: 'Set cable class',
  LabelKey.clearLinkClassOverride: 'Clear cable class override',
  LabelKey.setSignalFamily: 'Set signal family',

  // ── structured wiring ───────────────────────────────────────────────
  LabelKey.addStructure: 'Add structure',
  LabelKey.removeStructure: 'Remove structure',
  LabelKey.addOutlet: 'Add outlet',
  LabelKey.removeOutlet: 'Remove outlet',
  LabelKey.addOutletFromTemplate: 'Add outlet from template',
  LabelKey.addHomeRun: 'Add home run',
  LabelKey.addDrops: 'Add drops',
  LabelKey.removeDrops: 'Remove drops',
  LabelKey.fillCells: 'Fill cells',
  LabelKey.addPathway: 'Add pathway',
  LabelKey.removePathway: 'Remove pathway',

  // ── plates and gangs ────────────────────────────────────────────────
  LabelKey.addGang: 'Add gang',
  LabelKey.removeGang: 'Remove gang',
  LabelKey.setStrapSize: 'Set strap size',
  LabelKey.setCellOccupant: 'Set keystone',
  LabelKey.setGangPassThrough: 'Set pass-through',
  LabelKey.arrangePlate: 'Arrange plate',

  // ── locations and the plan ──────────────────────────────────────────
  LabelKey.addLocation: 'Add room',
  LabelKey.reparentLocation: 'Move room',
  LabelKey.removeLocation: 'Delete room',
  LabelKey.setPlanPin: 'Pin to plan',
  // SEPARATE FROM `setPlanPin`, on that value's own reasoning: "Undo Move
  // Pin" in front of somebody who has just placed their FIRST pin names
  // an act they did not perform.
  LabelKey.movePlanPin: 'Move pin',
  LabelKey.clearPlanPin: 'Remove pin',
  LabelKey.addPlanUnderlay: 'Add floorplan page',
  LabelKey.removePlanUnderlay: 'Remove floorplan page',
  LabelKey.reorderPlanUnderlay: 'Reorder floorplan pages',
  LabelKey.calibratePlan: 'Set plan scale',
  LabelKey.recalibratePlan: 'Change plan scale',
  LabelKey.rotatePlanClockwise: 'Rotate plan right',
  LabelKey.rotatePlanAnticlockwise: 'Rotate plan left',
  LabelKey.editPlanUnderlay: 'Edit floorplan page',
  LabelKey.lockPlacement: 'Lock position',
  LabelKey.unlockPlacement: 'Unlock position',
  LabelKey.pinSymbol: 'Pin symbol',
  LabelKey.unpinSymbol: 'Unpin symbol',
  LabelKey.moveSymbol: 'Move symbol',
  LabelKey.storeSymbolPositions: 'Arrange symbols',
  LabelKey.tidySheet: 'Tidy sheet',
  LabelKey.drawRoomOutline: 'Draw room outline',
  LabelKey.reshapeRoomOutline: 'Reshape room',
  LabelKey.clearRoomOutline: 'Erase room outline',
  LabelKey.setRoomEstimate: 'Set room estimate',
  LabelKey.clearRoomEstimate: 'Clear room estimate',

  // ── the device builder's own stack (CR-106) ─────────────────────────
  LabelKey.setTemplateProperty: 'Edit template',
  LabelKey.setPortProperty: 'Edit port',
  LabelKey.addPort: 'Add port',
  LabelKey.removePort: 'Remove port',
  LabelKey.quickAddPorts: 'Quick Add ports',
  LabelKey.generateArchetype: 'Generate from archetype',
  LabelKey.addBank: 'Add bank',
  LabelKey.renameBank: 'Rename bank',
  LabelKey.removeBank: 'Remove bank',
  LabelKey.mirrorBank: 'Mirror bank',
  LabelKey.pairPassthrough: 'Pair pass-through',
  LabelKey.unpairPassthrough: 'Unpair pass-through',
  LabelKey.renamePortKey: 'Rename port key',
  LabelKey.fillPorts: 'Fill ports',
  LabelKey.reorderPorts: 'Reorder ports',
  LabelKey.duplicatePorts: 'Duplicate ports',
  LabelKey.renumberPorts: 'Renumber ports',
  LabelKey.movePortsToBank: 'Move ports to bank',
  LabelKey.changePortType: 'Change port type',
  LabelKey.findAndReplacePorts: 'Find and replace',
  // ITS OWN VALUE AND ITS OWN WORD. The enum's comment: a sort commit
  // rewrites a whole bank at once and AC-058/D5 classes it as a data-loss
  // edge, so "Undo Reorder ports" in front of somebody who has just been
  // through a confirm dialog names the wrong act.
  LabelKey.commitPortSort: 'Sort ports',

  // ── templates in the project ────────────────────────────────────────
  LabelKey.saveTemplateToProject: 'Save template',
  LabelKey.removeTemplateFromProject: 'Remove template',

  // ── validation and project settings ─────────────────────────────────
  LabelKey.acknowledgeFinding: 'Acknowledge finding',
  LabelKey.unacknowledgeFinding: 'Withdraw acknowledgement',
  LabelKey.setRuleOverride: 'Override rule severity',
  LabelKey.setProjectSetting: 'Change project setting',
  LabelKey.setFamilyColorOverride: 'Override family colour',
  LabelKey.setLegendNotes: 'Edit legend notes',
  LabelKey.setProjectInfo: 'Edit project details',

  // ── registries and import ───────────────────────────────────────────
  LabelKey.addMediaType: 'Add media type',
  LabelKey.editMediaType: 'Edit media type',
  LabelKey.mergeMediaTypes: 'Merge media types',
  LabelKey.setConnectorAliases: 'Set connector aliases',
  LabelKey.importCsv: 'Import CSV',

  // ── everything else ─────────────────────────────────────────────────
  LabelKey.renameEntity: 'Rename',
  LabelKey.setEntityProperty: 'Edit',
};

/// What the Edit menu prints for [key], or null when the key has no
/// entry.
///
/// **NULL RATHER THAN A DERIVED STRING.** A caller that hits null has
/// found a `LabelKey` nobody named, and the honest render is the bare
/// word `Undo` rather than a de-camel-cased guess that reads like a bug
/// report. `undo_labels_test.dart` is what stops it happening.
///
/// Only tests call this (#945): it is a handle on live logic, not logic of its
/// own, so it stays and the analyzer keeps it out of lib/.
@visibleForTesting
String? undoLabelFor(LabelKey key) => kUndoLabels[key];

/// The full menu string: `Undo Move device`, or `Undo` when the stack is
/// empty or the key is unnamed.
String undoMenuLabel(String? labelKeyName) => _menuLabel('Undo', labelKeyName);

/// The same for redo.
String redoMenuLabel(String? labelKeyName) => _menuLabel('Redo', labelKeyName);

/// `UndoStack` exposes the label as the enum's `name` string, because
/// core hands out a stable identifier rather than a Flutter-facing type.
/// This resolves it back.
String _menuLabel(String verb, String? labelKeyName) {
  if (labelKeyName == null) return verb;
  for (final entry in kUndoLabels.entries) {
    if (entry.key.name == labelKeyName) return '$verb ${entry.value}';
  }
  return verb;
}
