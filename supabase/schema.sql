-- AK System cloud database (Supabase, free tier).
-- Run this once in the Supabase dashboard: SQL Editor > New query > paste > Run.
--
-- Who sees what:
--   owner      everything
--   architect  only projects they are on, plus those projects' client,
--              tasks and deliverables; read-only access to stages and members

-- ---------------------------------------------------------------- tables --

create table if not exists public.members (
  id uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted boolean not null default false,
  synced_at timestamptz not null default now(),
  name text not null default '',
  email text not null default '',
  role text not null default 'architect' check (role in ('owner', 'architect'))
);

create table if not exists public.stages (
  id uuid primary key,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted boolean not null default false,
  synced_at timestamptz not null default now(),
  name text not null default '',
  position integer not null default 0
);

create table if not exists public.clients (
  id uuid primary key,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted boolean not null default false,
  synced_at timestamptz not null default now(),
  name text not null default '',
  company text default '',
  phone text default '',
  email text default '',
  country text default '',
  notes text default ''
);

create table if not exists public.projects (
  id uuid primary key,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted boolean not null default false,
  synced_at timestamptz not null default now(),
  code text default '',
  name text not null default '',
  client_id uuid,
  service text default 'design',
  location text default '',
  abroad boolean not null default false,
  stage_id uuid,
  status text default 'active',
  start_date text,
  due_date text,
  team_ids text default '',  -- comma-separated member ids
  notes text default ''
);

create table if not exists public.tasks (
  id uuid primary key,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted boolean not null default false,
  synced_at timestamptz not null default now(),
  project_id uuid not null,
  title text not null default '',
  assignee_id uuid,
  due_date text,
  status text default 'todo',
  priority text default 'normal',
  stage_id uuid,
  notes text default ''
);

create table if not exists public.deliverables (
  id uuid primary key,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted boolean not null default false,
  synced_at timestamptz not null default now(),
  project_id uuid not null,
  title text not null default '',
  stage_id uuid,
  version integer not null default 1,
  status text default 'draft',
  due_date text,
  submitted_at text,
  approved_at text,
  file_link text default '',
  notes text default ''
);

create index if not exists tasks_project on public.tasks (project_id);
create index if not exists deliverables_project on public.deliverables (project_id);

-- --------------------------------------------- server sync timestamp --
-- Devices pull rows by synced_at, stamped with the server clock, so a phone
-- with a wrong clock can never make the other devices miss a change.

create or replace function public.stamp_synced_at() returns trigger
language plpgsql as $$
begin
  new.synced_at := clock_timestamp();
  return new;
end $$;

do $$
declare t text;
begin
  foreach t in array array['members','stages','clients','projects','tasks','deliverables'] loop
    execute format('drop trigger if exists stamp_synced_at on public.%I', t);
    execute format('create trigger stamp_synced_at before insert or update on public.%I
                    for each row execute function public.stamp_synced_at()', t);
    execute format('create index if not exists %I on public.%I (synced_at)', t || '_synced', t);
  end loop;
end $$;

-- ------------------------------------------------- new user -> member --
-- The first person to sign up becomes the owner; later sign-ups are architects.

create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.members (id, name, email, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'name', split_part(new.email, '@', 1)),
    new.email,
    case when exists (select 1 from public.members where role = 'owner')
         then 'architect' else 'owner' end
  );
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ------------------------------------------------------ access rules --

create or replace function public.is_owner() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.members
    where id = auth.uid() and role = 'owner' and not deleted
  );
$$;

create or replace function public.on_project(p uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.projects
    where id = p and auth.uid()::text = any (string_to_array(team_ids, ','))
  );
$$;

alter table public.members enable row level security;
alter table public.stages enable row level security;
alter table public.clients enable row level security;
alter table public.projects enable row level security;
alter table public.tasks enable row level security;
alter table public.deliverables enable row level security;

-- members: everyone signed in can read the team; only the owner changes it.
drop policy if exists members_read on public.members;
create policy members_read on public.members for select to authenticated using (true);
drop policy if exists members_owner on public.members;
create policy members_owner on public.members for all to authenticated
  using (public.is_owner()) with check (public.is_owner());

-- stages: everyone reads; only the owner edits the list.
drop policy if exists stages_read on public.stages;
create policy stages_read on public.stages for select to authenticated using (true);
drop policy if exists stages_owner on public.stages;
create policy stages_owner on public.stages for all to authenticated
  using (public.is_owner()) with check (public.is_owner());

-- projects: owner all; architects read projects they are on.
drop policy if exists projects_owner on public.projects;
create policy projects_owner on public.projects for all to authenticated
  using (public.is_owner()) with check (public.is_owner());
drop policy if exists projects_team on public.projects;
create policy projects_team on public.projects for select to authenticated
  using (auth.uid()::text = any (string_to_array(team_ids, ',')));

-- clients: owner all; architects read the clients of their projects.
drop policy if exists clients_owner on public.clients;
create policy clients_owner on public.clients for all to authenticated
  using (public.is_owner()) with check (public.is_owner());
drop policy if exists clients_team on public.clients;
create policy clients_team on public.clients for select to authenticated
  using (exists (
    select 1 from public.projects p
    where p.client_id = clients.id
      and auth.uid()::text = any (string_to_array(p.team_ids, ','))
  ));

-- tasks and deliverables: owner all; architects read and edit those on
-- their projects.
drop policy if exists tasks_owner on public.tasks;
create policy tasks_owner on public.tasks for all to authenticated
  using (public.is_owner()) with check (public.is_owner());
drop policy if exists tasks_team on public.tasks;
create policy tasks_team on public.tasks for all to authenticated
  using (public.on_project(project_id)) with check (public.on_project(project_id));

drop policy if exists deliverables_owner on public.deliverables;
create policy deliverables_owner on public.deliverables for all to authenticated
  using (public.is_owner()) with check (public.is_owner());
drop policy if exists deliverables_team on public.deliverables;
create policy deliverables_team on public.deliverables for all to authenticated
  using (public.on_project(project_id)) with check (public.on_project(project_id));

-- v2: professional structure (project type and area, task category,
-- document numbering). Safe to re-run.
alter table projects add column if not exists project_type text;
alter table projects add column if not exists area_sqm double precision;
alter table tasks add column if not exists category text;
alter table deliverables add column if not exists discipline text;
alter table deliverables add column if not exists doc_type text;
alter table deliverables add column if not exists doc_number integer;

-- v3: stages per service, map link, and money (owner only). Safe to re-run.
alter table public.stages add column if not exists service text;
alter table public.projects add column if not exists map_link text;

create table if not exists public.quotations (
  id uuid primary key, created_at timestamptz not null,
  updated_at timestamptz not null, deleted boolean not null default false,
  synced_at timestamptz not null default now(),
  number text, title text, client_id uuid, project_id uuid, date text,
  valid_until text, items text, discount double precision,
  vat_rate double precision, status text, terms text, notes text
);
create table if not exists public.invoices (
  id uuid primary key, created_at timestamptz not null,
  updated_at timestamptz not null, deleted boolean not null default false,
  synced_at timestamptz not null default now(),
  number text, title text, client_id uuid, project_id uuid,
  quotation_id uuid, date text, due_date text, items text,
  discount double precision, vat_rate double precision, status text,
  notes text
);
create table if not exists public.payments (
  id uuid primary key, created_at timestamptz not null,
  updated_at timestamptz not null, deleted boolean not null default false,
  synced_at timestamptz not null default now(),
  invoice_id uuid, date text, amount double precision, method text,
  reference text
);
create table if not exists public.expenses (
  id uuid primary key, created_at timestamptz not null,
  updated_at timestamptz not null, deleted boolean not null default false,
  synced_at timestamptz not null default now(),
  project_id uuid, date text, category text,
  amount double precision, vendor text, notes text
);

do $$
declare t text;
begin
  foreach t in array array['quotations', 'invoices', 'payments', 'expenses']
  loop
    execute format('drop trigger if exists stamp_synced_at on public.%I', t);
    execute format(
      'create trigger stamp_synced_at before insert or update on public.%I '
      'for each row execute function public.stamp_synced_at()', t);
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists owner_all on public.%I', t);
    execute format(
      'create policy owner_all on public.%I for all using (public.is_owner()) '
      'with check (public.is_owner())', t);
  end loop;
end $$;

-- v4: cost-plus percentage. Safe to re-run.
alter table public.projects add column if not exists markup_rate double precision;
alter table public.quotations add column if not exists markup_rate double precision;
alter table public.quotations add column if not exists show_markup boolean;
alter table public.invoices add column if not exists markup_rate double precision;
alter table public.invoices add column if not exists show_markup boolean;
