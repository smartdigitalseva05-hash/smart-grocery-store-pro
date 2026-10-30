import { withSupabase } from "npm:@supabase/server";

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
  if (!keyId || !keySecret) return reply(503, { error: "Razorpay secrets are not configured." });

  const userClient = ctx.supabase;
  const admin = ctx.supabaseAdmin;
  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) return reply(401, { error: "Invalid or expired session." });

  let body: { shop_id?: string; plan_id?: string; billing_cycle?: string };
  try { body = await req.json(); } catch { return reply(400, { error: "Invalid JSON body." }); }
  if (!body.shop_id || !body.plan_id || !["monthly", "yearly"].includes(String(body.billing_cycle))) {
    return reply(400, { error: "A shop, plan and valid billing cycle are required." });
  }

  const { data: checkout, error: checkoutError } = await userClient.rpc("create_subscription_checkout", {
    p_shop_id: body.shop_id,
    p_plan_id: body.plan_id,
    p_billing_cycle: body.billing_cycle,
  });
  if (checkoutError || !checkout?.payment_id || !checkout?.subscription_id) {
    return reply(400, { error: checkoutError?.message || "Could not prepare subscription payment." });
  }

  const paymentId = String(checkout.payment_id);
  const amountPaise = Math.round(Number(checkout.amount) * 100);
  if (!Number.isSafeInteger(amountPaise) || amountPaise < 100) {
    await admin.from("payments").update({ status: "failed", gateway_payload: { reason: "Invalid amount" } })
      .eq("id", paymentId).eq("status", "pending").eq("verified", false);
    await admin.from("shop_subscriptions").update({ status: "cancelled" })
      .eq("id", checkout.subscription_id).eq("status", "pending_payment");
    return reply(400, { error: "Invalid payment amount." });
  }

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
        headers: {
          "Authorization": "Basic " + btoa(keyId + ":" + keySecret),
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          amount: amountPaise,
          currency: "INR",
          receipt,
          notes: {
            app: "Smart Grocery Store Pro",
            payment_id: paymentId,
            subscription_id: String(checkout.subscription_id),
            shop_id: String(body.shop_id),
          },
        }),
      });
      const result = await response.json();
      if (!response.ok || !result.id || result.amount !== amountPaise || result.currency !== "INR") {
        throw new Error(result?.error?.description || "Razorpay did not create the expected order.");
      }

      const { data: saved, error: saveError } = await admin.from("payments")
        .update({
          gateway: "razorpay",
          gateway_order_id: String(result.id),
          gateway_payload: {
            razorpay_order_id: String(result.id),
            receipt,
            amount_paise: amountPaise,
            currency: "INR",
            stage: "order_created",
          },
        })
        .eq("id", paymentId)
        .eq("user_id", userData.user.id)
        .eq("status", "pending")
        .eq("verified", false)
        .is("gateway_order_id", null)
        .select("gateway_order_id")
        .maybeSingle();

      if (saveError) return reply(500, { error: "Could not safely link the Razorpay order. Please retry." });
      if (saved?.gateway_order_id) {
        orderId = String(saved.gateway_order_id);
      } else {
        const { data: winner, error: winnerError } = await admin.from("payments")
          .select("gateway_order_id,status,verified")
          .eq("id", paymentId).single();
        if (winnerError || !winner?.gateway_order_id || winner.status !== "pending" || winner.verified) {
          return reply(409, { error: "Another checkout changed this payment. Refresh and retry." });
        }
        orderId = String(winner.gateway_order_id);
      }
    } catch (error) {
      console.error("Razorpay order creation failed", String(error).slice(0, 500));
      return reply(502, { error: "Payment order could not be created. Please retry." });
    }
  }

  return reply(200, {
    key_id: keyId,
    order_id: orderId,
    payment_id: paymentId,
    amount: amountPaise,
    currency: "INR",
    name: "Smart Grocery Store Pro",
    description: "Shop subscription",
    prefill: { email: userData.user.email || "" },
  });
});
Deno.serve((req) => req.method === "OPTIONS" ? new Response("ok", { headers: cors }) : handler(req));