PIZZA BOY — VERSIONE CLOUD

Sito statico con backend Supabase. Mantieni la struttura delle cartelle quando pubblichi.
- Home: index.html
- Gestionale: admin.html
- Configurazione Supabase: assets/js/config.js
- Schema e policy database: supabase-setup.sql
- Istruzioni cloud: CONFIGURAZIONE-CLOUD.txt
- Istruzioni sicurezza: SECURITY-CHECKLIST.txt

Prima di pubblicare aggiornamenti, conserva una copia della versione funzionante.


PUBBLICAZIONE GITHUB PAGES
Questa cartella contiene index.html nella radice: carica direttamente TUTTO il contenuto della cartella nella root del repository pizza-boyy.github.io (non caricare la cartella contenitore). L'area admin è /admin.html.

SICUREZZA
Le chiavi Publishable/anon sono pubbliche per definizione: la protezione dei dati è demandata alle policy RLS di Supabase. Non inserire mai Secret/service_role nel browser. Le verifiche HTML/JavaScript migliorano l'esperienza ma non impediscono invii automatizzati: per un vero rate-limit/CAPTCHA verificato lato server serve un endpoint server-side (ad esempio Supabase Edge Function) con secret custodito lato server. Non dichiarare attivo un CAPTCHA o rate limit finché non viene configurato e testato.
