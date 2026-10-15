import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../update/update_service.dart';
import '../theme.dart';

/// Shown at the top of the Windows app when a newer version is ready.
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final u = context.watch<UpdateService?>();
    final r = u?.available;
    if (u == null || r == null || !u.supported) return const SizedBox();
    final busy =
        u.state == UpdateState.downloading || u.state == UpdateState.installing;
    if (u.dismissed && !busy) return const SizedBox();
    final ak = AkColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primary.withValues(alpha: .08),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.system_update_alt, color: scheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(switch (u.state) {
                      UpdateState.downloading =>
                        'Downloading version ${r.version}… '
                            '${(u.progress * 100).round()}%',
                      UpdateState.installing =>
                        'Installing version ${r.version}. AK System will '
                            'open again in a moment.',
                      _ => 'Version ${r.version} of AK System is ready.',
                    }, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              if (!busy)
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () => showWhatsNew(context, r),
                        child: const Text('What\'s new'),
                      ),
                      TextButton(
                        onPressed: u.later,
                        child: const Text('Later'),
                      ),
                      if (u.blocked)
                        TextButton(
                          onPressed: () => openDownloadPage(u),
                          child: const Text('Download page'),
                        ),
                      FilledButton(
                        onPressed: u.install,
                        child: Text(u.blocked ? 'Try again' : 'Update now'),
                      ),
                    ],
                  ),
                ),
              if (u.state == UpdateState.downloading) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(value: u.progress),
              ],
              if (u.problem != null && !busy) ...[
                const SizedBox(height: 4),
                Text(u.problem!, style: TextStyle(color: ak.bad, fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The release notes of a new version.
Future<void> showWhatsNew(BuildContext context, Release r) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('What\'s new in version ${r.version}'),
    content: SingleChildScrollView(
      child: Text(
        r.notes.isEmpty ? 'Improvements and fixes.' : r.notes,
        style: const TextStyle(height: 1.4),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  ),
);

/// The releases page in the browser, to install a version by hand.
Future<void> openDownloadPage(UpdateService u) =>
    launchUrl(u.releasesPage, mode: LaunchMode.externalApplication);
