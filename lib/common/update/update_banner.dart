/// The bar that appears when a newer desktop version has been published.
///
/// Deliberately not a dialogue. An update is not urgent and interrupting
/// someone at launch to tell them so is out of proportion; a strip above the
/// content says the same thing and can be ignored or dismissed.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/l10n.dart';
import 'update_check.dart';
import 'update_service.dart';

class UpdateBanner extends StatefulWidget {
  const UpdateBanner({super.key, required this.currentVersion});

  /// The running version, as `MAJOR.MINOR.PATCH`.
  final String currentVersion;

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  UpdateManifest? _manifest;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final manifest =
        await UpdateService.check(currentVersion: widget.currentVersion);
    if (!mounted) return;
    setState(() => _manifest = manifest);
  }

  Future<void> _dismiss() async {
    final manifest = _manifest;
    if (manifest == null) return;
    setState(() => _manifest = null);
    await UpdateService.dismiss(manifest.version);
  }

  @override
  Widget build(BuildContext context) {
    final manifest = _manifest;
    // Absent rather than empty: on every launch where there is no update —
    // which is nearly all of them — this must cost no vertical space at all.
    if (manifest == null) return const SizedBox.shrink();

    return Material(
      color: const Color.fromARGB(250, 224, 190, 78),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.system_update_alt,
                color: Colors.black87, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                manifest.notes == null
                    ? S
                        .of(context)!
                        .updateAvailable(manifest.version.toString())
                    : '${S.of(context)!.updateAvailable(manifest.version.toString())} — ${manifest.notes}',
                style: const TextStyle(color: Colors.black87, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: () => launchUrl(
                Uri.parse(manifest.downloadUrl),
                mode: LaunchMode.externalApplication,
              ),
              child: Text(
                S.of(context)!.updateDownload,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              tooltip: S.of(context)!.updateDismiss,
              onPressed: _dismiss,
              icon: const Icon(Icons.close, color: Colors.black87, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
