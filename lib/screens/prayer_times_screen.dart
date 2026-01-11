import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class PrayerTimesScreen extends StatefulWidget {
  final String locationLabel;
  final double qiblaDeg;

  const PrayerTimesScreen({
    super.key,
    required this.locationLabel,
    required this.qiblaDeg,
  });

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  int _selectedTabIndex = 0;

  // Mock prayer times for today
  final Map<String, String> _prayerTimes = {
    'fajr': '05:42 AM',
    'sunrise': '07:15 AM',
    'dhuhr': '12:58 PM',
    'asr': '03:45 PM',
    'maghrib': '05:51 PM',
    'isha': '07:22 PM',
  };

  final Map<String, String> _prayerSubtitles = {
    'fajr': 'DAWN',
    'sunrise': 'SHURUQ',
    'dhuhr': 'NOON',
    'asr': 'AFTERNOON',
    'maghrib': 'SUNSET',
    'isha': 'NIGHT',
  };

  String _getQiblaDirection(double degrees) {
    if (degrees >= 337.5 || degrees < 22.5) return 'N';
    if (degrees >= 22.5 && degrees < 67.5) return 'NE';
    if (degrees >= 67.5 && degrees < 112.5) return 'E';
    if (degrees >= 112.5 && degrees < 157.5) return 'SE';
    if (degrees >= 157.5 && degrees < 202.5) return 'S';
    if (degrees >= 202.5 && degrees < 247.5) return 'SW';
    if (degrees >= 247.5 && degrees < 292.5) return 'W';
    return 'NW';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: SafeArea(
        child: Column(
          children: [
            // Header with back button and location
            _buildHeader(),

            // Tabs
            _buildTabs(),

            // Main content
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Column(
                    children: [
                      // Islamic and Gregorian dates
                      _buildDateSection(),

                      const SizedBox(height: 24),

                      // Prayer cards
                      _buildPrayerCards(),

                      const SizedBox(height: 32),

                      // Qibla direction card
                      _buildQiblaCard(),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF050505),
        border: Border(bottom: BorderSide(color: const Color.fromRGBO(255, 255, 255, 0.05))),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back button
              SizedBox(
                width: 40,
                height: 40,
                child: Material(
                  color: const Color.fromRGBO(255, 255, 255, 0.05),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(8),
                    child: const Icon(Icons.chevron_left, color: Colors.white, size: 24),
                  ),
                ),
              ),

              // Location (flexible)
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on, size: 14, color: Colors.white54),
                        const SizedBox(width: 6),
                        Text(
                          'CURRENT LOCATION',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                            color: const Color.fromRGBO(255, 255, 255, 0.6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.locationLabel,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Empty space for balance
              const SizedBox(width: 40),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: const Color.fromRGBO(255, 255, 255, 0.05))),
      ),
      child: Row(
        children: [
          _buildTabButton('TODAY', 0),
          const SizedBox(width: 32),
          _buildTabButton('TOMORROW', 1),
          const SizedBox(width: 32),
          _buildTabButton('THIS WEEK', 2),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isActive = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: isActive ? const Color(0xFFD4AF37) : const Color.fromRGBO(255, 255, 255, 0.4),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 2,
            width: 24,
            color: isActive ? const Color(0xFFD4AF37) : Colors.transparent,
          ),
        ],
      ),
    );
  }

  Widget _buildDateSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ISLAMIC DATE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: const Color(0xFFD4AF37),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '9 Rabi\' al-Thani 1445',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'GREGORIAN',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: const Color.fromRGBO(255, 255, 255, 0.4),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tuesday, 24 Oct 2023',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color.fromRGBO(255, 255, 255, 0.6),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrayerCards() {
    final prayers = [
      ('fajr', 'fajr', Icons.wb_twilight),
      ('sunrise', 'sunrise', Icons.sunny_snowing),
      ('dhuhr', 'dhuhr', Icons.wb_sunny),
      ('asr', 'asr', Icons.sunny),
      ('maghrib', 'maghrib', Icons.wb_twilight),
      ('isha', 'isha', Icons.bedtime),
    ];

    return Column(
      children: prayers.map((prayer) {
        final key = prayer.$1;
        final iconData = prayer.$3;
        final isActive = key == 'dhuhr'; // Example: dhuhr is active
        final isSunrise = key == 'sunrise';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildPrayerCard(key, iconData, isActive, isSunrise),
        );
      }).toList(),
    );
  }

  Widget _buildPrayerCard(
    String prayerKey,
    IconData iconData,
    bool isActive,
    bool isSunrise,
  ) {
    final time = _prayerTimes[prayerKey] ?? '';
    final subtitle = _prayerSubtitles[prayerKey] ?? '';

    // Get localized prayer name
    final prayerName = prayerKey == 'sunrise' ? 'Sunrise' : tr(prayerKey);

    Widget card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isActive
            ? const Color.fromRGBO(212, 175, 55, 0.1)
            : isSunrise
                ? const Color.fromRGBO(255, 255, 255, 0.02)
                : const Color.fromRGBO(255, 255, 255, 0.05),
        border: Border.all(
          color: isActive
              ? const Color(0xFFD4AF37)
              : const Color.fromRGBO(255, 255, 255, 0.1),
          width: isActive ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? const Color(0xFFD4AF37)
                  : const Color.fromRGBO(212, 175, 55, 0.1),
            ),
            child: Icon(
              iconData,
              color: isActive ? const Color(0xFF050505) : const Color(0xFFD4AF37),
              size: 20,
            ),
          ),

          const SizedBox(width: 20),

          // Prayer name and subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prayerName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isActive ? Colors.white : const Color.fromRGBO(255, 255, 255, 0.9),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: isActive
                        ? const Color.fromRGBO(212, 175, 55, 0.8)
                        : const Color.fromRGBO(255, 255, 255, 0.3),
                  ),
                ),
              ],
            ),
          ),

          // Time
          Text(
            time,
            style: TextStyle(
              fontSize: isActive ? 22 : 18,
              fontWeight: FontWeight.w700,
              color: isActive ? const Color(0xFFD4AF37) : const Color.fromRGBO(255, 255, 255, 0.9),
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );

    // Active badge
    if (isActive) {
      card = Stack(
        children: [
          card,
          Positioned(
            right: 16,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'ACTIVE',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                  color: const Color(0xFF050505),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return card;
  }

  Widget _buildQiblaCard() {
    final qiblaDir = _getQiblaDirection(widget.qiblaDeg);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0A0A0A),
            const Color(0xFF050505),
          ],
        ),
        border: Border.all(
          color: const Color.fromRGBO(212, 175, 55, 0.2),
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FACING QIBLA',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: Color(0xFFD4AF37),
                  ),
                ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${widget.qiblaDeg.toStringAsFixed(0)}°',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      TextSpan(
                        text: ' $qiblaDir from ${widget.locationLabel}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color.fromRGBO(255, 255, 255, 0.4),
                        ),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 48,
            height: 48,
            child: Material(
              color: const Color(0xFFD4AF37),
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                onTap: () {
                  // Navigate to compass/qibla screen
                },
                borderRadius: BorderRadius.circular(24),
                child: const Icon(
                  Icons.explore,
                  color: Color(0xFF050505),
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
