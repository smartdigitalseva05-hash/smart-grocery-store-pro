import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};
function reply(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), { status, headers: cors });
}
function keyFromJson(name: string): string {
  const raw = Deno.env.get(name);
  if (!raw) return "";
  try { return JSON.parse(raw).default || ""; } catch { return ""; }
}
async function hmacHex(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const signature = new Uint8Array(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(message)));
  return Array.from(signature).map((b) => b.toString(16).padStart(2, "0")).join("");
}
function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply(405, { error: "Method not allowed" });

  const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
  const publishableKey = keyFromJson("SUPABASE_PUBLISHABLE_KEYS") || Deno.env.get("SUPABASE_PUBLISHABLE_KEY") || Deno.env.get("SUPABASE_ANON_KEY") || "";
  const secretKey = keyFromJson("SUPABASE_SECRET_KEYS") || Deno.env.get("SUPABASE_SECRET_KEY") || Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
  const razorpayKeyId = Deno.env.get("RAZORPAY_KEY_ID") || "";
  const razorpayKeySecret = Deno.env.get("RAZORPAY_KEY_SECRET") || "";
  if (!supabaseUrl || !publishableKey || !secretKey) return reply(500, { error: "Supabase Edge Function keys are not configured." });
  if (!razorpayKeyId || !razorpayKeySecret) return reply(503, { error: "Razorpay secrets are not configured." });

  const authorization = req.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) return reply(401, { error: "Sign in is required." });
  const userClient = createClient(supabaseUrl, publishableKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const admin = createClient(supabaseUrl, secretKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) return reply(401, { error: "Invalid or expired session." });

  let body: { payment_id?: string; razorpay_order_id?: string; razorpay_payment_id?: string; razorpay_signature?: string };
  try { body = await req.json(); } catch { return reply(400, { error: "Invalid JSON body." }); }
  if (!body.payment_id || !body.razorpay_order_id || !body.razorpay_payment_id || !body.razorpay_signature) {
    return reply(400, { error: "Missing payment verification fields." });
  }

  const { data: payment, error: paymentError } = await userClient.from("payments")
    .select("id,user_id,amount,currency,status,verified,gateway,gateway_order_id,gateway_payload")
    .eq("id", body.payment_id).eq("user_id", userData.user.id).single();
  if (paymentError || !payment) return reply(404, { error: "Payment record not found for this account." });
  if (payment.verified) return reply(200, { verified: true, message: "Payment already applied." });
  if (payment.gateway !== "razorpay" || payment.status !== "pending" || payment.currency !== "INR" ||
      payment.gateway_order_id !== body.razorpay_order_id) {
    return reply(409, { error: "Payment does not match the pending Razorpay order." });
  }

  const expectedSignature = await hmacHex(razorpayKeySecret, payment.gateway_order_id + "|" + body.razorpay_payment_id);
  if (!safeEqual(expectedSignature, body.razorpay_signature.toLowerCase())) {
    return reply(400, { error: "Razorpay payment signature is invalid." });
  }

  let gatewayPayment: Record<string, unknown>;
  try {
    const response = await fetch("https://api.razorpay.com/v1/payments/" + encodeURIComponent(body.razorpay_payment_id), {
      headers: { "Authorization": "Basic " + btoa(razorpayKeyId + ":" + razorpayKeySecret) },
    });
    gatewayPayment = await response.json();
    if (!response.ok) throw new Error("Could not retrieve payment from Razorpay.");
  } catch {
    return reply(502, { error: "Could not confirm payment status with Razorpay. Please retry." });
  }

  const expectedPaise = Math.round(Number(payment.amount) * 100);
  if (gatewayPayment.order_id !== payment.gateway_order_id ||
      gatewayPayment.status !== "captured" ||
      gatewayPayment.captured !== true ||
      gatewayPayment.currency !== "INR" ||
      gatewayPayment.amount !== expectedPaise) {
    return reply(409, { error: "Razorpay payment is not captured or does not match the expected amount." });
  }

  const payload = {
    ...(payment.gateway_payload || {}),
    razorpay_order_id: payment.gateway_order_id,
    razorpay_payment_id: body.razorpay_payment_id,
    captured: true,
    signature_verified: true,
    api_status_verified: true,
  };
  const { error: updateError } = await admin.from("payments").update({
    status: "success",
    gateway_transaction_id: body.razorpay_payment_id,
    gateway_payload: payload,
  }).eq("id", payment.id).eq("status", "pending").eq("verified", false);
  if (updateError) return reply(500, { error: "Could not save verified payment. Contact support with reference " + payment.id });

  const { error: activateError } = await admin.rpc("verify_payment_and_activate", { p_payment_id: payment.id });
  if (activateError) return reply(500, { error: "Payment was captured but subscription activation needs support review. Reference " + payment.id });

  return reply(200, { verified: true, payment_id: payment.id, message: "Payment verified and subscription applied." });
});