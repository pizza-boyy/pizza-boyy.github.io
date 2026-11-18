(function(){
  const ready=()=>Boolean(window.PB_SUPABASE_URL&&window.PB_SUPABASE_ANON_KEY&&window.supabase);
  let client=null;
  function db(){if(!ready())throw new Error('Configurazione cloud Supabase mancante.');if(!client)client=window.supabase.createClient(window.PB_SUPABASE_URL,window.PB_SUPABASE_ANON_KEY);return client;}
  async function submit(type,payload){
    const {data,error}=await db().functions.invoke('submit-public',{body:{type,payload}});
    if(error) throw new Error(data?.error||error.message||'Invio non riuscito');
    if(!data?.ok) throw new Error(data?.error||'Invio non riuscito');
    return {...payload,id:payload.id||data.id,createdAt:data.created_at};
  }
  async function list(table){const {data,error}=await db().from(table).select('id,payload,status,created_at').order('created_at',{ascending:false});if(error)throw error;return (data||[]).map(r=>({...r.payload,id:r.payload.id||r.id,status:r.status,createdAt:r.created_at}));}
  async function update(table,id,status){const {data,error}=await db().from(table).update({status}).eq('payload->>id',String(id)).select('id');if(error)throw error;return data;}
  window.PizzaBoyCloud={configured:ready,client:db,createOrder:o=>submit('order',o),createBooking:b=>submit('booking',b),orders:()=>list('pb_orders'),bookings:()=>list('pb_bookings'),updateOrder:(id,s)=>update('pb_orders',id,s),updateBooking:(id,s)=>update('pb_bookings',id,s),signIn:async(email,password)=>{const {data,error}=await db().auth.signInWithPassword({email,password});if(error)throw error;return data;},signOut:async()=>{const {error}=await db().auth.signOut();if(error)throw error;},session:async()=>{const {data,error}=await db().auth.getSession();if(error)throw error;return data.session;}};
})();
