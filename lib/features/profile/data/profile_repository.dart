import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileRepository {
  final _supabase = Supabase.instance.client;

  // Get current user profile
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      return response;
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      return null;
    }
  }

  // Update user profile
  Future<bool> updateProfile({
    String? fullName,
    String? avatarUrl,
    String? phone,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final updates = <String, dynamic>{
        'id': userId,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (fullName != null) updates['full_name'] = fullName;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
      if (phone != null) updates['phone'] = phone;

      // upsert instead of update: if the profiles row was never created
      // (e.g. the auth trigger failed), this creates it rather than silently
      // matching 0 rows and returning success with nothing saved.
      await _supabase
          .from('profiles')
          .upsert(updates, onConflict: 'id');
      return true;
    } catch (e, st) {
      debugPrint('Error updating profile: $e\n$st');
      return false;
    }
  }

  /// Uploads [file] to the `profiles` storage bucket under a stable per-user
  /// path (`avatars/<userId>/avatar.jpg`). Using a stable path + upsert means
  /// re-uploads replace the existing file instead of accumulating orphan files.
  ///
  /// A version timestamp is appended to the public URL so `Image.network`
  /// ignores its HTTP cache and renders the new photo immediately.
  ///
  /// On success: updates the `profiles` table *and* Supabase auth user_metadata
  /// so that [User.fromSupabase] (and therefore `authUser.photoURL`) reflects
  /// the new avatar on the next auth-state emission.
  ///
  /// Returns the public URL on success, or `null` on any error.
  Future<String?> uploadProfilePicture(File file) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      // Stable path — same file is overwritten on every upload.
      // image_picker always outputs JPEG when imageQuality is set.
      const storagePath = 'avatar.jpg';
      final bucketPath = 'avatars/$userId/$storagePath';

      await _supabase.storage.from('profiles').upload(
            bucketPath,
            file,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      final rawUrl =
          _supabase.storage.from('profiles').getPublicUrl(bucketPath);

      // Cache-bust: appending ?v=<timestamp> forces Image.network to bypass
      // the HTTP cache and display the freshly uploaded photo right away.
      final publicUrl = '$rawUrl?v=${DateTime.now().millisecondsSinceEpoch}';

      // 1. Persist to the profiles table
      await updateProfile(avatarUrl: publicUrl);

      // 2. Sync to Supabase auth user_metadata so authUser.photoURL is current
      //    without requiring a sign-out / sign-in cycle.
      await _supabase.auth.updateUser(
        UserAttributes(data: {'avatar_url': publicUrl}),
      );

      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading profile picture: $e');
      return null;
    }
  }
}
