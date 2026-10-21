// A failed catalogue query must never be reported as an empty catalogue.
//
// Background (2026-10-13). `_queryRestaurants` filtered on
// `restaurants.is_blocked`. That column existed on the old `restaurants`
// TABLE; migration 20260922010000 replaced it with a VIEW over `vendors` and
// deliberately did not mirror the column. Every request therefore came back
// as PostgREST 400 "column restaurants.is_blocked does not exist" — and the
// query's `catch` returned an empty list, which the caller rendered as
// "Je ne trouve rien qui corresponde dans les restaurants ouverts en ce
// moment." Restaurant search returned zero rows for every query for three
// weeks and looked like a data problem.
//
// Two things are locked in here:
//   1. the filter is gone from the source,
//   2. "the query failed" and "the catalogue has nothing" are different
//      sentences, so the next broken query is visible instead of plausible.
//
// The queries themselves need a live PostgREST and are out of scope for a
// unit test; `tool/ai_chat_category_probe.sh` covers that half.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cmandili_mobile/features/ai_chat/data/ai_chat_service.dart';

/// Source with comments removed.
///
/// Mandatory here: this file's own explanation of the bug contains the word
/// `is_blocked`, so an absence test run against the raw text would fail on a
/// comment describing the fix. (Same trap as `pg_get_functiondef` on the SQL
/// side — an absence test that reads comments tests the prose, not the code.)
String _codeWithoutComments(String source) {
  final withoutBlocks = source.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  return withoutBlocks
      .split('\n')
      // Only strip a `//` that starts the line's content, so the `//` inside
      // string literals such as 'https://…' cannot swallow real code.
      .map((line) => RegExp(r'^\s*//').hasMatch(line) ? '' : line)
      .join('\n');
}

void main() {
  // `readAsStringSync`, not `readAsString`: under `flutter test` the clock is
  // faked, so a real async disk read never completes and the Future hangs
  // with no error at all.
  // Every file of the assistant's data layer: the queries live in
  // catalogue_search.dart since the service was split.
  final rawSource = Directory('lib/features/ai_chat/data')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .map((f) => f.readAsStringSync())
      .join('\n');
  final code = _codeWithoutComments(rawSource);

  group('the comment stripper actually strips', () {
    // Without this, the absence test below could pass for the wrong reason —
    // an over-eager stripper that returned almost nothing would "prove"
    // anything. Mutation-proofing the proof.
    test('comments go, code stays', () {
      expect(rawSource, contains('is_blocked'),
          reason: 'the explanatory comment naming the bug should still be '
              'there — if it is gone, this test is guarding nothing');
      expect(code, contains("from('restaurants')"),
          reason: 'stripping must leave the restaurant query itself intact');
      expect(code, contains("eq('is_open', true)"),
          reason: 'stripping must leave the open-venue filter intact');
    });
  });

  group('is_blocked is no longer queried', () {
    test('no catalogue query filters on a column the view does not have', () {
      expect(code, isNot(contains('is_blocked')),
          reason: '`restaurants` is a view over `vendors` and has no '
              'is_blocked column; filtering on it is a hard PostgREST 400. '
              'Re-add it only once the column lives on `vendors`.');
    });

    test('the restaurant query still restricts itself to open venues', () {
      // The fix removes one filter. It must not have removed the other one:
      // a closed restaurant is not orderable and must stay out.
      expect(code, contains("eq('is_open', true)"));
    });
  });

  group('a failed query says something different from an empty one', () {
    test('the two messages are not the same sentence', () {
      final failed = AiChatService.queryFailedMessage();
      expect(failed, isNotEmpty);
      for (final slug in [...AiChatService.kServiceCategories, null]) {
        expect(failed, isNot(AiChatService.noResultsMessageFor(slug)),
            reason: 'a failure must not reuse the empty-state line for $slug');
      }
    });

    test('a failure claims nothing about what the catalogue holds', () {
      final failed = AiChatService.queryFailedMessage();
      expect(failed, isNot(matches(RegExp(r'rien|aucun|trouv', caseSensitive: false))),
          reason: 'we do not know whether anything matched — the query never '
              'ran. Saying "rien trouvé" here is the original bug.');
    });

    test('the empty state, by contrast, does report nothing found', () {
      // Proves the previous assertion is discriminating rather than trivially
      // true of every string in the file.
      expect(AiChatService.noResultsMessageFor('food'),
          matches(RegExp(r'rien|aucun|trouv', caseSensitive: false)));
    });
  });
}
