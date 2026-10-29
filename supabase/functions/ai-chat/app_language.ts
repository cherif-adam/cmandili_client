// The app's display language, sent by the client as `app_lang` ("fr" | "en"
// | "ar"). It decides the language of a greeting: phone test 29/10/2026, the
// app was in French, the user typed "hello", and the assistant introduced
// itself in English. Everything else still follows the user's language
// (SYSTEM_PROMPT RULE 1); Derja stays Derja.

export type AppLang = "fr" | "en" | "ar";

const NAMES: Record<AppLang, string> = { fr: "French", en: "English", ar: "Arabic" };

/// The greeting the assistant introduces itself with, per app language.
export const GREETINGS: Record<AppLang, string> = {
  fr: "Bonjour ! Je suis votre conseiller nutrition et découverte culinaire à Kairouan. Comment puis-je vous aider ? 😊",
  en: "Hi! I'm your nutrition and food discovery guide in Kairouan. How can I help you today? 😊",
  ar: "مرحبًا! أنا مرشدك في التغذية واكتشاف الأطباق في القيروان. كيف يمكنني مساعدتك؟ 😊",
};

/// "fr" | "en" | "ar", or null when the app sent nothing usable (an older
/// build sends no `app_lang` at all: nothing changes for it).
export function normaliseAppLang(raw: unknown): AppLang | null {
  if (typeof raw !== "string") return null;
  const t = raw.trim().toLowerCase().slice(0, 2);
  return t === "fr" || t === "en" || t === "ar" ? t : null;
}

/// Appended to the system prompt when the app sent its language.
export function appLanguageNote(appLang: AppLang | null): string {
  if (!appLang) return "";
  return `

━━━ APP LANGUAGE ━━━
The app is displayed in ${NAMES[appLang]} ("${appLang}"). A greeting (RULE 1, GREETINGS) is answered in
${NAMES[appLang]}, whatever language the greeting word itself is in. Everything else follows RULE 1.`;
}

/// A bare greeting is answered in the app's language, whatever the model
/// chose. The prompt asks for it; this makes it certain. Left alone: Derja
/// (a deliberate choice of the user), a reply already in the app language,
/// and anything that is more than a few words (a real sentence in another
/// language is a language choice, RULE 1).
export function followAppLanguageOnGreeting<
  T extends { intent: string; lang: string; message: string },
>(reply: T, appLang: AppLang | null, userText: string): T {
  if (!appLang || reply.intent !== "greeting") return reply;
  if (reply.lang === appLang || reply.lang === "tn") return reply;
  if (userText.trim().split(/\s+/).length > 4) return reply;
  return { ...reply, lang: appLang, message: GREETINGS[appLang] };
}
