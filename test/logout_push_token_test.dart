import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Logging out removes this phone's push token from device_tokens, BEFORE the
/// session ends (the RLS policy needs auth.uid()). Left in place, the phone
/// kept receiving the previous account's notifications after someone else
/// signed in on it. The next sign-in registers the token again (PushService).
void main() {
  final repo = File('lib/features/auth/data/auth_repository.dart')
      .readAsStringSync()
      .replaceAll('\r\n', '\n');
  final start = repo.indexOf('Future<void> signOut() async {');
  final body = repo.substring(start, repo.indexOf('\n  }\n', start));

  test('signOut deletes this phone token, then ends the session', () {
    expect(start, isNot(-1));
    final getToken = body.indexOf('FirebaseMessaging.instance.getToken()');
    final delete = body.indexOf(".from('device_tokens').delete().eq('token', token)");
    // The call itself, not the comment that mentions it.
    final end = body.indexOf('await _supabase.auth.signOut(');
    expect(getToken, isNot(-1), reason: 'the token is not read');
    expect(delete, isNot(-1), reason: 'the token is not deleted');
    expect(end, isNot(-1));
    expect(delete < end, isTrue, reason: 'deleted after the session ended: RLS refuses it');
  });

  test('a failure to delete the token never blocks the logout', () {
    final tryBlock = body.indexOf('try {');
    final delete = body.indexOf(".from('device_tokens').delete()");
    final catchBlock = body.indexOf('} catch', delete);
    expect(tryBlock < delete && delete < catchBlock, isTrue);
  });

  test('the next sign-in registers the token again', () {
    final push = File('lib/core/push/push_service.dart').readAsStringSync();
    expect(push.contains('AuthChangeEvent.signedIn) _registerToken()'), isTrue);
  });
}
