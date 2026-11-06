import { withSupabase } from "npm:@supabase/server@1";
import { createClient } from "npm:@supabase/supabase-js@2";
const cors = {
  "Access-Control-Allow-Origin": "https://smartdigitalseva05-hash.github.io",
  "Vary": "Origin",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};
function reply(status: number, body: Record<string, unknown>) { return new Response(JSON.stringify(body), { status, headers: cors }); }
function adminClient() {
  const raw = Deno.env.get("SUPABASE_SECRET_KEYS") || ""; let secret = "";
  try { const parsed = JSON.parse(raw); if (typeof parsed?.default === "string") secret = parsed.default; } catch {}
  secret ||= Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
  const url = Deno.env.get("SUPABASE_URL") || "";
  if (!url || !secret) throw new Error("Server credentials unavailable.");
  return createClient(url, secret, { auth: { autoRefreshToken: false, persistSession: false } });
}
async function hmacHex(secret: string, message: string) {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const sig = new Uint8Array(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(message)));
  return Array.from(sig).map(x => x.toString(16).padStart(2, "0")).join("");
}
function safeEqual(a: string,b: string) { if(a.length!==b.length)return false;let d=0;for(let i=0;i<a.length;i++)d|=a.charCodeAt(i)^b.charCodeAt(i);return d===0; }
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const handler = withSupabase({ auth: "none" }, async (req) => {
  if(req.method!=="POST")return reply(405,{error:"Method not allowed."});
  if(!(req.headers.get("content-type")||"").toLowerCase().startsWith("application/json"))return reply(415,{error:"JSON content type required."});
  const raw=await req.text();if(raw.length>8192)return reply(413,{error:"Request too large."});
  let body:Record<string,unknown>;try{body=JSON.parse(raw)}catch{return reply(400,{error:"Invalid JSON."})}
  if(typeof body.payment_id!=="string"||!uuid.test(body.payment_id)||typeof body.booking_request_id!=="string"||!uuid.test(body.booking_request_id)||
     typeof body.razorpay_order_id!=="string"||!/^order_[A-Za-z0-9]+$/.test(body.razorpay_order_id)||
     typeof body.razorpay_payment_id!=="string"||!/^pay_[A-Za-z0-9]+$/.test(body.razorpay_payment_id)||
     typeof body.razorpay_signature!=="string"||!/^[a-f0-9]{64}$/i.test(body.razorpay_signature))
    return reply(400,{error:"Invalid payment verification fields."});
  const keyId=Deno.env.get("RAZORPAY_KEY_ID")||"",keySecret=Deno.env.get("RAZORPAY_KEY_SECRET")||"";
  if(!keyId||!keySecret)return reply(503,{error:"Payment gateway is not configured."});
  const admin=adminClient();
  const {data:p,error}=await admin.from("hotel_payment_records").select("id,shop_id,booking_request_id,reservation_id,amount,currency,payment_status,gateway,gateway_order_id,gateway_payment_id")
    .eq("id",body.payment_id).eq("booking_request_id",body.booking_request_id).maybeSingle();
  if(error||!p)return reply(404,{verified:false,error:"Hotel payment reference not found."});
  if(p.payment_status==="verified")return reply(200,{verified:true,payment_id:p.id,message:"Payment already verified."});
  const { error: limitError } = await admin.rpc("consume_payment_endpoint_rate_limit", {
    p_user_id: p.booking_request_id, p_action: "verify",
  });
  if (limitError) {
    if (limitError.code === "PT429") return reply(429,{verified:false,error:"Too many verification attempts for this booking. Please wait 15 minutes and retry."});
    return reply(503,{verified:false,error:"Payment protection is temporarily unavailable. Please retry later."});
  }
  if(p.payment_status!=="pending"||p.gateway!=="razorpay"||p.currency!=="INR"||p.gateway_order_id!==body.razorpay_order_id||!p.reservation_id)
    return reply(409,{verified:false,error:"Payment does not match the approved hotel reservation."});
  const expected=await hmacHex(keySecret,p.gateway_order_id+"|"+body.razorpay_payment_id);
  if(!safeEqual(expected,String(body.razorpay_signature).toLowerCase()))return reply(400,{verified:false,error:"Razorpay signature verification failed."});
  let gatewayPayment:Record<string,unknown>;
  try{
    const response=await fetch("https://api.razorpay.com/v1/payments/"+encodeURIComponent(body.razorpay_payment_id),{headers:{Authorization:"Basic "+btoa(keyId+":"+keySecret)}});
    const result=await response.json();if(!response.ok)throw new Error("Gateway lookup failed.");gatewayPayment=result;
  }catch{return reply(502,{verified:false,error:"Could not confirm payment with Razorpay. Retry verification later."})}
  const expectedPaise=Math.round(Number(p.amount)*100);
  if(gatewayPayment.order_id!==p.gateway_order_id||gatewayPayment.currency!=="INR"||Number(gatewayPayment.amount)!==expectedPaise||
     gatewayPayment.status!=="captured"||gatewayPayment.captured!==true||gatewayPayment.id!==body.razorpay_payment_id)
    return reply(409,{verified:false,error:"Razorpay has not confirmed the exact captured booking amount."});
  const {data:changed,error:updateError}=await admin.from("hotel_payment_records").update({
    payment_status:"verified",gateway_payment_id:String(gatewayPayment.id),verified_at:new Date().toISOString(),updated_at:new Date().toISOString()
  }).eq("id",p.id).eq("payment_status","pending").is("gateway_payment_id",null).select("id").maybeSingle();
  if(updateError)return reply(503,{verified:false,error:"Verified payment could not be recorded. Contact support with your booking reference."});
  if(!changed){
    const {data:latest}=await admin.from("hotel_payment_records").select("payment_status,gateway_payment_id").eq("id",p.id).maybeSingle();
    if(latest?.payment_status==="verified"&&latest.gateway_payment_id===gatewayPayment.id)return reply(200,{verified:true,payment_id:p.id,message:"Payment already verified."});
    return reply(409,{verified:false,error:"Payment state changed. Contact hotel support before retrying."});
  }
  return reply(200,{verified:true,payment_id:p.id,message:"Hotel booking payment verified."});
});
Deno.serve(async(req)=>{if(req.method==="OPTIONS")return new Response("ok",{headers:cors});try{return await handler(req)}catch(error){console.error("Hotel verification error",String(error).slice(0,800));return reply(500,{verified:false,error:"Hotel payment verification service is temporarily unavailable."})}});
