import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';

const cors = { 'Access-Control-Allow-Origin': 'https://pizza-boyy.github.io', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS', 'Content-Type': 'application/json' };
const reply = (status:number, body:Record<string,unknown>) => new Response(JSON.stringify(body), {status, headers:cors});
const clean = (v:unknown,max=160) => typeof v === 'string' && v.trim().length>0 && v.trim().length<=max;
const phone = (v:unknown) => typeof v==='string' && /^[+0-9 ()-]{6,25}$/.test(v.trim());
serve(async req => {
  if(req.method==='OPTIONS') return new Response('ok',{headers:cors});
  if(req.method!=='POST') return reply(405,{error:'Metodo non consentito'});
  try {
    const ip = req.headers.get('cf-connecting-ip') || req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() || 'unknown';
    const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
    const {data:allowed,error:rateError}=await admin.rpc('pb_consume_public_rate_limit',{p_ip:ip});
    if(rateError) throw rateError;
    if(!allowed) return reply(429,{error:'Troppe richieste. Riprova tra qualche minuto.'});
    const body=await req.json();
    if(!body || !['order','booking'].includes(body.type) || !body.payload || typeof body.payload!=='object') return reply(400,{error:'Richiesta non valida'});
    const p=body.payload;
    if(body.type==='order') {
      if(!clean(p.customer,120)||!phone(p.phone)||!Array.isArray(p.items)||p.items.length<1||p.items.length>30) return reply(400,{error:'Dati ordine non validi'});
      if(!['delivery','pickup'].includes(p.mode)) return reply(400,{error:'Modalità ordine non valida'});
      for(const item of p.items) if(!clean(item.name,100)||!Number.isInteger(Number(item.qty))||Number(item.qty)<1||Number(item.qty)>30||!Number.isFinite(Number(item.price))||Number(item.price)<0||Number(item.price)>500) return reply(400,{error:'Prodotto o quantità non validi'});
      if(!Number.isFinite(Number(p.total))||Number(p.total)<0||Number(p.total)>2000) return reply(400,{error:'Totale non valido'});
      const {data,error}=await admin.from('pb_orders').insert({payload:p,status:'Nuovo'}).select('id,created_at').single();
      if(error) throw error;
      return reply(200,{ok:true,id:data.id,created_at:data.created_at});
    }
    if(!clean(p.name,120)||!phone(p.phone)||!/^\d{4}-\d{2}-\d{2}$/.test(p.date)||!/^\d{2}:\d{2}$/.test(p.time)||!Number.isInteger(Number(p.guests))||Number(p.guests)<1||Number(p.guests)>30) return reply(400,{error:'Dati prenotazione non validi'});
    const {data,error}=await admin.from('pb_bookings').insert({payload:p,status:'In attesa'}).select('id,created_at').single();
    if(error) throw error;
    return reply(200,{ok:true,id:data.id,created_at:data.created_at});
  } catch(e) { console.error(e); return reply(500,{error:'Errore durante l’invio. Riprova.'}); }
});
