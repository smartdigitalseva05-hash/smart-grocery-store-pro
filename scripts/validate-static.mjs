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
const publicScripts = ["password-security.js"];
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
function read(file) {
  const full = path.join(root, file);
  assert(fs.existsSync(full), "Missing required file: " + file);
  return fs.readFileSync(full, "utf8");
}
for (const page of pages) {
  const html = read(page);
  const ids = [...html.matchAll(/\bid=["']([^"']+)["']/g)].map(m => m[1]);
  const duplicateIds = ids.filter((id, index) => ids.indexOf(id) !== index);
  assert(duplicateIds.length === 0, page + ": duplicate element IDs: " + [...new Set(duplicateIds)].join(", "));
  let scriptIndex = 0;
  for (const match of html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi)) {
    const attrs = match[1] || "";
    const code = match[2] || "";
    if (!code.trim() || /type=["']module["']/i.test(attrs)) continue;
    scriptIndex++;
    try { new vm.Script(code, { filename: page + " inline script #" + scriptIndex }); }
    catch (error) { throw new Error(page + " inline script #" + scriptIndex + ": " + error.message); }
    checks++;
  }

  // Catch broken static local links and assets before publishing to GitHub Pages.
  for (const match of html.matchAll(/\b(?:href|src)=["']([^"']+)["']/gi)) {
    const raw = match[1].trim();
    if (!raw || raw.includes("${") || raw.includes("{{") || /^(?:#|[a-z][a-z0-9+.-]*:|\\/\\/)/i.test(raw)) continue;
    const pathname = decodeURIComponent(raw.split(/[?#]/, 1)[0]);
    if (!pathname) continue;
    const target = path.resolve(root, path.dirname(page), pathname);
    assert(target === root || target.startsWith(root + path.sep), page + ": link escapes repository: " + raw);
    assert(fs.existsSync(target), page + ": broken local link/asset: " + raw);
  }

  // External links opened in a new tab must not expose window.opener.
  for (const match of html.matchAll(/<a\b[^>]*>/gi)) {
    const tag = match[0];
    if (/target=["']_blank["']/i.test(tag)) {
      assert(/rel=["'][^"']*\bnoopener\b/i.test(tag), page + ": target=_blank anchor is missing rel=noopener");
    }
  }
}

for (const file of publicScripts) read(file);
const publicFiles = [...pages, ...publicScripts];
const secretPatterns = [
  /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/,
  /\bsb_secret_[A-Za-z0-9_-]{16,}/,
  /(?:SUPABASE_)?SERVICE_ROLE_KEY\s*[:=]\s*["'][^"']{12,}["']/i,
  /RAZORPAY_KEY_SECRET\s*[:=]\s*["'][^"']{8,}["']/i,
  /\brzp_live_[A-Za-z0-9]{12,}/i
];
for (const file of publicFiles) {
  const source = read(file);
  for (const pattern of secretPatterns) {
    assert(!pattern.test(source), file + ": possible private credential detected (" + pattern + ")");
  }
}

const registration = read("apply-shop.html");
const workspace = read("shopkeeper.html");
const owner = read("owner.html");
const portal = read("portal.html");
for (const [key, label] of categories) {
  assert(registration.includes('value="' + key + '"'), "Registration is missing business type: " + key);
  assert(workspace.includes(key + ":{name:"), "Shopkeeper workspace is missing category config: " + key);
  assert(owner.includes('key:"' + key + '"'), "Owner category controls are missing: " + key);
  assert(portal.includes("<h3>" + label + "</h3>"), "Portal category card is missing: " + label);
}
console.log("Static validation passed: " + checks + " checks across " + pages.length + " pages, " + publicScripts.length + " public scripts and " + categories.length + " business categories.");
