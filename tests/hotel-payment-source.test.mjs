import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const checkout = readFileSync("supabase/functions/hotel-payment-checkout/index.ts", "utf8");
const verify = readFileSync("supabase/functions/hotel-payment-verify/index.ts", "utf8");

test("hotel checkout preserves an order created by a concurrent request", () => {
  const declaration = checkout.indexOf("let orderId = prior?.gateway_order_id ||");
  const recovery = checkout.indexOf("if (createError || !created)");
  const reuse = checkout.indexOf("orderId = concurrent.gateway_order_id ||");
  assert.notEqual(declaration, -1, "orderId must be initialized");
  assert.ok(declaration < recovery, "orderId must be initialized before insert recovery");
  assert.notEqual(reuse, -1, "the concurrent pending order ID must be reused");
});

test("hotel checkout guards payment ID before creating a Razorpay order", () => {
  const guard = checkout.indexOf('if (!paymentId) return reply(503');
  const receipt = checkout.indexOf('const receipt = "hotel_" + paymentId.replaceAll');
  assert.notEqual(guard, -1, "payment ID guard must exist");
  assert.ok(guard < receipt, "payment ID must be checked before receipt construction");
});

test("guest hotel payment endpoints enforce per-booking limits and fail closed", () => {
  assert.match(checkout, /consume_payment_endpoint_rate_limit/);
  assert.match(checkout, /p_user_id:\s*request\.id,\s*p_action:\s*"checkout"/);
  assert.match(verify, /consume_payment_endpoint_rate_limit/);
  assert.match(verify, /p_user_id:\s*p\.booking_request_id,\s*p_action:\s*"verify"/);
  assert.match(checkout, /Payment protection is temporarily unavailable/);
  assert.match(verify, /Payment protection is temporarily unavailable/);
});
