// rackpal_core/src/draw/device_accent.dart — pure Dart.
//
// The eight colours a device may be accented with, in one place.
//
// ─────────────────────────────────────────────────────────────────────────
// WHY THIS FILE EXISTS: TWO SURFACES OFFER THE SAME EIGHT SWATCHES
// ─────────────────────────────────────────────────────────────────────────
// The device builder's Appearance section sets `TemplateBody.accentColor`;
// door 1's inspector section sets `DeviceOverrides.accentColor` on one
// placed instance (CR-054, DR-098 §11.97.5). They are different fields at
// different scopes and they must offer the SAME eight colours, because a
// swatch a person can pick on a template and not on an instance reads as
// a bug in whichever surface they met second.
//
// The list was a private `_swatches` inside `device_builder_screen.dart`.
// Copying it into a second widget is how the 1000x mass error and CR-080's
// font drift both started: one fact, two literals, and no gate that can
// see them disagree.
//
// ─────────────────────────────────────────────────────────────────────────
// THEY ARE OKABE-ITO, AND THE PALETTE'S COPY IS A DIFFERENT FACT
// ─────────────────────────────────────────────────────────────────────────
// `seed_registries.dart` carries these same eight hues as SIGNAL DOMAIN
// colours (`'#E69F00'` on `audio.analog`, and so on). That is CR-078's
// subject: colour lives on the signal domain, never on the family. This
// list is a DEVICE accent, which is DR-080 §11.79.4's subject. Sharing a
// source palette does not make them one fact, and merging them would put
// a device fill inside the thing `registry_parity` and PAL-1 gate.
//
// THE OLD COMMENT'S LAST CLAUSE WAS WRONG AND IS CORRECTED HERE. It read
// "these are the eight Okabe-Ito hues the palette already ships, which
// PAL-1 has already cleared". PAL-1 cleared them as SIGNAL FAMILY PAIRS.
// DR-080 §11.79.2 measured this directly: `tools/pal1_check.py` enumerates
// `SignalFamilyDef` pairs and "has no device concept whatsoever", so it
// cannot see a device fill and never cleared one. What actually protects
// a device body is DR-080 §11.79.4's rule that the four label inks are
// computed from the RESOLVED FILL's luminance, which is why pure black is
// safe to offer here at all.
//
// A FIXED SET AND NOT A WHEEL, which is the half of the original comment
// that was right and is kept: the value is an `Rgb` on the model, and a
// colour wheel invites a hue nobody has checked against anything.

import 'package:rackpal_core/src/units/rgb.dart';

/// The eight accent colours offered for a device, template or instance.
///
/// ORDER IS PART OF THE VALUE. Both surfaces draw them as a row in this
/// order, so a person who learns "the green one is third" on the builder
/// finds it third in the inspector. Appending is safe; reordering is a
/// change to something people have memorised.
const List<Rgb> kDeviceAccentSwatches = <Rgb>[
  Rgb(0x00, 0x00, 0x00),
  Rgb(0xE6, 0x9F, 0x00),
  Rgb(0x56, 0xB4, 0xE9),
  Rgb(0x00, 0x9E, 0x73),
  Rgb(0xF0, 0xE4, 0x42),
  Rgb(0x00, 0x72, 0xB2),
  Rgb(0xD5, 0x5E, 0x00),
  Rgb(0xCC, 0x79, 0xA7),
];
