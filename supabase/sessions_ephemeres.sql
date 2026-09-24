-- Palier 4 : Supabase — sessions éphémères (clé 8 alphanum, TTL 10 min)
-- 62^8 = 218T combinaisons, lookup 2s, RLS ouverte lecture/écriture anonyme (clé = secret).

create table if not exists public.sessions_ephemeres (
  cle text primary key check (char_length(cle) = 8),
  cle_publique text not null,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

alter table public.sessions_ephemeres enable row level security;

drop policy if exists "anon read/write sessions" on public.sessions_ephemeres;
create policy "anon read/write sessions" on public.sessions_ephemeres
  for all using (true) with check (true);

-- Nettoyage auto : supprime les expirées toutes les minutes (pg_cron ou via edge function)
-- Alternative sans pg_cron : le lookup filtre expires_at > now()
create index if not exists sessions_ephemeres_expires_at_idx on public.sessions_ephemeres (expires_at);
