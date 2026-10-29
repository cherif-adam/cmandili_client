// deno test supabase/functions/ai-chat/app_language_test.ts
//
// Phone test, 29/10/2026, app in French: "bonjour" got a French greeting,
// "aaslema" a Derja one, and "hello" an English one. The greeting must follow
// the app's language (fr/en/ar); Derja stays Derja.
import { assertEquals } from "jsr:@std/assert@1";
import {
  appLanguageNote,
  followAppLanguageOnGreeting,
  GREETINGS,
  normaliseAppLang,
} from "./app_language.ts";

const englishHello = {
  intent: "greeting",
  lang: "en",
  message: "Hi! I'm your nutrition and food discovery guide in Kairouan. How can I help you today? 😊",
  keyword: null,
};

Deno.test("'hello' in the French app gets the French greeting", () => {
  const out = followAppLanguageOnGreeting(englishHello, "fr", "hello");
  assertEquals(out.lang, "fr");
  assertEquals(out.message, GREETINGS.fr);
  assertEquals(out.keyword, null); // the rest of the reply is kept
});

Deno.test("the greeting follows each app language", () => {
  const french = { intent: "greeting", lang: "fr", message: "Bonjour ! 😊" };
  assertEquals(followAppLanguageOnGreeting(french, "en", "salut").message, GREETINGS.en);
  assertEquals(followAppLanguageOnGreeting(french, "ar", "bonjour").lang, "ar");
  assertEquals(followAppLanguageOnGreeting(englishHello, "ar", "hi").message, GREETINGS.ar);
});

Deno.test("left alone: Derja, the right language, other intents, real sentences, old builds", () => {
  const derja = { intent: "greeting", lang: "tn", message: "Aaslema bik! 🍽️" };
  assertEquals(followAppLanguageOnGreeting(derja, "fr", "aaslema"), derja);
  const french = { intent: "greeting", lang: "fr", message: "Bonjour ! 😊" };
  assertEquals(followAppLanguageOnGreeting(french, "fr", "hello"), french);
  const search = { intent: "search_food", lang: "en", message: "Here are grilled dishes" };
  assertEquals(followAppLanguageOnGreeting(search, "fr", "grilled chicken"), search);
  const sentence = "hello can you help me find something to eat";
  assertEquals(followAppLanguageOnGreeting(englishHello, "fr", sentence), englishHello);
  assertEquals(followAppLanguageOnGreeting(englishHello, null, "hello"), englishHello);
});

Deno.test("app_lang is read leniently and the prompt note names it", () => {
  assertEquals(normaliseAppLang("fr"), "fr");
  assertEquals(normaliseAppLang(" AR "), "ar");
  assertEquals(normaliseAppLang("en_US"), "en");
  assertEquals(normaliseAppLang("tn"), null);
  assertEquals(normaliseAppLang(undefined), null);
  assertEquals(appLanguageNote(null), "");
  assertEquals(appLanguageNote("fr").includes('The app is displayed in French ("fr")'), true);
});
