import test from "node:test";
import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";

const applied = [
  "20261105170640_add_restaurant_pos_billing.sql",
  "20261105170814_harden_restaurant_pos_checkout.sql",
  "20261105170900_add_restaurant_pos_idempotency.sql",
  "20261105171542_add_hotel_medical_repair_payroll_controls.sql",
  "20261105171602_index_hotel_medical_compliance_relations.sql",
  "20261106042203_hotel_payment_one_pending_request.sql",
];
const stale = [
  "20261105200000_add_restaurant_pos_billing.sql",
  "20261105201500_harden_restaurant_pos_checkout.sql",
  "20261105203000_add_restaurant_pos_idempotency.sql",
];

test("all recently applied production migrations have exact-version source files", () => {
  for (const name of applied) {
    const path = `supabase/migrations/${name}`;
    assert.ok(existsSync(path), `missing applied migration source: ${name}`);
    assert.ok(readFileSync(path, "utf8").trim().length > 0, `empty applied migration source: ${name}`);
  }
});

test("unapplied duplicate restaurant POS migration timestamps are absent", () => {
  for (const name of stale) assert.equal(existsSync(`supabase/migrations/${name}`), false, `stale duplicate migration remains: ${name}`);
});
