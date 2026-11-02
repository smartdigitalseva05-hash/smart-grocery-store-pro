import test from "node:test";
import assert from "node:assert/strict";
import { readBodyLimited as readCheckoutBody } from "../supabase/functions/razorpay-subscription-checkout/security-utils.js";
import { readBodyLimited as readVerifyBody } from "../supabase/functions/razorpay-verify-subscription-payment/security-utils.js";

const readers = [
  ["checkout", readCheckoutBody],
  ["payment verification", readVerifyBody]
];

for (const [label, readBodyLimited] of readers) {
  test(`${label}: accepts a body exactly at the byte limit`, async () => {
    const body = "123456";
    const req = new Request("https://example.test", { method: "POST", body });
    const result = await readBodyLimited(req, 6);
    assert.equal(result.error, undefined);
    assert.equal(new TextDecoder().decode(result.bytes), body);
  });

  test(`${label}: rejects oversized declared Content-Length`, async () => {
    const req = new Request("https://example.test", {
      method: "POST",
      headers: { "content-length": "100" },
      body: "{}"
    });
    const result = await readBodyLimited(req, 10);
    assert.equal(result.error, "too_large");
  });

  test(`${label}: rejects oversized streamed bodies without Content-Length`, async () => {
    const stream = new ReadableStream({
      start(controller) {
        controller.enqueue(new TextEncoder().encode("123456"));
        controller.enqueue(new TextEncoder().encode("789"));
        controller.close();
      }
    });
    const req = new Request("https://example.test", { method: "POST", body: stream, duplex: "half" });
    const result = await readBodyLimited(req, 8);
    assert.equal(result.error, "too_large");
  });

  test(`${label}: rejects malformed Content-Length`, async () => {
    const req = new Request("https://example.test", {
      method: "POST",
      headers: { "content-length": "not-a-number" },
      body: "{}"
    });
    const result = await readBodyLimited(req, 10);
    assert.equal(result.error, "invalid_content_length");
  });
}
