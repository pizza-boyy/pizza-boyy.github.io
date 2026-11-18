PIZZA BOY — SICUREZZA SERVER-SIDE
================================

IMPLEMENTATO NEL PACCHETTO
- Gli ordini e le prenotazioni pubbliche vengono inviati alla Supabase Edge Function `submit-public`.
- Il browser non scrive direttamente nelle tabelle ordini/prenotazioni.
- Validazione server-side di campi, telefono, modalità, quantità, prezzi numerici, date e ospiti.
- Rate limit server-side: massimo 8 invii per IP ogni 10 minuti (finestra memorizzata nel database).
- La chiave service_role è letta solo dai secrets della Edge Function e non compare nel frontend.
- RLS continua a limitare la lettura al solo admin autorizzato.

ATTIVAZIONE OBBLIGATORIA (una tantum)
1. Supabase Dashboard > SQL Editor: esegui prima `supabase-setup.sql`, poi `supabase/rate-limit.sql`.
2. Installa Supabase CLI e fai login: `supabase login`.
3. Collega il progetto: `supabase link --project-ref iexgyhstwwbvacbayjng`.
4. Imposta il secret: `supabase secrets set SUPABASE_SERVICE_ROLE_KEY=LA_TUA_SECRET_KEY`.
   Copia la Secret/service_role key da Supabase > Project Settings > API. NON inserirla in file del sito, GitHub o chat.
5. Dalla cartella del progetto pubblica: `supabase functions deploy submit-public --no-verify-jwt`.
6. Verifica che la function risponda a un ordine di prova e a una prenotazione.
7. Pubblica su GitHub Pages tutti i file della cartella, mantenendo la struttura.

ADMIN
- Crea l'utente in Authentication > Users.
- Inserisci il suo UID in `pb_admin_users` come indicato in CONFIGURAZIONE-CLOUD.txt.
- Non creare account admin pubblici. Mantieni MFA abilitata se disponibile.

LIMITI E CONTROLLI ANCORA NECESSARI
- Il rate limit usa l'IP inoltrato dall'infrastruttura e va monitorato in produzione.
- La verifica Turnstile non è attivata in questa build: per abilitarla servono site key e secret key Cloudflare e un widget nel checkout.
- Il prezzo viene controllato per formato e intervallo, ma non è ancora ricalcolato rispetto a un catalogo server-side autorevole: non considerare questa build pronta per accettare pagamenti o ordini con prezzi garantiti finché non viene configurato quel catalogo.
- Il limite IP non ferma attacchi distribuiti o volumetrici.
- La function deve essere deployata nel progetto Supabase: GitHub Pages da solo non esegue codice server.
