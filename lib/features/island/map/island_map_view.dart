// The scrolling island: painted world + level pads + the player's pin.
//
// Starts scrolled to the current level. Static slices are cached; only the
// ambient layer (waves, glow, snow, clouds) animates, and only on screen.

import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/mi_art.dart';
import '../../../domain/game_id.dart';
import '../../../domain/save_data.dart';
import '../../../domain/tier.dart';
import 'island_layout.dart';
import 'island_painter.dart';
import 'island_palette.dart';

class IslandMapView extends StatefulWidget {
  const IslandMapView({
    super.key,
    required this.game,
    required this.progress,
    required this.onLevel,
    required this.night,
    required this.badge,
    this.topInset = 140,
    this.bottomInset = 150,
  });

  final GameId game;
  final GameProgress progress;
  final ValueChanged<int> onLevel;
  final bool night;
  final int badge;
  final double topInset;
  final double bottomInset;

  @override
  State<IslandMapView> createState() => _IslandMapViewState();
}

class _IslandMapViewState extends State<IslandMapView> with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  late final AnimationController _time = AnimationController(vsync: this, duration: const Duration(seconds: 20));
  MapGeometry? _geo;
  double? _geoWidth;
  bool _jumped = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _time.stop();
    } else if (!_time.isAnimating) {
      _time.repeat();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _time.dispose();
    super.dispose();
  }

  MapGeometry _geometry(double width) {
    if (_geo == null || _geoWidth != width) {
      _geo = MapGeometry(IslandLayout.build(widget.game, width));
      _geoWidth = width;
      _jumped = false;
    }
    return _geo!;
  }

  void _jumpToCurrent(IslandLayout l, double viewport) {
    if (_jumped) return;
    _jumped = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final y = l.yOf(widget.progress.current);
      final target = (y - widget.topInset - (viewport - widget.topInset - widget.bottomInset) * .55).clamp(0.0, _scroll.position.maxScrollExtent);
      _scroll.jumpTo(target);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final geo = _geometry(box.maxWidth);
      final l = geo.layout;
      final pal = IslandPalette.of(widget.game);
      final current = widget.progress.current;
      _jumpToCurrent(l, box.maxHeight);
      const tileH = 900.0;
      final tiles = (l.height / tileH).ceil();
      return SingleChildScrollView(
        controller: _scroll,
        physics: const ClampingScrollPhysics(),
        child: SizedBox(
          height: l.height,
          child: Stack(clipBehavior: Clip.none, children: [
            for (var i = 0; i < tiles; i++)
              Positioned(
                left: 0,
                right: 0,
                top: i * tileH,
                height: min(tileH + 2, l.height - i * tileH),
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: MapTilePainter(geo: geo, palette: pal, top: i * tileH, height: min(tileH + 2, l.height - i * tileH), night: widget.night, current: current),
                  ),
                ),
              ),
            AnimatedBuilder(
              animation: _scroll,
              builder: (context, _) {
                final top = _scroll.hasClients ? _scroll.offset : 0.0;
                return Positioned(
                  left: 0,
                  right: 0,
                  top: top,
                  height: box.maxHeight,
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(painter: AmbientPainter(layout: l, palette: pal, top: top, time: _time, night: widget.night, frost: widget.game == GameId.sudoku)),
                    ),
                  ),
                );
              },
            ),
            for (var z = 0; z < 4; z++) _zoneSign(context, l, pal, z),
            for (var level = 1; level <= l.nodes.length; level++) _pad(l, pal, level, current),
            _pin(l, current),
          ]),
        ),
      );
    });
  }

  Widget _zoneSign(BuildContext context, IslandLayout l, IslandPalette pal, int z) {
    final tier = Tier.values[z];
    final first = l.nodeOf(tier.firstLevel);
    final y = z == 0 ? first.dy + 70 : (l.zoneBounds[z - 1] - 16);
    final onLeft = first.dx > l.width / 2;
    return Positioned(
      top: y - 18,
      left: onLeft ? l.leftEdge(y) + 10 : null,
      right: onLeft ? null : (l.width - l.rightEdge(y)) + 10,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 5, 12, 6),
        decoration: BoxDecoration(color: const Color(0xFF13213C), borderRadius: BorderRadius.circular(10), boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 3))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('${tier.label.toUpperCase()} · LEVELS ${tier.firstLevel}–${tier.lastLevel}', style: MiText.overline.copyWith(fontSize: 10.5, color: const Color(0xFFFFC233))),
          Text(pal.zones[z].name, style: MiText.headline.copyWith(fontSize: 14, color: Colors.white)),
        ]),
      ),
    );
  }

  Widget _pad(IslandLayout l, IslandPalette pal, int level, int current) {
    final rec = widget.progress.levels[level];
    final at = l.nodeOf(level);
    final playable = widget.progress.isPlayable(level);
    final isCurrent = level == current && rec == null;
    final size = isCurrent ? 84.0 : (Levels.isGate(level) ? 62.0 : (rec != null ? 58.0 : 54.0));
    return Positioned(
      left: at.dx - size / 2,
      top: at.dy - size / 2,
      width: size,
      height: size + (rec != null ? 0 : 0),
      child: LevelPad(
        level: level,
        record: rec,
        current: isCurrent,
        locked: !playable,
        gate: Levels.isGate(level),
        color: pal.accent,
        ledge: pal.accentLedge,
        night: widget.night,
        size: size,
        onTap: playable ? () => widget.onLevel(level) : null,
      ),
    );
  }

  Widget _pin(IslandLayout l, int current) {
    final at = l.nodeOf(current);
    return Positioned(
      left: at.dx - 22,
      top: at.dy - 94,
      child: IgnorePointer(child: _BouncingPin(badge: widget.badge, night: widget.night)),
    );
  }
}

/// One level pad: finished (island colour + stars), current (pulsing), locked, or a tier chest.
class LevelPad extends StatefulWidget {
  const LevelPad({
    super.key,
    required this.level,
    required this.record,
    required this.current,
    required this.locked,
    required this.gate,
    required this.color,
    required this.ledge,
    required this.night,
    required this.size,
    required this.onTap,
  });
  final int level;
  final LevelRecord? record;
  final bool current, locked, gate, night;
  final Color color, ledge;
  final double size;
  final VoidCallback? onTap;

  @override
  State<LevelPad> createState() => _LevelPadState();
}

class _LevelPadState extends State<LevelPad> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  bool _down = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.current && !MediaQuery.disableAnimationsOf(context)) {
      _pulse.repeat();
    } else {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rec = widget.record;
    final w = widget;
    final (Color top, Color ledge, Widget content, String label) = switch ((w.gate, rec != null, w.current, w.locked)) {
      (true, true, _, _) => (const Color(0xFFFFE29A), const Color(0xFFB7791F), const Icon(Icons.inventory_2_rounded, color: Color(0xFF7B4A12), size: 30), 'Level ${w.level}, tier chest, opened, ${rec!.stars} stars'),
      (_, true, _, _) => (w.color, w.ledge, _num(w.level, w.color.computeLuminance() > .4 ? const Color(0xFF0D1626) : Colors.white, 23), 'Level ${w.level}, ${rec!.stars} stars, replay'),
      (_, false, true, _) => (w.night ? const Color(0xFF16223A) : Colors.white, w.night ? const Color(0xFF0A1220) : w.ledge, _num(w.level, w.night ? w.color : Color.lerp(w.color, const Color(0xFF13213C), .45)!, 32), 'Level ${w.level}, play'),
      (true, false, false, _) => (w.night ? const Color(0xFF3A3014) : const Color(0xFFFFF1CC), w.night ? const Color(0xFF0A1220) : const Color(0xFFD9B66A), Icon(w.locked ? Icons.lock_rounded : Icons.inventory_2_rounded, color: const Color(0xFFB7791F), size: 26), 'Level ${w.level}, tier chest${w.locked ? ', locked' : ''}'),
      _ => (w.night ? const Color(0xFF2A3A57) : const Color(0xFFECEFF3), w.night ? const Color(0xFF0A1220) : const Color(0xFF9AA4B1), Icon(Icons.lock_rounded, color: w.night ? const Color(0xFFA9B9D1) : const Color(0xFF5A6A85), size: 22), 'Level ${w.level}, locked'),
    };
    final radius = w.gate ? 18.0 : w.size / 2;
    final pad = AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = _pulse.value;
        return Container(
          decoration: BoxDecoration(
            color: top,
            borderRadius: BorderRadius.circular(radius),
            border: w.current ? Border.all(color: w.color, width: 6) : null,
            boxShadow: [
              if (w.current) BoxShadow(color: w.color.withValues(alpha: .55 * (1 - t)), spreadRadius: 18 * t),
              if (!_down) BoxShadow(color: ledge, offset: const Offset(0, 6)),
              const BoxShadow(color: Color(0x33000000), offset: Offset(0, 10), blurRadius: 12),
            ],
          ),
          child: child,
        );
      },
      child: Center(child: content),
    );
    return Semantics(
      button: w.onTap != null,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: w.onTap == null ? null : (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: w.onTap,
        child: Stack(clipBehavior: Clip.none, children: [
          AnimatedSlide(offset: Offset(0, _down ? 6 / w.size : 0), duration: const Duration(milliseconds: 70), child: SizedBox(width: w.size, height: w.size, child: pad)),
          if (rec != null && !w.gate)
            Positioned(
              left: w.size / 2 - 27,
              top: -26,
              child: ExcludeSemantics(
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  for (var i = 0; i < 3; i++)
                    Padding(padding: EdgeInsets.only(bottom: i == 1 ? 6 : 0, right: 1), child: StarShape(filled: i < rec.stars, size: 17)),
                ]),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _num(int n, Color c, double size) => Text('$n', style: MiText.title.copyWith(fontSize: size, color: c, fontWeight: FontWeight.w700));
}

class _BouncingPin extends StatefulWidget {
  const _BouncingPin({required this.badge, required this.night});
  final int badge;
  final bool night;
  @override
  State<_BouncingPin> createState() => _BouncingPinState();
}

class _BouncingPinState extends State<_BouncingPin> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MediaQuery.disableAnimationsOf(context) ? _c.stop() : _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = PlayerBadge.of(widget.badge);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.translate(offset: Offset(0, -7 * Curves.easeInOut.transform(_c.value)), child: child),
      child: SizedBox(
        width: 44,
        height: 56,
        child: CustomPaint(
          painter: _PinPainter(widget.night ? const Color(0xFFEAF1FB) : const Color(0xFF13213C)),
          child: Align(
            alignment: const Alignment(0, -.42),
            child: Container(width: 26, height: 26, decoration: BoxDecoration(color: b.color, shape: BoxShape.circle), child: Icon(b.icon, size: 16, color: b.onColor)),
          ),
        ),
      ),
    );
  }
}

class _PinPainter extends CustomPainter {
  _PinPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size s) {
    final p = Path()
      ..moveTo(s.width / 2, s.height - 2)
      ..cubicTo(s.width / 2, s.height - 2, 4, s.height * .6, 4, s.height * .38)
      ..arcToPoint(Offset(s.width - 4, s.height * .38), radius: Radius.circular(s.width / 2 - 4))
      ..cubicTo(s.width - 4, s.height * .6, s.width / 2, s.height - 2, s.width / 2, s.height - 2)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
    canvas.drawPath(p, Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(_PinPainter old) => old.color != color;
}
