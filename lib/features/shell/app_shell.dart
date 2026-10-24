// The three-tab shell (Home, Insights, Settings) and Android back handling:
// another tab → Home; Home → "Leave Mind Isles?".

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_info.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/mi_colors.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  Future<void> _back(BuildContext context) async {
    if (shell.currentIndex != 0) {
      shell.goBranch(0);
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Leave ${AppInfo.name}?', style: MiText.title),
        content: Text('Your progress is saved.', style: MiText.body.copyWith(color: ctx.mi.inkSoft)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave')),
        ],
      ),
    );
    if (leave == true) await SystemNavigator.pop();
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
          decoration: BoxDecoration(color: c.card, border: Border(top: BorderSide(color: c.line))),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Row(children: [
                for (final (i, icon, label) in const [(0, Icons.home_rounded, 'Home'), (1, Icons.bar_chart_rounded, 'Insights'), (2, Icons.settings_rounded, 'Settings')])
                  Expanded(child: _Tab(icon: icon, label: label, selected: shell.currentIndex == i, onTap: () => shell.goBranch(i, initialLocation: i == shell.currentIndex))),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.icon, required this.label, required this.selected, required this.onTap});
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
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 220),
          height: 54,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(color: selected ? c.brandTint : Colors.transparent, borderRadius: BorderRadius.circular(18)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            AnimatedScale(scale: selected ? 1.12 : 1, duration: const Duration(milliseconds: 220), curve: Curves.easeOutBack, child: Icon(icon, color: fg, size: 24)),
            const SizedBox(height: 2),
            Text(label, style: MiText.caption.copyWith(color: fg, fontWeight: selected ? FontWeight.w800 : FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}
