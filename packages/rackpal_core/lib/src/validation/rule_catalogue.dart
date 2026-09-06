// The v1 DRC rule catalogue, as data (`#253`, `#254`, M5-A).
//
// ═══════════════════════════════════════════════════════════════════════
// METADATA IS DATA. THE PREDICATE IS CODE. THAT SPLIT IS THE WHOLE FILE
// ═══════════════════════════════════════════════════════════════════════
// AC-011 withdraws the claim that a user can author validation rules, and
// critique C10/D8 give the reason: a `RulePredicate` evaluated as an AST
// would make this app an interpreter for untrusted input. So a rule's id,
// tier, default severity and governing ruling live here as rows, and its
// predicate lives in Dart beside the thing it reasons about.
//
// THE 28 RULES DO NOT SHARE A SIGNATURE, and no amount of wishing makes
// them. A tier-1 connect rule answers about a gesture that has not
// happened yet and needs `(doc, from, to, ontoLink, freeing)`; `PLC-001`
// answers about a placement; a tier-3 rule reads the whole document and
// returns many findings. A single `List<Finding> Function(RackDocument)`
// would be clean for the fourteen post-hoc rules and would make the six
// spring-back rules unimplementable, which is why this file carries rows
// and a tier rather than function pointers.
//
// ═══════════════════════════════════════════════════════════════════════
// docs/02 §5 IS THE CATALOGUE, AND A TEST HOLDS THIS FILE TO IT
// ═══════════════════════════════════════════════════════════════════════
// CR-021: *"a rule not listed there does not exist"*. The corpus refers to
// a `docs/rules.md` and that file is deliberately never created. So
// `rule_catalogue_test.dart` PARSES docs/02 §5.1, §5.2 and §5.3 and
// asserts the ids here are exactly the ids there, tier by tier. Adding a
// row without adding it to the catalogue fails, and so does the reverse.
// A second copy of a list is a liability unless something compares them.
//
// FIVE OF THE EIGHT TIER-1 RULES WERE ALREADY BUILT when this landed:
// `TOP-001`..`TOP-005` in `derived/connect_rules.dart`, with rule ids,
// sentences and an evaluation order its enum encodes. This file does not
// rewrite them. It carries their rows and a test binds the two, which is
// the arrangement that keeps working code working and still fails when
// the two drift.
import 'package:rackpal_core/src/model/enums.dart' show Severity;

/// docs/02 §5's three tiers, in the frame CR-017 sets: *"the gesture may
/// hesitate. The document may not lie."*
enum RuleTier {
  /// States in which the document *means nothing*. The command is
  /// rejected and there is no escape, because there is nothing to escape
  /// to. These are the only rules that may prevent an edit.
  modelIllegal('T1'),

  /// Physically or electrically wrong and known at drag time. The wire
  /// springs back with a reason chip, remedy actions and
  /// `[ Connect anyway ]`, which files the tier-3 finding instead.
  springBack('T2'),

  /// Everything else, including anything unevaluatable at drag time. A
  /// `Finding` in the issues list, acknowledgeable with a reason that
  /// prints on sheet `T0.02`.
  postHoc('T3');

  const RuleTier(this.label);

  /// `'T1'`. What docs/02 §5's tier table calls it.
  final String label;
}

/// One row of docs/02 §5: everything about a rule that is not its code.
final class RuleMeta {
  const RuleMeta({
    required this.ruleId,
    required this.tier,
    required this.summary,
    required this.rationale,
    required this.governing,
    this.defaultSeverity,
    this.severityBand,
    this.codeCitation,
  });

  /// `'TOP-003'`. The join to `Finding.ruleId`, to `RuleOverride` and to
  /// `AckedFinding`, and the reason canon §12.6(b) ratifies `PLC-001..003`
  /// as numbered rules: an unnumbered blocking rule can carry neither.
  final String ruleId;

  final RuleTier tier;

  /// One line, in the catalogue's own words. Not the message a person
  /// sees: `ConnectRefused` already rules that a refusal carries a
  /// COMPLETE SENTENCE naming the real designators, and a generic summary
  /// is exactly what that forbids.
  final String summary;

  /// WHY the rule exists, in trade language, for the `[ Why? ]` viewer
  /// (AC-058/D1, M5-F3).
  ///
  /// [summary] says what the predicate TESTS, in the model's vocabulary.
  /// A person who clicks `[ Why? ]` is not asking for that restated: they
  /// are asking what goes wrong on the job, and a viewer that answered
  /// with the predicate would be the button that *"leads nowhere"* the
  /// completeness critique named.
  ///
  /// REQUIRED, so the catalogue cannot carry a rule with no explanation.
  /// AC-058/D1 describes `CompatibilityRuleDef.rationale` as though the
  /// text already existed and only lacked a viewer; it did not. That type
  /// is from `docs/research/design-data-model.md`, a priority-3 document,
  /// and was never built. This is the field that sentence assumed.
  ///
  /// M5-H1 wants these same 28 rules *"in trade language, not model
  /// language"* for expert review, so this is ONE text serving both, and
  /// H2's corrections land on the words the product actually shows.
  final String rationale;

  /// The ruling ids this rule answers to, e.g. `['CR-017', 'AC-018']`.
  /// §8.2's citation, carried by the rule rather than by a comment.
  ///
  /// THESE ARE THIS REPOSITORY'S IDS, NOT AN EXTERNAL DOCUMENT'S, which
  /// is why [codeCitation] is a separate field and not a row here.
  final List<String> governing;

  /// The external code article this rule asks a person to verify against,
  /// e.g. `'NEC 800.154'`. Null for every rule that turns on nothing
  /// outside this product, which is 26 of the 28.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// A FIELD BECAUSE THE ARTICLE WAS PROSE, AND PROSE IS NOT FINDABLE
  /// ═══════════════════════════════════════════════════════════════════
  /// DR-129 §11.128. `CODE-002`'s message ends *"Verify against NEC
  /// 800.154"*, which is correct and puts the article at the end of a
  /// sentence that begins with a cable designator. The M5-H2 reviewer's
  /// twelfth finding was that a code-adjacent row wants more than that.
  ///
  /// DR-125's shape: **the catalogue authorises the fact and the surface
  /// renders it.** A panel inferring "this is a code rule" from a rule id
  /// beginning `CODE-` would be a widget deciding what the catalogue
  /// means, which is the thing CR-021 exists to prevent.
  ///
  /// WHAT DOES NOT GO HERE. `CODE-002` also names `300.22(C)`'s
  /// metal-raceway exception, and that stays in the message: it is an
  /// argument about what this product cannot see, not a citation to look
  /// up, and a sentence is where an argument belongs.
  final String? codeCitation;

  /// The severity a finding is filed at before any `RuleOverride`.
  ///
  /// NULL FOR EVERY TIER-1 RULE, and that null is structural rather than
  /// unknown (G4/CR-114 is about measurements, and this is a fact about
  /// the tier). A T1 rule refuses the command; it never files a finding,
  /// so there is nothing for a severity to describe. `severityIsTiered`
  /// in the test holds the correspondence in both directions.
  final Severity? defaultSeverity;

  /// The severities this rule's predicate may choose between, when the
  /// catalogue authorises a BAND rather than a single value.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// WHY THIS EXISTS, AND WHY IT IS NOT "LET PREDICATES PICK"
  /// ═══════════════════════════════════════════════════════════════════
  /// `evaluateDocument` builds every `Finding` with the project-resolved
  /// severity and DISCARDS whatever the predicate set, which is correct
  /// and was ruled: M5-E found `LEN-001` stamping its own `advisory` on a
  /// good argument that *"is not in the catalogue"*, and a predicate
  /// choosing a second severity is inventing a rule (CR-021).
  ///
  /// **`RCK-003` is the opposite case.** docs/02 §5.3's row has said
  /// *"warning (advisory at 85%)"* since M0: the CATALOGUE authorises two
  /// severities and the evaluator had no way to express that, so the
  /// `advisory` the predicate had been setting since M5-E **never reached
  /// a single user**. Nobody had checked, because the AC-051 pair asserts
  /// which rule fires and never how loudly (DR-125 §11.124.2).
  ///
  /// So the catalogue declares the band and the evaluator honours it for
  /// exactly the rules that declare one. **CR-021 is preserved**: the
  /// catalogue still decides what a rule may say, and a predicate still
  /// cannot invent it.
  ///
  /// NULL MEANS ONE SEVERITY, which is every other rule.
  ///
  /// **A PROJECT OVERRIDE COLLAPSES THE BAND**, deliberately: an override
  /// is the project saying what this rule counts as here, so a rack that
  /// was advisory, warning and error becomes whatever was set. That is
  /// what `rules_rack.dart` already promised, that *"a project that
  /// demotes `RCK-003` demotes all three"*.
  final Set<Severity>? severityBand;

  @override
  String toString() => '$ruleId (${tier.label})';
}

/// docs/02 §5.1: eight tier-1 rules, model-level illegality.
///
/// `TOP-001`..`TOP-005` are implemented in `derived/connect_rules.dart`.
/// **`PLC-001`..`PLC-003` are not implemented anywhere**, which a census
/// at the start of M5 established rather than assumed: the string
/// `PLC-00` appears in no Dart file in this repository, and there is no
/// placement-validity helper for the geometry code to call. They are
/// rows here and unbuilt predicates, which is the honest state.
const List<RuleMeta> kTier1Rules = <RuleMeta>[
  RuleMeta(
    ruleId: 'TOP-001',
    tier: RuleTier.modelIllegal,
    summary: 'A conductor may not connect a port to itself.',
    rationale:
        'A cable that starts and ends at the same jack is not a cable. Nothing '
        'can be pulled to it and nothing can be terminated on it, so a drawing '
        'showing one is describing work no installer can do.',
    governing: ['CR-017'],
  ),
  RuleMeta(
    ruleId: 'TOP-002',
    tier: RuleTier.modelIllegal,
    summary:
        'Two conductors may not duplicate the same ordered port pair on '
        'the same link.',
    rationale:
        'Two conductors between the same pair of pins inside one cable is the '
        'same conductor counted twice. The schedule would call for wire nobody '
        'pulls, and the terminations would not add up on site.',
    governing: ['CR-017'],
  ),
  RuleMeta(
    ruleId: 'TOP-003',
    tier: RuleTier.modelIllegal,
    summary:
        "A port's live conductor count may not exceed its effective "
        'maxConnections.',
    rationale:
        'A jack takes the number of plugs it physically has. A drawing showing '
        'two cables in one HDMI port is asking for something the hardware '
        'cannot do, and the second cable has nowhere to go.',
    governing: ['CR-017'],
  ),
  RuleMeta(
    ruleId: 'TOP-004',
    tier: RuleTier.modelIllegal,
    summary:
        'Every endpoint must resolve: a PortEndpoint to an existing, '
        'non-tombstoned port.',
    rationale:
        'A cable landing on a port that is not there is a run nobody can '
        'terminate. This usually means the device was deleted after the cable '
        'was drawn.',
    governing: ['CR-017', 'AC-018'],
  ),
  RuleMeta(
    ruleId: 'TOP-005',
    tier: RuleTier.modelIllegal,
    summary:
        "A shelf-hosted device's hostDeviceId must resolve to a container "
        'and must not create a containment cycle.',
    rationale:
        'A shelf mounted inside itself has no place in a rack. The elevation '
        'could not be drawn, because the device would have no height and no '
        'position.',
    governing: ['CR-017'],
  ),
  RuleMeta(
    ruleId: 'PLC-001',
    tier: RuleTier.modelIllegal,
    summary:
        'RailPlacement.ruIndex lies in [1, rack.heightU] and the device '
        'fits within the rack extent on that face.',
    rationale:
        'A device at RU 45 of a 42U rack is not in the rack. Whatever the '
        'drawing says, the installer arrives to find no rail there.',
    governing: ['CR-017'],
  ),
  RuleMeta(
    ruleId: 'PLC-002',
    tier: RuleTier.modelIllegal,
    summary:
        'startTwelfth in [0,11], spanTwelfths in [1,12], and '
        'startTwelfth + spanTwelfths at most 12.',
    rationale:
        'A rack unit is divided into twelfths so part-width gear can sit side '
        'by side. A device claiming more than the full width, or starting past '
        'its own right-hand edge, is in a position on the rail that does not '
        'exist.',
    governing: ['CR-030'],
  ),
  RuleMeta(
    ruleId: 'PLC-003',
    tier: RuleTier.modelIllegal,
    summary:
        'ZeroUPlacement.channelId resolves in rack.zeroUChannels and the '
        'offset lies within the channel.',
    rationale:
        'Zero-U gear mounts in a channel down the side of the rack. A device '
        'in a channel this rack does not have, or past the end of one, has '
        'nothing to screw into.',
    governing: ['CR-031'],
  ),
];

/// docs/02 §5.2: six tier-2 rules, gesture-level spring-back.
///
/// Every one of these also exists as a tier-3 finding once the user takes
/// `[ Connect anyway ]`, which is why each carries a default severity
/// despite refusing nothing: the severity is what the FILED finding gets.
const List<RuleMeta> kTier2Rules = <RuleMeta>[
  RuleMeta(
    ruleId: 'SIG-001',
    tier: RuleTier.springBack,
    summary:
        'HDBaseT port connected to a net.ethernet switch port. The '
        'flagship rule: PoH into a switch port.',
    rationale:
        'HDBaseT extenders often push power down the same cable. Plugged into '
        'a network switch that is not expecting it, that power can destroy the '
        'switch. This is the failure this product was built to catch.',
    governing: ['CR-017'],
    defaultSeverity: Severity.error,
  ),
  RuleMeta(
    ruleId: 'SIG-002',
    tier: RuleTier.springBack,
    summary:
        "The sink's acceptedFamilies excludes the service's signalFamily, "
        'and no InlineAdapter is declared.',
    rationale:
        'The signal arriving is not one this input can read. It will show '
        'nothing, or noise, and the crew will spend a morning swapping cables '
        'to find out why. If an adapter is going in, declare it and this '
        'clears.',
    governing: ['CR-017'],
    defaultSeverity: Severity.error,
  ),
  RuleMeta(
    ruleId: 'DIR-001',
    tier: RuleTier.springBack,
    summary:
        'source to source, or sink to sink. Exceptions: both ports '
        'declare returnChannel (eARC), or the net is passiveSplit.',
    rationale:
        'Two outputs wired to each other, or two inputs: nothing is driving '
        'the run. Two exceptions are real and allowed for, eARC where both '
        'ends talk back, and a passive split.',
    governing: ['AC-040'],
    defaultSeverity: Severity.error,
  ),
  RuleMeta(
    ruleId: 'DIR-003',
    tier: RuleTier.springBack,
    summary:
        'IR emitter output plugged into an IR receiver jack. Damages '
        'hardware; PortDef.pinoutVariant exists solely to detect it.',
    rationale:
        'IR emitters and receivers use the same plug and different wiring. '
        'Swapped, the emitter can be damaged. The connector will not tell you, '
        'which is the whole reason this is checked in the drawing.',
    governing: ['AC-040'],
    defaultSeverity: Severity.error,
  ),
  RuleMeta(
    ruleId: 'CON-001',
    tier: RuleTier.springBack,
    summary:
        'Connector types do not mate and no InlineAdapter is declared. '
        'Satisfied by data: declaring the adapter clears it.',
    rationale:
        'The plug does not fit the jack. Declaring the adapter that is '
        'actually going in the box clears this: it is asking what the job '
        'includes, not refusing the design.',
    governing: ['CR-015'],
    defaultSeverity: Severity.error,
  ),
  RuleMeta(
    ruleId: 'ELE-006',
    tier: RuleTier.springBack,
    summary:
        'Constant-voltage speaker on a low-Z amplifier output, or the '
        'reverse.',
    rationale:
        'Constant-voltage (70/100 V) speakers and low-impedance amplifier '
        'outputs are not interchangeable. The wrong pairing is quiet at best '
        'and a damaged amplifier at worst.',
    governing: ['AC-040'],
    defaultSeverity: Severity.error,
  ),
];

/// docs/02 §5.3: fourteen tier-3 rules, the post-hoc findings.
///
/// **v1 ships this set and no more** (AC-040 as amended by DR-020). The
/// count is the scope gate: roadmap M5's own risk list names *"just one
/// more obvious rule"* without its fixture pair as the mechanism by which
/// this milestone overruns, so `rule_catalogue_test.dart` fails when the
/// size changes and makes any addition a deliberate, visible act.
const List<RuleMeta> kTier3Rules = <RuleMeta>[
  RuleMeta(
    ruleId: 'ELE-003',
    tier: RuleTier.postHoc,
    summary:
        'Speaker polarity inverted between the two ends of a conductor '
        'pair.',
    rationale:
        'One speaker of a pair wired backwards cancels bass where the two '
        'overlap. It measures fine and sounds thin, so it is usually found '
        'long after handover, if at all.',
    governing: ['AC-030'],
    defaultSeverity: Severity.warning,
  ),
  RuleMeta(
    ruleId: 'ELE-005',
    tier: RuleTier.postHoc,
    summary:
        'Speaker taps on a constant-voltage line exceed 80% of the '
        'amplifier channel rating. Known taps only; unrecorded taps are '
        'counted and named, never estimated.',
    rationale:
        'Overload a 70 V line and the amplifier clips, and clipped square '
        'waves are what destroy tweeters, so the cost of getting this '
        'wrong is a van full of replacement drivers rather than a '
        'protection circuit doing its job. The 80% is headroom on the same '
        'convention PWR-001 derates a breaker by, and it is a planning '
        'figure rather than a measurement: a tap nobody recorded still '
        'draws, so the total this reports is a FLOOR.',
    governing: ['AC-040', 'DR-132', 'CR-114'],
    defaultSeverity: Severity.warning,
  ),
  RuleMeta(
    ruleId: 'NET-001',
    tier: RuleTier.postHoc,
    summary:
        'Sum of PD class draw on a switch exceeds '
        'PowerProfile.poeBudgetWatts.',
    rationale:
        'A switch has a total power budget, not only a per-port one. Load '
        'every port and it starts dropping devices, usually the ones that came '
        'up last and usually at the worst moment.',
    governing: ['CR-056'],
    defaultSeverity: Severity.error,
  ),
  RuleMeta(
    ruleId: 'PWR-001',
    tier: RuleTier.postHoc,
    summary:
        'Continuous amps on a circuit exceed 80% of the breaker, on '
        'typical times diversity, in VA. A planning estimate and not a '
        'compliance check.',
    rationale:
        'Continuous load on a breaker is conventionally kept to 80% of its '
        'rating; past that, expect nuisance trips. This is a planning estimate '
        'from typical draw and diversity, NOT a compliance check: verify '
        'against real nameplates before anyone commits to a panel schedule.',
    governing: ['CR-020', 'AC-020', 'DR-079'],
    defaultSeverity: Severity.warning,
  ),
  RuleMeta(
    ruleId: 'PWR-003',
    tier: RuleTier.postHoc,
    summary: 'Outlets consumed exceed outlets provided in the rack.',
    rationale:
        'More things to plug in than places to plug them. Somebody will arrive '
        'with a power strip nobody drew, in a rack whose load was worked out '
        'without it.',
    governing: ['AC-040'],
    defaultSeverity: Severity.error,
  ),
  RuleMeta(
    ruleId: 'LEN-001',
    tier: RuleTier.postHoc,
    summary:
        'Ethernet channel over 100 m. A null length emits "length '
        'unknown, cannot verify" rather than passing silently.',
    rationale:
        '100 m is the whole Ethernet channel, patch cords at both ends '
        'included, not just the horizontal run. Past it the link negotiates '
        'down or drops. Where the length is not known, this says so rather '
        'than passing quietly.',
    governing: ['AC-024'],
    defaultSeverity: Severity.error,
  ),
  RuleMeta(
    ruleId: 'LEN-002',
    tier: RuleTier.postHoc,
    summary:
        "A run's known length exceeds MediaTypeDef.maxRunLengthPassive. "
        'Generic by construction: one rule reading the registry, not one '
        'rule per medium.',
    rationale:
        'Every medium has a distance past which it needs help. The figure is '
        'read from the media registry rather than written into the rule, so a '
        "run past its own medium's limit needs an extender or a different "
        'cable.',
    governing: ['DR-020'],
    defaultSeverity: Severity.warning,
  ),
  RuleMeta(
    ruleId: 'RCK-001',
    tier: RuleTier.postHoc,
    summary: 'RU overlap on the same face.',
    rationale:
        'Two devices in the same rack space. One of them is not going in, and '
        'the elevation is showing a rack that cannot be built.',
    governing: ['AC-040'],
    defaultSeverity: Severity.error,
  ),
  RuleMeta(
    ruleId: 'RCK-002',
    tier: RuleTier.postHoc,
    summary: 'Device extends past heightU.',
    rationale:
        'The device runs off the end of the rack. Either the rack is shorter '
        'than the design assumed, or the device is mounted too low to fit.',
    governing: ['AC-040'],
    defaultSeverity: Severity.error,
  ),
  RuleMeta(
    ruleId: 'RCK-003',
    tier: RuleTier.postHoc,
    summary:
        'Sum of device weight exceeds Rack.weightCapacity. Advisory at '
        '60%, warning at 85%, error over capacity.',
    rationale:
        'Racks have a load rating, and a full rack of amplifiers reaches it '
        'faster than people expect. The notice starts at 60% because a 42U '
        'rack at 85% of its rating is already heavy enough for the casters '
        'to mark a floor, and a warning that arrives then arrives after the '
        'fourth amplifier was specified rather than before it.',
    governing: ['CR-020'],
    defaultSeverity: Severity.warning,
    // THE ONE BANDED ROW IN THE CATALOGUE (DR-125 §11.124.2). docs/02
    // §5.3 has authorised two severities here since M0; the evaluator
    // could not express it, so the `advisory` half never reached anybody.
    severityBand: {Severity.advisory, Severity.warning, Severity.error},
  ),
  RuleMeta(
    ruleId: 'RCK-012',
    tier: RuleTier.postHoc,
    summary:
        'Front depth plus rear depth plus a 50 mm cable allowance exceeds '
        'usable depth, for overlapping RU ranges.',
    rationale:
        'Gear mounted front and rear in the same rack space shares the depth '
        'between them, and cables need somewhere to bend. The 50 mm allowance '
        'is what stands between the design and a rear door that will not '
        'close.',
    governing: ['AC-022'],
    defaultSeverity: Severity.error,
  ),
  RuleMeta(
    ruleId: 'RCK-013',
    tier: RuleTier.postHoc,
    summary:
        'Device mass exceeds maxUnsupportedMass on front ears only; '
        'requires rear support or a shelf.',
    rationale:
        'Heavy gear hung on its front ears alone will bend them and can tear '
        'out of the rail. It needs rear support or a shelf. Common on power '
        'amplifiers and UPS units, which are heavier than they look.',
    governing: ['AC-028'],
    defaultSeverity: Severity.warning,
  ),
  RuleMeta(
    ruleId: 'CODE-001',
    tier: RuleTier.postHoc,
    summary:
        'Class 2/3 conductor in a Pathway with containsLineVoltage. Cites '
        'NEC 725.136 and asks the user to verify rather than asserting a '
        'violation.',
    rationale:
        'Low-voltage cable sharing a pathway with line voltage. NEC 725.136 '
        'governs when that is permitted and when it is not, and the answer '
        'depends on the cable, the barrier and the jurisdiction. This flags it '
        'for you to verify against the article; it does not decide it.',
    governing: ['AC-027', 'DR-079'],
    defaultSeverity: Severity.warning,
    codeCitation: 'NEC 725.136',
  ),
  RuleMeta(
    ruleId: 'CODE-002',
    tier: RuleTier.postHoc,
    summary:
        "Pathway.kind is plenumSpace and the jacket's LISTING is not "
        'plenum-rated for its own NEC article. A listing from another '
        'article, or none, is unknown and skips (G4).',
    rationale:
        'Cable in a plenum has to carry a plenum listing, because in a fire '
        'that air path feeds the rest of the building. A jacket listed under '
        'another article, or carrying no listing at all, is treated as unknown '
        'here rather than assumed either way.',
    governing: ['AC-027', 'DR-079'],
    defaultSeverity: Severity.warning,
    codeCitation: 'NEC 800.154',
  ),
  RuleMeta(
    ruleId: 'LNK-020',
    tier: RuleTier.postHoc,
    summary: 'N links have unbound endpoints. A checklist, not a failure.',
    rationale:
        'Cables drawn but not yet landed on anything. This is a checklist for '
        'the end of a design session, not a fault: unbound ends are a normal '
        'way to work.',
    governing: ['AC-018'],
    defaultSeverity: Severity.advisory,
  ),
];

/// All 28, in tier order.
///
/// EXPLICIT, NOT REFLECTIVE (`#253`). There is no scan of the source tree
/// and no annotation: a rule that is not in one of the three lists above
/// does not exist, and its absence is visible here rather than silent at
/// run time.
const List<RuleMeta> kRuleCatalogue = <RuleMeta>[
  ...kTier1Rules,
  ...kTier2Rules,
  ...kTier3Rules,
];

/// The catalogue keyed by `ruleId`, which is how `Finding`, `RuleOverride`
/// and `AckedFinding` all join to it.
final Map<String, RuleMeta> kRulesById = <String, RuleMeta>{
  for (final rule in kRuleCatalogue) rule.ruleId: rule,
};

/// The rules of one tier, in catalogue order.
List<RuleMeta> rulesInTier(RuleTier tier) => <RuleMeta>[
  for (final rule in kRuleCatalogue)
    if (rule.tier == tier) rule,
];
