import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/tr.dart';
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

// ─── Game Card ────────────────────────────────────────────────────────────────

class GameCard extends StatelessWidget {
  final GameCardData data;
  final VoidCallback onTap;

  const GameCard({super.key, required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tr(
        context,
        '${data.nameAr}، ${_tagline(context)}',
        '${data.nameEn}, ${_tagline(context)}',
        '${data.nameZh}，${_tagline(context)}',
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Haptics.light();
            onTap();
          },
          borderRadius: BorderRadius.circular(20),
          splashColor: data.accentColor.withValues(alpha: 0.12),
          highlightColor: data.accentColor.withValues(alpha: 0.06),
          child: Ink(
            decoration: BoxDecoration(
              color: const Color(0xFF0E0E1C),
              borderRadius: BorderRadius.circular(20),
              border: BorderDirectional(
                top: BorderSide(
                    color: data.accentColor.withValues(alpha: 0.30),
                    width: 0.5),
                bottom: const BorderSide(color: AppColors.border, width: 0.5),
                start: BorderSide(color: data.accentColor, width: 2.5),
                end: const BorderSide(color: AppColors.border, width: 0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: data.accentColor.withValues(alpha: 0.18),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.34),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(19.5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Art banner (top) ───────────────────────────────────
                  Expanded(
                    flex: 52,
                    child: _ArtBanner(
                      icon: data.icon,
                      accentColor: data.accentColor,
                      category: _category(context),
                    ),
                  ),
                  // ── Separator ────────────────────────────────────────────
                  Container(
                    height: 0.5,
                    color: data.accentColor.withValues(alpha: 0.20),
                  ),
                  // ── Info section (bottom) ───────────────────────────────
                  Expanded(
                    flex: 48,
                    child: _InfoSection(
                      data: data,
                      tagline: _tagline(context),
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

  String _category(BuildContext context) => switch (data.type) {
        GameType.schulteGrid => tr(context, 'بصر سريع', 'VISUAL SCAN', '视觉扫描'),
        GameType.reactionTime => tr(context, 'ردود فعل', 'REFLEX', '反应力'),
        GameType.numberMemory => tr(context, 'ذاكرة أرقام', 'MEMORY', '数字记忆'),
        GameType.stroopTest => tr(context, 'تركيز', 'FOCUS', '专注力'),
        GameType.visualMemory =>
          tr(context, 'ذاكرة بصرية', 'VISUAL MEM', '视觉记忆'),
        GameType.sequenceMemory => tr(context, 'تسلسل', 'SEQUENCE', '序列'),
        GameType.numberMatrix => tr(context, 'إدراك', 'COGNITION', '认知力'),
        GameType.reverseMemory => tr(context, 'عكس', 'REVERSE', '逆向'),
        GameType.slidingPuzzle => tr(context, 'فضاء', 'SPATIAL', '空间'),
        GameType.towerOfHanoi => tr(context, 'استراتيجية', 'STRATEGY', '策略'),
      };

  String _tagline(BuildContext context) => switch (data.type) {
        GameType.schulteGrid => tr(context, 'سرعة الإدراك والتركيز',
            'Perception & Focus Speed', '专注与感知速度'),
        GameType.reactionTime => tr(
            context, 'اختبر زمن الاستجابة', 'Train Instant Reaction', '训练瞬时反应'),
        GameType.numberMemory =>
          tr(context, 'احتفظ بسلاسل أطول', 'Retain Longer Digits', '记住更长数字'),
        GameType.stroopTest => tr(context, 'قاوم التداخل البصري',
            'Resist Visual Interference', '抗干扰训练'),
        GameType.visualMemory =>
          tr(context, 'تتبع الأنماط بسرعة', 'Track Patterns Quickly', '快速记忆图形'),
        GameType.sequenceMemory => tr(context, 'استدعاء التسلسل بدقة',
            'Recall Sequence Precisely', '精准序列记忆'),
        GameType.numberMatrix => tr(context, 'ذاكرة مواقع الأرقام',
            'Remember Number Positions', '数字位置记忆'),
        GameType.reverseMemory =>
          tr(context, 'عكس السلسلة ذهنيًا', 'Reverse the Sequence', '倒序工作记忆'),
        GameType.slidingPuzzle => tr(context, 'تفكير مكاني وخطوات أقل',
            'Spatial Planning Challenge', '空间规划挑战'),
        GameType.towerOfHanoi => tr(context, 'تخطيط متعدد الخطوات',
            'Multi-step Strategic Logic', '多步策略推理'),
      };
}

// ─── Art Banner ───────────────────────────────────────────────────────────────

class _ArtBanner extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final String category;

  const _ArtBanner({
    required this.icon,
    required this.accentColor,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Painted gradient bg + circuit texture
        CustomPaint(
          painter: _ArtBannerPainter(accentColor: accentColor),
        ),

        // Outer halo glow ring
        Center(
          child: Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  accentColor.withValues(alpha: 0.30),
                  accentColor.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),

        // Icon circle with metallic gradient + glow border
        Center(
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E1E2E), Color(0xFF0C0C18)],
              ),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.65),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.45),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.18),
                  blurRadius: 6,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(
              icon,
              color: accentColor,
              size: 26,
            ),
          ),
        ),

        // Category chip top-left
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
            decoration: BoxDecoration(
              color: const Color(0xCC0E1020),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.42),
                width: 0.6,
              ),
            ),
            child: Text(
              category,
              style: AppTypography.caption.copyWith(
                color: accentColor,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.55,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const Positioned(
          left: 10,
          right: 10,
          bottom: 8,
          child: _EqualizerLine(),
        ),
      ],
    );
  }
}

// ─── Info Section ─────────────────────────────────────────────────────────────

class _InfoSection extends StatelessWidget {
  final GameCardData data;
  final String tagline;

  const _InfoSection({required this.data, required this.tagline});

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
                      tr(context, data.nameAr, data.nameEn, data.nameZh),
                      style: AppTypography.labelLarge.copyWith(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.start,
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
                      textAlign: TextAlign.start,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: data.accentColor.withValues(alpha: 0.14),
                  border: Border.all(
                      color: data.accentColor.withValues(alpha: 0.35)),
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: data.accentColor,
                  size: 15,
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              data.bestScore != null
                  ? _ScoreBadge(
                      score: data.bestScore!.score,
                      metric: data.type.scoreMetric,
                      lowerIsBetter: data.type.lowerIsBetter,
                      color: data.accentColor,
                    )
                  : _NewBadge(color: data.accentColor),
              Text(
                tr(context, 'انقر للتشغيل', 'Tap to play', '点击开始'),
                style: AppTypography.caption.copyWith(
                  color: AppColors.textDisabled,
                  fontSize: 9,
                  letterSpacing: 0.25,
                ),
              )
            ],
          ),
        ],
      ),
    );
  }
}

// ─── New Badge ────────────────────────────────────────────────────────────────

class _NewBadge extends StatelessWidget {
  final Color color;

  const _NewBadge({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.40)),
      ),
      child: Text(
        tr(context, 'جديد', 'New', '新'),
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
}

// ─── Score Badge ──────────────────────────────────────────────────────────────

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

// ─── Art Banner Painter ───────────────────────────────────────────────────────

class _ArtBannerPainter extends CustomPainter {
  final Color accentColor;

  const _ArtBannerPainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    // ── Background gradient ──────────────────────────────────────────────
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF161A2E), Color(0xFF101223), Color(0xFF0E0E1C)],
        stops: [0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // ── Radial accent glow ───────────────────────────────────────────────
    final radialRect = Rect.fromCircle(
      center: Offset(size.width * 0.78, size.height * 0.22),
      radius: size.width * 0.75,
    );
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          accentColor.withValues(alpha: 0.22),
          accentColor.withValues(alpha: 0.10),
          accentColor.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.35, 1.0],
      ).createShader(radialRect);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), glowPaint);

    // ── Horizontal grooves (music texture) ──────────────────────────────
    final linePaint = Paint()
      ..color = accentColor.withValues(alpha: 0.045)
      ..strokeWidth = 0.5;
    for (double y = 8; y < size.height; y += 12) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // ── Dot texture ─────────────────────────────────────────────────────
    final dotPaint = Paint()..color = accentColor.withValues(alpha: 0.08);
    const dotSpacing = 18.0;
    for (double x = 4; x < size.width * 0.45; x += dotSpacing) {
      for (double y = 6; y < size.height * 0.75; y += dotSpacing) {
        canvas.drawCircle(Offset(x, y), 0.9, dotPaint);
      }
    }

    // ── Bottom fade into info section ────────────────────────────────────
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

class _EqualizerLine extends StatelessWidget {
  const _EqualizerLine();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 14,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(16, (i) {
          final h = [4.0, 8.0, 6.0, 10.0, 5.0, 11.0, 7.0, 9.0][i % 8];
          return Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: h,
                width: 2,
                decoration: BoxDecoration(
                  color: AppColors.textPrimary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
