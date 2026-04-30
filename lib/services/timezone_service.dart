import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class TimeZoneService {
  static bool _initialized = false;

  static const Map<String, String> _timeZoneIds = {
    'WIB': 'Asia/Jakarta',
    'WITA': 'Asia/Makassar',
    'WIT': 'Asia/Jayapura',
    'London': 'Europe/London',
    'UTC': 'UTC',
    'New York': 'America/New_York',
    'Tokyo': 'Asia/Tokyo',
  };

  static const Map<String, String> _timeZoneLabels = {
    'WIB': 'WIB (UTC+7)',
    'WITA': 'WITA (UTC+8)',
    'WIT': 'WIT (UTC+9)',
    'London': 'London (UTC+0)',
    'UTC': 'UTC',
    'New York': 'New York (UTC-5)',
    'Tokyo': 'Tokyo (UTC+9)',
  };

  static void _initialize() {
    if (_initialized) return;
    tz.initializeTimeZones();
    _initialized = true;
  }

  static bool isValidTimeZone(String timezone) {
    return _timeZoneIds.containsKey(timezone);
  }

  static tz.Location _location(String timezone) {
    _initialize();
    final locationId = _timeZoneIds[timezone] ?? 'UTC';
    return tz.getLocation(locationId);
  }

  static DateTime currentTime(String timezone) {
    return tz.TZDateTime.now(_location(timezone));
  }

  static DateTime convertToZone(String timezone, [DateTime? at]) {
    final dateTime = at?.toUtc() ?? DateTime.now().toUtc();
    return tz.TZDateTime.from(dateTime, _location(timezone));
  }

  static String formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  static String formatZoneTime(String timezone) {
    final dateTime = currentTime(timezone);
    return formatTime(dateTime);
  }

  static String zoneLabel(String timezone) {
    return _timeZoneLabels[timezone] ?? timezone;
  }
}
