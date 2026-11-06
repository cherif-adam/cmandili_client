// deno test --allow-env supabase/functions/_shared/simulate_test.ts
import { assertEquals } from "jsr:@std/assert@1";
import { simulatedLlmStatus } from "./simulate.ts";

function jwt(claims: Record<string, unknown>): string {
  const b64 = (o: unknown) => btoa(JSON.stringify(o)).replace(/=+$/, "").replace(/\+/g, "-").replace(/\//g, "_");
  return `${b64({ alg: "HS256" })}.${b64(claims)}.sig`;
}

function req(claims: Record<string, unknown> | null, header?: string): Request {
  const headers = new Headers();
  if (claims) headers.set("authorization", `Bearer ${jwt(claims)}`);
  if (header) headers.set("x-simulate-llm-status", header);
  return new Request("http://x", { method: "POST", headers });
}

Deno.test("off by default", () => {
  Deno.env.delete("LLM_SIMULATE_USER_ID");
  assertEquals(simulatedLlmStatus(req({ sub: "u1", role: "authenticated" })), null);
  assertEquals(simulatedLlmStatus(req(null)), null);
});

Deno.test("the header works for the service role only", () => {
  assertEquals(simulatedLlmStatus(req({ role: "service_role" }, "429")), 429);
  assertEquals(simulatedLlmStatus(req({ sub: "u1", role: "authenticated" }, "429")), null);
  assertEquals(simulatedLlmStatus(req({ role: "anon" }, "429")), null);
});

Deno.test("the secrets target one user only", () => {
  Deno.env.set("LLM_SIMULATE_USER_ID", "u1");
  Deno.env.set("LLM_SIMULATE_STATUS", "429");
  try {
    assertEquals(simulatedLlmStatus(req({ sub: "u1", role: "authenticated" })), 429);
    assertEquals(simulatedLlmStatus(req({ sub: "u2", role: "authenticated" })), null);
  } finally {
    Deno.env.delete("LLM_SIMULATE_USER_ID");
    Deno.env.delete("LLM_SIMULATE_STATUS");
  }
});
