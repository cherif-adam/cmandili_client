/// Pure helpers for venue operating hours (single daily slot per venue:
/// `opening_time` / `closing_time` TIME columns, Africa/Tunis local time).
///
/// Tunisia is fixed UTC+1 with no DST, so the conversion is a constant
/// offset — no timezone database needed.
library;

/// Label telling the user when a closed venue is expected to open next.
///
/// [openingTimeRaw] is the Postgres TIME string (`'08:30:00'` or `'08:30'`)
/// as returned by the `opening_time` column. Returns:
///  - `'Ouvre à HH:MM'` when today's opening time is still ahead,
///  - `'Ouvre demain à HH:MM'` when it already passed,
///  - `null` when the venue has no configured/parsable hours (caller shows
///    nothing — the badge alone communicates the closed state).
///
/// Hours are identical every day, so there is no "next open day" case.
/// Note: partners open manually each morning (auto-open is intentionally
/// not implemented), so this is an expectation, not a guarantee.
///
/// [nowUtc] is injectable for tests; defaults to the current UTC time.
String? nextOpeningLabel(String? openingTimeRaw, {DateTime? nowUtc}) {
  if (openingTimeRaw == null || openingTimeRaw.isEmpty) return null;

  final parts = openingTimeRaw.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

  // Africa/Tunis = UTC+1, fixed.
  final tunisNow = (nowUtc ?? DateTime.now().toUtc()).add(const Duration(hours: 1));
  final nowMinutes = tunisNow.hour * 60 + tunisNow.minute;
  final openMinutes = hour * 60 + minute;

  final hh = hour.toString().padLeft(2, '0');
  final mm = minute.toString().padLeft(2, '0');
  return nowMinutes < openMinutes ? 'Ouvre à $hh:$mm' : 'Ouvre demain à $hh:$mm';
}
