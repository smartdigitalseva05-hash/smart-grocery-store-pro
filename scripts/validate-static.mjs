import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";

const root = process.cwd();
const pages = [
  "index.html", "owner.html", "apply-shop.html", "shopkeeper.html",
  "portal.html", "showcase.html", "catalogue.html", "demo-store.html",
  "digital-service-request.html", "electronics-repair.html", "hotel-booking.html",
  "my-orders.html", "restaurant-booking.html", "shopkeeper-benefits.html", "business-category.html"
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
    if (!raw || raw.includes("${") || raw.includes("{{") || raw.startsWith("//") || raw.startsWith("#") || /^[a-z][a-z0-9+.-]*:/i.test(raw)) continue;
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
const storefront = read("index.html");
const categoryLanding = read("business-category.html");
for (const [key, label] of categories) {
  assert(registration.includes('value="' + key + '"'), "Registration is missing business type: " + key);
  assert(workspace.includes(key + ":{name:"), "Shopkeeper workspace is missing category config: " + key);
  assert(owner.includes('key:"' + key + '"'), "Owner category controls are missing: " + key);
  assert(portal.includes("<h3>" + label + "</h3>"), "Portal category card is missing: " + label);
}
assert(storefront.includes('id="businessTypeFilter"'), "Customer storefront is missing its business-category filter.");
assert(storefront.includes("p.shop?.business_type === selectedBusinessType"),
  "Customer storefront must filter products by the selected shop business type.");

const categorySlugs = [
  "grocery", "daily-needs", "garments", "jewellery", "restaurant", "hotel",
  "office-company", "electronics", "medical", "digital-services", "other-businesses"
];
for (const slug of categorySlugs) {
  assert(categoryLanding.includes('"' + slug + '"'), "Dedicated category landing page is missing: " + slug);
  assert(portal.includes("business-category.html?category=" + slug),
    "Portal category card is missing its dedicated URL: " + slug);
}
assert(categoryLanding.includes('id="apply"'), "Category landing page is missing category-aware registration link.");
assert(categoryLanding.includes('encodeURIComponent(current.slug)'), "Category registration link must preserve selected category.");

assert(workspace.includes("const cfg=types[shop.business_type]||types.other;"),
  "Unknown business types must use the generic workspace, never inherit Grocery tools.");

const requiredCategoryPanels = [
  ["Restaurant", 'id="restaurantKitchenPanel"'],
  ["Hotel", 'id="hotelManagementPanel"'],
  ["Office / Company", 'id="officeManagementPanel"'],
  ["Electronics", 'id="electronicsManagementPanel"'],
  ["Medical", 'id="medicalManagementPanel"'],
  ["Digital Services", 'id="digitalSevaPanel"']
];
for (const [label, marker] of requiredCategoryPanels) {
  assert(workspace.includes(marker), "Shopkeeper workspace is missing the " + label + " module panel.");
}
assert(workspace.includes("function renderVariants("), "Garments variant renderer is missing.");
assert(workspace.includes("function loadJewelleryDetails("), "Jewellery detail loader is missing.");

const shopkeeperForms = [...workspace.matchAll(/<form\b[^>]*\bid=["']([^"']+)["']/g)].map(match => match[1]);
const shopkeeperSubmitHandlers = new Set(
  [...workspace.matchAll(/\$\(["']([^"']+Form)["']\)\.addEventListener\(["']submit["']/g)].map(match => match[1])
);
for (const formId of shopkeeperForms) {
  assert(shopkeeperSubmitHandlers.has(formId), "Shopkeeper form has no submit handler: " + formId);
}
assert(!/from\(["']shop_credit_ledger["']\)[\s\S]{0,160}\.(?:update|delete)\(/i.test(workspace),
  "Shop credit ledger must remain append-only in the shopkeeper client.");
console.log("Static validation passed: " + checks + " checks across " + pages.length + " pages, " + publicScripts.length + " public scripts and " + categories.length + " business categories.");
