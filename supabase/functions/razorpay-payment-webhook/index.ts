import { withSupabase } from "npm:@supabase/server@1";
import { createClient } from "npm:@supabase/supabase-js@2";
import { readBodyLimited, hmacHex, safeEqual } from "./security-utils.js";
function createAdminClient() {
  const raw = Deno.env.get("SUPABASE_SECRET_KEYS") || "";
  let secretKey = "";
  if (raw) {
    try {
      const parsed = JSON.parse(raw);
      if (typeof parsed?.default === "string") secretKey = parsed.default;
    } catch { /* Use legacy injected key below when available. */ }
  }
  secretKey ||= Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
  const url = Deno.env.get("SUPABASE_URL") || "";
  if (!url || !secretKey) throw new Error("Supabase server secret key is unavailable.");
  return createClient(url, secretKey, { auth: { autoRefreshToken: false, persistSession: false } });
}

function reply(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}
const handler = withSupabase({ auth: "none" }, async (req) => {
  if (req.method !== "POST") return reply(405, { error: "Method not allowed" });
  const webhookSecret = Deno.env.get("RAZORPAY_WEBHOOK_SECRET") || "";
  if (!webhookSecret) return reply(500, { error: "Webhook secret is not configured." });
  const bodyResult = await readBodyLimited(req, 1024 * 1024);
  if (bodyResult.error === "too_large") return reply(413, { error: "Webhook body exceeds the 1 MiB limit." });
  if (bodyResult.error) return reply(400, { error: "Invalid webhook content length." });
  const rawBodyBytes = bodyResult.bytes;
  const rawBody = new TextDecoder().decode(rawBodyBytes);
  const supplied = req.headers.get("X-Razorpay-Signature") || "";
  if (!/^[a-f0-9]{64}$/i.test(supplied)) return reply(400, { error: "Missing or invalid webhook signature." });
  const expected = await hmacHex(webhookSecret, rawBodyBytes);
  if (!safeEqual(expected, supplied.toLowerCase())) return reply(400, { error: "Webhook signature verification failed." });
  let parsedEvent: unknown;
  try { parsedEvent = JSON.parse(rawBody); } catch { return reply(400, { error: "Invalid webhook JSON." }); }
  if (!parsedEvent || typeof parsedEvent !== "object" || Array.isArray(parsedEvent)) return reply(400, { error: "Webhook body must be a JSON object." });
  const event = parsedEvent as Record<string, any>;
  if (!["payment.captured", "order.paid"].includes(String(event.event || "")))
    return reply(200, { received: true, ignored: true, event: event.event || "unknown" });
  const entity = event?.payload?.payment?.entity;
  if (!entity || entity.status !== "captured" || entity.captured !== true || !entity.order_id || !entity.id || entity.currency !== "INR")
    return reply(200, { received: true, ignored: true, reason: "Payment is not captured INR." });
  const admin = createAdminClient();
  const { data: payment, error: lookupError } = await admin.from("payments")
    .select("id,user_id,amount,currency,status,verified,gateway,gateway_order_id,gateway_transaction_id,gateway_payload")
    .eq("gateway_order_id", entity.order_id).maybeSingle();
  if (lookupError) return reply(500, { error: "Payment lookup failed." });
  if (!payment) return reply(404, { error: "No matching pending payment for this Razorpay order." });
  if (payment.verified) return reply(200, { received: true, already_applied: true });
  if (payment.gateway !== "razorpay" || payment.currency !== "INR" ||
      !["pending", "success"].includes(payment.status) || Math.round(Number(payment.amount) * 100) !== Number(entity.amount))
    return reply(409, { error: "Gateway payment does not match the stored payment record." });
  if (payment.status === "success" && payment.gateway_transaction_id !== entity.id)
    return reply(409, { error: "A different Razorpay transaction is already recorded." });
  if (payment.status === "pending") {
    const payload = { ...(payment.gateway_payload || {}), razorpay_order_id: entity.order_id,
      razorpay_payment_id: entity.id, captured: true, webhook_signature_verified: true, webhook_event: event.event };
    const { data: changed, error: updateError } = await admin.from("payments").update({
      status: "success", gateway_transaction_id: entity.id, gateway_payload: payload,
    }).eq("id", payment.id).eq("status", "pending").eq("verified", false).select("id").maybeSingle();
    if (updateError) return reply(500, { error: "Could not persist verified payment." });
    if (!changed) {
      const { data: latest, error: latestError } = await admin.from("payments")
        .select("status,verified,gateway_transaction_id,gateway_order_id").eq("id", payment.id).maybeSingle();
      if (latestError) return reply(500, { error: "Could not confirm payment state." });
      if (latest?.verified) return reply(200, { received: true, already_applied: true });
      if (!latest || latest.status !== "success" || latest.gateway_transaction_id !== entity.id || latest.gateway_order_id !== entity.order_id)
        return reply(409, { error: "Payment state changed; no activation was performed." });
    }
  }
  const { error: activateError } = await admin.rpc("verify_payment_and_activate", { p_payment_id: payment.id });
  if (activateError) return reply(500, { error: "Payment captured but database activation failed; webhook retry required." });
  return reply(200, { received: true, applied: true, payment_id: payment.id });
});
Deno.serve(async (req) => {
  try { return await handler(req); }
  catch (error) {
    console.error("Razorpay webhook unhandled error", String(error).slice(0, 1000));
    return reply(500, { error: "Webhook processing failed; Razorpay may retry delivery." });
  }
});
