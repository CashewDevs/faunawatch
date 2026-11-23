import 'package:faunawatch/features/app_update/services/app_update_installer.dart';
import 'package:faunawatch/features/app_update/viewmodels/app_update_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

/// Opens the "Update available" box for the newer release found by the last
/// check. It follows the update through download, permission and install.
Future<void> showUpdateAvailableDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const UpdateAvailableDialog(),
  );
}

class UpdateAvailableDialog extends ConsumerStatefulWidget {
  const UpdateAvailableDialog({super.key});

  @override
  ConsumerState<UpdateAvailableDialog> createState() =>
      _UpdateAvailableDialogState();
}

class _UpdateAvailableDialogState extends ConsumerState<UpdateAvailableDialog> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Coming back from Android settings: check the permission again, so the
    // installer opens without another tap.
    _lifecycle = AppLifecycleListener(
      onResume: () => ref
          .read(appUpdateViewModelProvider.notifier)
          .recheckInstallPermission(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _openReleasePage(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    final opened = await ref
        .read(appUpdateViewModelProvider.notifier)
        .openReleasePage();
    navigator.pop();
    if (!opened) {
      messenger?.showSnackBar(
        const SnackBar(content: Text("Couldn't open the download page.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appUpdateViewModelProvider);
    final viewModel = ref.read(appUpdateViewModelProvider.notifier);
    final release = state.latest;
    if (release == null) return const SizedBox.shrink();

    final bodyStyle = GoogleFonts.dmSans(fontSize: 14, height: 1.4);
    final later = TextButton(
      onPressed: () => Navigator.of(context).pop(),
      child: const Text('Later'),
    );

    final (
      String title,
      Widget content,
      List<Widget> actions,
    ) = switch (state.installStatus) {
      UpdateInstallStatus.idle => (
        'Update available',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Version ${release.version.label} is ready.'
              '${state.installed == null ? '' : ' You have ${state.installed!.label}.'}',
              style: bodyStyle,
            ),
            if (release.notes != null) ...[
              const SizedBox(height: 12),
              Text(
                "What's new",
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(release.notes!, style: bodyStyle),
            ],
          ],
        ),
        [
          later,
          if (state.canUpdateInApp)
            FilledButton(
              onPressed: viewModel.startUpdate,
              child: const Text('Update'),
            )
          else
            FilledButton(
              onPressed: () => _openReleasePage(context, ref),
              child: const Text('Open download page'),
            ),
        ],
      ),
      UpdateInstallStatus.downloading => (
        'Downloading update',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              state.downloadProgress == null
                  ? 'Downloading version ${release.version.label}…'
                  : 'Downloading version ${release.version.label}… '
                        '${(state.downloadProgress! * 100).floor()}%',
              style: bodyStyle,
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: state.downloadProgress,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
        ),
        [
          TextButton(
            onPressed: viewModel.cancelDownload,
            child: const Text('Cancel'),
          ),
        ],
      ),
      UpdateInstallStatus.needsPermission => (
        'One more step',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Android needs your OK for FaunaWatch to install updates.\n\n'
              'Tap Open settings and turn on "Allow from this source". When '
              'you come back, the update installs.',
              style: bodyStyle,
            ),
            if (state.permissionStillMissing) ...[
              const SizedBox(height: 12),
              Text(
                "FaunaWatch still isn't allowed to install apps. Tap Open "
                'settings and turn on "Allow from this source".',
                style: bodyStyle.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
        [
          later,
          FilledButton(
            onPressed: viewModel.openInstallSettings,
            child: const Text('Open settings'),
          ),
        ],
      ),
      UpdateInstallStatus.installing => (
        'Finish in the installer',
        Text(
          "Tap Update on Android's screen to finish. FaunaWatch will "
          'close and update.\n\nIf you closed that screen, tap Install to '
          'open it again.',
          style: bodyStyle,
        ),
        [
          later,
          FilledButton(
            onPressed: viewModel.installDownloaded,
            child: const Text('Install'),
          ),
        ],
      ),
      UpdateInstallStatus.failed => (
        "Couldn't update",
        Text(switch (state.installFailure) {
          AppUpdateInstallFailure.installFailed =>
            "Android's installer couldn't open. Try again.",
          _ =>
            'The download stopped. Check your internet connection and '
                'try again.',
        }, style: bodyStyle),
        [
          later,
          FilledButton(
            onPressed: viewModel.startUpdate,
            child: const Text('Try again'),
          ),
        ],
      ),
    };

    return PopScope(
      // Cancel the download first, so it never runs out of sight.
      canPop: !state.isDownloading,
      child: AlertDialog(
        title: Text(
          title,
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w800),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: SingleChildScrollView(child: content),
        ),
        actions: actions,
      ),
    );
  }
}
