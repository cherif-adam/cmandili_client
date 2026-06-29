#!/usr/bin/env node
/**
 * Data-only FCM test sender — Partner closed-app alarm.
 *
 * Sends the EXACT same data-only `new_order` message that
 * notify-partner-order/index.ts sends, so you can verify the killed-app
 * alarm (sound + full-screen popup) and the deep-link-on-tap on a real
 * Android device — without placing a real order.
 *
 * ── Prerequisites ──────────────────────────────────────────────────────────
 *   npm i google-auth-library            # one-time, anywhere
 *   Node 18+ (uses global fetch)
 *
 * ── Inputs (env vars) ──────────────────────────────────────────────────────
 *   GOOGLE_SERVICE_ACCOUNT   The Firebase service-account JSON (string) — the
 *                            SAME secret you set with:
 *                              supabase secrets set GOOGLE_SERVICE_ACCOUNT="$(cat sa.json)"
 *                            OR pass --sa-file path/to/service-account.json
 *   FCM_TOKEN                The target device's FCM token. Get it from the
 *                            device_tokens table for the partner's user_id, or
 *                            print it in-app from PushService._registerToken().
 *
 * ── Usage ──────────────────────────────────────────────────────────────────
 *   FCM_TOKEN="xxx" GOOGLE_SERVICE_ACCOUNT="$(cat sa.json)" node test-send.mjs
 *   # or
 *   node test-send.mjs --sa-file ./sa.json --token "xxx" --order-id "<uuid>"
 *
 * ── How to test the CLOSED-APP path ────────────────────────────────────────
 *   1. Install the partner app on a real Android phone, log in (registers token).
 *   2. SWIPE THE APP AWAY from recents (fully terminate it).
 *   3. Run this script.
 *   4. Expect: screen wakes, full-screen alarm popup on the lock screen,
 *      new_order.mp3 rings continuously. Tap it → app opens straight on the
 *      matching order's detail screen.
 */

import { readFileSync } from "node:fs";
import { JWT } from "google-auth-library";

// ── arg / env parsing ───────────────────────────────────────────────────────
function arg(name) {
  const i = process.argv.indexOf(`--${name}`);
  return i !== -1 ? process.argv[i + 1] : undefined;
}

const saFile = arg("sa-file");
const saJson = saFile
  ? readFileSync(saFile, "utf8")
  : process.env.GOOGLE_SERVICE_ACCOUNT;

const fcmToken = arg("token") || process.env.FCM_TOKEN;
// order-id is optional; a fake UUID still fires the alarm. Use a REAL order id
// to also verify the deep-link opens the correct order detail screen.
const orderId =
  arg("order-id") || process.env.ORDER_ID || "00000000-0000-0000-0000-000000000000";

if (!saJson) {
  console.error("✖ Missing service account. Set GOOGLE_SERVICE_ACCOUNT or pass --sa-file.");
  process.exit(1);
}
if (!fcmToken) {
  console.error("✖ Missing device token. Set FCM_TOKEN or pass --token.");
  process.exit(1);
}

const serviceAccount = JSON.parse(saJson);

// ── auth + send ──────────────────────────────────────────────────────────────
const jwtClient = new JWT({
  email: serviceAccount.client_email,
  key: serviceAccount.private_key,
  scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
});

const { token: accessToken } = await jwtClient.getAccessToken();
const projectId = serviceAccount.project_id;
const endpoint = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

// Mirror notify-partner-order/index.ts EXACTLY: data-only, no `notification`
// block, high priority, content-available for the iOS background wake.
const message = {
  message: {
    token: fcmToken,
    data: {
      type: "new_order",
      title: "Nouvelle commande ! (TEST)",
      body: "Commande #TEST1234 en attente d'acceptation.",
      order_id: orderId,
    },
    android: { priority: "high" },
    apns: { payload: { aps: { "content-available": 1 } } },
  },
};

console.log(`→ project: ${projectId}`);
console.log(`→ order_id: ${orderId}`);
console.log(`→ token: ${fcmToken.slice(0, 16)}…`);

const res = await fetch(endpoint, {
  method: "POST",
  headers: {
    Authorization: `Bearer ${accessToken}`,
    "Content-Type": "application/json",
  },
  body: JSON.stringify(message),
});

const text = await res.text();
if (res.ok) {
  console.log("✓ Sent. FCM response:", text);
  console.log("  Check the device — the closed-app alarm should be ringing.");
} else {
  console.error(`✖ FCM error ${res.status}:`, text);
  process.exit(1);
}
