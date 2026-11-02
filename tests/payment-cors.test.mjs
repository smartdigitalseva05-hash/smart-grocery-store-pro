import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const productionOrigin = "https://smartdigitalseva05-hash.github.io";
const functions = [
  ["checkout", new URL("../supabase/functions/razorpay-subscription-checkout/index.ts", import.meta.url)],
  ["payment verification", new URL("../supabase/functions/razorpay-verify-subscription-payment/index.ts", import.meta.url)]
];

for (const [label, path] of functions) {
  const source = await readFile(path, "utf8");

  test(`${label}: CORS is restricted to the production frontend origin`, () => {
    assert.ok(source.includes(`"Access-Control-Allow-Origin": "${productionOrigin}"`));
    assert.ok(source.includes('"Vary": "Origin"'));
    assert.ok(!source.includes('"Access-Control-Allow-Origin": "*"'));
  });

  test(`${label}: request body is capped at 16 KiB`, () => {
    assert.ok(source.includes("readBodyLimited(req, 16 * 1024)"));
    assert.ok(source.includes("Request body exceeds the 16 KiB limit."));
  });
}
