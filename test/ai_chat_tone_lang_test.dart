// One register per language, and the client follows the user's language.
//
// Two bugs, one commit. First, French mixed "tu" and "vous" — the system
// prompt's own examples said "Tu cherches une pizzeria…" two lines from
// "Puis-je vous aider…", so the model copied whichever was nearest. Second,
// and worse: every sentence the CLIENT writes (empty result, relaxed result,
// unreachable catalogue) was hardcoded French, so a Derja or English
// conversation answered itself in French the moment a search came back empty.
// The function now reports the language it used as `lang`, and these follow
// it.
//
// Registers, fixed per language and not interchangeable:
//   fr → "vous", always. Polite, professional, short.
//   en → polite, neutral.
//   ar → polite Modern Standard Arabic.
//   tn → Derja in Latin script: friendly, simple, warm, never stiff.
//
// The prompt half can only be verified against a deployed function:
// `bash tool/ai_chat_category_probe.sh prompt` now prints the reported `lang`
// next to a guess from the text and flags both a mismatch and a tu-form slip.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cmandili_mobile/services/ai_chat_service.dart';

/// Every message the client can put on screen by itself, in one language.
List<String> clientMessages(String lang) => [
      AiChatService.queryFailedMessage(lang: lang),
      AiChatService.relaxedFoodNotice(lang: lang),
      AiChatService.relaxedRestaurantNotice(lang: lang),
      AiChatService.noResultsMessageFor('food', lang: lang),
      AiChatService.noResultsMessageFor('food', lang: lang, maxPrice: 40),
      AiChatService.noResultsMessageFor('flowers', lang: lang),
      AiChatService.noResultsMessageFor('flowers', lang: lang, maxPrice: 40),
      AiChatService.noResultsMessageFor('flowers', lang: lang, minPrice: 30),
      AiChatService.noResultsMessageFor('gifts', lang: lang, minPrice: 20, maxPrice: 50),
      AiChatService.noResultsMessageFor(null, lang: lang),
      AiChatService.noResultsMessageFor(null, lang: lang, maxPrice: 40),
      AiChatService.relaxedNoticeFor('flowers', lang: lang),
      AiChatService.relaxedNoticeFor(null, lang: lang),
    ];

void main() {
  group('normaliseLang', () {
    test('accepts the four languages', () {
      for (final l in AiChatService.kLanguages) {
        expect(AiChatService.normaliseLang(l), l);
      }
    });

    test('tolerates the obvious spellings', () {
      const cases = {
        'FR': 'fr',
        ' français ': 'fr',
        'french': 'fr',
        'english': 'en',
        'ENG': 'en',
        'arabic': 'ar',
        'fusha': 'ar',
        'derja': 'tn',
        'darija': 'tn',
        'tunisian': 'tn',
      };
      cases.forEach((input, expected) {
        expect(AiChatService.normaliseLang(input), expected,
            reason: '"$input" → $expected');
      });
    });

    test('falls back to French rather than throwing', () {
      // An older function build sends no `lang` at all. French is the app's
      // default locale, so that is the fallback — never a crash, never an
      // empty string reaching a switch.
      for (final junk in [null, '', '   ', 'klingon', 42, true, ['fr']]) {
        expect(AiChatService.normaliseLang(junk), 'fr',
            reason: '$junk should fall back to fr');
      }
    });
  });

  group('every client message exists in all four languages', () {
    test('none is empty', () {
      for (final lang in AiChatService.kLanguages) {
        for (final msg in clientMessages(lang)) {
          expect(msg.trim(), isNotEmpty, reason: 'empty message for $lang');
        }
      }
    });

    test('a language actually changes the wording', () {
      // Guards against a translation that silently falls through to French —
      // which is the bug this whole commit is about.
      final fr = clientMessages('fr');
      for (final lang in ['en', 'ar', 'tn']) {
        final other = clientMessages(lang);
        for (var i = 0; i < fr.length; i++) {
          expect(other[i], isNot(fr[i]),
              reason: 'message #$i is identical in fr and $lang — '
                  'probably an untranslated fallthrough');
        }
      }
    });

    test('the budget is restated in the right language', () {
      expect(AiChatService.noResultsMessageFor('food', maxPrice: 40, lang: 'fr'),
          contains('sous 40 TND'));
      expect(AiChatService.noResultsMessageFor('food', maxPrice: 40, lang: 'en'),
          contains('under 40 TND'));
      expect(AiChatService.noResultsMessageFor('food', maxPrice: 40, lang: 'tn'),
          contains('taht 40 TND'));
      expect(AiChatService.noResultsMessageFor('food', maxPrice: 40, lang: 'ar'),
          contains('40'));
    });

    test('whole amounts still print without decimals, in every language', () {
      for (final lang in AiChatService.kLanguages) {
        expect(
            AiChatService.noResultsMessageFor('flowers',
                maxPrice: 40.0, lang: lang),
            isNot(contains('40.0')),
            reason: '$lang should say 40, not 40.0');
      }
    });
  });

  group('French is "vous", with no "tu" left anywhere', () {
    // The forms that were actually in the code: 'Essaie', 'Dis-moi',
    // 'si tu veux'. Whole words only, so "actuellement" cannot trip them.
    //
    // Deliberately NOT listed: 'regarde' and 'cherche'. They collide with the
    // first person — "Je regarde côté fleuriste" is correct vous-form French
    // and an earlier version of this test failed on it. A register check that
    // flags "je regarde" teaches you to reword good French.
    final tuForms = RegExp(
      r"\b(tu|te|ton|ta|tes|toi)\b|(?<!')\b(Essaie|Essaye|Dis-moi)\b",
      caseSensitive: false,
    );

    test('no client message addresses the user as "tu"', () {
      for (final msg in clientMessages('fr')) {
        expect(msg, isNot(matches(tuForms)),
            reason: 'tu-form in a French message: "$msg"');
      }
    });

    test('the polite forms are the ones actually used', () {
      final all = clientMessages('fr').join(' ');
      expect(all, contains('Essayez'));
      expect(all, contains('Dites-moi'));
      expect(all, contains('si vous voulez'));
    });
  });

  group('the other three registers', () {
    test('Derja stays in Latin script and does not go formal', () {
      final tn = clientMessages('tn').join(' ');
      // Derja here is written in Latin letters: no Arabic block at all.
      expect(tn, isNot(matches(RegExp(r'[؀-ۿ]'))),
          reason: 'Derja is Latin script; Fusha is the ar language');
      // And it still sounds like Derja rather than translated French.
      expect(tn, matches(RegExp(r'\b(hani|famma|njiblek|nchouf|taht|chwaya|3awed)\b')));
    });

    test('Arabic is in Arabic script and uses the courteous forms', () {
      final ar = clientMessages('ar').join(' ');
      expect(ar, matches(RegExp(r'[؀-ۿ]')));
      expect(ar, matches(RegExp(r'يُرجى|إليك|يمكنني')),
          reason: 'polite MSA, not bare imperatives');
    });

    test('English carries no French left over', () {
      final en = clientMessages('en').join(' ');
      expect(en, isNot(contains('Rien')));
      expect(en, isNot(contains('Je ')));
      expect(en, isNot(contains('côté')));
    });

    test('English is polite', () {
      final en = clientMessages('en').join(' ').toLowerCase();
      expect(en, contains('please'),
          reason: 'polite and neutral, not bare imperatives');
    });
  });

  group('the prompt and the client agree on the contract', () {
    // The client reads `lang` and the prompt must promise to send it. These
    // are two files that can drift apart silently, so the contract is checked
    // rather than trusted. `readAsStringSync`: the test clock is faked, so a
    // real async read never completes.
    final prompt =
        File('supabase/functions/ai-chat/index.ts').readAsStringSync();

    test('the output format declares lang with the four values', () {
      expect(prompt, contains('"lang": "fr" | "en" | "ar" | "tn"'),
          reason: 'the JSON contract must declare the field the client reads');
    });

    test('every language the prompt can emit is one the client accepts', () {
      final declared = RegExp(r'"lang":"([a-z]+)"')
          .allMatches(prompt)
          .map((m) => m.group(1)!)
          .toSet();
      expect(declared, isNotEmpty, reason: 'the examples should carry lang');
      for (final l in declared) {
        expect(AiChatService.kLanguages, contains(l),
            reason: '"$l" appears in a prompt example but the client would '
                'silently map it to French');
      }
    });

    test('the register rule is in the prompt, not just in the client', () {
      expect(prompt, contains('RULE 1B'));
      expect(prompt, contains('"vous", ALWAYS'));
    });
  });
}
