// The recent-files menu (docs/03-architecture.md §9.5).
//
// ==================================================================
// THE THREE STATES ARE THE FEATURE
// ==================================================================
// §9.5 requires lazy pruning: "a temporarily unmounted network drive must
// not evict the entry". The app layer enforces that as a rule about
// errno; this widget is the half the user can see, and the reason it has
// three states rather than two:
//
//   * `ok`          — the probe answered and the file is there.
//   * `checking`    — the probe has NOT answered, or timed out. Dimmed,
//                     AND STILL CLICKABLE. A slow network share is not a
//                     broken entry, and greying out the click would turn
//                     a 600 ms wait into a permanently unreachable file.
//   * `unreachable` — the probe answered and the file is not there.
//                     Dimmed, still clickable, with a subtitle that says
//                     so. NOT removed: only a definitive failure on an
//                     actual open attempt removes an entry.
//
// The measurement behind all of it: `exists` on a dead UNC path took
// 1261 ms on the development machine and returned false without throwing.
// Ten of those at startup is 12.6 seconds against a 1.2 s cold-start
// budget — so nothing on the startup path probes, this menu renders
// immediately from the stored list, and the probe runs when the menu is
// OPENED.
//
// PRESENTATIONAL ONLY. It takes a list of view models and a callback. It
// does not know what a path is beyond a string to display.
import 'package:flutter/material.dart';

/// What a bounded reachability probe learned about one entry, as far as
/// the menu is concerned.
enum RecentEntryStatus {
  /// The file is there.
  ok,

  /// No answer yet. Dimmed, still clickable.
  checking,

  /// Answered, and the file is not there. Dimmed, still clickable.
  unreachable,
}

/// One row of the recents menu.
@immutable
final class RecentEntryView {
  const RecentEntryView({
    required this.id,
    required this.displayName,
    required this.subtitle,
    required this.status,
  });

  /// Passed back to `onOpen`. The entry's path, but this widget treats it
  /// as an opaque token.
  final String id;

  /// `ProjectInfo.projectName` when the document had one, else the file
  /// stem. Stored by the app so the menu needs no disk access to render.
  final String displayName;

  /// The path, or wherever it came from, shown small underneath.
  final String subtitle;

  final RecentEntryStatus status;

  @override
  bool operator ==(Object other) =>
      other is RecentEntryView &&
      other.id == id &&
      other.displayName == displayName &&
      other.subtitle == subtitle &&
      other.status == status;

  @override
  int get hashCode => Object.hash(id, displayName, subtitle, status);

  @override
  String toString() => 'RecentEntryView($displayName, $status)';
}

/// The menu items for the recent-files submenu.
///
/// Returns a LIST rather than a widget so the caller can drop it straight
/// into a `SubmenuButton`'s `menuChildren`, which is what makes the
/// keyboard traversal of the File menu work without this widget knowing
/// anything about menus.
List<Widget> buildRecentFilesMenuItems({
  required List<RecentEntryView> entries,
  required void Function(String id) onOpen,
}) {
  if (entries.isEmpty) {
    // NOT an empty submenu. An empty menu that opens onto nothing is the
    // "never silently do nothing" failure in miniature: the user clicks,
    // something appears, and it says nothing at all.
    // `onPressed` is left at its null default: the row is DISABLED, which
    // is the honest rendering of "there is nothing here to open".
    return const [MenuItemButton(child: Text('No recent files'))];
  }
  return [
    for (final entry in entries)
      MenuItemButton(
        // EVERY state is pressable, including `unreachable`. See header.
        onPressed: () => onOpen(entry.id),
        child: _RecentEntryRow(entry: entry),
      ),
  ];
}

final class _RecentEntryRow extends StatelessWidget {
  const _RecentEntryRow({required this.entry});

  final RecentEntryView entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dimmed = entry.status != RecentEntryStatus.ok;
    final base = theme.textTheme.bodyMedium ?? const TextStyle();
    final subtitle = switch (entry.status) {
      RecentEntryStatus.ok => entry.subtitle,
      RecentEntryStatus.checking => '${entry.subtitle} · checking…',
      RecentEntryStatus.unreachable => '${entry.subtitle} · not available',
    };
    return SizedBox(
      width: 420,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            entry.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: base.copyWith(
              color: dimmed ? base.color?.withValues(alpha: 0.6) : base.color,
            ),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (theme.textTheme.bodySmall ?? const TextStyle()).copyWith(
              fontStyle: entry.status == RecentEntryStatus.unreachable
                  ? FontStyle.italic
                  : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }
}
