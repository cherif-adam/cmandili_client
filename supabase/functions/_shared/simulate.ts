// Test hook: make every LLM provider "answer" an HTTP status (429 by default)
// for ONE caller, to check the no-model paths live without burning the
// Gemini quota or breaking a key for everyone. Off unless set up:
//
//   1. From the phone, for one account:
//        supabase secrets set LLM_SIMULATE_USER_ID=<auth uid> LLM_SIMULATE_STATUS=429
//      ... test ...
//        supabase secrets unset LLM_SIMULATE_USER_ID LLM_SIMULATE_STATUS
//   2. From curl, with the service-role key: header `x-simulate-llm-status: 429`.
//
// Every other caller is untouched, and a simulated failure never starts the
// provider cooldown (see llm.ts), so nobody else is pushed into degraded mode.
// The JWT is decoded without checking its signature on purpose: both
// functions run with verify_jwt = true, so the gateway already did.

function jwtClaims(authorization: string | null): Record<string, unknown> | null {
  const token = authorization?.replace(/^Bearer\s+/i, "") ?? "";
  const payload = token.split(".")[1];
  if (!payload) return null;
  try {
    const b64 = payload.replace(/-/g, "+").replace(/_/g, "/");
    const padded = b64 + "=".repeat((4 - (b64.length % 4)) % 4);
    const parsed = JSON.parse(new TextDecoder().decode(Uint8Array.from(atob(padded), (c) => c.charCodeAt(0))));
    return parsed && typeof parsed === "object" ? parsed as Record<string, unknown> : null;
  } catch {
    return null;
  }
}

function asStatus(raw: string | null | undefined): number | null {
  const n = Number((raw ?? "").trim() || "429");
  return Number.isInteger(n) && n >= 400 && n <= 599 ? n : null;
}

/** The status to simulate for this request, or null (the normal case). */
export function simulatedLlmStatus(req: Request): number | null {
  const claims = jwtClaims(req.headers.get("authorization"));
  if (!claims) return null;

  const header = req.headers.get("x-simulate-llm-status");
  if (header && claims.role === "service_role") return asStatus(header);

  const user = (Deno.env.get("LLM_SIMULATE_USER_ID") ?? "").trim();
  if (user && claims.sub === user) return asStatus(Deno.env.get("LLM_SIMULATE_STATUS"));

  return null;
}
