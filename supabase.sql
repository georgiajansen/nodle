-- People Map: database setup.
-- Paste this whole file into Supabase > SQL Editor > New query, then click "Run".
-- It is safe to run more than once.

-- One row per user. The whole People Map (the "S" object) is stored in "data".
create table if not exists public.user_data (
  user_id    uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  data       jsonb not null,
  updated_at timestamptz default now()
);

-- Row Level Security: each user can only see and change their own row.
alter table public.user_data enable row level security;

drop policy if exists "Users can read their own data"   on public.user_data;
drop policy if exists "Users can add their own data"    on public.user_data;
drop policy if exists "Users can change their own data" on public.user_data;

create policy "Users can read their own data"
  on public.user_data for select
  to authenticated
  using (auth.uid() = user_id);

create policy "Users can add their own data"
  on public.user_data for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Users can change their own data"
  on public.user_data for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- No delete policy on purpose: the app never deletes your row.
