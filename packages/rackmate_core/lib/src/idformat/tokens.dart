// Canonical designator/label token vocabulary (CR-045).
//
// design-data-model.md §3.9, design-ux-device-builder.md §6.8,
// design-ux-schematic.md §1.5 and design-pdf-export.md §3.2 each defined
// their own token set; CR-045 rules that the pdf-export grammar (formal,
// with optional segments and filters) is the one engine, fed by the merge
// of all four vocabularies with collisions resolved to the longer,
// unambiguous name. This is that merged set.

/// Every token name `IdFormat` (see `id_format.dart`) recognises inside a
/// `{TOKEN}` reference. Referencing anything outside this set is a
/// validation failure, never a silent no-op (CR-045).
const Set<String> kIdFormatTokens = {
  'SITE',
  'BUILDING',
  'FLOOR',
  'SPACE',
  'TR',
  'ROOM',
  'ROOM_ABBR',
  'AREA',
  'ZONE',
  'RACK',
  'PANEL',
  'PORT',
  'OUTLET',
  'PATHWAY',
  'SERVICE',
  'MEDIA',
  'DOMAIN',
  'TYPE_PREFIX',
  'SEP',
  'SEQ',
  'DEV_SEQ',
  'PORT_SEQ',
  'DEV_BLOCK',
  'SRC_REFDES',
  'SRC_PORT',
  'DST_REFDES',
  'DST_PORT',
  'DEVICE',
  'DIR',
  'RUN',
  'N',
};
