import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";

const root = process.cwd();
const pages = [
  "index.html", "owner.html", "apply-shop.html", "shopkeeper.html",
  "portal.html", "showcase.html", "catalogue.html", "demo-store.html",
  "digital-service-request.html", "electronics-repair.html", "hotel-booking.html",
  "my-orders.html", "restaurant-booking.html", "shopkeeper-benefits.html", "business-category.html",
  "customer-manual-odia.html", "manual-center.html", "owner-id-center.html", "owner-profile.html",
  "owner-profile/index.html", "shopkeeper-manual-odia.html", "storefront.html",
  "super-admin-manual-english.html", "super-admin-manual-odia.html", "verify-owner.html",
  "googlee231ccb6a07a2d79.html", "googlee231ccb6a07a2d79 (1).html"
];
const publicScripts = ["password-security.js", "starter-catalogues.js"];
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
    const scriptType = attrs.match(/\\btype=["']([^"']+)["']/i)?.[1]?.toLowerCase();
    if (!code.trim() || scriptType === "module" ||
        (scriptType && !["text/javascript","application/javascript"].includes(scriptType))) continue;
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
const starterSource = read("starter-catalogues.js");
const starterSandbox = { window: {} };
vm.runInNewContext(starterSource, starterSandbox, { filename: "starter-catalogues.js" });
const starterCatalogues = starterSandbox.window.SMART_BUSINESS_STARTER_CATALOGUES;
assert(starterCatalogues && typeof starterCatalogues === "object", "Starter catalogue data is not exposed.");
for (const [key] of categories) {
  const items = starterCatalogues[key];
  assert(Array.isArray(items) && items.length === 200, key + " must have exactly 200 starter catalogue items.");
  const names = items.map(item => String(item.name || "").trim().toLowerCase());
  assert(names.every(Boolean) && new Set(names).size === 200, key + " starter catalogue names must be non-empty and unique.");
  assert(items.every(item => item.category && Number.isFinite(Number(item.price)) && Number(item.price) > 0),
    key + " starter catalogue items must include category and positive suggested price.");
}
const shopkeeperCatalogue = read("shopkeeper.html");
assert(shopkeeperCatalogue.includes('<script src="./starter-catalogues.js"></script>'),
  "Shopkeeper dashboard must load the shared category starter catalogues.");
assert(shopkeeperCatalogue.includes("STARTER_CATALOGUES[currentShop?.business_type]"),
  "Shopkeeper dashboard must use the selected shop's business type catalogue.");
assert(shopkeeperCatalogue.includes("bulkStarterSelection.clear();loadShopData()"),
  "Switching shops must clear selected starter items before loading the next shop.");
assert(shopkeeperCatalogue.includes('replace(/\\bdaal\\b/g,"dal")'),
  "Bulk catalogue import must normalize common Dal/Daal spelling duplicates.");
assert(shopkeeperCatalogue.includes("images:[],is_available:false"),
  "Bulk catalogue imports must remain hidden drafts without unverified images.");
const pagesWorkflow = read(".github/workflows/pages.yml");
assert(pagesWorkflow.includes("password-security.js starter-catalogues.js .pages-site/"),
  "GitHub Pages artifact must include the shared starter catalogue script.");
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
for (const [key] of categories) {
  assert(registration.includes('value="' + key + '"'), "Registration is missing business type: " + key);
  assert(workspace.includes(key + ":{name:"), "Shopkeeper workspace is missing category config: " + key);
  assert(owner.includes('key:"' + key + '"'), "Owner category controls are missing: " + key);
}
// Customer accounts are permanently connected to one shop; customers must not browse category-wide shop listings.
assert(storefront.includes("connected_shop_id"), "Customer storefront must use the permanent connected-shop binding.");
assert(storefront.includes("profile.connected_shop_id"), "Customer storefront must load the customer's connected shop.");
assert(!storefront.includes('id="businessTypeFilter"'), "Customer storefront must not expose a business-category filter.");
assert(categoryLanding.includes("Customers cannot browse shops by business category"),
  "Category landing page must explain that customers join through a shopkeeper QR/link.");
assert(categoryLanding.includes("./portal.html"), "Category landing page must link back to the business portal.");

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
assert(workspace.includes('id="customerDirectoryPanel"'), "Shopkeeper workspace is missing the customer contact book.");
assert(workspace.includes('id="customerDirectorySearch"'), "Customer contact book is missing its search control.");
assert(workspace.includes('recentShopOrders= data||[]') || workspace.includes('recentShopOrders=data||[]'),
  "Customer contact book must use the current shop's loaded order result.");
assert(workspace.includes('eq("shop_id",currentShop.id)'), "Shopkeeper customer/order queries must remain scoped to the selected shop.");
assert(workspace.includes("function renderCustomerDirectory("), "Shopkeeper customer contact renderer is missing.");
assert(workspace.includes('id="customerDirectoryRefresh"'), "Customer contact refresh control is missing.");
assert(workspace.includes('id="financialSummaryPanel"'), "Shopkeeper financial summary panel is missing.");
assert(workspace.includes('id="financialPeriod"'), "Financial summary period selector is missing.");
assert(workspace.includes("async function loadFinancialSummary()"), "Shop-scoped financial summary loader is missing.");
assert(workspace.includes('db.from("orders").select("id,total,status,payment_status,created_at").eq("shop_id",currentShop.id)'), "Financial summary must query only the selected shop.");
assert(workspace.includes('addEventListener("change",loadFinancialSummary)'), "Financial summary period selector is not wired.");

assert(workspace.includes('select("id,name,description,category_id,price,sale_price,stock,is_available,offer_text,images")'),
  "Product manager must load the fields required for complete product editing.");
assert(workspace.includes('textContent="Edit product details"'), "Shopkeeper product manager is missing full detail editing.");
assert(workspace.includes("category_id:selectedCategory?.value||null"), "Product editing must support category reassignment.");
assert(workspace.includes("description:description.trim()||null"), "Product editing must support description changes.");
assert(workspace.includes('id="orderStatusFilter"'), "Shopkeeper order manager is missing the status filter.");
assert(workspace.includes('id="orderSearch"'), "Shopkeeper order manager is missing order search.");
assert(workspace.includes("const visibleOrders=data.filter(o=>"), "Shopkeeper order filters must be applied to the selected shop's fetched orders.");
assert(workspace.includes('db.from("order_status_history").select("old_status,new_status,reason,created_at").eq("order_id",o.id)'), "Delivery timeline must read status history for the selected order only.");
assert(workspace.includes('textContent="View delivery timeline"'), "Shopkeeper order cards must expose delivery timeline control.");
assert(workspace.includes("for(const o of visibleOrders)"), "Shopkeeper order renderer must use filtered orders.");
assert(workspace.includes('!["grocery","daily_needs"].includes(shop.business_type)'), "Supplier/purchase panel must be limited to Grocery and Daily Needs shops.");
assert(workspace.includes('!["grocery","daily_needs"].includes(currentShop.business_type)'), "Supplier/purchase loader must enforce the same category allowlist.");
assert(workspace.includes('id="procurementHeading"'), "Supplier/purchase panel must show its category-specific heading.");
assert(workspace.includes('textContent="Add a product or service"'), "Other Businesses must have product/service catalogue wording.");
assert(workspace.includes('textContent="Add a Daily Needs item"'), "Daily Needs must have category-specific item creation wording.");
assert(workspace.includes('id="productNameLabel"'), "Category-specific product/service naming label is missing.");
assert(workspace.includes('category:categories(name)'), "Inventory CSV must resolve category names through the products.category_id foreign key.");
assert(workspace.includes('x.category?.name||""'), "Inventory CSV must export the joined category name safely.");

assert(workspace.includes('id="customerDirectoryRefresh"'), "Customer contact refresh control is missing.");

// Verify every category-specific manager is wired into the selected-shop refresh cycle.
const categoryLoaders = [
  ["Restaurant tables", "loadRestaurantTables"], ["Restaurant reservations", "loadRestaurantReservations"],
  ["Restaurant menu", "loadRestaurantMenu"], ["Restaurant ticket options", "loadRestaurantTicketOptions"],
  ["Restaurant kitchen", "loadRestaurantKitchen"], ["Hotel rooms", "loadHotelRooms"],
  ["Hotel reservations", "loadHotelReservations"], ["Hotel booking requests", "loadHotelBookingRequests"],
  ["Hotel housekeeping", "loadHotelHousekeepingTasks"], ["Office employees", "loadOfficeEmployees"],
  ["Office attendance", "loadOfficeAttendance"], ["Office leave requests", "loadOfficeLeaveRequests"],
  ["Office payroll", "loadOfficePayroll"], ["Office tasks", "loadOfficeTasks"],
  ["Electronics inventory", "loadElectronicsInventory"], ["Electronics repair jobs", "loadElectronicsServiceJobs"],
  ["Medical batches", "loadMedicalBatches"], ["Digital service applications", "loadDigitalApplications"],
  ["Supplier procurement", "loadGroceryProcurement"], ["Customer credit book", "loadCustomerCredit"]
];
const shopRefreshStart = workspace.indexOf("async function loadShopData()");
const shopRefresh = workspace.slice(shopRefreshStart, shopRefreshStart + 5000);
for (const [label, loader] of categoryLoaders) {
  assert(workspace.includes("async function " + loader + "("), "Missing category manager loader: " + label);
  assert(shopRefresh.includes("await " + loader + "("), "Selected-shop refresh does not load: " + label);
}
for (const [, loader] of categoryLoaders) {
  const start = workspace.indexOf("async function " + loader + "(");
  const next = workspace.indexOf("\nasync function ", start + 20);
  const body = workspace.slice(start, next < 0 ? start + 12000 : next);
  assert(body.includes('.eq("shop_id",currentShop.id)') || body.includes(".eq('shop_id',currentShop.id)"),
    loader + " must query only the currently selected shop.");
}
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
