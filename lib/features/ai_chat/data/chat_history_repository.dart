import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/chat_message.dart';

/// The saved conversation (chat_messages): read back on open, cleared on
/// request, one user + one assistant row written per turn.
class ChatHistoryRepository {
  ChatHistoryRepository(this._supabase);

  final SupabaseClient _supabase;

  // ── Load history (restore chat on screen open) ────────────────────────────
  // persistMessages has always written every turn to chat_messages, but
  // nothing ever read it back — every chat open started blank despite the
  // saved transcript. Returns newest-first (matches the screen's `reverse:
  // true` ListView directly); the screen derives the chronological (oldest-
  // first) _apiHistory shape itself by reversing this list.
  //
  // Secondary `is_user` sort: persistMessages inserts [userRow, aiRow] in one
  // statement, so both share the exact same `now()` (frozen per-transaction in
  // Postgres) — without a tiebreaker a tied pair's order is undefined. Sorting
  // is_user ascending (false/model before true/user) within a tie places the
  // pair correctly in this newest-first list: [..., model_reply, user_msg, ...].
  Future<List<ChatMessage>> loadHistory({int limit = 40}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];
    try {
      final rows = await _supabase
          .from('chat_messages')
          .select('text, is_user, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .order('is_user', ascending: true)
          .limit(limit) as List<dynamic>;

      return rows.cast<Map<String, dynamic>>().map((r) {
        return ChatMessage(
          text: (r['text'] ?? '') as String,
          isUser: (r['is_user'] ?? false) as bool,
        );
      }).toList();
    } catch (e) {
      debugPrint('AiChatService – loadHistory error: $e');
      return [];
    }
  }

  // ── Clear history ("Effacer la conversation") ─────────────────────────────
  // Permanently deletes every chat_messages row for this user — RLS ("Users
  // delete own chat messages", auth.uid() = user_id) already scopes this to
  // the caller's own rows, same as loadHistory's read. The screen is
  // responsible for confirming with the user before calling this and for
  // resetting its own local state (_messages/_apiHistory) on success.
  Future<bool> clearHistory() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      await _supabase.from('chat_messages').delete().eq('user_id', userId);
      return true;
    } catch (e) {
      debugPrint('AiChatService – clearHistory error: $e');
      return false;
    }
  }

  // ── Persist messages ──────────────────────────────────────────────────────

  Future<void> persistMessages({
    required String userText,
    required String aiReply,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase.from('chat_messages').insert([
        {'user_id': userId, 'text': userText, 'is_user': true},
        {'user_id': userId, 'text': aiReply, 'is_user': false},
      ]);
    } catch (e) {
      debugPrint('AiChatService – persist error: $e');
    }
  }
}
