// CR-005: BTU/hr from watts is *derived*, computed only for display, and
// never persisted — the file format only ever stores PowerProfile's
// typicalWatts / btuPerHourOverride as integers.

/// Watts-to-BTU/hr conversion factor. The one double constant in the
/// units layer: it is never itself stored, only ever used at the moment
/// of display.
const double kBtuPerWattHour = 3.412142;

/// Converts a wattage into BTU/hr for display. This is the one
/// conversion site — nothing else should hardcode [kBtuPerWattHour].
double wattsToBtuPerHour(num watts) => watts * kBtuPerWattHour;
