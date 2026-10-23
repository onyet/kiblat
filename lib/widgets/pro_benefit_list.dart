import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Current Kiblat Pro benefits, shared by the upgrade card and promo dialogs.
class ProBenefitList extends StatelessWidget {
  const ProBenefitList({
    super.key,
    required this.color,
    this.fontSize = 12,
  });

  final Color color;
  final double fontSize;

  static const keys = <String>[
    'pro_benefit_ads',
    'pro_benefit_adzan',
    'pro_benefit_themes',
    'pro_benefit_widgets',
    'pro_benefit_travel',
    'pro_benefit_reminders',
    'pro_benefit_tracker',
    'pro_benefit_tasbih',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final key in keys)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '✅ ${tr(key)}',
              style: TextStyle(color: color, fontSize: fontSize, height: 1.35),
            ),
          ),
      ],
    );
  }
}
