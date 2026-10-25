// Pure helpers for the text search's candidate query, kept out of index.ts so
// they can be unit-tested without starting the server (search_filters_test.ts).

/**
 * A spelling-tolerant regex for the dish the user named, for PostgREST's
 * `imatch` (case-insensitive POSIX regex).
 *
 * Doubled letters are collapsed, then every letter may repeat: "chapati",
 * "chapatti" and "chappati" all give `c+h+a+p+a+t+i+`, which matches each of
 * them in the menu. Several words may be separated by anything (`.*`).
 *
 * Only letters and digits are kept (any script, so Arabic works too). The
 * result therefore never contains a quote, a comma, a parenthesis or a
 * backslash, and is safe inside a double-quoted PostgREST filter value.
 * Returns null when nothing usable is left.
 */
export function keywordPattern(keyword: string | null | undefined): string | null {
  if (!keyword) return null;
  const words = keyword.toLowerCase().normalize("NFC")
    .split(/[^\p{L}\p{N}]+/u)
    .filter((w) => w.length > 0);
  if (words.length === 0) return null;
  return words
    .map((w) =>
      [...w]
        .filter((ch, i, all) => i === 0 || ch !== all[i - 1])
        .map((ch) => `${ch}+`)
        .join("")
    )
    .join(".*");
}

/** What the "taxonomy" part of a relaxation tier filters on. */
export type TaxonomyFilter =
  | { kind: "keyword"; or: string }
  | { kind: "category"; pattern: string }
  | null;

/**
 * The dish the user NAMED wins over the category the model GUESSED.
 *
 * The intent prompt asks for a "best guess" category, but shops name their
 * menu sections freely: the same chapati sits under "Chapati" in one shop
 * and "Sandwiches" in another. Requiring both the guessed category and the
 * keyword kept only the dishes that happened to be filed under the guess —
 * "n7eb chapati ... 10 dt" returned 1 of the 35 chapatis on the menu. So:
 *   - a keyword matches the dish name, its description or its menu section;
 *   - the guessed category is used only when no dish was named.
 */
export function taxonomyFilter(
  intent: { category: string | null; keyword: string | null },
): TaxonomyFilter {
  const pattern = keywordPattern(intent.keyword);
  if (pattern) {
    return {
      kind: "keyword",
      or: ["name", "description", "category"]
        .map((column) => `${column}.imatch."${pattern}"`)
        .join(","),
    };
  }
  if (intent.category) {
    return { kind: "category", pattern: `%${intent.category}%` };
  }
  return null;
}
