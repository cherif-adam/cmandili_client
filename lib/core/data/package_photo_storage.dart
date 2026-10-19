import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Uploads to the `package-photos` storage bucket, shared by the parcel photo
/// (courier) and the bill photo (facture). Each method keeps the path and
/// upload options its screen used before. Errors propagate.
class PackagePhotoStorage {
  static const _bucket = 'package-photos';
  final _supabase = Supabase.instance.client;

  /// Parcel photo: `<userId>/<ms>.jpg`, sent as JPEG, overwriting allowed.
  /// Returns the public URL.
  Future<String> uploadParcelPhoto(String userId, Uint8List bytes) async {
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _supabase.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions:
              const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
    return _supabase.storage.from(_bucket).getPublicUrl(path);
  }

  /// Bill photo: `<userId>/bill_<ms>.jpg`, default upload options.
  /// Returns the public URL.
  Future<String> uploadBillPhoto(String userId, Uint8List bytes) async {
    final path = '$userId/bill_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _supabase.storage.from(_bucket).uploadBinary(path, bytes);
    return _supabase.storage.from(_bucket).getPublicUrl(path);
  }
}
