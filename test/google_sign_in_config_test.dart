import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Google Sign-In on Android needs serverClientId to be a WEB client of the
/// same Firebase / Google Cloud project as the app's Android OAuth client
/// (package + SHA-1). A client ID from another project gives "DEVELOPER_ERROR"
/// on the phone, or "Unacceptable audience in id_token" at Supabase.
void main() {
  final services = jsonDecode(File('android/app/google-services.json').readAsStringSync()) as Map<String, dynamic>;
  final repo = File('lib/features/auth/data/auth_repository.dart').readAsStringSync();
  final gradle = File('android/app/build.gradle.kts').readAsStringSync();

  final webClients = <String>{};
  final packages = <String>{};
  for (final c in (services['client'] as List).cast<Map<String, dynamic>>()) {
    packages.add(c['client_info']['android_client_info']['package_name'] as String);
    for (final o in (c['oauth_client'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      if (o['client_type'] == 3) webClients.add(o['client_id'] as String);
    }
  }
  final serverClientId = RegExp(r"serverClientId:\s*'([^']+)'").firstMatch(repo)?.group(1);
  final appId = RegExp(r'applicationId\s*=\s*"([^"]+)"').firstMatch(gradle)?.group(1);

  test('serverClientId is a web client of the app\'s Firebase project', () {
    expect(serverClientId, isNotNull);
    expect(webClients, contains(serverClientId));
  });

  test('google-services.json knows this app\'s package', () {
    expect(appId, isNotNull);
    expect(packages, contains(appId));
  });
}
