// The console palette, as ARGB. DR-090 (canon §11.89). Board #770.
//
// ═════════════════════════════════════════════════════════════════════
// WHY THIS IS IN `rackpal_core` AND NOT IN THE WIDGET LAYER
// ═════════════════════════════════════════════════════════════════════
// Because `contrast.dart` is here, and DR-080 §11.79.4 says in terms that
// the product must not acquire a SECOND definition of contrast. A palette
// defined in `rackpal_ui` as `Color` constants could only be checked by
// a second implementation of relative luminance, which is the mistake
// CR-080's font drift and the `family_glyph` measurement each made in
// their own register: one fact, two implementations, nothing comparing
// them. Here the numbers in DR-090 are checkable by the authority that
// already exists, and `console_palette_test.dart` checks them.
//
// `rackpal_ui` turns these into `Color` and into a `ThemeData`. It does
// not restate any of them.
//
// ═════════════════════════════════════════════════════════════════════
// TWO OF THESE VALUES ARE NOT THE ONES THE USER GAVE, AND SAY SO
// ═════════════════════════════════════════════════════════════════════
// [kConsoleSecondaryText] and [kConsoleNonCriticalText] were lightened
// from `#64748B` and `#718096`, which measure 3.08:1 and 3.65:1 on
// Card and fail AA. The first attempt lightened both to the AA floor and
// left them ΔE 0.87 apart, which is below the just-noticeable difference:
// two tokens, one colour, where the values as given were ΔE 4.85 apart.
// So the contrast fix destroyed a distinction the user had made, and the
// rule worth carrying out of it is that A CONSTRAINT CHECKED TOKEN BY
// TOKEN CANNOT SEE THE SET.
//
// ═════════════════════════════════════════════════════════════════════
// STATUS HUE IS NEVER THE ONLY CUE (§11.89.6)
// ═════════════════════════════════════════════════════════════════════
// Four of the five status colours sit within ΔE 25 of one of the eight
// signal-domain hues they share a window with, and Warning and Caution
// are fixed brand values that collide on their own, so no re-derivation
// fixes it. A status marker must therefore carry a second cue that
// survives its colour being deleted: a shape, an icon, a border or a
// word. A bare coloured dot is not a status marker.

/// Canvas Back: the drawing surface.
const int kConsoleCanvas = 0xFF0B0D10;

/// Console Base: sidebar navigation and the equipment drawer.
const int kConsoleBase = 0xFF14181E;

/// Card / Panel: panels, cards and raised surfaces. The darkest surface
/// that text sits on, so it is the one every text tier is measured
/// against.
const int kConsoleCard = 0xFF222933;

/// Button and slider grounds.
const int kConsoleButtonBase = 0xFF0D1117;

/// Body text.
const int kConsolePrimaryText = 0xFFE2E8F0;

/// Text on controls.
const int kConsoleControlText = 0xFFE4E7EB;

/// The active state of a control.
const int kConsoleActive = 0xFFA0AEC0;

/// Secondary text. Lightened from `#64748B`; see this file's header.
///
/// `#64748B` was also already `kUnresolvedSignalArgb`, so shipping it here
/// would have given one value two unrelated meanings in one window.
const int kConsoleSecondaryText = 0xFF8190A4;

/// Non-critical data text. Lightened from `#718096`; see the header.
const int kConsoleNonCriticalText = 0xFF929EAF;

/// Tracks, borders, dividers and off-state fills.
///
/// NOT for text. At 1.22:1 on Card a line is still findable, because the
/// eye is told where to look, and a label is not, because a label is a
/// shape the eye has to decode. That is why the token split in two.
const int kConsoleInactiveSurface = 0xFF2D3748;

/// Disabled labels and icons. See [kConsoleInactiveSurface].
const int kConsoleInactiveInk = 0xFF586679;

/// Critical. Pantone 186.
///
/// A FILL AND NEVER INK. On Card it measures 2.49:1 and fails AA as text;
/// as a chip with light text on it, 4.74:1 and passes. It is also the
/// only one of the five that takes light ink, which
/// `prefersLightInk` in `contrast.dart` decides rather than this
/// file asserting it twice.
const int kConsoleCritical = 0xFFC8102E;

/// Warning. Pantone 152.
const int kConsoleWarning = 0xFFE57200;

/// Caution. Pantone 109.
const int kConsoleCaution = 0xFFFFD100;

/// Notice. Derived, moved from the user's `#BFCED6`.
const int kConsoleNotice = 0xFF86BDDA;

/// Nominal. Derived, moved from the user's `#93E9BE`.
const int kConsoleNominal = 0xFFC2FFE0;

/// The five status colours in ascending greyscale luminance.
///
/// The ORDER is the point: greyscale is what a mono laser prints and is
/// the axis deuteranopia also collapses onto, so this list is the ladder
/// PAL-1's 0.10 floor is measured along.
const List<int> kConsoleStatusLadder = <int>[
  kConsoleCritical,
  kConsoleWarning,
  kConsoleNotice,
  kConsoleCaution,
  kConsoleNominal,
];

/// Door 1's scope cue: "this edit touches this device and nothing else"
/// (CR-054, DR-098 §11.97.5).
///
/// A SCOPE IS NOT A SEVERITY, and this constant exists rather than a
/// reuse of [kConsoleWarning] for exactly that reason. Nothing is wrong
/// when this badge shows; it is telling the user how far an edit reaches.
/// `console_theme.dart`'s header already refuses to put status in the
/// `ColorScheme` so no widget picks a severity up by accident, and reading
/// amber off the status ladder here would walk straight into the same
/// mistake from the other side.
///
/// IT IS AN INK AND A BORDER, NEVER A FILL. The badge draws on
/// [kConsoleCard], which is why the only bar this has to clear is 4.5:1
/// against that surface, asserted in `console_palette_test.dart`. Adding a
/// scope FILL would need its own ink and its own pair of assertions, and
/// the badge does not need one to be read.
///
/// DR-090 §11.89.6 IS SATISFIED BY THE SENTENCE, not by this value. The
/// badge always spells out what will and will not change, so deleting this
/// colour would cost the eye a cue and cost the reader nothing. Doors 2
/// and 3 get their own tokens when `#231` and `#232` build them; they are
/// deliberately not defined here in advance, because a colour with no
/// caller cannot be checked against the thing it draws on.
const int kConsoleScopeInstance = 0xFFFFC24D;
