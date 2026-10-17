import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kiblat/services/dzikir_service.dart';
import 'package:kiblat/services/settings_service.dart';
import 'package:kiblat/utils/theme_util.dart';

class DzikirScreen extends StatefulWidget {
  const DzikirScreen({super.key});

  @override
  State<DzikirScreen> createState() => _DzikirScreenState();
}

class _DzikirScreenState extends State<DzikirScreen> {
  DzikirPeriod _period = DzikirPeriod.pagi;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      await DzikirService.instance.load();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _onTapItem(DzikirItem item) async {
    if (DzikirService.instance.isComplete(item)) {
      HapticFeedback.selectionClick();
      return;
    }
    HapticFeedback.lightImpact();
    await DzikirService.instance.increment(item);
    if (DzikirService.instance.isComplete(item)) {
      HapticFeedback.mediumImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: SettingsService.instance.notifier,
      builder: (context, settings, _) {
        final bg = AppTheme.getBackgroundColor(settings, context);
        final text = AppTheme.getTextColor(settings, context);
        final accent = AppTheme.getAccentColor(settings, context);
        final card = AppTheme.getCardColor(settings, context);

        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              tr('dzikir_title'),
              style: TextStyle(color: text, fontWeight: FontWeight.bold),
            ),
            iconTheme: IconThemeData(color: text),
            actions: [
              IconButton(
                tooltip: tr('dzikir_reset_period'),
                icon: Icon(Icons.refresh, color: text),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(tr('dzikir_reset_period')),
                      content: Text(tr('dzikir_reset_confirm')),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(tr('cancel')),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(tr('save')),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await DzikirService.instance.resetPeriod(_period);
                  }
                },
              ),
            ],
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _error!,
                          style: TextStyle(color: text),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: SegmentedButton<DzikirPeriod>(
                            segments: [
                              ButtonSegment(
                                value: DzikirPeriod.pagi,
                                label: Text(tr('dzikir_morning')),
                                icon: const Icon(Icons.wb_sunny_outlined),
                              ),
                              ButtonSegment(
                                value: DzikirPeriod.petang,
                                label: Text(tr('dzikir_evening')),
                                icon: const Icon(Icons.nights_stay_outlined),
                              ),
                            ],
                            selected: {_period},
                            onSelectionChanged: (s) {
                              setState(() => _period = s.first);
                            },
                          ),
                        ),
                        ValueListenableBuilder<Map<String, int>>(
                          valueListenable:
                              DzikirService.instance.countsNotifier,
                          builder: (context, counts, child) {
                            final done =
                                DzikirService.instance.completedCount(_period);
                            final total = DzikirService.instance
                                .itemsFor(_period)
                                .length;
                            final repsDone = DzikirService.instance
                                .totalRepeatDone(_period);
                            final repsTarget = DzikirService.instance
                                .totalRepeatTarget(_period);
                            return Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 0, 20, 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    tr(
                                      'dzikir_progress_fmt',
                                      namedArgs: {
                                        'done': '$done',
                                        'total': '$total',
                                      },
                                    ),
                                    style: TextStyle(
                                      color: text.withValues(alpha: 0.75),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: total == 0
                                          ? 0
                                          : done / total,
                                      minHeight: 6,
                                      backgroundColor:
                                          text.withValues(alpha: 0.12),
                                      color: accent,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    tr(
                                      'dzikir_reps_fmt',
                                      namedArgs: {
                                        'done': '$repsDone',
                                        'total': '$repsTarget',
                                      },
                                    ),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: text.withValues(alpha: 0.55),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        Expanded(
                          child: ValueListenableBuilder<Map<String, int>>(
                            valueListenable:
                                DzikirService.instance.countsNotifier,
                            builder: (context, counts, child) {
                              final items = DzikirService.instance
                                  .itemsFor(_period);
                              return ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  4,
                                  12,
                                  24,
                                ),
                                itemCount: items.length + 1,
                                itemBuilder: (context, index) {
                                  if (index == items.length) {
                                    return Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        8,
                                        16,
                                        8,
                                        8,
                                      ),
                                      child: Text(
                                        tr('dzikir_attribution'),
                                        style: TextStyle(
                                          fontSize: 11,
                                          height: 1.35,
                                          color:
                                              text.withValues(alpha: 0.45),
                                        ),
                                      ),
                                    );
                                  }
                                  final item = items[index];
                                  final count = DzikirService.instance
                                      .countFor(item.id);
                                  final complete = DzikirService.instance
                                      .isComplete(item);
                                  final locale = context.locale;
                                  return _DzikirCard(
                                    item: item,
                                    count: count,
                                    complete: complete,
                                    cardColor: card,
                                    textColor: text,
                                    accentColor: accent,
                                    meaning: item.localizedMeaning(locale),
                                    showIndonesianNote: item
                                        .meaningUsesIndonesianFallback(
                                      locale,
                                    ),
                                    onTap: () => _onTapItem(item),
                                    onLongPress: () async {
                                      await DzikirService.instance
                                          .resetItem(item);
                                      HapticFeedback.selectionClick();
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
        );
      },
    );
  }
}

class _DzikirCard extends StatelessWidget {
  final DzikirItem item;
  final int count;
  final bool complete;
  final Color cardColor;
  final Color textColor;
  final Color accentColor;
  final String meaning;
  final bool showIndonesianNote;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _DzikirCard({
    required this.item,
    required this.count,
    required this.complete,
    required this.cardColor,
    required this.textColor,
    required this.accentColor,
    required this.meaning,
    required this.showIndonesianNote,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      complete
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: complete
                          ? accentColor
                          : textColor.withValues(alpha: 0.45),
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(
                          alpha: complete ? 0.25 : 0.12,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$count / ${item.repeat}',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                if (item.arabic.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Directionality(
                    textDirection: ui.TextDirection.rtl,
                    child: Text(
                      item.arabic,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 20,
                        height: 1.6,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                if (item.latin.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.latin,
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.7),
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      height: 1.35,
                    ),
                  ),
                ],
                if (meaning.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  if (showIndonesianNote)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        tr('dzikir_meaning_id_note'),
                        style: TextStyle(
                          color: accentColor.withValues(alpha: 0.85),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Text(
                    meaning,
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.8),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
                if (item.source.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.source,
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.45),
                      fontSize: 11,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  tr('dzikir_tap_hint'),
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.4),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
