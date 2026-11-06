// deno test supabase/functions/_shared/llm_test.ts
import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import {
  callLlmJson,
  cooldownMs,
  extractJsonObject,
  isCoolingDown,
  type LlmCall,
  LlmUnavailableError,
  resetCooldowns,
} from "./llm.ts";

const CALL: LlmCall = {
  label: "test",
  timeoutMs: 200,
  openRouter: { apiKey: "or", model: "m", title: "t", messages: [], temperature: 0, maxTokens: 10 },
  gemini: { apiKey: "g", model: "m", systemPrompt: "s", contents: [], temperature: 0, maxOutputTokens: 10 },
};

const orOk = (content: string) =>
  new Response(JSON.stringify({ choices: [{ message: { content } }] }), { status: 200 });
const geminiOk = (text: string) =>
  new Response(JSON.stringify({ candidates: [{ content: { parts: [{ text }] } }] }), { status: 200 });

/** A fetch that answers per provider and records who was called. */
function fakeFetch(answers: { openrouter?: () => Response | Promise<Response>; gemini?: () => Response | Promise<Response> }) {
  const calls: string[] = [];
  const impl = (url: string, init?: RequestInit) => {
    const who = url.includes("openrouter") ? "openrouter" : "gemini";
    calls.push(who);
    const answer = answers[who];
    if (!answer) return Promise.reject(new Error("unexpected call"));
    return new Promise<Response>((resolve, reject) => {
      init?.signal?.addEventListener("abort", () => reject(init.signal!.reason));
      Promise.resolve(answer()).then(resolve, reject);
    });
  };
  return { impl, calls };
}

// The silenced console.warn keeps the test output readable.
function quiet<T>(fn: () => Promise<T>): Promise<T> {
  const warn = console.warn;
  console.warn = () => {};
  return fn().finally(() => (console.warn = warn));
}

Deno.test("OpenRouter answers: Gemini is never called", async () => {
  resetCooldowns();
  const f = fakeFetch({ openrouter: () => orOk('{"a":1}') });
  const r = await callLlmJson(CALL, extractJsonObject, f.impl);
  assertEquals(r.provider, "openrouter");
  assertEquals(r.value, { a: 1 });
  assertEquals(f.calls, ["openrouter"]);
});

Deno.test("OpenRouter 402 -> Gemini, and OpenRouter is skipped on the next call", async () => {
  resetCooldowns();
  const f = fakeFetch({
    openrouter: () => new Response('{"error":"no credits"}', { status: 402 }),
    gemini: () => geminiOk('{"b":2}'),
  });
  const first = await quiet(() => callLlmJson(CALL, extractJsonObject, f.impl));
  assertEquals(first.provider, "gemini");
  assertEquals(isCoolingDown("openrouter"), true);
  const second = await quiet(() => callLlmJson(CALL, extractJsonObject, f.impl));
  assertEquals(second.provider, "gemini");
  assertEquals(f.calls, ["openrouter", "gemini", "gemini"]);
});

Deno.test("an unparseable answer counts as a failure, without a cooldown", async () => {
  resetCooldowns();
  const f = fakeFetch({ openrouter: () => orOk("Sure! Here you go."), gemini: () => geminiOk('{"c":3}') });
  const r = await quiet(() => callLlmJson(CALL, extractJsonObject, f.impl));
  assertEquals(r.provider, "gemini");
  assertEquals(isCoolingDown("openrouter"), false);
});

Deno.test("a timeout moves on to the next provider", async () => {
  resetCooldowns();
  const f = fakeFetch({
    openrouter: () => new Promise<Response>(() => {}), // never answers
    gemini: () => geminiOk('{"d":4}'),
  });
  const r = await quiet(() => callLlmJson(CALL, extractJsonObject, f.impl));
  assertEquals(r.provider, "gemini");
  assertEquals(isCoolingDown("openrouter"), false);
});

Deno.test("both providers fail (402 + 429): LlmUnavailableError, both cooling down", async () => {
  resetCooldowns();
  const f = fakeFetch({
    openrouter: () => new Response("{}", { status: 402 }),
    gemini: () => new Response('{"error":{"code":429}}', { status: 429, headers: { "retry-after": "30" } }),
  });
  await quiet(() => assertRejects(() => callLlmJson(CALL, extractJsonObject, f.impl), LlmUnavailableError));
  assertEquals(isCoolingDown("openrouter"), true);
  assertEquals(isCoolingDown("gemini"), true);
  // The next request reaches no provider at all: the caller degrades at once.
  await quiet(() => assertRejects(() => callLlmJson(CALL, extractJsonObject, f.impl), LlmUnavailableError));
  assertEquals(f.calls, ["openrouter", "gemini"]);
});

Deno.test("no key configured: LlmUnavailableError without any call", async () => {
  resetCooldowns();
  const f = fakeFetch({});
  const noKeys: LlmCall = {
    ...CALL,
    openRouter: { ...CALL.openRouter!, apiKey: "" },
    gemini: { ...CALL.gemini!, apiKey: "" },
  };
  await assertRejects(() => callLlmJson(noKeys, extractJsonObject, f.impl), LlmUnavailableError);
  assertEquals(f.calls, []);
});

Deno.test("simulated 429: no provider called, no cooldown for anyone else", async () => {
  resetCooldowns();
  const f = fakeFetch({ openrouter: () => orOk('{"a":1}'), gemini: () => geminiOk('{"b":2}') });
  await quiet(() =>
    assertRejects(() => callLlmJson({ ...CALL, simulateStatus: 429 }, extractJsonObject, f.impl), LlmUnavailableError)
  );
  assertEquals(f.calls, []);
  assertEquals(isCoolingDown("openrouter"), false);
  assertEquals(isCoolingDown("gemini"), false);
  // The next, normal request is served as usual.
  const r = await callLlmJson(CALL, extractJsonObject, f.impl);
  assertEquals(r.provider, "openrouter");
});

Deno.test("cooldown lengths", () => {
  assertEquals(cooldownMs(402, null), 600_000);
  assertEquals(cooldownMs(401, null), 600_000);
  assertEquals(cooldownMs(429, null), 60_000);
  assertEquals(cooldownMs(429, "30"), 30_000);
  assertEquals(cooldownMs(429, "99999"), 600_000);
  assertEquals(cooldownMs(500, null), 0);
  assertEquals(cooldownMs(null, null), 0);
});

Deno.test("extractJsonObject strips fences and prose, refuses arrays", () => {
  assertEquals(extractJsonObject('```json\n{"x":1}\n```'), { x: 1 });
  assertEquals(extractJsonObject('Voici : {"x":2} !'), { x: 2 });
  let threw = false;
  try {
    extractJsonObject("[1,2]");
  } catch {
    threw = true;
  }
  assertEquals(threw, true);
});
