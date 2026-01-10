import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// Small top bar widget displaying current location and a settings button.
class HomeTopBar extends StatelessWidget {
  final String locationLabel;
  final VoidCallback onSettingsTap;

  const HomeTopBar({super.key, required this.locationLabel, required this.onSettingsTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 36), // spacer
          Column(
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    color: Colors.white70,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    tr('current_location'),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                locationLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            onPressed: onSettingsTap,
          ),
        ],
      ),
    );
  }
}
