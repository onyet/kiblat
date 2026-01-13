import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class HomePrayerSheet extends StatefulWidget {
  final String prayerKey; // localization key e.g. 'maghrib'
  final String prayerTime;
  final String countdownDur; // e.g. '1h 20m'
  final VoidCallback? onViewFullSchedule;

  /// If true, the sheet starts expanded. Default: false (minimized)
  final bool startExpanded;

  /// Optional: when provided, shows the currently active prayer in collapsed mode
  final String? activePrayerKey;
  final bool isActive;

  /// Whether the next prayer is imminent (e.g., within 10 minutes). When true and
  /// the sheet is collapsed, the sheet will show a subtle pulse to draw attention.
  final bool isImminent;

  /// Optional ValueListenable for per-second countdown updates (preferred).
  final ValueListenable<Duration>? timeToNextListenable;

  /// Optional ValueListenable for imminence/pulse updates.
  final ValueListenable<bool>? isImminentListenable;

  /// Auto-collapse duration when the sheet is expanded. Default 30s, can be overridden for tests.
  final Duration autoCollapseDuration;

  const HomePrayerSheet({
    super.key,
    required this.prayerKey,
    required this.prayerTime,
    required this.countdownDur,
    this.onViewFullSchedule,
    this.startExpanded = false,
    this.activePrayerKey,
    this.isActive = false,
    this.isImminent = false,
    this.timeToNextListenable,
    this.isImminentListenable,
    this.autoCollapseDuration = const Duration(seconds: 30),
  });

  @override
  State<HomePrayerSheet> createState() => _HomePrayerSheetState();
}

class _HomePrayerSheetState extends State<HomePrayerSheet>
    with SingleTickerProviderStateMixin {
  late bool _expanded;
  Timer? _autoCollapseTimer;
  late final AnimationController _pulseController;
  VoidCallback? _isImminentListener;

  @override
  void initState() {
    super.initState();
    _expanded = widget.startExpanded;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
      lowerBound: 0.0,
      upperBound: 1.0,
    );

    // If a listenable is provided, attach and control pulse from it
    if (widget.isImminentListenable != null) {
      _isImminentListener = () => _updatePulseFromNotifier();
      widget.isImminentListenable!.addListener(_isImminentListener!);
      _updatePulseFromNotifier();
    } else {
      _updatePulseState();
    }

    // If starting expanded, begin auto-collapse timer
    if (_expanded) _startAutoCollapseTimer();
  }

  @override
  void dispose() {
    _autoCollapseTimer?.cancel();
    if (widget.isImminentListenable != null && _isImminentListener != null) {
      widget.isImminentListenable!.removeListener(_isImminentListener!);
    }
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomePrayerSheet oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Restart auto-collapse when the sheet is expanded or when the prayer changes
    if (_expanded && (oldWidget.prayerKey != widget.prayerKey)) {
      _startAutoCollapseTimer();
    }

    // If imminence source changed, rewire listener
    if (oldWidget.isImminentListenable != widget.isImminentListenable) {
      if (oldWidget.isImminentListenable != null &&
          _isImminentListener != null) {
        oldWidget.isImminentListenable!.removeListener(_isImminentListener!);
      }
      if (widget.isImminentListenable != null) {
        _isImminentListener = () => _updatePulseFromNotifier();
        widget.isImminentListenable!.addListener(_isImminentListener!);
        _updatePulseFromNotifier();
      } else {
        _isImminentListener = null;
        _updatePulseState();
      }
    }
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _startAutoCollapseTimer();
      } else {
        _cancelAutoCollapseTimer();
      }
      _updatePulseState();
    });
  }

  void _startAutoCollapseTimer() {
    _autoCollapseTimer?.cancel();
    _autoCollapseTimer = Timer(widget.autoCollapseDuration, () {
      if (!mounted) return;
      setState(() {
        _expanded = false;
        _updatePulseState();
      });
    });
  }

  void _cancelAutoCollapseTimer() {
    _autoCollapseTimer?.cancel();
    _autoCollapseTimer = null;
  }

  void _updatePulseState() {
    final shouldPulse = widget.isImminent && !_expanded;
    if (shouldPulse) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  void _updatePulseFromNotifier() {
    final shouldPulse = widget.isImminentListenable!.value && !_expanded;
    if (shouldPulse) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return '00:00:00';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final prayerName = tr(widget.prayerKey);
    final countdownText = tr(
      'time_to_prayer_fmt',
      namedArgs: {'dur': widget.countdownDur, 'prayer': prayerName},
    );

    // Local helper to map prayer key to IconData (kept consistent with PrayerTimesScreen)
    IconData iconForPrayer(String name) {
      switch (name.toLowerCase()) {
        case 'fajr':
          return Icons.wb_twilight;
        case 'dhuhr':
          return Icons.wb_sunny;
        case 'asr':
          return Icons.sunny;
        case 'maghrib':
          return Icons.wb_twilight;
        case 'isha':
          return Icons.bedtime;
        case 'sunrise':
          return Icons.sunny_snowing;
        default:
          return Icons.access_time;
      }
    }

    final isCompact = MediaQuery.of(context).size.height < 700;

    final horizontalMargin = isCompact ? 16.0 : 20.0;
    final contentPadding = isCompact ? 12.0 : 20.0;
    final titleSpacing = isCompact ? 8.0 : 12.0;
    final iconSize = isCompact ? 22.0 : 28.0;
    final nameFontSize = isCompact ? 18.0 : 24.0;
    final timeFontSize = isCompact ? 12.0 : 14.0;
    final badgeHPadding = isCompact ? 10.0 : 14.0;
    final badgeVPadding = isCompact ? 6.0 : 7.0;
    final badgeFontSize = isCompact ? 12.0 : 13.0;
    final betweenBadgeAndButton = isCompact ? 12.0 : 16.0;
    final buttonHeight = isCompact ? 44.0 : 52.0;

    // Collapsed header row
    final collapsedInner = GestureDetector(
      onTap: _toggle,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: contentPadding,
          vertical: isCompact ? 10 : 12,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color.fromRGBO(212, 175, 55, 0.2)),
        ),
        child: Row(
          children: [
            // Active prayer indicator (if any)
            if (widget.activePrayerKey != null && widget.isActive) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  tr('status_active').toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF050505),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(width: isCompact ? 8 : 12),
              Text(
                tr(widget.activePrayerKey!),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: isCompact ? 14 : 16,
                ),
              ),
              SizedBox(width: isCompact ? 8 : 12),
              Icon(
                Icons.arrow_forward_ios,
                size: isCompact ? 14 : 16,
                color: const Color.fromRGBO(255, 255, 255, 0.5),
              ),
              SizedBox(width: isCompact ? 8 : 12),
            ],

            // Next prayer label (inline: Name and Time adjacent, left-aligned)
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        tr(widget.prayerKey),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: isCompact ? 14 : 16,
                        ),
                      ),
                    ),
                    SizedBox(width: isCompact ? 6 : 8),
                    Text(
                      widget.prayerTime,
                      style: TextStyle(
                        color: Color.fromRGBO(255, 255, 255, 0.6),
                        fontSize: isCompact ? 14 : 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Icon(
              Icons.expand_more,
              color: const Color.fromRGBO(255, 255, 255, 0.6),
            ),
          ],
        ),
      ),
    );

    // Pulse wrapping: prefer external notifier if available
    final isPulsing = widget.isImminentListenable != null
        ? widget.isImminentListenable!.value && !_expanded
        : (widget.isImminent && !_expanded);

    final collapsed = isPulsing
        ? ScaleTransition(
            key: const ValueKey('pulse_wrap'),
            scale: Tween<double>(begin: 1.0, end: 1.06).animate(
              CurvedAnimation(
                parent: _pulseController,
                curve: Curves.easeInOut,
              ),
            ),
            child: collapsedInner,
          )
        : collapsedInner;

    // Expanded content (previous full layout) — trimmed slightly to avoid duplication
    final expanded = GestureDetector(
      onTap: () {},
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.only(
          left: horizontalMargin,
          right: horizontalMargin,
          bottom: horizontalMargin,
        ),
        padding: EdgeInsets.all(contentPadding),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color.fromRGBO(212, 175, 55, 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Header with collapse affordance
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr('next_prayer').toUpperCase(),
                    style: TextStyle(
                      color: const Color.fromRGBO(212, 175, 55, 0.6),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _toggle,
                  child: Icon(
                    Icons.expand_less,
                    color: const Color.fromRGBO(255, 255, 255, 0.6),
                  ),
                ),
              ],
            ),
            SizedBox(height: titleSpacing),

            // Icon + Prayer name + Time
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeIn,
              layoutBuilder: (currentChild, previousChildren) => Stack(
                children: [
                  ...previousChildren,
                  if (currentChild != null) currentChild,
                ],
              ),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(scale: anim, child: child),
              ),
              child: SizedBox(
                key: ValueKey('${widget.prayerKey}_${widget.prayerTime}'),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      iconForPrayer(widget.prayerKey),
                      color: const Color(0xFFD4AF37),
                      size: iconSize,
                    ),
                    SizedBox(width: isCompact ? 10 : 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prayerName,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: nameFontSize,
                            height: 1.0,
                          ),
                        ),
                        SizedBox(height: isCompact ? 3 : 4),
                        Text(
                          widget.prayerTime,
                          style: TextStyle(
                            color: Color.fromRGBO(255, 255, 255, 0.5),
                            fontSize: timeFontSize,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: isCompact ? 10 : 14),

            // Golden countdown badge
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.2),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: widget.timeToNextListenable != null
                  ? ValueListenableBuilder<Duration>(
                      valueListenable: widget.timeToNextListenable!,
                      builder: (context, dur, _) {
                        final cd = _formatDuration(dur);
                        return Container(
                          key: ValueKey('badge_${widget.prayerKey}'),
                          padding: EdgeInsets.symmetric(
                            horizontal: badgeHPadding,
                            vertical: badgeVPadding,
                          ),
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(212, 175, 55, 0.12),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: const Color.fromRGBO(212, 175, 55, 0.25),
                            ),
                          ),
                          child: Text(
                            tr(
                              'time_to_prayer_fmt',
                              namedArgs: {'dur': cd, 'prayer': prayerName},
                            ),
                            style: TextStyle(
                              color: const Color(0xFFD4AF37),
                              fontSize: badgeFontSize,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                    )
                  : Container(
                      key: ValueKey('badge_${widget.prayerKey}'),
                      padding: EdgeInsets.symmetric(
                        horizontal: badgeHPadding,
                        vertical: badgeVPadding,
                      ),
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(212, 175, 55, 0.12),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color.fromRGBO(212, 175, 55, 0.25),
                        ),
                      ),
                      child: Text(
                        countdownText,
                        style: TextStyle(
                          color: const Color(0xFFD4AF37),
                          fontSize: badgeFontSize,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
            ),

            SizedBox(height: betweenBadgeAndButton),

            // Full-width gradient button
            SizedBox(
              width: double.infinity,
              height: buttonHeight,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFBF953F),
                      const Color(0xFFFCF6BA),
                      const Color(0xFFBF953F),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromRGBO(212, 175, 55, 0.3),
                      blurRadius: 20,
                      spreadRadius: -2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onViewFullSchedule,
                    borderRadius: BorderRadius.circular(14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tr('view_full_schedule').toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                            fontSize: 13,
                            letterSpacing: 1.0,
                          ),
                        ),
                        SizedBox(width: isCompact ? 6 : 8),
                        Icon(
                          Icons.calendar_today,
                          size: isCompact ? 16 : 18,
                          color: Colors.black,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
      child: _expanded
          ? expanded
          : Padding(
              padding: EdgeInsets.only(
                left: horizontalMargin,
                right: horizontalMargin,
                bottom: horizontalMargin,
              ),
              child: collapsed,
            ),
    );
  }
}
