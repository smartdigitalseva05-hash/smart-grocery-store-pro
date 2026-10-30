import { withSupabase } from "npm:@supabase/server";

function reply(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}
async function hmacHex(secret: string, body: string): Promise<string> {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const signature = new Uint8Array(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(body)));
  return Array.from(signature).map((b) => b.toString(16).padStart(2, "0")).join("");
}
function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

Deno.serve(withSupabase({ auth: "none" }, async (req, ctx) => {
  if (req.method !== "POST") return reply(405, { error: "Method not allowed" });
  const webhookSecret = Deno.env.get("RAZORPAY_WEBHOOK_SECRET") || "";
  if (!webhookSecret) return reply(500, { error: "Webhook secret is not configured." });

  const rawBody = await req.text();
  const supplied = req.headers.get("X-Razorpay-Signature") || "";
  if (!/^[a-f0-9]{64}$/i.test(supplied)) return reply(400, { error: "Missing or invalid webhook signature." });
  const expected = await hmacHex(webhookSecret, rawBody);
  if (!safeEqual(expected, supplied.toLowerCase())) return reply(400, { error: "Webhook signature verification failed." });

  let event: Record<string, any>;
  try { event = JSON.parse(rawBody); } catch { return reply(400, { error: "Invalid webhook JSON." }); }
  if (!["payment.captured", "order.paid"].includes(String(event.event || ""))) {
    return reply(200, { received: true, ignored: true, event: event.event || "unknown" });
  }

  const entity = event?.payload?.payment?.entity;
  if (!entity || entity.status !== "captured" || entity.captured !== true ||
      !entity.order_id || !entity.id || entity.currency !== "INR") {
    return reply(200, { received: true, ignored: true, reason: "Payment is not captured INR." });
  }

  const admin = ctx.supabaseAdmin;
  const { data: payment, error: lookupError } = await admin.from("payments")
    .select("id,user_id,amount,currency,status,verified,gateway,gateway_order_id,gateway_payload")
    .eq("gateway_order_id", entity.order_id).maybeSingle();
  if (lookupError) return reply(500, { error: "Payment lookup failed." });
  if (!payment) return reply(404, { error: "No matching pending payment for this Razorpay order." });
  if (payment.verified) return reply(200, { received: true, already_applied: true });
  if (payment.gateway !== "razorpay" || payment.currency !== "INR" ||
      payment.status === "failed" || Math.round(Number(payment.amount) * 100) !== Number(entity.amount)) {
    return reply(409, { error: "Gateway payment does not match the stored payment record." });
  }

  const payload = {
    ...(payment.gateway_payload || {}),
    razorpay_order_id: entity.order_id,
    razorpay_payment_id: entity.id,
    captured: true,
    webhook_signature_verified: true,
    webhook_event: event.event,
  };
  const { error: updateError } = await admin.from("payments").update({
    status: "success",
    gateway_transaction_id: entity.id,
    gateway_payload: payload,
  }).eq("id", payment.id).eq("verified", false);
  if (updateError) return reply(500, { error: "Could not persist verified payment." });

  const { error: activateError } = await admin.rpc("verify_payment_and_activate", { p_payment_id: payment.id });
  if (activateError) return reply(500, { error: "Payment captured but database activation failed; webhook retry required." });

  return reply(200, { received: true, applied: true, payment_id: payment.id });
}));