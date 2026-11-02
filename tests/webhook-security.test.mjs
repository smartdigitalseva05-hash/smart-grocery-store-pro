import { test } from "node:test";
import assert from "node:assert/strict";
import { createHmac, webcrypto } from "node:crypto";
globalThis.crypto ??= webcrypto;
const { readBodyLimited, hmacHex, safeEqual } = await import("../supabase/functions/razorpay-payment-webhook/security-utils.js");

function request(chunks, headers = {}) {
  return {
    headers: new Headers(headers),
    body: new ReadableStream({
      start(controller) {
        for (const chunk of chunks) controller.enqueue(chunk);
        controller.close();
      },
    }),
  };
}

test("reads a body within the configured byte limit", async () => {
  const result = await readBodyLimited(request([new TextEncoder().encode("abc")]), 3);
  assert.equal(result.error, undefined);
  assert.equal(new TextDecoder().decode(result.bytes), "abc");
});

test("rejects an oversized declared Content-Length before reading", async () => {
  const result = await readBodyLimited(request([new TextEncoder().encode("x")], { "content-length": "1048577" }), 1048576);
  assert.equal(result.error, "too_large");
});

test("rejects an oversized streamed body when Content-Length is absent", async () => {
  const result = await readBodyLimited(request([new Uint8Array([1, 2, 3]), new Uint8Array([4, 5])]), 4);
  assert.equal(result.error, "too_large");
});

test("accepts a body exactly at the byte limit", async () => {
  const result = await readBodyLimited(request([new Uint8Array([1, 2, 3, 4])]), 4);
  assert.equal(result.error, undefined);
  assert.deepEqual(Array.from(result.bytes), [1, 2, 3, 4]);
});

test("rejects malformed Content-Length", async () => {
  const result = await readBodyLimited(request([], { "content-length": "-1" }), 10);
  assert.equal(result.error, "invalid_content_length");
});

test("HMAC-SHA256 matches the standard test vector using exact raw bytes", async () => {
  const secret = "key";
  const body = new TextEncoder().encode("The quick brown fox jumps over the lazy dog");
  const expected = "f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8";
  assert.equal(await hmacHex(secret, body), expected);
  assert.equal(createHmac("sha256", secret).update(body).digest("hex"), expected);
});

test("signature comparison accepts equal strings and rejects mismatches", () => {
  assert.equal(safeEqual("a".repeat(64), "a".repeat(64)), true);
  assert.equal(safeEqual("a".repeat(64), "b".repeat(64)), false);
  assert.equal(safeEqual("short", "longer"), false);
});
