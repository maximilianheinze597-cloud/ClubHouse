import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';
Deno.serve(async (req: Request) => {
 if(req.method==='OPTIONS') return new Response('ok',{headers:corsHeaders});
 if(req.method!=='POST') return new Response(JSON.stringify({error:'method_not_allowed'}),{status:405,headers:{...corsHeaders,'Content-Type':'application/json'}});
 const url=Deno.env.get('SUPABASE_URL'), anon=Deno.env.get('SUPABASE_ANON_KEY'), auth=req.headers.get('Authorization');
 if(!url||!anon) return new Response(JSON.stringify({error:'server_not_configured'}),{status:503,headers:{...corsHeaders,'Content-Type':'application/json'}});
 if(!auth?.startsWith('Bearer ')) return new Response(JSON.stringify({error:'authentication_required'}),{status:401,headers:{...corsHeaders,'Content-Type':'application/json'}});
 try { const body=await req.json(); if(typeof body.packId!=='string'||typeof body.idempotencyKey!=='string') return new Response(JSON.stringify({error:'packId_and_idempotencyKey_required'}),{status:400,headers:{...corsHeaders,'Content-Type':'application/json'}});
 const client=createClient(url,anon,{global:{headers:{Authorization:auth}},auth:{persistSession:false}}); const {data:{user},error:authError}=await client.auth.getUser(); if(authError||!user) return new Response(JSON.stringify({error:'authentication_required'}),{status:401,headers:{...corsHeaders,'Content-Type':'application/json'}});
 const {data,error}=await client.rpc('open_pack',{p_pack_id:body.packId,p_idempotency_key:body.idempotencyKey}); if(error){const status=error.message.includes('insufficient_club_points')?409:error.message.includes('pack_unavailable')?404:400;return new Response(JSON.stringify({error:error.message}),{status,headers:{...corsHeaders,'Content-Type':'application/json'}});} return new Response(JSON.stringify(data),{status:200,headers:{...corsHeaders,'Content-Type':'application/json'}});
 } catch { return new Response(JSON.stringify({error:'invalid_request'}),{status:400,headers:{...corsHeaders,'Content-Type':'application/json'}}); }
});