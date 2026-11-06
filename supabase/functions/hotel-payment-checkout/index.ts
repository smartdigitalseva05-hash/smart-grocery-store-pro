import { withSupabase } from "npm:@supabase/server@1";
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "https://smartdigitalseva05-hash.github.io",
  "Vary": "Origin",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};
function reply(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), { status, headers: cors });
}
function adminClient() {
  const raw = Deno.env.get("SUPABASE_SECRET_KEYS") || "";
  let secret = "";
  try { const parsed = JSON.parse(raw); if (typeof parsed?.default === "string") secret = parsed.default; } catch {}
  secret ||= Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
  const url = Deno.env.get("SUPABASE_URL") || "";
  if (!url || !secret) throw new Error("Server credentials are unavailable.");
  return createClient(url, secret, { auth: { autoRefreshToken: false, persistSession: false } });
}
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const handler = withSupabase({ auth: "none" }, async (req) => {
  if (req.method !== "POST") return reply(405, { error: "Method not allowed." });
  if (!(req.headers.get("content-type") || "").toLowerCase().startsWith("application/json"))
    return reply(415, { error: "JSON content type required." });
  const raw = await req.text();
  if (raw.length > 8192) return reply(413, { error: "Request too large." });
  let body: Record<string, unknown>;
  try { body = JSON.parse(raw); } catch { return reply(400, { error: "Invalid JSON." }); }
  if (typeof body.booking_request_id !== "string" || !uuid.test(body.booking_request_id))
    return reply(400, { error: "A valid booking reference is required." });
  const keyId = Deno.env.get("RAZORPAY_KEY_ID") || "";
  const keySecret = Deno.env.get("RAZORPAY_KEY_SECRET") || "";
  if (!keyId || !keySecret) return reply(503, { error: "Hotel payment gateway is not configured." });
  const admin = adminClient();
  const { data: request, error: requestError } = await admin.from("hotel_booking_requests")
    .select("id,shop_id,status,reservation_id,check_in,check_out")
    .eq("id", body.booking_request_id).maybeSingle();
  if (requestError) return reply(503, { error: "Booking status could not be checked." });
  if (!request) return reply(404, { error: "Booking reference not found." });
  if (request.status !== "accepted" || !request.reservation_id)
    return reply(409, { approved: false, pending_approval: request.status === "pending",
      error: request.status === "pending" ? "Your request is awaiting hotel approval. Check again after the hotel confirms it." : "This booking is not approved for payment." });
  const { data: reservation, error: reservationError } = await admin.from("hotel_reservations")
    .select("id,shop_id,check_in,check_out,nightly_rate,status,room_id")
    .eq("id", request.reservation_id).eq("shop_id", request.shop_id).maybeSingle();
  if (reservationError || !reservation || reservation.status === "cancelled" ||
      reservation.check_in !== request.check_in || reservation.check_out !== request.check_out)
    return reply(409, { error: "The approved reservation could not be validated. Contact the hotel." });
  const nights = (Date.parse(reservation.check_out + "T00:00:00Z") - Date.parse(reservation.check_in + "T00:00:00Z")) / 86400000;
  const nightlyPaise = Math.round(Number(reservation.nightly_rate) * 100);
  const amount = nightlyPaise * nights;
  if (!Number.isSafeInteger(amount) || amount < 100 || amount > 10000000000)
    return reply(400, { error: "The hotel has not configured a valid payable room total." });
  const { data: prior, error: priorError } = await admin.from("hotel_payment_records")
    .select("id,amount,payment_status,gateway_order_id,gateway_payment_id")
    .eq("booking_request_id", request.id).order("created_at", { ascending: false }).limit(1).maybeSingle();
  if (priorError) return reply(503, { error: "Payment status could not be checked." });
  const { data: alreadyPaid, error: paidLookupError } = await admin.from("hotel_payment_records")
    .select("id").eq("booking_request_id", request.id).eq("payment_status", "verified").limit(1).maybeSingle();
  if (paidLookupError) return reply(503, { error: "Payment history could not be checked." });
  if (alreadyPaid || prior?.payment_status === "verified")
    return reply(200, { verified: true, payment_id: alreadyPaid?.id || prior?.id, message: "Payment already verified." });

  // Initialize once before the insert/recovery branch. A concurrent request may
  // already have created the pending Razorpay order; preserve that order ID.
  let paymentId = prior?.payment_status === "pending" ? prior.id as string : undefined;
  let orderId = prior?.gateway_order_id || "";
  if (prior?.payment_status === "pending" && Math.round(Number(prior.amount) * 100) !== amount)
    return reply(409, { error: "The reservation total changed. Ask the hotel to review the booking before payment." });
  if (!paymentId) {
    const { data: created, error: createError } = await admin.from("hotel_payment_records").insert({
      shop_id: request.shop_id, booking_request_id: request.id, reservation_id: reservation.id,
      amount: (amount / 100).toFixed(2), currency: "INR", payment_status: "pending", gateway: "razorpay",
    }).select("id").single();
    if (createError || !created) {
      const { data: concurrent } = await admin.from("hotel_payment_records")
        .select("id,amount,payment_status,gateway_order_id").eq("booking_request_id", request.id)
        .eq("payment_status", "pending").maybeSingle();
      if (!concurrent) return reply(503, { error: "Could not prepare the hotel payment. Please retry." });
      if (Math.round(Number(concurrent.amount) * 100) !== amount)
        return reply(409, { error: "A pending payment exists for a different reservation total. Ask the hotel to review it." });
      paymentId = concurrent.id;
      orderId = concurrent.gateway_order_id || "";
    } else paymentId = created.id;
  }
  if (!orderId) {
    const receipt = "hotel_" + paymentId.replaceAll("-", "").slice(0, 32);
    try {
      const response = await fetch("https://api.razorpay.com/v1/orders", {
        method: "POST",
        headers: { "Authorization": "Basic " + btoa(keyId + ":" + keySecret), "Content-Type": "application/json" },
        body: JSON.stringify({ amount, currency: "INR", receipt, notes: {
          app: "Smart Business Pro Hotel", hotel_payment_id: paymentId, booking_request_id: request.id,
          reservation_id: reservation.id, shop_id: request.shop_id,
        } }),
      });
      const result = await response.json();
      if (!response.ok || !result.id || result.amount !== amount || result.currency !== "INR")
        throw new Error("Gateway order did not match the expected amount.");
      const { data: saved, error: saveError } = await admin.from("hotel_payment_records")
        .update({ gateway_order_id: String(result.id), updated_at: new Date().toISOString() })
        .eq("id", paymentId).eq("payment_status", "pending").is("gateway_order_id", null)
        .select("gateway_order_id").maybeSingle();
      if (saveError) return reply(503, { error: "Could not securely link the payment order. Retry the same booking." });
      if (saved?.gateway_order_id) orderId = saved.gateway_order_id;
      else {
        const { data: latest } = await admin.from("hotel_payment_records").select("gateway_order_id,payment_status")
          .eq("id", paymentId).maybeSingle();
        if (!latest?.gateway_order_id || latest.payment_status !== "pending")
          return reply(409, { error: "Payment order changed. Refresh the booking page." });
        orderId = latest.gateway_order_id;
      }
    } catch (error) {
      console.error("Hotel Razorpay order creation failed", String(error).slice(0, 500));
      return reply(502, { error: "Razorpay could not create the payment order. No payment was collected." });
    }
  }
  return reply(200, { key_id: keyId, order_id: orderId, payment_id: paymentId, amount,
    currency: "INR", name: "Smart Business Pro", description: "Hotel room booking",
    prefill: {}, notes: { booking_request_id: request.id } });
});
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try { return await handler(req); }
  catch (error) { console.error("Hotel checkout error", String(error).slice(0, 800)); return reply(500, { error: "Hotel checkout service is temporarily unavailable." }); }
});
