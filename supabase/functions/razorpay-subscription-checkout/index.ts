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
function reply(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), { status, headers: cors });
}
const handler = withSupabase({ auth: "user" }, async (req, ctx) => {
  if (req.method !== "POST") return reply(405, { error: "Method not allowed" });
  const keyId = Deno.env.get("RAZORPAY_KEY_ID") || "";
  const keySecret = Deno.env.get("RAZORPAY_KEY_SECRET") || "";
  if (!keyId || !keySecret) return reply(503, { error: "Razorpay Test/Live API credentials are not configured in Supabase Edge Function Secrets." });
  const userClient = ctx.supabase;
  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) return reply(401, { error: "Invalid or expired session. Please sign in again." });
  let rawBody: unknown;
  try { rawBody = await req.json(); } catch { return reply(400, { error: "Invalid JSON body." }); }
  if (!rawBody || typeof rawBody !== "object" || Array.isArray(rawBody)) return reply(400, { error: "Request body must be a JSON object." });
  const body = rawBody as { shop_id?: string; plan_id?: string; billing_cycle?: string };
  const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  if (typeof body.shop_id !== "string" || !uuidPattern.test(body.shop_id) ||
      typeof body.plan_id !== "string" || !uuidPattern.test(body.plan_id) ||
      !["monthly", "yearly"].includes(String(body.billing_cycle))) {
    return reply(400, { error: "A valid shop ID, plan ID and monthly/yearly billing cycle are required." });
  }
  const { data: checkout, error: checkoutError } = await userClient.rpc("create_subscription_checkout", {
    p_shop_id: body.shop_id, p_plan_id: body.plan_id, p_billing_cycle: body.billing_cycle,
  });
  if (checkoutError || !checkout?.payment_id || !checkout?.subscription_id) {
    return reply(400, { error: checkoutError?.message || "Could not prepare subscription payment." });
  }
  const paymentId = String(checkout.payment_id);
  const amountPaise = Math.round(Number(checkout.amount) * 100);
  if (!Number.isSafeInteger(amountPaise) || amountPaise < 100) return reply(400, { error: "Invalid payment amount. Please contact support." });
  const admin = createAdminClient();
  const { data: currentPayment, error: currentError } = await admin.from("payments")
    .select("id,user_id,amount,currency,status,verified,gateway,gateway_order_id,shop_subscription_id")
    .eq("id", paymentId).eq("user_id", userData.user.id).single();
  if (currentError || !currentPayment || currentPayment.shop_subscription_id !== checkout.subscription_id ||
      Number(currentPayment.amount) !== Number(checkout.amount) || currentPayment.currency !== "INR" ||
      currentPayment.status !== "pending" || currentPayment.verified || currentPayment.gateway !== "razorpay") {
    return reply(409, { error: "The pending subscription payment changed. Refresh and try again." });
  }
  let orderId = currentPayment.gateway_order_id ? String(currentPayment.gateway_order_id) : "";
  if (!orderId) {
    const receipt = "sgs_" + paymentId.replaceAll("-", "").slice(0, 28);
    try {
      const response = await fetch("https://api.razorpay.com/v1/orders", {
        method: "POST",
        headers: { "Authorization": "Basic " + btoa(keyId + ":" + keySecret), "Content-Type": "application/json" },
        body: JSON.stringify({ amount: amountPaise, currency: "INR", receipt, notes: {
          app: "Smart Grocery Store Pro", payment_id: paymentId,
          subscription_id: String(checkout.subscription_id), shop_id: String(body.shop_id),
        }}),
      });
      const result = await response.json();
      if (!response.ok || !result.id || result.amount !== amountPaise || result.currency !== "INR") {
        throw new Error(result?.error?.description || "Razorpay did not create the expected order.");
      }
      const { data: saved, error: saveError } = await admin.from("payments").update({
        gateway_order_id: String(result.id),
        gateway_payload: { razorpay_order_id: String(result.id), receipt, amount_paise: amountPaise, currency: "INR", stage: "order_created" },
      }).eq("id", paymentId).eq("user_id", userData.user.id).eq("status", "pending").eq("verified", false)
        .is("gateway_order_id", null).select("gateway_order_id").maybeSingle();
      if (saveError) return reply(500, { error: "Could not safely link the Razorpay order. Please retry." });
      if (saved?.gateway_order_id) orderId = String(saved.gateway_order_id);
      else {
        const { data: winner, error: winnerError } = await admin.from("payments")
          .select("gateway_order_id,status,verified").eq("id", paymentId).single();
        if (winnerError || !winner?.gateway_order_id || winner.status !== "pending" || winner.verified)
          return reply(409, { error: "Another checkout changed this payment. Refresh and retry." });
        orderId = String(winner.gateway_order_id);
      }
    } catch (error) {
      console.error("Razorpay order creation failed", String(error).slice(0, 500));
      return reply(502, { error: "Payment order could not be created. Please retry." });
    }
  }
  return reply(200, { key_id: keyId, order_id: orderId, payment_id: paymentId, amount: amountPaise,
    currency: "INR", name: "Smart Grocery Store Pro", description: "Shop subscription",
    prefill: { email: userData.user.email || "" } });
});
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try { return await handler(req); }
  catch (error) {
    console.error("Subscription checkout unhandled error", String(error).slice(0, 1000));
    return reply(500, { error: "Checkout service encountered an internal error. Please retry; no payment was confirmed." });
  }
});
