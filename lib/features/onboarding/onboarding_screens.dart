// First launch: Welcome → Try a puzzle → Pick your island → Make it yours.
// No account: everything is stored on the phone. Ends on level 1 of the chosen
// island, where three quick tips explain lives, the clock and hints.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ads/ad_service.dart';
import '../../core/notifications/reminder_service.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/island_style.dart';
import '../../core/theme/mi_colors.dart';
import '../../core/widgets/mi_art.dart';
import '../../core/widgets/mi_buttons.dart';
import '../../core/widgets/mi_controls.dart';
import '../../core/widgets/pinned_page.dart';
import '../../core/widgets/pressable.dart';
import '../../domain/game_id.dart';
import '../../state/save_controller.dart';
import '../home/widgets/mini_island.dart';
import '../settings/backup_actions.dart';
import 'widgets/game_preview.dart';
import 'widgets/welcome_scene.dart';

/// Choices made during onboarding, committed on the last step.
class OnboardingDraft {
  const OnboardingDraft({
    this.game = GameId.thread,
    this.name = '',
    this.badge = 0,
    this.playedBefore = false,
    this.reminder = true,
  });
  final GameId game;
  final String name;
  final int badge;
  final bool playedBefore;
  final bool reminder;
  OnboardingDraft copyWith({
    GameId? game,
    String? name,
    int? badge,
    bool? playedBefore,
    bool? reminder,
  }) => OnboardingDraft(
    game: game ?? this.game,
    name: name ?? this.name,
    badge: badge ?? this.badge,
    playedBefore: playedBefore ?? this.playedBefore,
    reminder: reminder ?? this.reminder,
  );
}

class OnboardingDraftNotifier extends Notifier<OnboardingDraft> {
  @override
  OnboardingDraft build() => const OnboardingDraft();
  void update(OnboardingDraft Function(OnboardingDraft d) f) =>
      state = f(state);
}

final onboardingDraftProvider =
    NotifierProvider<OnboardingDraftNotifier, OnboardingDraft>(
      OnboardingDraftNotifier.new,
    );

/// Step dots (1..4) shared by the onboarding screens.
class StepDots extends StatelessWidget {
  const StepDots(this.step, {super.key});
  final int step;
  @override
  Widget build(BuildContext context) {
    final c = context.mi;
    return Semantics(
      label: 'Step $step of 4',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 4; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: i == step ? 28 : 8,
              height: 8,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: i == step
                    ? c.brand
                    : (i < step ? c.brand.withValues(alpha: .45) : c.line),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.step, this.onSkip});
  final int step;
  final VoidCallback? onSkip;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: Row(
      children: [
        StepDots(step),
        const Spacer(),
        if (onSkip != null) MiTextButton(label: 'Skip', onTap: onSkip),
      ],
    ),
  );
}

// ---------------------------------------------------------------- Welcome

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mi;
    return Scaffold(
      backgroundColor: const Color(0xFFFFEFD6),
      body: Column(
        children: [
          const Expanded(child: WelcomeScene()),
          Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                ),
                padding: EdgeInsets.fromLTRB(
                  24,
                  22,
                  24,
                  16 + MediaQuery.paddingOf(context).bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const StepDots(1),
                    const SizedBox(height: 14),
                    Text(
                      'Welcome aboard, puzzler!',
                      style: MiText.display.copyWith(color: c.ink),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "I'm Pip. Four islands of brain teasers are waiting — from easy beaches to expert peaks. No account, no internet needed.",
                      style: MiText.body.copyWith(
                        color: c.inkSoft,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 18),
                    MiButton(
                      label: 'Set sail',
                      trailingIcon: Icons.arrow_forward_rounded,
                      onTap: () => context.push(Routes.tryPuzzle),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: MiTextButton(
                        label: 'I have a backup file — restore it',
                        icon: Icons.upload_file_rounded,
                        onTap: () async {
                          if (await pickAndRestore(context, ref) &&
                              context.mounted) {
                            ref.read(adServiceProvider).start();
                            context.go(Routes.home);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              )
              .animate()
              .slideY(begin: .25, duration: 450.ms, curve: Curves.easeOutBack)
              .fadeIn(duration: 300.ms),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Pick island

class PickIslandScreen extends ConsumerWidget {
  const PickIslandScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mi;
    final draft = ref.watch(onboardingDraftProvider);
    final sel = draft.game;
    final st = context.island(sel);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopBar(step: 3, onSkip: () => context.push(Routes.profile)),
              const SizedBox(height: 8),
              Text(
                'Where should we land first?',
                style: MiText.display.copyWith(color: c.ink),
              ),
              const SizedBox(height: 4),
              Text(
                'Each island has its own puzzle. You can sail to any of them later.',
                style: MiText.body.copyWith(color: c.inkSoft),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    return GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio:
                          (box.maxWidth / 2 - 6) /
                          ((box.maxHeight - 12) / 2).clamp(150, 220),
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        for (final g in GameId.values)
                          _IslandTile(
                            game: g,
                            selected: g == sel,
                            onTap: () => ref
                                .read(onboardingDraftProvider.notifier)
                                .update((d) => d.copyWith(game: g)),
                          ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              MiCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    GamePreview(game: sel, size: 72),
                    const SizedBox(width: 14),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Column(
                          key: ValueKey(sel),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sel.title,
                              style: MiText.headline.copyWith(color: c.ink),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              sel.rule,
                              style: MiText.small.copyWith(
                                color: c.inkSoft,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              MiButton(
                label: 'Start on ${sel.island}',
                color: st.color,
                ledge: st.ledge,
                onColor: st.onColor,
                onTap: () => context.push(Routes.profile),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IslandTile extends StatelessWidget {
  const _IslandTile({
    required this.game,
    required this.selected,
    required this.onTap,
  });
  final GameId game;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mi;
    final st = context.island(game);
    return AnimatedSlide(
      offset: Offset(0, selected ? -.02 : 0),
      duration: const Duration(milliseconds: 200),
      child: MiPressable(
        onTap: onTap,
        selected: selected,
        semanticLabel:
            '${game.title} on ${game.island}${selected ? ', selected' : ''}',
        color: c.card,
        ledge: selected ? st.color : c.ledge,
        ledgeHeight: selected ? 6 : 3,
        radius: 22,
        border: Border.all(
          color: selected ? st.color : Colors.transparent,
          width: 3,
        ),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: MiniIsland(
                      game: game,
                      night: c.isNight,
                      height: double.infinity,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        game.title,
                        style: MiText.headline.copyWith(
                          fontSize: 17,
                          color: c.ink,
                        ),
                      ),
                      Text(
                        game.island,
                        style: MiText.caption.copyWith(color: c.inkSoft),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (selected)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: st.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: Icon(Icons.check_rounded, size: 16, color: st.onColor),
                ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Profile

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});
  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  late final _name = TextEditingController(
    text: ref.read(onboardingDraftProvider).name,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final d = ref.read(onboardingDraftProvider);
    ref
        .read(saveProvider.notifier)
        .completeOnboarding(
          name: _name.text,
          badge: d.badge,
          firstGame: d.game,
          playedBefore: d.playedBefore,
          reminder: d.reminder,
        );
    if (d.reminder) await ref.read(reminderServiceProvider).requestPermission();
    ref.read(adServiceProvider).start();
    ref
        .read(reminderServiceProvider)
        .sync(ref.read(saveProvider), ref.read(clockProvider)());
    if (!mounted) return;
    final router = GoRouter.of(context);
    final level = ref.read(saveProvider).progress(d.game).current;
    router.go(Routes.home);
    router.push(Routes.island(d.game));
    router.push(Routes.play(d.game, level));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mi;
    final d = ref.watch(onboardingDraftProvider);
    final notifier = ref.read(onboardingDraftProvider.notifier);
    return Scaffold(
      body: SafeArea(
        child: PinnedPage(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          headerPadding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
          header: _TopBar(step: 4, onSkip: _finish),
          children: [
            Text('Make it yours', style: MiText.display.copyWith(color: c.ink)),
            const SizedBox(height: 16),
            Text(
              'What should we call you?',
              style: MiText.bodyStrong.copyWith(color: c.ink),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              maxLength: 20,
              onChanged: (v) => notifier.update((x) => x.copyWith(name: v)),
              style: MiText.bodyStrong.copyWith(fontSize: 18, color: c.ink),
              decoration: InputDecoration(
                hintText: 'Your name',
                counterText: '',
                filled: true,
                fillColor: c.card,
                helperText: 'Only shown on this phone.',
                helperStyle: MiText.caption.copyWith(color: c.inkSoft),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: c.line, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: c.line, width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: c.brand, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Pick a badge',
              style: MiText.bodyStrong.copyWith(color: c.ink),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < PlayerBadge.all.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Semantics(
                        button: true,
                        selected: d.badge == i,
                        label: '${PlayerBadge.all[i].name} badge',
                        onTap: () =>
                            notifier.update((x) => x.copyWith(badge: i)),
                        excludeSemantics: true,
                        child: GestureDetector(
                          excludeFromSemantics: true,
                          onTap: () =>
                              notifier.update((x) => x.copyWith(badge: i)),
                          child: AnimatedScale(
                            scale: d.badge == i ? 1.08 : 1,
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutBack,
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: FittedBox(
                                child: BadgeAvatar(
                                  badge: i,
                                  size: 52,
                                  ring: d.badge == i,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Where should we start?',
              style: MiText.bodyStrong.copyWith(color: c.ink),
            ),
            const SizedBox(height: 8),
            _Choice(
              title: "I'm new to puzzles",
              sub: 'Start on the beach with Easy levels',
              selected: !d.playedBefore,
              onTap: () =>
                  notifier.update((x) => x.copyWith(playedBefore: false)),
            ),
            const SizedBox(height: 8),
            _Choice(
              title: "I've played before",
              sub: 'Open Medium levels on every island too',
              selected: d.playedBefore,
              onTap: () =>
                  notifier.update((x) => x.copyWith(playedBefore: true)),
            ),
            const SizedBox(height: 14),
            MiCard(
              padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
              child: Row(
                children: [
                  Icon(Icons.notifications_rounded, color: c.ink),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily puzzle reminder',
                          style: MiText.label.copyWith(
                            color: c.ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Every day at 8:00 PM',
                          style: MiText.caption.copyWith(color: c.inkSoft),
                        ),
                      ],
                    ),
                  ),
                  MiSwitch(
                    value: d.reminder,
                    label: 'Daily puzzle reminder',
                    onChanged: (v) =>
                        notifier.update((x) => x.copyWith(reminder: v)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_rounded, size: 15, color: c.inkSoft),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'No account needed. Everything stays on this phone.',
                    style: MiText.caption.copyWith(color: c.inkSoft),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            MiButton(
              label: 'Start playing',
              icon: Icons.play_arrow_rounded,
              onTap: _finish,
            ),
          ],
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.title,
    required this.sub,
    required this.selected,
    required this.onTap,
  });
  final String title, sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mi;
    return MiPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: '$title. $sub',
      color: selected ? c.brandTint : c.card,
      radius: 18,
      border: Border.all(color: selected ? c.brand : c.line, width: 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? c.brand : c.inkSoft,
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: selected
                ? Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: c.brand,
                      shape: BoxShape.circle,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: MiText.headline.copyWith(fontSize: 17, color: c.ink),
                ),
                Text(
                  sub,
                  style: MiText.small.copyWith(
                    color: c.inkSoft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
