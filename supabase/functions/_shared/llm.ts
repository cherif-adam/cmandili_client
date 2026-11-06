// LLM provider calls shared by ai-chat and ai-search.
//
// One entry point, callLlmJson: OpenRouter first, then direct Gemini, each
// under its own timeout. ANY failure of a provider moves on to the next one:
// an HTTP error (402 no credits, 429 quota, 5xx), a timeout, a network error,
// an empty answer, or an answer that does not parse as the JSON the caller
// expects. When every provider has failed it throws LlmUnavailableError, and
// the caller decides what to do without the model (ai-search falls back to a
// plain database search, ai-chat to a dish search on the user's own words).
//
// Provider error bodies are LOGGED here and never returned: they used to reach
// the app verbatim (a 502 carrying Gemini's whole 429 JSON), and the Recherche
// IA screen printed them.
//
// Cooldown: a provider that answers 401/402/403 (bad key, no credits) is
// skipped for 10 minutes, one that answers 429 for its Retry-After (60 s when
// absent, 10 min at most). Without it every request paid a full round trip to
// a provider known to be dead before reaching the one that works — on
// 2026-11-06 OpenRouter answered 402 to every call. The memory lives in the
// isolate, so it is per instance and lost on a cold start, which is fine:
// worst case is one wasted call. Timeouts, 5xx and bad JSON are treated as
// transient and cause no cooldown.

export type ProviderName = "openrouter" | "gemini";

export interface OpenRouterCall {
  apiKey: string;
  model: string;
  /** X-Title header, for OpenRouter's attribution. */
  title: string;
  /** OpenAI chat format, system message included. */
  messages: unknown[];
  temperature: number;
  maxTokens: number;
  /** Extra body fields, e.g. `reasoning: { enabled: false }`. */
  extra?: Record<string, unknown>;
}

export interface GeminiCall {
  apiKey: string;
  model: string;
  systemPrompt: string;
  /** Native `contents`: [{ role: "user" | "model", parts: [...] }]. */
  contents: unknown[];
  temperature: number;
  maxOutputTokens: number;
}

export interface LlmCall {
  /** Log prefix, e.g. "ai-search:intent". */
  label: string;
  /** Per provider, not in total. */
  timeoutMs: number;
  openRouter?: OpenRouterCall;
  gemini?: GeminiCall;
  /**
   * Test hook (simulate.ts): every provider "answers" this status without
   * being called. Never starts a cooldown, so other callers are unaffected.
   */
  simulateStatus?: number | null;
}

/** Every configured provider failed (or is cooling down). */
export class LlmUnavailableError extends Error {
  constructor(readonly attempts: string[]) {
    super(`all LLM providers failed: ${attempts.join(" | ") || "none configured"}`);
    this.name = "LlmUnavailableError";
  }
}

class ProviderError extends Error {
  constructor(message: string, readonly status: number | null, readonly retryAfter: string | null) {
    super(message);
  }
}

const cooldownUntil = new Map<ProviderName, number>();

/** Test hook: forget every cooldown. */
export function resetCooldowns(): void {
  cooldownUntil.clear();
}

/** How long a provider is skipped after answering [status], in ms (0 = not). */
export function cooldownMs(status: number | null, retryAfter: string | null): number {
  if (status === 401 || status === 402 || status === 403) return 10 * 60_000;
  if (status === 429) {
    const seconds = retryAfter == null ? NaN : Number(retryAfter);
    const ms = Number.isFinite(seconds) && seconds > 0 ? seconds * 1000 : 60_000;
    return Math.min(ms, 10 * 60_000);
  }
  return 0;
}

export function isCoolingDown(provider: ProviderName, now = Date.now()): boolean {
  return (cooldownUntil.get(provider) ?? 0) > now;
}

type FetchLike = (input: string, init?: RequestInit) => Promise<Response>;

/**
 * Calls the configured providers in order until one returns content that
 * [parse] accepts. [parse] must throw on anything unusable.
 */
export async function callLlmJson<T>(
  call: LlmCall,
  parse: (text: string) => T,
  fetchImpl: FetchLike = fetch,
): Promise<{ value: T; provider: ProviderName }> {
  const attempts: string[] = [];
  const order: [ProviderName, () => Promise<string>][] = [];
  if (call.openRouter?.apiKey) {
    order.push(["openrouter", () => openRouter(call.openRouter!, call.timeoutMs, fetchImpl)]);
  }
  if (call.gemini?.apiKey) {
    order.push(["gemini", () => gemini(call.gemini!, call.timeoutMs, fetchImpl)]);
  }

  if (call.simulateStatus != null) {
    for (const [name] of order) attempts.push(`${name}: simulated HTTP ${call.simulateStatus}`);
    console.warn(`[${call.label}] simulated provider failure (HTTP ${call.simulateStatus})`);
    throw new LlmUnavailableError(attempts);
  }

  for (const [name, run] of order) {
    if (isCoolingDown(name)) {
      attempts.push(`${name}: cooling down`);
      continue;
    }
    try {
      const text = await run();
      const value = parse(text);
      return { value, provider: name };
    } catch (e) {
      const status = e instanceof ProviderError ? e.status : null;
      const pause = e instanceof ProviderError ? cooldownMs(e.status, e.retryAfter) : 0;
      if (pause > 0) cooldownUntil.set(name, Date.now() + pause);
      const reason = describe(e);
      attempts.push(`${name}: ${status ?? ""} ${reason.slice(0, 120)}`.trim());
      console.warn(
        `[${call.label}] ${name} failed${pause > 0 ? ` (skipped for ${pause / 1000}s)` : ""}: ${
          reason.slice(0, 400)
        }`,
      );
    }
  }
  throw new LlmUnavailableError(attempts);
}

function describe(e: unknown): string {
  if (e instanceof DOMException && (e.name === "TimeoutError" || e.name === "AbortError")) {
    return "timeout";
  }
  return e instanceof Error ? e.message : String(e);
}

async function openRouter(c: OpenRouterCall, timeoutMs: number, fetchImpl: FetchLike): Promise<string> {
  const res = await fetchImpl("https://openrouter.ai/api/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${c.apiKey}`,
      "Content-Type": "application/json",
      "HTTP-Referer": "https://cmandili.com",
      "X-Title": c.title,
    },
    body: JSON.stringify({
      model: c.model,
      messages: c.messages,
      temperature: c.temperature,
      max_tokens: c.maxTokens,
      response_format: { type: "json_object" },
      ...(c.extra ?? {}),
    }),
    signal: AbortSignal.timeout(timeoutMs),
  });
  const raw = await res.text();
  if (!res.ok) {
    throw new ProviderError(`HTTP ${res.status}: ${raw.slice(0, 300)}`, res.status, res.headers.get("retry-after"));
  }
  let parsed: { choices?: { message?: { content?: string }; finish_reason?: string }[] };
  try {
    parsed = JSON.parse(raw);
  } catch {
    throw new ProviderError(`non-JSON envelope: ${raw.slice(0, 300)}`, null, null);
  }
  const content = parsed.choices?.[0]?.message?.content;
  if (!content) {
    throw new ProviderError(
      `no content (finish_reason=${parsed.choices?.[0]?.finish_reason ?? "unknown"})`,
      null,
      null,
    );
  }
  return content;
}

async function gemini(c: GeminiCall, timeoutMs: number, fetchImpl: FetchLike): Promise<string> {
  const res = await fetchImpl(
    `https://generativelanguage.googleapis.com/v1beta/models/${c.model}:generateContent`,
    {
      method: "POST",
      headers: { "x-goog-api-key": c.apiKey, "Content-Type": "application/json" },
      body: JSON.stringify({
        system_instruction: { parts: [{ text: c.systemPrompt }] },
        contents: c.contents,
        generationConfig: {
          temperature: c.temperature,
          maxOutputTokens: c.maxOutputTokens,
          responseMimeType: "application/json",
          // gemini-2.5-flash is a thinking model: spend the budget on the
          // JSON answer, not on reasoning tokens.
          thinkingConfig: { thinkingBudget: 0 },
        },
      }),
      signal: AbortSignal.timeout(timeoutMs),
    },
  );
  const raw = await res.text();
  if (!res.ok) {
    throw new ProviderError(`HTTP ${res.status}: ${raw.slice(0, 300)}`, res.status, res.headers.get("retry-after"));
  }
  let parsed: {
    candidates?: { content?: { parts?: { text?: string }[] }; finishReason?: string }[];
    promptFeedback?: { blockReason?: string };
  };
  try {
    parsed = JSON.parse(raw);
  } catch {
    throw new ProviderError(`non-JSON envelope: ${raw.slice(0, 300)}`, null, null);
  }
  const text = (parsed.candidates?.[0]?.content?.parts ?? []).map((p) => p.text ?? "").join("");
  if (!text) {
    const why = parsed.promptFeedback?.blockReason ?? parsed.candidates?.[0]?.finishReason ?? "unknown";
    throw new ProviderError(`no content (${why})`, null, null);
  }
  return text;
}

/**
 * The JSON object in a model answer. Models sometimes wrap it in ```json
 * fences or add prose despite the JSON response format — strip both. Throws
 * when there is no JSON object, which callLlmJson treats as a provider failure.
 */
export function extractJsonObject(text: string): Record<string, unknown> {
  let s = text.trim();
  const fence = s.match(/```(?:json)?\s*([\s\S]*?)```/i);
  if (fence) s = fence[1].trim();
  if (!s.startsWith("{")) {
    const obj = s.match(/\{[\s\S]*\}/);
    if (obj) s = obj[0];
  }
  const parsed = JSON.parse(s);
  if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error("model answer is not a JSON object");
  }
  return parsed as Record<string, unknown>;
}
