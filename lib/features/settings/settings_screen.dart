// Settings & profile: name and badge, Day / Night / System, board options,
// relaxed mode, sound and vibration, reminders, local backup, ad privacy,
// reset progress, and about.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/ads/ad_service.dart';
import '../../core/constants/app_info.dart';
import '../../core/notifications/reminder_service.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/mi_colors.dart';
import '../../core/widgets/mi_art.dart';
import '../../core/widgets/mi_buttons.dart';
import '../../core/widgets/mi_controls.dart';
import '../../core/widgets/mi_dialog.dart';
import '../../core/widgets/pinned_page.dart';
import '../../domain/game_id.dart';
import '../../domain/save_data.dart';
import '../../state/save_controller.dart';
import '../play/how_to_play_sheet.dart';

final _privacyRequiredProvider = FutureProvider<bool>(
  (ref) => ref.read(adServiceProvider).privacyOptionsRequired(),
);
final _versionProvider = FutureProvider<String>((ref) async {
  try {
    final i = await PackageInfo.fromPlatform();
    return '${i.version} (${i.buildNumber})';
  } catch (_) {
    return '';
  }
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _syncReminders(WidgetRef ref) => ref
      .read(reminderServiceProvider)
      .sync(ref.read(saveProvider), ref.read(clockProvider)());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mi;
    final save = ref.watch(saveProvider);
    final s = save.settings;
    final ctl = ref.read(saveProvider.notifier);
    void set(AppSettings Function(AppSettings) f) => ctl.updateSettings(f);
    final privacy = ref.watch(_privacyRequiredProvider).value ?? false;
    final version = ref.watch(_versionProvider).value ?? '';
    final reminderAt = TimeOfDay(
      hour: s.reminderMinutes ~/ 60,
      minute: s.reminderMinutes % 60,
    );

    return SafeArea(
      bottom: false,
      child: PinnedPage(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        header: Text(
          'Settings',
          style: MiText.display.copyWith(fontSize: 28, color: c.ink),
        ),
        children: [
          MiCard(
            child: Column(
              children: [
                Row(
                  children: [
                    BadgeAvatar(badge: save.profile.badge, size: 56),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            save.profile.name.isEmpty
                                ? 'Puzzler'
                                : save.profile.name,
                            style: MiText.title.copyWith(color: c.ink),
                          ),
                          Text(
                            'Puzzler level ${save.playerLevel} · ${save.xp} XP',
                            style: MiText.small.copyWith(color: c.inkSoft),
                          ),
                        ],
                      ),
                    ),
                    MiIconButton(
                      icon: Icons.edit_rounded,
                      label: 'Edit name and badge',
                      background: c.page,
                      onTap: () => _editProfile(context, ref),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: save.xpIntoLevel / 200,
                    minHeight: 8,
                    color: c.brand,
                    backgroundColor: c.brandTint,
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${200 - save.xpIntoLevel} XP to level ${save.playerLevel + 1}',
                    style: MiText.caption.copyWith(color: c.inkSoft),
                  ),
                ),
              ],
            ),
          ),
          const SectionLabel('Appearance'),
          _Group(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Theme',
                      style: MiText.label.copyWith(
                        color: c.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    MiSegmented<ThemeChoice>(
                      values: ThemeChoice.values,
                      expand: true,
                      height: 44,
                      selected: s.theme,
                      labelOf: (t) => switch (t) {
                        ThemeChoice.day => 'Day',
                        ThemeChoice.night => 'Night',
                        ThemeChoice.system => 'System',
                      },
                      iconOf: (t) => switch (t) {
                        ThemeChoice.day => Icons.wb_sunny_rounded,
                        ThemeChoice.night => Icons.nightlight_round,
                        ThemeChoice.system => Icons.phone_iphone_rounded,
                      },
                      onChanged: (t) => set((x) => x.copyWith(theme: t)),
                    ),
                    const SizedBox(height: 8),
                    Text(switch (s.theme) {
                      ThemeChoice.day => 'Always light, with sea-blue grounds.',
                      ThemeChoice.night =>
                        'Always dark — easier on the eyes at night.',
                      ThemeChoice.system => 'Follows your phone.',
                    }, style: MiText.caption.copyWith(color: c.inkSoft)),
                  ],
                ),
              ),
              _Toggle(
                title: 'Colour-blind patterns',
                sub: 'Adds patterns and marks to colour-coded pieces',
                value: s.colourBlind,
                onChanged: (v) => set((x) => x.copyWith(colourBlind: v)),
              ),
              _Toggle(
                title: 'Large numbers on boards',
                value: s.largeNumbers,
                onChanged: (v) => set((x) => x.copyWith(largeNumbers: v)),
              ),
            ],
          ),
          const SectionLabel('Gameplay'),
          _Group(
            children: [
              _Toggle(
                title: 'Relaxed mode',
                sub: 'No clock, no lives — one star per level',
                value: s.relaxed,
                onChanged: (v) => set((x) => x.copyWith(relaxed: v)),
              ),
              _Toggle(
                title: 'Show the clock',
                sub: 'Hide it if it stresses you; it still runs',
                value: s.showClock,
                onChanged: (v) => set((x) => x.copyWith(showClock: v)),
              ),
              _Toggle(
                title: 'Mark mistakes',
                sub:
                    'Underline clashes in Sudoku Six, flag wrong Quilt patches',
                value: s.markMistakes,
                onChanged: (v) => set((x) => x.copyWith(markMistakes: v)),
              ),
              _Toggle(
                title: 'Ask before using a hint',
                value: s.confirmHint,
                onChanged: (v) => set((x) => x.copyWith(confirmHint: v)),
              ),
            ],
          ),
          const SectionLabel('Sound and feel'),
          _Group(
            children: [
              _Toggle(
                title: 'Sound effects',
                value: s.sound,
                onChanged: (v) => set((x) => x.copyWith(sound: v)),
              ),
              _Toggle(
                title: 'Vibration',
                value: s.haptics,
                onChanged: (v) => set((x) => x.copyWith(haptics: v)),
              ),
              _Toggle(
                title: 'Reduce motion',
                sub: 'Also on when your phone asks for it',
                value: s.reduceMotion,
                onChanged: (v) => set((x) => x.copyWith(reduceMotion: v)),
              ),
            ],
          ),
          const SectionLabel('Reminders'),
          _Group(
            children: [
              _Toggle(
                title: 'Daily puzzle',
                sub: 'Every day at ${reminderAt.format(context)}',
                value: s.dailyReminder,
                onChanged: (v) async {
                  set((x) => x.copyWith(dailyReminder: v));
                  if (v) {
                    await ref.read(reminderServiceProvider).requestPermission();
                  }
                  await _syncReminders(ref);
                },
              ),
              if (s.dailyReminder)
                _Row(
                  title: 'Reminder time',
                  value: reminderAt.format(context),
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: reminderAt,
                    );
                    if (t == null) return;
                    set(
                      (x) =>
                          x.copyWith(reminderMinutes: t.hour * 60 + t.minute),
                    );
                    await _syncReminders(ref);
                  },
                ),
              _Toggle(
                title: 'Lives are full again',
                value: s.livesAlert,
                onChanged: (v) async {
                  set((x) => x.copyWith(livesAlert: v));
                  if (v) {
                    await ref.read(reminderServiceProvider).requestPermission();
                  }
                  await _syncReminders(ref);
                },
              ),
            ],
          ),
          const SectionLabel('Data and privacy'),
          _Group(
            children: [
              _Row(
                title: 'Local backup',
                sub: s.autoBackup
                    ? 'Automatic ${s.backupWeekly ? 'weekly' : 'daily'}'
                    : 'Automatic backups off',
                onTap: () => context.push(Routes.backup),
              ),
              if (privacy)
                _Row(
                  title: 'Ad privacy choices',
                  onTap: () => ref.read(adServiceProvider).showPrivacyOptions(),
                ),
              _Row(
                title: 'Reset all progress…',
                danger: true,
                onTap: () => _confirmReset(context, ref),
              ),
            ],
          ),
          const SectionLabel('About'),
          _Group(
            children: [
              _Row(
                title: 'How to play each game',
                onTap: () => _pickHowTo(context),
              ),
              _Row(
                title: 'Licences',
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: AppInfo.name,
                  applicationVersion: version,
                ),
              ),
              _Row(title: 'Version', value: version.isEmpty ? '—' : version),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickHowTo(BuildContext context) async {
    final g = await showMiSheet<GameId>(
      context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('How to play', style: MiText.title.copyWith(color: ctx.mi.ink)),
          const SizedBox(height: 10),
          for (final g in GameId.values)
            ListTile(
              title: Text(
                g.title,
                style: MiText.headline.copyWith(color: ctx.mi.ink),
              ),
              subtitle: Text(
                g.island,
                style: MiText.caption.copyWith(color: ctx.mi.inkSoft),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.pop(ctx, g),
            ),
        ],
      ),
    );
    if (g != null && context.mounted) await showHowToPlay(context, g);
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final ok = await showMiConfirm(
      context,
      icon: Icons.restart_alt_rounded,
      tone: MiDialogTone.danger,
      title: 'Reset all progress?',
      message: 'Levels, stars, insights and achievements on this phone are cleared. Your name and settings stay. A backup is saved first, just in case.',
      confirmLabel: 'Reset',
      cancelLabel: 'Keep my progress',
      confirmIsPrimary: false,
    );
    if (!ok) return;
    await ref
        .read(saveStoreProvider)
        .writeLocalBackup(ref.read(saveProvider), ref.read(clockProvider)());
    await ref.read(saveProvider.notifier).resetProgress();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Progress reset. A backup was saved first.'),
        ),
      );
    }
  }

  Future<void> _editProfile(BuildContext context, WidgetRef ref) async {
    final save = ref.read(saveProvider);
    final name = TextEditingController(text: save.profile.name);
    var badge = save.profile.badge;
    await showMiSheet<void>(
      context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final c = ctx.mi;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Your profile', style: MiText.title.copyWith(color: c.ink)),
              const SizedBox(height: 12),
              TextField(
                controller: name,
                maxLength: 20,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Name',
                  counterText: '',
                  filled: true,
                  fillColor: c.page,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (var i = 0; i < PlayerBadge.all.length; i++)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: i == badge,
                        label: '${PlayerBadge.all[i].name} badge',
                        onTap: () => setState(() => badge = i),
                        excludeSemantics: true,
                        child: GestureDetector(
                          excludeFromSemantics: true,
                          onTap: () => setState(() => badge = i),
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: FittedBox(
                                child: BadgeAvatar(
                                  badge: i,
                                  size: 48,
                                  ring: i == badge,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              MiButton(
                label: 'Save',
                onTap: () {
                  ref
                      .read(saveProvider.notifier)
                      .updateProfile(name: name.text, badge: badge);
                  Navigator.pop(ctx);
                },
              ),
            ],
          );
        },
      ),
    );
    name.dispose();
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final c = context.mi;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) Divider(height: 1, color: c.line),
          ],
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.title,
    required this.value,
    required this.onChanged,
    this.sub,
  });
  final String title;
  final String? sub;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    final c = context.mi;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 58),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: MiText.label.copyWith(color: c.ink, fontSize: 16),
                  ),
                  if (sub != null)
                    Text(
                      sub!,
                      style: MiText.caption.copyWith(
                        color: c.inkSoft,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ),
          MiSwitch(value: value, onChanged: onChanged, label: title),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    this.sub,
    this.value,
    this.onTap,
    this.danger = false,
  });
  final String title;
  final String? sub, value;
  final VoidCallback? onTap;
  final bool danger;
  @override
  Widget build(BuildContext context) {
    final c = context.mi;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: MiText.label.copyWith(
                        color: danger ? c.danger : c.ink,
                        fontSize: 16,
                        fontWeight: danger ? FontWeight.w800 : FontWeight.w700,
                      ),
                    ),
                    if (sub != null)
                      Text(
                        sub!,
                        style: MiText.caption.copyWith(
                          color: c.inkSoft,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (value != null)
              Text(value!, style: MiText.label.copyWith(color: c.inkSoft)),
            if (onTap != null && !danger)
              Icon(Icons.chevron_right_rounded, color: c.inkSoft),
          ],
        ),
      ),
    );
  }
}
