// Closed venues are excluded BY THE QUERY, never by Dart afterwards.
//
// All three catalogue queries used to fetch rows, let PostgREST apply
// `.limit(20)`, and only then drop the closed venues in Dart. So the 20
// cheapest matching items were chosen across open AND closed venues and the
// closed ones thinned out afterwards: a search could return nothing while an
// open venue held matching items. Invisible on 2026-10-13 (all 12 restaurants
// and all 20 vendors were open) and certain to bite the first evening a few
// close.
//
// The relaxation tiers made it worse than a missing-results bug: a page of
// rows that all belonged to closed venues reads as "this tier matched
// nothing", so the search relaxes — and then tells the user it could not find
// what they asked for, which is false.
//
// The invariant is structural, so this reads the source. The queries
// themselves need a live PostgREST; `tool/ai_chat_category_probe.sh` covers
// that, and the embedded-filter syntax was verified against the live API.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source with comments removed — this file's own explanation mentions the old
/// shape, and so do the comments in the service. An absence test that reads
/// comments tests the prose, not the code.
String _codeWithoutComments(String source) {
  final withoutBlocks = source.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  return withoutBlocks
      .split('\n')
      .map((line) => RegExp(r'^\s*//').hasMatch(line) ? '' : line)
      .join('\n');
}

void main() {
  // Sync read: the test clock is faked, so an async disk read never completes.
  // Every file of the assistant's data layer: the queries live in
  // catalogue_search.dart since the service was split.
  final raw = Directory('lib/features/ai_chat/data')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .map((f) => f.readAsStringSync())
      .join('\n');
  final code = _codeWithoutComments(raw);

  group('the stripper leaves the code it is asked about', () {
    test('comments go, queries stay', () {
      expect(raw, contains('limit(20)'),
          reason: 'sanity: the queries are still in this file');
      expect(code, contains("from('food_items')"));
      expect(code, contains("from('vendor_items')"));
      expect(code, contains("from('restaurants')"));
    });
  });

  group('is_open is part of the query', () {
    test('the dish query filters the embedded restaurant', () {
      expect(code, contains("eq('restaurants.is_open', true)"));
    });

    test('the venue query filters the embedded restaurant', () {
      // _fetchRestaurantsSelling reads food_items too, and needs its own.
      final occurrences =
          RegExp(r"eq\('restaurants\.is_open', true\)").allMatches(code).length;
      expect(occurrences, greaterThanOrEqualTo(2),
          reason: 'both food_items readers (dish search and venue search) '
              'must filter on the embedded venue, not in Dart');
    });

    test('the shop query filters the embedded vendor', () {
      expect(code, contains("eq('vendors.is_open', true)"));
    });

    test('the widest venue tier reads only open venues', () {
      // _fetchOpenRestaurants queries `restaurants` directly, where is_open is
      // a plain column.
      expect(code, contains("eq('is_open', true)"));
    });
  });

  group('nothing filters is_open in Dart any more', () {
    test('no post-filter on an embedded is_open survives', () {
      // The exact shape that used to run after `.limit(20)`:
      //   .where((r) => (r['restaurants'] as Map)['is_open'] == true)
      expect(code, isNot(contains("['is_open'] == true")),
          reason: 'a Dart-side is_open filter runs AFTER the server applied '
              'the limit, which is the bug. Filter in the query.');
    });

    test('every embed that is filtered on is an inner join', () {
      // An embedded filter on a LEFT embed does not restrict the parent rows
      // in the way this code relies on; `!inner` is load-bearing.
      expect(code, contains('restaurants!inner'));
      expect(code, contains('vendors!inner'));
      // And no plain `restaurants (` embed is left in a filtered query.
      expect(code, isNot(matches(RegExp(r'restaurants \(id, name, image_url'))),
          reason: 'the dish query embed must be restaurants!inner');
    });
  });
}
