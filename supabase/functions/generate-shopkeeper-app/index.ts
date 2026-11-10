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
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const handler = withSupabase({ auth: "user" }, async (req, ctx) => {
  if (req.method !== "POST") return reply(405, { error: "Method not allowed." });
  const { data: authData, error: authError } = await ctx.supabase.auth.getUser();
  if (authError || !authData.user) return reply(401, { error: "Sign in again to continue." });

  // This RPC requires active Super Admin role AND AAL2 MFA in the signed JWT.
  const { data: ownerAllowed, error: ownerError } = await ctx.supabase.rpc("owner_dashboard_summary");
  if (ownerError || !ownerAllowed) return reply(403, { error: "Owner access with verified authenticator MFA is required." });

  const origin = req.headers.get("origin") || "";
  if (origin && origin !== "https://smartdigitalseva05-hash.github.io") return reply(403, { error: "Origin not allowed." });
  const declared = Number(req.headers.get("content-length") || "0");
  if (declared > 8192) return reply(413, { error: "Request too large." });
  let body: { shop_id?: string };
  try { body = await req.json(); } catch { return reply(400, { error: "Invalid JSON." }); }
  if (!body || typeof body.shop_id !== "string" || !uuidPattern.test(body.shop_id)) {
    return reply(400, { error: "A valid shop ID is required." });
  }

  const token = Deno.env.get("GITHUB_ACTIONS_TOKEN") || "";
  if (!token) return reply(503, {
    error: "APK builder is not connected yet. Add a GitHub token as Supabase Edge Function secret GITHUB_ACTIONS_TOKEN (Actions: write permission), then retry."
  });

  // Use the authenticated Owner session for database reads. This applies the
  // existing Super Admin RLS policies and avoids a separately configured key.
  const { data: shop, error: shopError } = await ctx.supabase.from("shops")
    .select("id,owner_id,name,status,is_active,subscription_expires_at")
    .eq("id", body.shop_id).maybeSingle();
  if (shopError) {
    console.error("Shop lookup failed", shopError.code, shopError.message);
    return reply(500, { error: "Could not verify the shop record. Refresh the Owner Panel and retry." });
  }
  if (!shop) return reply(404, { error: "Shop not found in the Owner-accessible shop list." });
  if (shop.status !== "active" || shop.is_active !== true ||
      !shop.subscription_expires_at || new Date(shop.subscription_expires_at).getTime() <= Date.now()) {
    return reply(409, { error: "Only an active shop with a current subscription can receive an app." });
  }
  const { data: profile, error: profileError } = await ctx.supabase.from("profiles")
    .select("id,role,is_active").eq("id", shop.owner_id).maybeSingle();
  if (profileError) {
    console.error("Shopkeeper profile lookup failed", profileError.code, profileError.message);
    return reply(500, { error: "Could not verify the linked shopkeeper account. Refresh and retry." });
  }
  if (!profile || profile.role !== "shopkeeper" || profile.is_active !== true) {
    return reply(409, { error: "The linked shopkeeper account is not approved and active." });
  }

  const packageSuffix = String(shop.id).replaceAll("-", "").slice(0, 12).toLowerCase();
  const dispatch = await fetch(
    "https://api.github.com/repos/smartdigitalseva05-hash/smart-grocery-store-pro/actions/workflows/shopkeeper-android-app.yml/dispatches",
    {
      method: "POST",
      headers: {
        "Authorization": "Bearer " + token,
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        ref: "main",
        inputs: { shop_id: shop.id, shop_name: shop.name || "My Shop", package_suffix: packageSuffix },
      }),
    },
  );
  if (!dispatch.ok) {
    const detail = (await dispatch.text()).slice(0, 400);
    console.error("GitHub workflow dispatch failed", dispatch.status, detail);
    return reply(502, { error: "Could not queue the Android build. Check the GitHub token permissions and workflow file." });
  }
  return reply(202, {
    queued: true,
    shop_id: shop.id,
    release_tag: "shopkeeper-" + shop.id,
    package_name: "com.smartbusinesspro.shop.s" + packageSuffix,
    workflow_url: "https://github.com/smartdigitalseva05-hash/smart-grocery-store-pro/actions/workflows/shopkeeper-android-app.yml",
    message: "APK build queued. This shop's APK will appear here after GitHub Actions finishes.",
  });
});

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try { return await handler(req); }
  catch (error) {
    console.error("Shopkeeper APK generation failed", String(error).slice(0, 800));
    return reply(500, { error: "App generation service failed safely. No shop data was changed." });
  }
});
