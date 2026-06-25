import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});

class SupabaseService {
  static final SupabaseClient client = Supabase.instance.client;
  
  // Auth methods
  Future<void> signOut() async {
    try {
      await client.auth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out: e');
    }
  }
  
  // Database operations
  Future<List<Map<String, dynamic>>> query(String table, {
    String? select,
    Map<String, dynamic>? eq,
    int? limit,
    String? orderBy,
    bool ascending = true,
  }) async {
    try {
      var filter = client.from(table).select(select ?? '*');

      if (eq != null) {
        eq.forEach((key, value) {
          filter = filter.eq(key, value);
        });
      }

      // .order()/.limit() return a PostgrestTransformBuilder, so widen the
      // type before applying them rather than reassigning the filter variable.
      PostgrestTransformBuilder<PostgrestList> transform = filter;
      if (orderBy != null) {
        transform = transform.order(orderBy, ascending: ascending);
      }
      if (limit != null) {
        transform = transform.limit(limit);
      }

      final response = await transform;
      return response;
    } catch (e) {
      throw Exception('Query failed: $e');
    }
  }
  
  // Real-time subscriptions
  RealtimeChannel subscribe(String table, String event, Function(dynamic) callback) {
    final channel = client.channel('custom-channel');

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: table,
      callback: (payload) {
        callback(payload);
      },
    ).subscribe();

    return channel;
  }
  
  // File storage operations
  Future<String> uploadFile(String bucket, String path, String filePath) async {
    try {
      final response =
          await client.storage.from(bucket).upload(path, File(filePath));
      return response;
    } catch (e) {
      throw Exception('File upload failed: $e');
    }
  }
  
  Future<String> getPublicUrl(String bucket, String path) async {
    try {
      final response = client.storage.from(bucket).getPublicUrl(path);
      return response;
    } catch (e) {
      throw Exception('Failed to get public URL: e');
    }
  }
}