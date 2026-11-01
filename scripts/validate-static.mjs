import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";

const root = process.cwd();
const pages = [
  "index.html", "owner.html", "apply-shop.html", "shopkeeper.html",
  "portal.html", "showcase.html", "catalogue.html", "demo-store.html",
  "digital-service-request.html", "electronics-repair.html", "hotel-booking.html",
  "my-orders.html", "restaurant-booking.html", "shopkeeper-benefits.html"
];
const categories = [
  ["grocery", "Grocery"], ["daily_needs", "Daily Needs"], ["garments", "Garments"],
  ["jewellery", "Jewellery"], ["restaurant", "Restaurant"], ["hotel", "Hotel"],
  ["office_company", "Office / Company"], ["electronics", "Electronics"],
  ["medical", "Medical"], ["digital_services", "Digital Services"], ["other", "Other Businesses"]
];
let checks = 0;
function assert(condition, message) {
  checks++;
  if (!condition) throw new Error(message);
}
for (const page of pages) {
  const file = path.join(root, page);
  assert(fs.existsSync(file), `Missing required page: ${page}`);
  const html = fs.readFileSync(file, "utf8");
  const ids = [...html.matchAll(/\\bid=["']([^"']+)["']/g)].map(m => m[1]);
  const duplicateIds = ids.filter((id, index) => ids.indexOf(id) !== index);
  assert(duplicateIds.length === 0, `${page}: duplicate element IDs: ${[...new Set(duplicateIds)].join(", ")}`);
  let scriptIndex = 0;
  for (const match of html.matchAll(/<script\\b([^>]*)>([\\s\\S]*?)<\\/script>/gi)) {
    const attrs = match[1] || "";
    const code = match[2] || "";
    if (!code.trim() || /type=["']module["']/i.test(attrs)) continue;
    scriptIndex++;
    try { new vm.Script(code, { filename: `${page} inline script #${scriptIndex}` }); }
    catch (error) { throw new Error(`${page} inline script #${scriptIndex}: ${error.message}`); }
    checks++;
  }
}
const registration = fs.readFileSync(path.join(root, "apply-shop.html"), "utf8");
const workspace = fs.readFileSync(path.join(root, "shopkeeper.html"), "utf8");
const owner = fs.readFileSync(path.join(root, "owner.html"), "utf8");
const portal = fs.readFileSync(path.join(root, "portal.html"), "utf8");
for (const [key, label] of categories) {
  assert(registration.includes(`value="${key}"`), `Registration is missing business type: ${key}`);
  assert(workspace.includes(`${key}:{name:`), `Shopkeeper workspace is missing category config: ${key}`);
  assert(owner.includes(`key:"${key}"`), `Owner category controls are missing: ${key}`);
  assert(portal.includes(`<h3>${label}</h3>`), `Portal category card is missing: ${label}`);
}
console.log(`Static validation passed: ${checks} checks across ${pages.length} pages and ${categories.length} business categories.`);
