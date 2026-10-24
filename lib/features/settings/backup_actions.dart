// Save a backup to a file the player chooses, and restore one — shared by the
// Backup screen and onboarding ("I have a backup file").

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_info.dart';
import '../../core/storage/save_store.dart';
import '../../core/widgets/mi_dialog.dart';
import '../../state/save_controller.dart';
import '../../core/constants/plural.dart';

void _snack(BuildContext context, String text) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// Asks before replacing progress, showing what's inside the backup.
Future<bool> confirmRestore(BuildContext context, BackupInfo info) async {
  final when = DateFormat('d MMM y, h:mm a').format(info.createdAt);
  return showMiConfirm(
    context,
    icon: Icons.settings_backup_restore_rounded,
    title: 'Restore this backup?',
    message:
        'Saved $when · ${plural(info.levels, 'level')} · ${plural(info.stars, 'star')}.\n\nThis replaces the progress, stars and settings on this phone.',
    confirmLabel: 'Restore',
    cancelLabel: 'Cancel',
  );
}

/// Lets the player pick a .mindisles file and restores it after confirming.
/// Returns true when something was restored.
Future<bool> pickAndRestore(BuildContext context, WidgetRef ref) async {
  final PlatformFile? file;
  try {
    file = await FilePicker.pickFile(
      dialogTitle: 'Choose a ${AppInfo.name} backup',
    );
  } catch (_) {
    if (context.mounted) _snack(context, "Couldn't open the file picker.");
    return false;
  }
  if (file == null || !context.mounted) return false;
  final BackupPayload payload;
  try {
    payload = SaveStore.decodeBackup(await file.readAsBytes());
  } on FormatException catch (e) {
    if (context.mounted) _snack(context, e.message);
    return false;
  } catch (_) {
    if (context.mounted) _snack(context, "That file couldn't be read.");
    return false;
  }
  if (!context.mounted) return false;
  return restorePayload(context, ref, payload);
}

/// Restores an already-decoded backup after confirming.
Future<bool> restorePayload(
  BuildContext context,
  WidgetRef ref,
  BackupPayload payload,
) async {
  if (!await confirmRestore(context, payload.info)) return false;
  await ref.read(saveProvider.notifier).replaceAll(payload.data);
  if (context.mounted) _snack(context, 'Progress restored');
  return true;
}

/// Writes a backup file wherever the player chooses (Files, Drive, Downloads…).
Future<void> exportBackup(BuildContext context, WidgetRef ref) async {
  final now = ref.read(clockProvider)();
  final bytes = SaveStore.encodeBackup(ref.read(saveProvider), now);
  final name =
      'mind-isles-${DateFormat('yyyyMMdd-HHmm').format(now)}.${AppInfo.backupExtension}';
  try {
    final uri = await FilePicker.saveFile(
      fileName: name,
      bytes: bytes,
      mimeType: 'application/json',
      dialogTitle: 'Save your backup',
    );
    if (uri != null && context.mounted) _snack(context, 'Backup saved');
  } catch (_) {
    if (context.mounted) _snack(context, "Couldn't save the backup file.");
  }
}

/// Saves a copy in the app's own backups folder ("Back up now").
Future<void> backupNow(BuildContext context, WidgetRef ref) async {
  await ref.read(saveProvider.notifier).flush();
  await ref
      .read(saveStoreProvider)
      .writeLocalBackup(ref.read(saveProvider), ref.read(clockProvider)());
  if (context.mounted) _snack(context, 'Backed up on this phone');
}
