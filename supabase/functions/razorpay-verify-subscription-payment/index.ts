import { withSupabase } from "npm:@supabase/server@1";
import { createClient } from "npm:@supabase/supabase-js@2";
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

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};
function reply(status: number, body: Record<string, unknown>) { return new Response(JSON.stringify(body), { status, headers: cors }); }
async function hmacHex(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const signature = new Uint8Array(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(message)));
  return Array.from(signature).map((b) => b.toString(16).padStart(2, "0")).join("");
}
function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0; for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}
const handler = withSupabase({ auth: "user" }, async (req, ctx) => {
  if (req.method !== "POST") return reply(405, { error: "Method not allowed" });
  const userClient = ctx.supabase;
  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) return reply(401, { error: "Invalid or expired session." });
  let rawBody: unknown;
  try { rawBody = await req.json(); } catch { return reply(400, { error: "Invalid JSON body." }); }
  if (!rawBody || typeof rawBody !== "object" || Array.isArray(rawBody)) return reply(400, { error: "Request body must be a JSON object." });
  const body = rawBody as { payment_id?: string; razorpay_order_id?: string; razorpay_payment_id?: string; razorpay_signature?: string };
  const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  if (typeof body.payment_id !== "string" || !uuidPattern.test(body.payment_id) ||
      typeof body.razorpay_order_id !== "string" || !/^order_[A-Za-z0-9]+$/.test(body.razorpay_order_id) ||
      typeof body.razorpay_payment_id !== "string" || !/^pay_[A-Za-z0-9]+$/.test(body.razorpay_payment_id) ||
      typeof body.razorpay_signature !== "string" || !/^[a-f0-9]{64}$/i.test(body.razorpay_signature))
    return reply(400, { error: "Invalid payment verification fields." });
  const { data: payment, error: paymentError } = await userClient.from("payments")
    .select("id,user_id,amount,currency,status,verified,gateway,gateway_order_id,gateway_transaction_id,gateway_payload")
    .eq("id", body.payment_id).eq("user_id", userData.user.id).single();
  if (paymentError || !payment) return reply(404, { error: "Payment record not found for this account." });
  if (payment.verified) return reply(200, { verified: true, message: "Payment already applied." });
  if (payment.gateway !== "razorpay" || !["pending", "success"].includes(payment.status) || payment.currency !== "INR" ||
      payment.gateway_order_id !== body.razorpay_order_id ||
      (payment.status === "success" && payment.gateway_transaction_id !== body.razorpay_payment_id))
    return reply(409, { error: "Payment does not match the pending or recoverable Razorpay transaction." });
  const keyId = Deno.env.get("RAZORPAY_KEY_ID") || "";
  const keySecret = Deno.env.get("RAZORPAY_KEY_SECRET") || "";
  if (!keyId || !keySecret) return reply(503, { error: "Razorpay API credentials are not configured." });
  const expectedSignature = await hmacHex(keySecret, payment.gateway_order_id + "|" + body.razorpay_payment_id);
  if (!safeEqual(expectedSignature, body.razorpay_signature.toLowerCase())) return reply(400, { error: "Razorpay payment signature is invalid." });
  let gatewayPayment: Record<string, unknown>;
  try {
    const response = await fetch("https://api.razorpay.com/v1/payments/" + encodeURIComponent(body.razorpay_payment_id), {
      headers: { "Authorization": "Basic " + btoa(keyId + ":" + keySecret) },
    });
    gatewayPayment = await response.json();
    if (!response.ok) throw new Error("Could not retrieve payment from Razorpay.");
  } catch {
    return reply(502, { error: "Could not confirm payment status with Razorpay. Please retry." });
  }
  const expectedPaise = Math.round(Number(payment.amount) * 100);
  if (gatewayPayment.order_id !== payment.gateway_order_id || gatewayPayment.status !== "captured" ||
      gatewayPayment.captured !== true || gatewayPayment.currency !== "INR" || gatewayPayment.amount !== expectedPaise)
    return reply(409, { error: "Razorpay payment is not captured or does not match the expected amount." });
  const admin = createAdminClient();
  const payload = { ...(payment.gateway_payload || {}), razorpay_order_id: payment.gateway_order_id,
    razorpay_payment_id: body.razorpay_payment_id, captured: true, signature_verified: true, api_status_verified: true };
  const { data: saved, error: updateError } = await admin.from("payments").update({ status: "success",
    gateway_transaction_id: body.razorpay_payment_id, gateway_payload: payload })
    .eq("id", payment.id).eq("status", payment.status).eq("verified", false)
    .select("id,status,verified,gateway_transaction_id").maybeSingle();
  if (updateError) return reply(500, { error: "Could not save verified payment. Contact support with reference " + payment.id });
  if (!saved) {
    const { data: latest, error: latestError } = await admin.from("payments")
      .select("status,verified,gateway_transaction_id").eq("id", payment.id).maybeSingle();
    if (latestError) return reply(500, { error: "Could not confirm saved payment state. Contact support with reference " + payment.id });
    if (latest?.verified) return reply(200, { verified: true, payment_id: payment.id, message: "Payment already applied." });
    if (!latest || latest.status !== "success" || latest.gateway_transaction_id !== body.razorpay_payment_id)
      return reply(409, { error: "Payment state changed during verification. Refresh and retry the same transaction." });
  }
  const { error: activateError } = await admin.rpc("verify_payment_and_activate", { p_payment_id: payment.id });
  if (activateError) return reply(500, { error: "Payment was captured but subscription activation needs support review. Reference " + payment.id });
  return reply(200, { verified: true, payment_id: payment.id, message: "Payment verified and subscription applied." });
});
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try { return await handler(req); }
  catch (error) {
    console.error("Subscription verification unhandled error", String(error).slice(0, 1000));
    return reply(500, { error: "Payment verification encountered an internal error. Do not pay again; contact support if money was debited." });
  }
});
