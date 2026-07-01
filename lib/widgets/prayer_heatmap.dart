import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:kiblat/utils/theme_util.dart';
import 'package:kiblat/services/settings_service.dart';

class PrayerHeatmap extends StatelessWidget {
  final Map<String, List<String>> history;
  final List<String> todayPrayers;

  const PrayerHeatmap({
    super.key,
    required this.history,
    required this.todayPrayers,
  });

  String _formatDateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance.notifier.value;
    final isLight = AppTheme.isLight(settings, context);
    final accent = AppTheme.getAccentColor(settings, context);
    final text = AppTheme.getTextColor(settings, context);
    final card = AppTheme.getCardColor(settings, context);
    final border = AppTheme.getBorderColor(settings, context);

    // Prepare data for the last 365 days
    final now = DateTime.now();
    final List<int> intensities = [];
    for (int i = 364; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key = _formatDateKey(date);
      final prayers = i == 0 ? todayPrayers : (history[key] ?? []);
      // Filter out sunnah for intensity if needed, or count all. 
      // User said "2 or 3 sholat hijau muda", usually refers to the 5 mandatory.
      final regularCount = prayers.where((p) => !['dhuha', 'tahajjud'].contains(p)).length;
      intensities.add(regularCount);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tr('prayer_heatmap').toUpperCase(),
                style: TextStyle(
                  color: text,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              Row(
                children: [
                  _legendBox(0, accent, isLight),
                  _legendBox(2, accent, isLight),
                  _legendBox(4, accent, isLight),
                  _legendBox(5, accent, isLight),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 100, // 7 rows of boxes
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true, // Show most recent on the right
                physics: const BouncingScrollPhysics(),
                child: CustomPaint(
                  size: Size((365 / 7).ceil() * 14.0, 98),
                  painter: HeatmapPainter(
                    intensities: intensities,
                    accentColor: accent,
                    isLight: isLight,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tr('filter_1_year'), style: TextStyle(color: text.withValues(alpha: 0.4), fontSize: 10, fontWeight: FontWeight.bold)),
              Text(tr('today'), style: TextStyle(color: accent.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendBox(int level, Color accent, bool isLight) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: _getColorForLevel(level, accent, isLight),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  static Color _getColorForLevel(int level, Color accent, bool isLight) {
    if (level == 0) return isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.05);
    if (level <= 2) return accent.withValues(alpha: 0.2);
    if (level <= 4) return accent.withValues(alpha: 0.5);
    return accent;
  }
}

class HeatmapPainter extends CustomPainter {
  final List<int> intensities;
  final Color accentColor;
  final bool isLight;

  HeatmapPainter({
    required this.intensities,
    required this.accentColor,
    required this.isLight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double boxSize = 10.0;
    final double spacing = 3.0;
    final paint = Paint()..style = PaintingStyle.fill;

    // Start drawing from 364 days ago
    // Group into columns of 7 (week)
    for (int i = 0; i < intensities.length; i++) {
      final int col = i ~/ 7;
      final int row = i % 7;

      paint.color = PrayerHeatmap._getColorForLevel(intensities[i], accentColor, isLight);
      
      final rect = Rect.fromLTWH(
        col * (boxSize + spacing),
        row * (boxSize + spacing),
        boxSize,
        boxSize,
      );
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant HeatmapPainter oldDelegate) {
    return oldDelegate.intensities != intensities || oldDelegate.accentColor != accentColor;
  }
}
