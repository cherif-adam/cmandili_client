import 'package:flutter_test/flutter_test.dart';
import 'package:cmandili_mobile/core/utils/venue_hours.dart';

void main() {
  group('nextOpeningLabel', () {
    // 06:30 UTC = 07:30 Africa/Tunis (fixed UTC+1)
    final morningUtc = DateTime.utc(2026, 7, 3, 6, 30);
    // 20:00 UTC = 21:00 Africa/Tunis
    final eveningUtc = DateTime.utc(2026, 7, 3, 20, 0);

    test('before opening time → Ouvre à HH:MM (today)', () {
      expect(
        nextOpeningLabel('08:30:00', nowUtc: morningUtc),
        'Ouvre à 08:30',
      );
    });

    test('after opening time → Ouvre demain à HH:MM', () {
      expect(
        nextOpeningLabel('08:30:00', nowUtc: eveningUtc),
        'Ouvre demain à 08:30',
      );
    });

    test('exactly at opening time counts as passed → demain', () {
      // 07:30 Tunis == opening 07:30
      expect(
        nextOpeningLabel('07:30:00', nowUtc: morningUtc),
        'Ouvre demain à 07:30',
      );
    });

    test('HH:MM format without seconds is accepted', () {
      expect(
        nextOpeningLabel('09:05', nowUtc: morningUtc),
        'Ouvre à 09:05',
      );
    });

    test('UTC→Tunis conversion crosses midnight correctly', () {
      // 23:30 UTC = 00:30 Tunis next day → before an 08:00 opening
      final lateUtc = DateTime.utc(2026, 7, 3, 23, 30);
      expect(
        nextOpeningLabel('08:00:00', nowUtc: lateUtc),
        'Ouvre à 08:00',
      );
    });

    test('no hours configured → null (no crash)', () {
      expect(nextOpeningLabel(null, nowUtc: morningUtc), isNull);
      expect(nextOpeningLabel('', nowUtc: morningUtc), isNull);
    });

    test('garbage input → null (no crash)', () {
      expect(nextOpeningLabel('not-a-time', nowUtc: morningUtc), isNull);
      expect(nextOpeningLabel('25:99:00', nowUtc: morningUtc), isNull);
      expect(nextOpeningLabel('8', nowUtc: morningUtc), isNull);
    });
  });
}
