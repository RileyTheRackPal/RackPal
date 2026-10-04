// packages/rackpal_ui/lib/src/network/open_web_page.dart
// NET-A/4b (`#995`), DR-048 §11.47.7, DR-229: "Open web page", behind a
// confirmation that shows the URL.
//
// ═════════════════════════════════════════════════════════════════════
// THE CONFIRMATION IS NOT OPTIONAL
// ═════════════════════════════════════════════════════════════════════
// §11.47.7: it shows the target before anything opens, so the gesture is
// never a silent navigation to an address somebody typed. There is no
// "don't ask again". DR-229 §11.228.2 makes the URL editable, prefilled
// `http://<address>/`, because the trade's gear splits across HTTP and
// HTTPS and some of it listens on another port; the edit is for this
// launch and is never written back to the device.
//
// ONE BUTTON, TWO HOSTS (§11.228.1). The inspector's NETWORK section and
// the Devices view's last column both mount [OpenWebPageButton], so the
// two cannot build different URLs or skip the dialog differently. It reads
// the launcher from [WebPageScope] and offers nothing when there is no
// launcher or no address: a disabled button cannot say why.
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/network/web_page_scope.dart';

/// The gesture's name, on the button, its tooltip and the dialog's title.
const String kOpenWebPageLabel = 'Open web page';

/// The dialog's one sentence of explanation.
const String kOpenWebPageExplain =
    'This opens the address below in your web browser. Change it first if '
    'the device uses https or another port.';

/// What the dialog says under a URL it will not open.
const String kOpenWebPageOnlyHttp =
    'Only http:// and https:// addresses open from here.';

/// What is said when the system would not open the browser.
const String kOpenWebPageRefused =
    'The browser could not be opened for that address.';

/// The dialog's confirming button.
const String kOpenWebPageConfirm = 'Open';

/// The dialog's URL field.
const Key kWebPageUrlFieldKey = ValueKey('web-page-url');

/// The address [row]'s web page is at: its IP, or its hostname when it
/// has none (DR-229 §11.228.2), or null when it has neither.
String? webPageAddressFor(NetworkRow row) {
  for (final value in [row.ip, row.hostname]) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
  }
  return null;
}

/// The URL the dialog opens on for [address]: `http://<address>/`.
///
/// AN IPv6 ADDRESS IS BRACKETED, as a URL requires, and told from an IPv4
/// address with a port (`10.0.10.2:8080`, which somebody will type into
/// the IP column) by having more than one colon.
String webPageUrlFor(String address) {
  final ipv6 = ':'.allMatches(address).length > 1 && !address.startsWith('[');
  return ipv6 ? 'http://[$address]/' : 'http://$address/';
}

/// Shows the confirmation for [initialUrl]; the URL to open, or null when
/// the user cancelled.
Future<Uri?> showOpenWebPageDialog(
  BuildContext context, {
  required String initialUrl,
}) => showDialog<Uri>(
  context: context,
  builder: (_) => _OpenWebPageDialog(initialUrl: initialUrl),
);

class _OpenWebPageDialog extends StatefulWidget {
  const _OpenWebPageDialog({required this.initialUrl});

  final String initialUrl;

  @override
  State<_OpenWebPageDialog> createState() => _OpenWebPageDialogState();
}

class _OpenWebPageDialogState extends State<_OpenWebPageDialog> {
  late final TextEditingController _url = TextEditingController(
    text: widget.initialUrl,
  );

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Uri? get _parsed {
    final uri = Uri.tryParse(_url.text.trim());
    return uri != null && isOpenableWebUrl(uri) ? uri : null;
  }

  void _open() {
    final uri = _parsed;
    if (uri != null) Navigator.of(context).pop(uri);
  }

  @override
  Widget build(BuildContext context) {
    final valid = _parsed != null;
    return AlertDialog(
      title: const Text(kOpenWebPageLabel),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(kOpenWebPageExplain),
            const SizedBox(height: 12),
            TextField(
              key: kWebPageUrlFieldKey,
              controller: _url,
              autofocus: true,
              decoration: InputDecoration(
                isDense: true,
                errorText: valid ? null : kOpenWebPageOnlyHttp,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _open(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: valid ? _open : null,
          child: const Text(kOpenWebPageConfirm),
        ),
      ],
    );
  }
}

/// The confirmation, then the launch, for [row]. Says so when the system
/// would not open the browser; says nothing when the user cancelled.
Future<void> openWebPage(BuildContext context, NetworkRow row) async {
  final launcher = WebPageScope.maybeOf(context);
  final address = webPageAddressFor(row);
  if (launcher == null || address == null) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final uri = await showOpenWebPageDialog(
    context,
    initialUrl: webPageUrlFor(address),
  );
  if (uri == null) return;
  if (!await launcher(uri)) {
    messenger?.showSnackBar(const SnackBar(content: Text(kOpenWebPageRefused)));
  }
}

/// "Open web page" for [row]: an icon in the Devices view, a labelled
/// button in the inspector. Nothing at all without a launcher above it or
/// an address to open.
class OpenWebPageButton extends StatelessWidget {
  const OpenWebPageButton({required this.row, this.compact = false, super.key});

  final NetworkRow row;

  /// True for the Devices view's narrow column: an icon with a tooltip.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (WebPageScope.maybeOf(context) == null) return const SizedBox.shrink();
    if (webPageAddressFor(row) == null) return const SizedBox.shrink();
    final key = ValueKey('web-page-${row.deviceId.v}');
    return compact
        ? IconButton(
            key: key,
            tooltip: kOpenWebPageLabel,
            iconSize: 16,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.open_in_new),
            onPressed: () => openWebPage(context, row),
          )
        : TextButton.icon(
            key: key,
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text(kOpenWebPageLabel),
            onPressed: () => openWebPage(context, row),
          );
  }
}
