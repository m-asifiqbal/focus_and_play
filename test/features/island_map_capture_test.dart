import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_and_play_mindgame/core/theme/app_theme.dart';
import 'package:focus_and_play_mindgame/core/theme/mi_colors.dart';
import 'package:focus_and_play_mindgame/domain/game_id.dart';
import 'package:focus_and_play_mindgame/domain/save_data.dart';
import 'package:focus_and_play_mindgame/features/island/map/island_map_view.dart';

import '../helpers/screen_capture.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final g in GameId.values) {
    for (final night in [false, true]) {
      testWidgets('island map renders: ${g.name} ${night ? 'night' : 'day'}', (tester) async {
        usePhoneView(tester);
        final progress = GameProgress(levels: {
          for (var l = 1; l <= 33; l++) l: LevelRecord(stars: l % 3 + 1, bestSeconds: 60, noHint: true, solvedAt: 0),
        }, chestsOpened: {15, 30});
        await tester.pumpWidget(ProviderScope(
          child: MaterialApp(
            theme: AppTheme.build(night ? MiColors.night : MiColors.day),
            home: capturable(Scaffold(
              body: IslandMapView(game: g, progress: progress, onLevel: (_) {}, night: night, badge: 0),
            )),
          ),
        ));
        await tester.pump(const Duration(milliseconds: 500));
        await capture(tester, 'map_${g.name}_${night ? 'night' : 'day'}');
        expect(find.byType(LevelPad), findsWidgets);
      });
    }
  }
}
