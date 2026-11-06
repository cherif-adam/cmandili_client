// What the assistant says after a dish search, dish by dish:
//   "Calzone : trouvé chez Texas food.
//    Malfouf thon : pas disponible pour le moment."
//
// The model writes its message BEFORE anything is searched, so it cannot know
// what exists. When a dish is missing its lead-in ("voici ce qui est
// disponible") would be a promise the cards do not keep; the per-dish lines
// replace it. When everything was found the model's message stays, followed
// by the lines when there were several dishes.
//
// Languages follow the model's `lang` ("fr" | "en" | "ar" | "tn"), like the
// app's own sentences in chat_wording.dart.

import type { DishOutcome, DishRow } from "../_shared/dish_search.ts";

type Lang = "fr" | "en" | "ar" | "tn";

function asLang(raw: string): Lang {
  return raw === "en" || raw === "ar" || raw === "tn" ? raw : "fr";
}

/** "malfouf thon" -> "Malfouf thon". */
export function dishLabel(dish: string): string {
  const s = dish.trim();
  return s.length === 0 ? s : s[0].toLocaleUpperCase("fr") + s.slice(1);
}

/** "Texas food", "A et B", "A, B et C", "A, B, C et 2 autres". */
export function venuesPhrase(names: string[], lang: string): string {
  const l = asLang(lang);
  const and = { fr: " et ", en: " and ", tn: " w ", ar: " و" }[l];
  const comma = l === "ar" ? "، " : ", ";
  const shown = names.slice(0, 3);
  const more = names.length - shown.length;
  if (more > 0) {
    const others = {
      fr: `${more} autre${more > 1 ? "s" : ""}`,
      en: `${more} more`,
      tn: `${more} okhrin`,
      ar: `${more} آخرين`,
    }[l];
    return `${shown.join(comma)}${and}${others}`;
  }
  if (shown.length <= 1) return shown.join("");
  return `${shown.slice(0, -1).join(comma)}${and}${shown[shown.length - 1]}`;
}

/** "sous 5 TND" ... — same wording as ChatWording._budgetPhrase in the app. */
export function budgetPhrase(maxPrice: number | null, minPrice: number | null, lang: string): string | null {
  if (maxPrice == null && minPrice == null) return null;
  const n = (v: number) => (Number.isInteger(v) ? String(v) : String(v));
  const l = asLang(lang);
  if (maxPrice != null && minPrice != null) {
    return {
      fr: `entre ${n(minPrice)} et ${n(maxPrice)} TND`,
      en: `between ${n(minPrice)} and ${n(maxPrice)} TND`,
      tn: `bin ${n(minPrice)} w ${n(maxPrice)} TND`,
      ar: `بين ${n(minPrice)} و${n(maxPrice)} دينار`,
    }[l];
  }
  if (maxPrice != null) {
    return {
      fr: `sous ${n(maxPrice)} TND`,
      en: `under ${n(maxPrice)} TND`,
      tn: `taht ${n(maxPrice)} TND`,
      ar: `بأقل من ${n(maxPrice)} دينار`,
    }[l];
  }
  return {
    fr: `au-dessus de ${n(minPrice!)} TND`,
    en: `above ${n(minPrice!)} TND`,
    tn: `akthar mn ${n(minPrice!)} TND`,
    ar: `بأكثر من ${n(minPrice!)} دينار`,
  }[l];
}

function venuesOf(rows: DishRow[]): string[] {
  const names: string[] = [];
  for (const r of rows) {
    if (!names.includes(r.restaurant_name)) names.push(r.restaurant_name);
  }
  return names;
}

/** One line per dish, plus a hint when nothing at all was found. */
export function dishLines(
  outcomes: DishOutcome[],
  lang: string,
  maxPrice: number | null = null,
  minPrice: number | null = null,
): string {
  const l = asLang(lang);
  const budget = budgetPhrase(maxPrice, minPrice, l);
  const lines = outcomes.map((o) => {
    const d = dishLabel(o.dish);
    if (o.rows.length > 0) {
      const v = venuesPhrase(venuesOf(o.rows), l);
      return {
        fr: `${d} : trouvé chez ${v}.`,
        en: `${d}: found at ${v}.`,
        tn: `${d}: famma 3and ${v}.`,
        ar: `${d}: متوفر عند ${v}.`,
      }[l];
    }
    if (budget != null) {
      return {
        fr: `${d} : rien ${budget} pour le moment.`,
        en: `${d}: nothing ${budget} right now.`,
        tn: `${d}: ma famma chay ${budget} tw.`,
        ar: `${d}: لا شيء ${budget} حاليًا.`,
      }[l];
    }
    return {
      fr: `${d} : pas disponible pour le moment.`,
      en: `${d}: not available right now.`,
      tn: `${d}: mouch disponible tw.`,
      ar: `${d}: غير متوفر حاليًا.`,
    }[l];
  });
  if (outcomes.length > 0 && outcomes.every((o) => o.rows.length === 0)) {
    lines.push({
      fr: "Essayez un autre plat ou un autre restaurant.",
      en: "Please try another dish or another restaurant.",
      tn: "Jarreb makla okhra wella restaurant ekher.",
      ar: "جرّب طبقًا آخر أو مطعمًا آخر.",
    }[l]);
  }
  return lines.join("\n");
}

/** The assistant's final message once the dishes have been searched. */
export function chatMessageFor(
  modelMessage: string,
  outcomes: DishOutcome[],
  lang: string,
  maxPrice: number | null = null,
  minPrice: number | null = null,
): string {
  if (outcomes.length === 0) return modelMessage;
  const allFound = outcomes.every((o) => o.rows.length > 0);
  if (allFound && outcomes.length === 1) return modelMessage;
  const lines = dishLines(outcomes, lang, maxPrice, minPrice);
  return allFound ? `${modelMessage}\n\n${lines}` : lines;
}

/** Lead-in when no model answered and the dishes come from the user's words. */
export function degradedLead(appLang: string): string {
  switch (appLang) {
    case "en":
      return "Our assistant is temporarily unavailable, but here are the dishes matching your message 👇";
    case "ar":
      return "المساعد غير متاح مؤقتًا، لكن إليك الأطباق التي تطابق رسالتك 👇";
    default:
      return "Notre assistant est momentanément indisponible, mais voici les plats qui correspondent à votre message 👇";
  }
}

/**
 * For app builds released before 2026-11-06, which ignore `dish_results` and
 * run their own search from `keyword`: the names of the dishes found, so their
 * first search tier (`name ILIKE '%<term>%'` per comma-separated term) lands
 * on exactly these dishes instead of relaxing to the cheapest items on the
 * menu. Names a PostgREST `or=(...)` filter cannot carry are left out. Null
 * when none is usable. Remove once no such build is installed.
 */
export function legacyKeyword(rows: DishRow[]): string | null {
  const names: string[] = [];
  for (const r of rows) {
    const n = r.name.trim();
    if (n.length === 0 || /[,()"\\%*:]/u.test(n)) continue;
    if (!names.some((x) => x.toLowerCase() === n.toLowerCase())) names.push(n);
  }
  return names.length === 0 ? null : names.join(", ");
}
