// Local backup: status, "Back up now", automatic backups (daily / weekly),
// save to a file anywhere, restore from a file, and the backups kept on this phone.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/storage/save_store.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/mi_colors.dart';
import '../../core/widgets/mi_buttons.dart';
import '../../core/widgets/mi_controls.dart';
import '../../state/save_controller.dart';
import 'backup_actions.dart';
import '../../core/constants/plural.dart';

final backupsProvider = FutureProvider.autoDispose<List<BackupInfo>>((ref) => ref.read(saveStoreProvider).listBackups());

class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mi;
    final s = ref.watch(settingsProvider);
    final list = ref.watch(backupsProvider);
    final latest = list.value?.firstOrNull;
    String when(DateTime d) => DateFormat('d MMM, h:mm a').format(d);
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
          Row(children: [
            MiIconButton(icon: Icons.arrow_back_rounded, label: 'Back', onTap: () => context.pop()),
            const SizedBox(width: 10),
            Text('Local backup', style: MiText.title.copyWith(fontSize: 24, color: c.ink)),
          ]),
          const SizedBox(height: 14),
          MiCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Container(width: 52, height: 52, decoration: BoxDecoration(color: c.brandTint, borderRadius: BorderRadius.circular(16)), child: Icon(Icons.verified_user_rounded, color: c.brandInk, size: 30)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(latest == null ? 'No backup yet' : 'Your progress is safe', style: MiText.headline.copyWith(color: c.ink)),
                    Text(latest == null ? 'Make one now — it takes a second.' : 'Last backup ${when(latest.createdAt)} · ${(latest.bytes / 1024).ceil()} KB', style: MiText.small.copyWith(color: c.inkSoft)),
                  ]),
                ),
              ]),
              const SizedBox(height: 14),
              MiButton(
                label: 'Back up now',
                icon: Icons.backup_rounded,
                height: 52,
                onTap: () async {
                  await backupNow(context, ref);
                  ref.invalidate(backupsProvider);
                },
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(22)),
            child: Column(children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 60),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Back up automatically', style: MiText.label.copyWith(color: c.ink, fontSize: 16)),
                      Text('When the app opens · keeps the last 5', style: MiText.caption.copyWith(color: c.inkSoft)),
                    ]),
                  ),
                  MiSwitch(value: s.autoBackup, label: 'Back up automatically', onChanged: (v) => ref.read(saveProvider.notifier).updateSettings((x) => x.copyWith(autoBackup: v))),
                ]),
              ),
              if (s.autoBackup) ...[
                Divider(height: 1, color: c.line),
                SizedBox(
                  height: 58,
                  child: Row(children: [
                    Expanded(child: Text('How often', style: MiText.label.copyWith(color: c.ink, fontSize: 16))),
                    MiSegmented<bool>(
                      values: const [false, true],
                      labelOf: (w) => w ? 'Weekly' : 'Daily',
                      selected: s.backupWeekly,
                      height: 38,
                      onChanged: (w) => ref.read(saveProvider.notifier).updateSettings((x) => x.copyWith(backupWeekly: w)),
                    ),
                  ]),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 12),
          // Same height for both cards, whichever description wraps further.
          IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: _Action(icon: Icons.download_rounded, title: 'Save to a file', sub: 'A .mindisles file you can keep anywhere', onTap: () => exportBackup(context, ref))),
            const SizedBox(width: 10),
            Expanded(
              child: _Action(
                icon: Icons.upload_rounded,
                title: 'Restore a file',
                sub: "You'll see what changes before anything is replaced",
                onTap: () async {
                  await pickAndRestore(context, ref);
                  ref.invalidate(backupsProvider);
                },
              ),
            ),
          ])),
          const SectionLabel('On this phone'),
          list.when(
            loading: () => const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
            error: (_, _) => Text("Couldn't read the backups folder.", style: MiText.small.copyWith(color: c.inkSoft)),
            data: (items) => items.isEmpty
                ? Padding(padding: const EdgeInsets.all(12), child: Text('No backups on this phone yet.', style: MiText.small.copyWith(color: c.inkSoft)))
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(22)),
                    child: Column(children: [
                      for (final (i, b) in items.indexed) ...[
                        SizedBox(
                          height: 62,
                          child: Row(children: [
                            Expanded(
                              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(when(b.createdAt), style: MiText.label.copyWith(color: c.ink, fontWeight: FontWeight.w800)),
                                Text('${b.automatic ? 'Automatic' : 'Saved by you'} · ${plural(b.levels, 'level')} · ${plural(b.stars, 'star')}', style: MiText.caption.copyWith(color: c.inkSoft)),
                              ]),
                            ),
                            MiTextButton(
                              label: 'Restore',
                              onTap: () async {
                                try {
                                  final payload = SaveStore.decodeBackup(await b.file!.readAsBytes(), file: b.file);
                                  if (context.mounted) await restorePayload(context, ref, payload);
                                } catch (_) {
                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("That backup couldn't be read.")));
                                }
                              },
                            ),
                          ]),
                        ),
                        if (i < items.length - 1) Divider(height: 1, color: c.line),
                      ],
                    ]),
                  ),
          ),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.lock_rounded, size: 16, color: c.inkSoft),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'A backup holds your levels, stars, insights, badges and settings. It never leaves the phone unless you save it somewhere yourself.',
                style: MiText.caption.copyWith(color: c.inkSoft),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.title, required this.sub, required this.onTap});
  final IconData icon;
  final String title, sub;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.mi;
    return MiCard(
      onTap: onTap,
      semanticLabel: title,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: c.brandInk, size: 26),
        const SizedBox(height: 6),
        Text(title, style: MiText.headline.copyWith(fontSize: 17, color: c.ink)),
        const SizedBox(height: 2),
        Text(sub, style: MiText.caption.copyWith(color: c.inkSoft, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
