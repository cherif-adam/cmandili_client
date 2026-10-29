import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Nothing secret ships inside the app. `.env` used to be bundled as an
/// asset, so anyone who unzipped the APK could read it (the client's held an
/// OpenRouter API key). The public values now come in at build time with
/// --dart-define-from-file (see BuildConfig).
void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync().replaceAll('\r\n', '\n');

  test('.env is not an asset and flutter_dotenv is gone', () {
    expect(RegExp(r'^\s*-\s*\.env\s*$', multiLine: true).hasMatch(pubspec), isFalse);
    expect(pubspec, isNot(contains('flutter_dotenv')));
  });

  test('no code reads .env any more', () {
    final readers = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => RegExp(r'flutter_dotenv|dotenv\.(env|load)').hasMatch(f.readAsStringSync()))
        .map((f) => f.path)
        .toList();
    expect(readers, isEmpty);
  });

  test('the example config names exactly the three public values', () {
    final example =
        jsonDecode(File('dart_defines.example.json').readAsStringSync()) as Map<String, dynamic>;
    expect(example.keys.toSet(), {'SUPABASE_URL', 'SUPABASE_ANON_KEY', 'GOOGLE_MAPS_API_KEY'});
  });

  test('no bundled asset holds a secret', () {
    final folders = RegExp(r'^\s*-\s*(assets/[^\s]*)\s*$', multiLine: true)
        .allMatches(pubspec)
        .map((m) => m.group(1)!)
        .toList();
    expect(folders, isNotEmpty);
    final secret = RegExp(r'sk-or-v1|private_key|BEGIN (RSA |EC )?PRIVATE KEY|sbp_[0-9a-f]{20}');
    final leaks = <String>[];
    for (final folder in folders) {
      final dir = Directory(folder);
      if (!dir.existsSync()) continue;
      for (final f in dir.listSync(recursive: true).whereType<File>()) {
        if (secret.hasMatch(latin1.decode(f.readAsBytesSync(), allowInvalid: true))) leaks.add(f.path);
      }
    }
    expect(leaks, isEmpty);
  });
}
