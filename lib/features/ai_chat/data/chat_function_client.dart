import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_intent.dart';

/// The `ai-chat` Edge Function: sends the message (+ history, + picture)
/// and turns its answer into a [ChatIntent], or throws a [ChatFailure]
/// saying what went wrong.
class ChatFunctionClient {
  ChatFunctionClient(this._supabase);

  final SupabaseClient _supabase;

  static const String _functionName = 'ai-chat';

  // ── Edge Function call (text + optional vision) ───────────────────────────

  Future<ChatIntent> call(
    String userText,
    List<Map<String, dynamic>> history, {
    File? imageFile,
    String? appLang,
  }) async {
    String? imageBase64;
    String? mimeType;

    if (imageFile != null) {
      final bytes = await imageFile.readAsBytes();
      imageBase64 = base64Encode(bytes);

      // Detect MIME type from extension
      final ext = imageFile.path.split('.').last.toLowerCase();
      mimeType = switch (ext) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        _ => 'image/jpeg',
      };
    }

    final FunctionResponse response;
    try {
      response = await _supabase.functions
          .invoke(
            _functionName,
            body: {
              'text': userText,
              // Gemini-style history [{role, parts:[{text}]}] — the function
              // converts it, giving the assistant real conversation memory.
              'history': history,
              if (imageBase64 != null) 'imageBase64': imageBase64,
              if (mimeType != null) 'mimeType': mimeType,
              // The app's display language: a greeting is answered in it.
              if (appLang != null) 'app_lang': appLang,
            },
          )
          .timeout(const Duration(seconds: 60)); // longer for vision
    } on FunctionException catch (e) {
      // The edge function itself responded with a non-2xx (e.g. 502 when
      // BOTH OpenRouter and Gemini failed) — that's a server-side failure,
      // not a connectivity problem on the phone.
      throw ChatFailure(
        ChatFailureKind.server,
        'ai-chat Edge Function HTTP ${e.status}: ${e.details ?? e.reasonPhrase}',
      );
    } catch (e) {
      // Anything else here (no signal, DNS failure, the 60s timeout above,
      // socket reset, ...) — the request never got a real response at all.
      throw ChatFailure(ChatFailureKind.network, 'Network error: $e');
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw ChatFailure(
        ChatFailureKind.malformed,
        'ai-chat returned an unexpected payload: $data',
      );
    }
    if (data.containsKey('error')) {
      // A well-formed { error, details? } from the function — also a
      // server-side failure (both providers down, misconfiguration, etc.).
      final details = data['details'];
      throw ChatFailure(
        ChatFailureKind.server,
        '${data['error']}${details != null ? '\n$details' : ''}',
      );
    }

    return ChatIntent.fromJson(data);
  }
}
