import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:kiblat/services/settings_service.dart';
import 'package:kiblat/utils/theme_util.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:kiblat/services/ad_service.dart';
import 'package:kiblat/services/tasbih_pro_service.dart';
import 'package:kiblat/screens/dzikir/dzikir_screen.dart';
import 'dart:async';
import 'dart:math' as math;

class TasbihScreen extends StatefulWidget {
  const TasbihScreen({super.key});

  @override
  State<TasbihScreen> createState() => _TasbihScreenState();
}

class _TasbihScreenState extends State<TasbihScreen> with SingleTickerProviderStateMixin {
  int _counter = 0;
  int _target = 33;
  int _totalCount = 0;
  String? _activeWiridId;

  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _glowAnimation;

  BannerAd? _bannerAd;
  bool _bannerLoaded = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.90).chain(CurveTween(curve: Curves.easeOut)), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.90, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 50),
    ]).animate(_animController);
    
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    _loadBannerAd();
    SettingsService.instance.notifier.addListener(_onSettingsChanged);
    unawaited(TasbihProService.instance.load());
  }

  String _wiridLabel(TasbihWirid w) {
    final key = w.nameKey;
    if (key != null && key.isNotEmpty) {
      final translated = tr(key);
      if (translated != key) return translated;
    }
    return w.name;
  }

  @override
  void dispose() {
    _animController.dispose();
    SettingsService.instance.notifier.removeListener(_onSettingsChanged);
    _bannerAd?.dispose();
    super.dispose();
  }

  void _onSettingsChanged() {
    final settings = SettingsService.instance.notifier.value;
    if (settings.isProUser) {
      if (_bannerAd != null) {
        setState(() => _disposeBannerAd());
      }
    } else {
      _loadBannerAd();
    }
  }

  void _loadBannerAd() async {
    final settings = SettingsService.instance.notifier.value;
    if (settings.isProUser) {
      _disposeBannerAd();
      return;
    }

    if (_bannerAd != null) return;

    if (!AdService.isInitialized) {
      await AdService.initialize();
    }

    final adUnitId = AdService.settingsBannerUnitId;
    debugPrint('[Tasbih] Loading BannerAd with Unit ID: $adUnitId');
    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _bannerLoaded = true);
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          _bannerAd = null;
          if (mounted) setState(() => _bannerLoaded = false);
          Future.delayed(const Duration(seconds: 30), () {
            if (mounted) _loadBannerAd();
          });
        },
      ),
    )..load();
  }

  void _disposeBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _bannerLoaded = false;
  }

  void _increment() {
    HapticFeedback.lightImpact();
    _animController.forward(from: 0);
    final settings = SettingsService.instance.notifier.value;
    setState(() {
      _counter++;
      _totalCount++;
      if (_counter >= _target) {
        if (settings.isProUser) {
          final wirids = TasbihProService.instance.wiridsNotifier.value;
          TasbihWirid? wirid;
          try {
            wirid = wirids.firstWhere((w) => w.id == _activeWiridId);
          } catch (_) {
            wirid = wirids.isNotEmpty ? wirids.first : null;
          }
          if (wirid != null) {
            unawaited(TasbihProService.instance.recordSession(wirid, _target));
          } else {
            unawaited(TasbihProService.instance.addCount(_target));
          }
        }
        _counter = 0;
        HapticFeedback.vibrate();
      }
    });
  }

  void _reset() {
    HapticFeedback.mediumImpact();
    setState(() {
      _counter = 0;
      _totalCount = 0;
    });
  }

  Future<void> _showWiridLibrary(dynamic settings) async {
    await TasbihProService.instance.load();
    if (!mounted) return;

    final sheetBg = AppTheme.getCardColor(settings, context);
    final sheetText = AppTheme.getTextColor(settings, context);
    final accent = AppTheme.getAccentColor(settings, context);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: sheetBg,
      builder: (ctx) {
        final maxHeight = MediaQuery.sizeOf(ctx).height * 0.75;
        return ValueListenableBuilder<List<TasbihWirid>>(
          valueListenable: TasbihProService.instance.wiridsNotifier,
          builder: (ctx, wirids, _) {
            final sessions =
                TasbihProService.instance.sessionsNotifier.value.take(5).toList();
            return SizedBox(
              height: maxHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: Text(
                      tr('tasbih_library'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: sheetText,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      children: [
                        if (wirids.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              tr('tasbih_library_empty'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: sheetText.withValues(alpha: 0.7),
                              ),
                            ),
                          )
                        else
                          ...wirids.map((w) {
                            final selected = _activeWiridId == w.id;
                            return ListTile(
                              selected: selected,
                              selectedTileColor:
                                  accent.withValues(alpha: 0.12),
                              leading: Icon(
                                selected
                                    ? Icons.check_circle
                                    : Icons.spa_outlined,
                                color: selected ? accent : sheetText,
                              ),
                              title: Text(
                                _wiridLabel(w),
                                style: TextStyle(
                                  color: sheetText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${tr('target')}: ${w.target}',
                                style: TextStyle(
                                  color: sheetText.withValues(alpha: 0.65),
                                ),
                              ),
                              onTap: () {
                                setState(() {
                                  _target = w.target;
                                  _activeWiridId = w.id;
                                  _counter = 0;
                                });
                                Navigator.pop(ctx);
                              },
                              trailing: IconButton(
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: sheetText.withValues(alpha: 0.7),
                                ),
                                onPressed: () => TasbihProService.instance
                                    .removeWirid(w.id),
                              ),
                            );
                          }),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () {
                            unawaited(_promptAddWirid(ctx));
                          },
                          icon: Icon(Icons.add, color: accent),
                          label: Text(
                            tr('add_wirid'),
                            style: TextStyle(color: accent),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            tr('recent_sessions'),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: sheetText,
                            ),
                          ),
                        ),
                        if (sessions.isEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                            child: Text(
                              tr('tasbih_no_sessions'),
                              style: TextStyle(
                                color: sheetText.withValues(alpha: 0.6),
                              ),
                            ),
                          )
                        else
                          ...sessions.map(
                            (s) => ListTile(
                              dense: true,
                              title: Text(
                                s.wiridName,
                                style: TextStyle(color: sheetText),
                              ),
                              subtitle: Text(
                                '${s.count} · ${s.completedAt}',
                                style: TextStyle(
                                  color: sheetText.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _promptAddWirid(BuildContext sheetContext) async {
    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController(text: '33');
    try {
      final ok = await showDialog<bool>(
        context: sheetContext,
        builder: (c2) => AlertDialog(
          title: Text(tr('add_wirid')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(labelText: tr('wirid_name')),
              ),
              TextField(
                controller: targetCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: tr('target')),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c2, false),
              child: Text(tr('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c2, true),
              child: Text(tr('save')),
            ),
          ],
        ),
      );
      if (ok == true && nameCtrl.text.trim().isNotEmpty) {
        await TasbihProService.instance.addWirid(
          TasbihWirid(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: nameCtrl.text.trim(),
            target: int.tryParse(targetCtrl.text) ?? 33,
          ),
        );
      }
    } catch (e, st) {
      debugPrint('[Tasbih] add wirid failed: $e\n$st');
      if (sheetContext.mounted) {
        ScaffoldMessenger.of(sheetContext).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      nameCtrl.dispose();
      targetCtrl.dispose();
    }
  }

  void _openDzikir() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DzikirScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: SettingsService.instance.notifier,
      builder: (context, settings, _) {
        final bgColor = AppTheme.getBackgroundColor(settings, context);
        final textColor = AppTheme.getTextColor(settings, context);
        final accentColor = AppTheme.getAccentColor(settings, context);
        final cardColor = AppTheme.getCardColor(settings, context);
        final isPro = settings.isProUser;

        String? activeWiridName;
        if (_activeWiridId != null) {
          final match = TasbihProService.instance.wiridsNotifier.value
              .where((w) => w.id == _activeWiridId);
          if (match.isNotEmpty) {
            activeWiridName = _wiridLabel(match.first);
          }
        }

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            title: Text(
              tr('tasbih_digital'),
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            actions: [
              IconButton(
                tooltip: tr('tasbih_reset'),
                icon: Icon(Icons.refresh, color: textColor),
                onPressed: _reset,
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Column(
                    children: [
                      _TasbihFeatureCard(
                        cardColor: cardColor,
                        textColor: textColor,
                        accentColor: accentColor,
                        icon: Icons.wb_twilight_outlined,
                        title: tr('dzikir_open'),
                        subtitle: tr('dzikir_card_subtitle'),
                        onTap: _openDzikir,
                      ),
                      const SizedBox(height: 8),
                      _TasbihFeatureCard(
                        cardColor: cardColor,
                        textColor: textColor,
                        accentColor: accentColor,
                        icon: Icons.library_books_outlined,
                        title: tr('tasbih_library'),
                        subtitle: isPro
                            ? tr('wirid_library_card_subtitle')
                            : tr('wirid_library_pro_hint'),
                        trailing: isPro
                            ? null
                            : Icon(
                                Icons.lock_outline,
                                size: 18,
                                color: textColor.withValues(alpha: 0.45),
                              ),
                        onTap: isPro
                            ? () => _showWiridLibrary(settings)
                            : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(tr('wirid_library_pro_hint')),
                                  ),
                                );
                              },
                      ),
                      if (isPro)
                        ValueListenableBuilder<int>(
                          valueListenable:
                              TasbihProService.instance.dailyCountNotifier,
                          builder: (context, daily, _) {
                            final target = TasbihProService
                                .instance.dailyTargetNotifier.value;
                            return Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  tr(
                                    'daily_dhikr_fmt',
                                    namedArgs: {
                                      'count': '$daily',
                                      'target': '$target',
                                    },
                                  ),
                                  style: TextStyle(
                                    color: textColor.withValues(alpha: 0.65),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Reserve space for chips/labels/instruction; scale ring to fit.
                      const reserved = 140.0;
                      final ring = (constraints.maxHeight - reserved)
                          .clamp(160.0, 240.0);
                      final inner = ring * 0.76;
                      final countSize = (ring * 0.24).clamp(36.0, 56.0);

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          children: [
                            Text(
                              tr('tasbih_target_label'),
                              style: TextStyle(
                                color: textColor.withValues(alpha: 0.45),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [33, 99, 100].map((t) {
                                final selected =
                                    _target == t && _activeWiridId == null;
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 6),
                                  child: ChoiceChip(
                                    label: Text('$t'),
                                    selected: selected,
                                    visualDensity: VisualDensity.compact,
                                    onSelected: (on) {
                                      if (!on) return;
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        _target = t;
                                        _activeWiridId = null;
                                        _counter = 0;
                                      });
                                    },
                                    selectedColor: accentColor,
                                    labelStyle: TextStyle(
                                      color:
                                          selected ? Colors.black : textColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            if (activeWiridName != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                '${tr('active_wirid')}: $activeWiridName',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: accentColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            Expanded(
                              child: Center(
                                child: GestureDetector(
                                  onTap: _increment,
                                  child: ScaleTransition(
                                    scale: _scaleAnimation,
                                    child: SizedBox(
                                      width: ring,
                                      height: ring,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          AnimatedBuilder(
                                            animation: _glowAnimation,
                                            builder: (context, child) {
                                              return Container(
                                                width: ring * 0.92,
                                                height: ring * 0.92,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color:
                                                          accentColor.withValues(
                                                        alpha: 0.12 +
                                                            (_glowAnimation
                                                                    .value *
                                                                0.12),
                                                      ),
                                                      blurRadius: 20 +
                                                          (_glowAnimation
                                                                  .value *
                                                              12),
                                                      spreadRadius: 1 +
                                                          (_glowAnimation
                                                                  .value *
                                                              4),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                          CustomPaint(
                                            size: Size(ring, ring),
                                            painter: TasbihProgressPainter(
                                              progress: _counter / _target,
                                              color: accentColor,
                                              backgroundColor: accentColor
                                                  .withValues(alpha: 0.1),
                                            ),
                                          ),
                                          Container(
                                            width: inner,
                                            height: inner,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: cardColor,
                                              border: Border.all(
                                                color: accentColor.withValues(
                                                  alpha: 0.28,
                                                ),
                                                width: 2,
                                              ),
                                            ),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  '$_counter',
                                                  style: TextStyle(
                                                    fontSize: countSize,
                                                    fontWeight: FontWeight.w900,
                                                    color: accentColor,
                                                    fontFamily: 'monospace',
                                                    letterSpacing: -2,
                                                    height: 1,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '/ $_target',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: textColor.withValues(
                                                      alpha: 0.55,
                                                    ),
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Text(
                              '${tr('total_count')}: $_totalCount',
                              style: TextStyle(
                                color: textColor.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                              child: Text(
                                tr('tasbih_instruction'),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: textColor.withValues(alpha: 0.4),
                                  fontSize: 11,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                if (!isPro && _bannerAd != null && _bannerLoaded)
                  SizedBox(
                    width: _bannerAd!.size.width.toDouble(),
                    height: _bannerAd!.size.height.toDouble(),
                    child: AdWidget(ad: _bannerAd!),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TasbihFeatureCard extends StatelessWidget {
  final Color cardColor;
  final Color textColor;
  final Color accentColor;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const _TasbihFeatureCard({
    required this.cardColor,
    required this.textColor,
    required this.accentColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.55),
                        fontSize: 11,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              trailing ??
                  Icon(
                    Icons.chevron_right,
                    color: textColor.withValues(alpha: 0.35),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class TasbihProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  TasbihProgressPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width / 2, size.height / 2) - 10;
    
    // Background circle
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, progressPaint);
    
    // Add dots for every 10 counts or markers
    final markerPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
      
    for (int i = 0; i < 33; i++) {
      final angle = -math.pi / 2 + (2 * math.pi * (i / 33));
      final x = center.dx + (radius) * math.cos(angle);
      final y = center.dy + (radius) * math.sin(angle);
      
      if (i % 11 == 0) {
        canvas.drawCircle(Offset(x, y), 3, markerPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant TasbihProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
