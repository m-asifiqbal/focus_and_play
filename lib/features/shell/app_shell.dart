// The three-tab shell (Home, Insights, Settings) and Android back handling:
// another tab → Home; Home → "Leaving already?".

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/mi_colors.dart';
import '../../core/widgets/mi_dialog.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  Future<void> _back(BuildContext context) async {
    if (shell.currentIndex != 0) {
      shell.goBranch(0);
      return;
    }
    final leave = await showMiConfirm(
      context,
      pip: true,
      title: 'Leaving already?',
      message: 'Your progress is saved. Pip will keep your islands warm!',
      confirmLabel: 'Leave',
      cancelLabel: 'Stay and play',
      confirmIsPrimary: false,
    );
    if (leave) await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mi;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back(context);
      },
      child: Scaffold(
        body: shell,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: c.card,
            border: Border(top: BorderSide(color: c.line)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: _NavBar(
                index: shell.currentIndex,
                onTap: (i) =>
                    shell.goBranch(i, initialLocation: i == shell.currentIndex),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The three tabs with one highlight pill that slides from the old tab to the new
/// one (instead of fading out here and in there), while the icons pop.
class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  static const _tabs = [
    (Icons.home_rounded, 'Home'),
    (Icons.bar_chart_rounded, 'Insights'),
    (Icons.settings_rounded, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.mi;
    final instant = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      height: 54,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth / _tabs.length;
          return Stack(
            children: [
              AnimatedPositionedDirectional(
                duration: instant
                    ? Duration.zero
                    : const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                start: index * w + 4,
                width: w - 8,
                top: 0,
                height: 54,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.brandTint,
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final (i, (icon, label)) in _tabs.indexed)
                    Expanded(
                      child: _Tab(
                        icon: icon,
                        label: label,
                        selected: index == i,
                        onTap: () => onTap(i),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mi;
    final fg = selected ? c.brandInk : c.inkSoft;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        excludeFromSemantics: true,
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 54,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: selected ? 1.08 : 1,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: Icon(icon, color: fg, size: 24),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: MiText.caption.copyWith(
                  color: fg,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
