import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';

/// Utility for converting between Gregorian and Hijri dates
class HijriConverter {
  /// Convert Gregorian DateTime to Hijri date string
  /// Returns format like "9 Rabi' al-Thani 1445"
  static String toHijriString(DateTime gregorianDate) {
    try {
      final hijri = HijriCalendar.fromDate(gregorianDate);
      final monthName = hijri.getLongMonthName();
      return '${hijri.hDay} $monthName ${hijri.hYear}';
    } catch (e) {
      // Fallback if conversion fails
      return 'Date error';
    }
  }

  /// Get the Hijri month name in English
  static String getHijriMonthNameEnglish(int monthNumber) {
    const months = [
      'Muharram',
      'Safar',
      'Rabi\' al-Awwal',
      'Rabi\' al-Thani',
      'Jumada al-Awwal',
      'Jumada al-Thani',
      'Rajab',
      'Sha\'ban',
      'Ramadan',
      'Shawwal',
      'Dhu al-Qi\'dah',
      'Dhu al-Hijjah',
    ];

    if (monthNumber >= 1 && monthNumber <= 12) {
      return months[monthNumber - 1];
    }
    return '';
  }

  /// Get the Hijri month name in Arabic
  static String _getArabicMonthName(int monthNumber) {
    const months = [
      'محرم',
      'صفر',
      'ربيع الأول',
      'ربيع الثاني',
      'جمادى الأولى',
      'جمادى الثانية',
      'رجب',
      'شعبان',
      'رمضان',
      'شوال',
      'ذو القعدة',
      'ذو الحجة',
    ];

    if (monthNumber >= 1 && monthNumber <= 12) {
      return months[monthNumber - 1];
    }
    return '';
  }

  /// Get Hijri year, month, day separately
  static HijriDate getHijriDate(DateTime gregorianDate) {
    try {
      final hijri = HijriCalendar.fromDate(gregorianDate);

      return HijriDate(
        day: hijri.hDay,
        month: hijri.hMonth,
        year: hijri.hYear,
        monthName: getHijriMonthNameEnglish(hijri.hMonth),
        monthNameArabic: _getArabicMonthName(hijri.hMonth),
      );
    } catch (e) {
      // Return null/default on error
      return HijriDate(
        day: 0,
        month: 0,
        year: 0,
        monthName: 'Unknown',
        monthNameArabic: 'غير معروف',
      );
    }
  }

  /// Format Gregorian date as "Tuesday, 24 Oct 2023"
  static String formatGregorian(DateTime date) {
    try {
      return DateFormat('EEEE, d MMM yyyy').format(date);
    } catch (e) {
      return DateFormat('yyyy-MM-dd').format(date);
    }
  }

  /// Format Gregorian date as "24 Oct 2023"
  static String formatGregorianShort(DateTime date) {
    try {
      return DateFormat('d MMM yyyy').format(date);
    } catch (e) {
      return DateFormat('yyyy-MM-dd').format(date);
    }
  }

  /// Get day of week name (Monday, Tuesday, etc.)
  static String getDayOfWeekName(DateTime date) {
    try {
      return DateFormat('EEEE').format(date);
    } catch (e) {
      return '';
    }
  }
}

/// Structured Hijri date data
class HijriDate {
  final int day;
  final int month;
  final int year;
  final String monthName;
  final String monthNameArabic;

  HijriDate({
    required this.day,
    required this.month,
    required this.year,
    required this.monthName,
    required this.monthNameArabic,
  });

  /// Get formatted string like "9 Rabi' al-Thani 1445"
  String toFormattedString() => '$day $monthName $year';

  /// Get formatted string with Arabic month name
  String toFormattedStringArabic() => '$day $monthNameArabic $year';
}
