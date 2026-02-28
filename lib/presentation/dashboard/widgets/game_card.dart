import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/haptics.dart';
import '../../../domain/enums/game_type.dart';
import '../../../data/models/score_record.dart';

/// Data for a single game card on the dashboard
class GameCardData {
  final GameType type;
  final String nameAr;
  final String nameEn;
  final String nameZh;
  final IconData icon;
  final Color accentColor;
  final ScoreRecord? bestScore;

  const GameCardData({
    required this.type,
    required this.nameAr,
    required this.nameEn,
    required this.nameZh,
    required this.icon,
    required this.accentColor,
    this.bestScore,
  });
}

class GameCard extends StatelessWidget {
  final GameCardData data;
  final VoidCallback onTap;

  const GameCard({super.key, required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final gameName = _localizedName(context);
    final tagline = _tagline(l10n);

    return Semantics(
      button: true,
      label: l10n.gameCardSemantics(gameName, tagline),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Haptics.light();
            onTap();
          },
          borderRadius: BorderRadius.circular(22),
          splashColor: data.accentColor.withValues(alpha: 0.12),
          highlightColor: data.accentColor.withValues(alpha: 0.06),
          child: Ink(
            decoration: BoxDecoration(
              color: const Color(0xFF0E0E1C),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: data.accentColor.withValues(alpha: 0.22),
                width: 0.6,
              ),
              boxShadow: [
                BoxShadow(
                  color: data.accentColor.withValues(alpha: 0.14),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.34),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(21.5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 52,
                    child: _ArtBanner(
                      type: data.type,
                      accentColor: data.accentColor,
                    ),
                  ),
                  Container(
                    height: 0.5,
                    color: data.accentColor.withValues(alpha: 0.20),
                  ),
                  Expanded(
                    flex: 48,
                    child: _InfoSection(
                      data: data,
                      gameName: gameName,
                      tagline: tagline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _localizedName(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    return switch (code) {
      'ar' => data.nameAr,
      'zh' => data.nameZh,
      _ => data.nameEn,
    };
  }

  String _tagline(AppL10n l10n) => switch (data.type) {
        GameType.schulteGrid => l10n.taglineSchulte,
        GameType.reactionTime => l10n.taglineReaction,
        GameType.numberMemory => l10n.taglineNumberMemory,
        GameType.stroopTest => l10n.taglineStroop,
        GameType.visualMemory => l10n.taglineVisual,
        GameType.sequenceMemory => l10n.taglineSequence,
        GameType.numberMatrix => l10n.taglineMatrix,
        GameType.reverseMemory => l10n.taglineReverse,
        GameType.slidingPuzzle => l10n.taglineSliding,
        GameType.towerOfHanoi => l10n.taglineHanoi,
      };
}

class _ArtBanner extends StatelessWidget {
  final GameType type;
  final Color accentColor;

  const _ArtBanner({
    required this.type,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: _ArtBannerPainter(accentColor: accentColor),
        ),
        CustomPaint(
          painter: _CoverArtworkPainter(type: type, accentColor: accentColor),
        ),
      ],
    );
  }
}

class _InfoSection extends StatelessWidget {
  final GameCardData data;
  final String gameName;
  final String tagline;

  const _InfoSection({
    required this.data,
    required this.gameName,
    required this.tagline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0B0B17),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gameName,
                      style: AppTypography.labelLarge.copyWith(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tagline,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [
              data.bestScore != null
                  ? _ScoreBadge(
                      score: data.bestScore!.score,
                      metric: data.type.scoreMetric,
                      lowerIsBetter: data.type.lowerIsBetter,
                      color: data.accentColor,
                    )
                  : _NewBadge(color: data.accentColor),
            ],
          ),
        ],
      ),
    );
  }
}

class _NewBadge extends StatelessWidget {
  final Color color;

  const _NewBadge({required this.color});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.40)),
      ),
      child: Text(
        l10n.dashboardNewLabel,
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final double score;
  final String metric;
  final bool lowerIsBetter;
  final Color color;

  const _ScoreBadge({
    required this.score,
    required this.metric,
    required this.lowerIsBetter,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final String display = switch (metric) {
      'time' => '${(score / 1000).toStringAsFixed(1)}s',
      'ms' => '${score.round()}ms',
      'length' => '${score.toInt()}',
      'correct' => '${score.toInt()}',
      'moves' => '${score.toInt()}',
      _ => score.toStringAsFixed(0),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, color: color, size: 10),
          const SizedBox(width: 3),
          Text(
            display,
            style: AppTypography.labelMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtBannerPainter extends CustomPainter {
  final Color accentColor;

  const _ArtBannerPainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF161A2E), Color(0xFF101223), Color(0xFF0E0E1C)],
        stops: [0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final radialRect = Rect.fromCircle(
      center: Offset(size.width * 0.78, size.height * 0.22),
      radius: size.width * 0.75,
    );
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          accentColor.withValues(alpha: 0.16),
          accentColor.withValues(alpha: 0.07),
          accentColor.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.35, 1.0],
      ).createShader(radialRect);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), glowPaint);

    final fadeRect =
        Rect.fromLTWH(0, size.height * 0.5, size.width, size.height * 0.5);
    final fadePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          const Color(0xFF0B0B17).withValues(alpha: 0.55),
        ],
      ).createShader(fadeRect);
    canvas.drawRect(fadeRect, fadePaint);
  }

  @override
  bool shouldRepaint(covariant _ArtBannerPainter old) =>
      old.accentColor != accentColor;
}

class _CoverArtworkPainter extends CustomPainter {
  final GameType type;
  final Color accentColor;

  const _CoverArtworkPainter({
    required this.type,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (type) {
      case GameType.schulteGrid:
        _drawSchulte(canvas, size);
      case GameType.reactionTime:
        _drawReaction(canvas, size);
      case GameType.numberMemory:
        _drawNumberMemory(canvas, size);
      case GameType.stroopTest:
        _drawStroop(canvas, size);
      case GameType.visualMemory:
        _drawVisual(canvas, size);
      case GameType.sequenceMemory:
        _drawSequence(canvas, size);
      case GameType.numberMatrix:
        _drawMatrix(canvas, size);
      case GameType.reverseMemory:
        _drawReverse(canvas, size);
      case GameType.slidingPuzzle:
        _drawSliding(canvas, size);
      case GameType.towerOfHanoi:
        _drawHanoi(canvas, size);
    }
  }

  void _drawSchulte(Canvas canvas, Size size) {
    final p = Paint()
      ..color = accentColor.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const grid = 4;
    final w = size.width * 0.52;
    final h = size.height * 0.52;
    final left = size.width * 0.23;
    final top = size.height * 0.22;
    final cw = w / grid;
    final ch = h / grid;
    for (int i = 0; i <= grid; i++) {
      canvas.drawLine(
        Offset(left + i * cw, top),
        Offset(left + i * cw, top + h),
        p,
      );
      canvas.drawLine(
        Offset(left, top + i * ch),
        Offset(left + w, top + i * ch),
        p,
      );
    }
    final pathPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.65)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(left + cw * 0.5, top + ch * 3.4)
      ..lineTo(left + cw * 1.5, top + ch * 2.6)
      ..lineTo(left + cw * 2.5, top + ch * 1.8)
      ..lineTo(left + cw * 3.2, top + ch * 0.8);
    canvas.drawPath(path, pathPaint);
  }

  void _drawReaction(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.52);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (int i = 1; i <= 4; i++) {
      ring.color = accentColor.withValues(alpha: 0.12 + i * 0.05);
      canvas.drawCircle(center, 10 + i * 12, ring);
    }
    final pulse = Paint()
      ..color = accentColor.withValues(alpha: 0.70)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    final path = Path();
    final y = size.height * 0.26;
    path.moveTo(size.width * 0.18, y);
    path.lineTo(size.width * 0.34, y);
    path.lineTo(size.width * 0.40, y - 9);
    path.lineTo(size.width * 0.47, y + 8);
    path.lineTo(size.width * 0.56, y - 12);
    path.lineTo(size.width * 0.66, y);
    path.lineTo(size.width * 0.82, y);
    canvas.drawPath(path, pulse);
  }

  void _drawNumberMemory(Canvas canvas, Size size) {
    final bar = Paint()..color = accentColor.withValues(alpha: 0.22);
    final hi = Paint()..color = accentColor.withValues(alpha: 0.58);
    final baseY = size.height * 0.60;
    final startX = size.width * 0.20;
    const count = 7;
    final gap = size.width * 0.08;
    for (int i = 0; i < count; i++) {
      final h = (i % 2 == 0 ? 20.0 : 30.0) + (i == 3 ? 12 : 0);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(startX + i * gap, baseY - h, 10, h),
        const Radius.circular(3),
      );
      canvas.drawRRect(rect, i == 3 ? hi : bar);
    }
  }

  void _drawStroop(Canvas canvas, Size size) {
    final colors = [
      const Color(0xFFE53935),
      const Color(0xFF1E88E5),
      const Color(0xFF43A047),
      const Color(0xFFFDD835),
    ];
    final rects = [
      Rect.fromLTWH(size.width * 0.22, size.height * 0.32, 52, 14),
      Rect.fromLTWH(size.width * 0.44, size.height * 0.42, 58, 14),
      Rect.fromLTWH(size.width * 0.28, size.height * 0.56, 62, 14),
      Rect.fromLTWH(size.width * 0.54, size.height * 0.28, 50, 14),
    ];
    for (int i = 0; i < rects.length; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rects[i], const Radius.circular(8)),
        Paint()..color = colors[i].withValues(alpha: 0.74),
      );
    }
  }

  void _drawVisual(Canvas canvas, Size size) {
    const n = 4;
    final left = size.width * 0.24;
    final top = size.height * 0.24;
    final area = size.width * 0.52;
    final cw = area / n;
    final on = {1, 4, 6, 10, 13};
    for (int i = 0; i < n * n; i++) {
      final x = left + (i % n) * cw;
      final y = top + (i ~/ n) * cw;
      final lit = on.contains(i);
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(x + 2, y + 2, cw - 4, cw - 4),
        const Radius.circular(4),
      );
      canvas.drawRRect(
        r,
        Paint()
          ..color = lit
              ? accentColor.withValues(alpha: 0.55)
              : accentColor.withValues(alpha: 0.12),
      );
    }
  }

  void _drawSequence(Canvas canvas, Size size) {
    final nodes = [
      Offset(size.width * 0.26, size.height * 0.60),
      Offset(size.width * 0.38, size.height * 0.38),
      Offset(size.width * 0.55, size.height * 0.52),
      Offset(size.width * 0.70, size.height * 0.30),
      Offset(size.width * 0.78, size.height * 0.58),
    ];
    final line = Paint()
      ..color = accentColor.withValues(alpha: 0.55)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(nodes.first.dx, nodes.first.dy);
    for (int i = 1; i < nodes.length; i++) {
      path.lineTo(nodes[i].dx, nodes[i].dy);
    }
    canvas.drawPath(path, line);

    for (int i = 0; i < nodes.length; i++) {
      canvas.drawCircle(
        nodes[i],
        i == nodes.length - 1 ? 5.5 : 4.0,
        Paint()
          ..color = accentColor.withValues(
              alpha: i == nodes.length - 1 ? 0.85 : 0.45),
      );
    }
  }

  void _drawMatrix(Canvas canvas, Size size) {
    final p = Paint()..color = accentColor.withValues(alpha: 0.20);
    final hi = Paint()..color = accentColor.withValues(alpha: 0.60);
    final spots = [
      Offset(size.width * 0.25, size.height * 0.28),
      Offset(size.width * 0.45, size.height * 0.34),
      Offset(size.width * 0.63, size.height * 0.24),
      Offset(size.width * 0.35, size.height * 0.52),
      Offset(size.width * 0.58, size.height * 0.50),
      Offset(size.width * 0.74, size.height * 0.62),
      Offset(size.width * 0.30, size.height * 0.70),
    ];
    for (int i = 0; i < spots.length; i++) {
      canvas.drawCircle(spots[i], i == 0 ? 7 : 5, i == 0 ? hi : p);
    }
  }

  void _drawReverse(Canvas canvas, Size size) {
    final p = Paint()
      ..color = accentColor.withValues(alpha: 0.62)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final y = size.height * 0.52;
    for (int i = 0; i < 4; i++) {
      final x = size.width * (0.72 - i * 0.14);
      canvas.drawLine(Offset(x, y), Offset(x - 16, y - 12), p);
      canvas.drawLine(Offset(x, y), Offset(x - 16, y + 12), p);
    }
  }

  void _drawSliding(Canvas canvas, Size size) {
    final left = size.width * 0.28;
    final top = size.height * 0.28;
    const n = 3;
    final cell = size.width * 0.14;
    for (int i = 0; i < n * n; i++) {
      if (i == 8) continue;
      final x = left + (i % n) * cell;
      final y = top + (i ~/ n) * cell;
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, cell - 4, cell - 4),
        const Radius.circular(5),
      );
      canvas.drawRRect(
        r,
        Paint()..color = accentColor.withValues(alpha: 0.16 + (i % 3) * 0.10),
      );
    }
  }

  void _drawHanoi(Canvas canvas, Size size) {
    final baseY = size.height * 0.70;
    final pegPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.40)
      ..strokeWidth = 2;
    final pegX = [size.width * 0.30, size.width * 0.50, size.width * 0.70];
    for (final x in pegX) {
      canvas.drawLine(
          Offset(x, baseY), Offset(x, size.height * 0.32), pegPaint);
    }

    final disks = [42.0, 32.0, 22.0];
    for (int i = 0; i < disks.length; i++) {
      final w = disks[i];
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          pegX[0] - w / 2,
          baseY - 12 - i * 10,
          w,
          8,
        ),
        const Radius.circular(5),
      );
      canvas.drawRRect(
        rect,
        Paint()..color = accentColor.withValues(alpha: 0.28 + i * 0.18),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CoverArtworkPainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.accentColor != accentColor;
  }
}
