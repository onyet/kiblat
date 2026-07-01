import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:kiblat/services/settings_service.dart';
import 'package:kiblat/utils/theme_util.dart';
import 'package:flutter/services.dart';

class TasbihScreen extends StatefulWidget {
  const TasbihScreen({super.key});

  @override
  State<TasbihScreen> createState() => _TasbihScreenState();
}

class _TasbihScreenState extends State<TasbihScreen> {
  int _counter = 0;
  int _target = 33;
  int _totalCount = 0;

  void _increment() {
    HapticFeedback.mediumImpact();
    setState(() {
      _counter++;
      _totalCount++;
      if (_counter >= _target) {
        _counter = 0;
        HapticFeedback.vibrate();
      }
    });
  }

  void _reset() {
    setState(() {
      _counter = 0;
      _totalCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance.notifier.value;
    final bgColor = AppTheme.getBackgroundColor(settings, context);
    final textColor = AppTheme.getTextColor(settings, context);
    final accentColor = AppTheme.getAccentColor(settings, context);
    final cardColor = AppTheme.getCardColor(settings, context);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, color: textColor, size: 30),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Tasbih Digital Pro',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: textColor),
            onPressed: _reset,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            
            // Target selector
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [33, 99, 100].map((t) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: ChoiceChip(
                  label: Text('$t'),
                  selected: _target == t,
                  onSelected: (selected) {
                    if (selected) setState(() => _target = t);
                  },
                  selectedColor: accentColor,
                  labelStyle: TextStyle(
                    color: _target == t ? Colors.black : textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )).toList(),
            ),

            const SizedBox(height: 40),

            // Counter Display
            GestureDetector(
              onTap: _increment,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cardColor,
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.2),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                  border: Border.all(color: accentColor.withValues(alpha: 0.5), width: 4),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$_counter',
                      style: TextStyle(
                        fontSize: 80,
                        fontWeight: FontWeight.w900,
                        color: accentColor,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text(
                      '/ $_target',
                      style: TextStyle(
                        fontSize: 20,
                        color: textColor.withValues(alpha: 0.5),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),

            Text(
              'Total: $_totalCount',
              style: TextStyle(
                color: textColor.withValues(alpha: 0.7),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),

            const Spacer(),
            
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Ketuk lingkaran untuk menghitung.\nGetaran aktif setiap hitungan dan target.',
                textAlign: TextAlign.center,
                style: TextStyle(color: textColor.withValues(alpha: 0.4), fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
