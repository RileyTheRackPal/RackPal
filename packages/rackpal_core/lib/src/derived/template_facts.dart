// The facts a browser filter chip asks about one template (`#243`,
// DR-104 §11.103.6, docs/06 §7.1).
//
// ═══════════════════════════════════════════════════════════════════════
// DR-104 SAID EACH CHIP NEEDS A PRODUCER IT DID NOT GRANT. ALL EIGHT HAD
// ONE
// ═══════════════════════════════════════════════════════════════════════
// §11.103.6 hedged: `#243`'s chip list is *"a menu to choose from and not
// a contract, and each chip needs a producer this ruling does not grant
// it."* The census found every one already in the model:
//
//   RU height          `frontU` / `rearU`
//   mount method       `TemplateBody.mountMethod`
//   has HDMI           the ports' connectors and families
//   has PoE            the ports' families AND `PoeSpec.role`
//   is passthrough     `TemplateBody.isPassthrough`
//   container          `TemplateBody.isContainer`
//   used in project    `countDevicesOnTemplate` (`template_usage.dart`)
//   drafts             `isDraftTemplate` (`builder/template_draft.dart`)
//
// So the chip row ships whole rather than as whichever subset had data,
// and this file is a projection of eight existing answers rather than
// eight new rules.
//
// ═══════════════════════════════════════════════════════════════════════
// `hasPoE` IS TWO QUESTIONS AND BOTH COUNT
// ═══════════════════════════════════════════════════════════════════════
// A port can carry PoE by declaring the `net.poe` family, or by carrying
// a `PoeSpec` whose `role` is `pse` or `pd` on an ordinary Ethernet port,
// which is how the seeded switches model it. Reading only the family
// would answer "no PoE" for a 24-port PoE switch, which is the device the
// chip most exists to find. `role: none` is an explicit "this port does
// not do PoE" and is NOT a hit; G4's distinction between a measured
// negative and an absent one, on a chip.
//
// ═══════════════════════════════════════════════════════════════════════
// `usedInProject` IS A COUNT AND THE CHIP READS THE PREDICATE
// ═══════════════════════════════════════════════════════════════════════
// `countDevicesOnTemplate` already answers with a number, and a number is
// what a card can print ("used 3 times") where a boolean is only what the
// chip can filter on. Storing the count and deriving the boolean keeps
// one call doing both jobs.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/builder/template_draft.dart'
    show isDraftTemplate;
import 'package:rackpal_core/src/derived/placeable_templates.dart';
import 'package:rackpal_core/src/derived/template_usage.dart'
    show countDevicesOnTemplate;
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/model/template.dart';

/// Everything docs/06 §7.1's sidebar filters on, for one template.
@immutable
final class TemplateFacts {
  const TemplateFacts({
    required this.ruHeight,
    required this.mountMethod,
    required this.hasHdmi,
    required this.hasPoe,
    required this.isPassthrough,
    required this.isContainer,
    required this.isDraft,
    required this.usedInProject,
  });

  /// The template's rail footprint: the larger of its two faces.
  ///
  /// **ZERO IS A REAL ANSWER**, and it means the same thing the palette's
  /// occupancy badge means by it: a field device or a 0U occupant has no
  /// rail footprint. An `RU height` chip must therefore offer `0U` as a
  /// value rather than treating it as missing.
  final int ruHeight;

  final MountMethod mountMethod;
  final bool hasHdmi;
  final bool hasPoe;
  final bool isPassthrough;
  final bool isContainer;
  final bool isDraft;

  /// How many devices in the document resolve to this template id.
  final int usedInProject;

  bool get isUsedInProject => usedInProject > 0;
}

/// Whether any port declares a signal family whose id starts with
/// [prefix].
///
/// A PREFIX rather than an equality, because the families are a dotted
/// hierarchy: `video.hdmi.1_4`, `video.hdmi.2_0` and `video.hdmi.2_1` are
/// three ids and one question. Callers pass the level they mean.
///
/// **IT ALSO TESTED `carriedProtocols` UNTIL DR-134, AND THAT HALF NEVER
/// MATCHED ANYTHING.** Not because the question was wrong but because no
/// gesture could answer it: every seeded port and every authored one held
/// `[]`. The answers this function gives are unchanged by its removal,
/// which is the measurement that made the field's deletion safe rather
/// than the argument that made it right (§11.133.2).
bool templateHasFamilyPrefix(TemplateBody body, String prefix) =>
    body.ports.any((p) => p.signalFamily.v.startsWith(prefix));

/// Whether any port declares a connector whose id starts with [prefix].
bool templateHasConnectorPrefix(TemplateBody body, String prefix) =>
    body.ports.any((p) => p.connector.v.startsWith(prefix));

/// Builds [row]'s facts.
///
/// [doc] is optional and decides one field: without it `usedInProject` is
/// zero, which is the honest answer for a caller that has no document
/// rather than a claim that nothing uses it. A browser always has one.
TemplateFacts buildTemplateFacts(PlaceableTemplate row, {RackDocument? doc}) {
  final body = row.body;
  return TemplateFacts(
    ruHeight: body.frontU > body.rearU ? body.frontU : body.rearU,
    mountMethod: body.mountMethod,
    // BOTH SPELLINGS. A device can carry HDMI as a connector on a port
    // whose family is the generic `video.digital`, or as a family on a
    // port whose connector is something else entirely (an HDMI signal
    // over a captive lead). Either is "has HDMI" to somebody looking for
    // one.
    hasHdmi:
        templateHasFamilyPrefix(body, 'video.hdmi') ||
        templateHasConnectorPrefix(body, 'conn.hdmi'),
    hasPoe:
        templateHasFamilyPrefix(body, 'net.poe') ||
        // See the header: a PoE switch models it on the SPEC, not the
        // family, so a family-only read answers "no" for the device the
        // chip most exists to find. `role: none` is a measured negative
        // and is deliberately not a hit.
        body.ports.any(
          (p) => switch (p.poe?.role) {
            PoeRole.pse || PoeRole.pd => true,
            PoeRole.none || null => false,
          },
        ),
    isPassthrough: body.isPassthrough,
    isContainer: body.isContainer,
    isDraft: isDraftTemplate(body),
    usedInProject: doc == null
        ? 0
        : countDevicesOnTemplate(doc, row.templateId),
  );
}
