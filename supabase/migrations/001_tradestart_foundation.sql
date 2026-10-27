-- TradeStart production foundation, revision 001.
-- Run against a NEW dedicated Supabase project. Review policies before real use.
create extension if not exists pgcrypto;
create schema if not exists private;

create table public.ts_admins (
 user_id uuid primary key references auth.users(id) on delete cascade,
 created_at timestamptz not null default now()
);
create table public.ts_participants (
 id uuid primary key default gen_random_uuid(),
 user_id uuid unique references auth.users(id) on delete set null,
 full_name text not null check(length(trim(full_name)) between 1 and 100),
 skills text not null default '',
 status text not null default 'pending' check(status in ('pending','active','inactive')),
 eligibility_verified boolean not null default false,
 created_at timestamptz not null default now()
);
create table public.ts_shifts (
 id uuid primary key default gen_random_uuid(),
 title text not null check(length(trim(title)) > 0),
 general_location text not null,
 start_at timestamptz not null,
 expected_hours numeric(5,2) not null check(expected_hours > 0 and expected_hours <= 24),
 hourly_rate numeric(8,2) not null default 20 check(hourly_rate > 0),
 openings integer not null default 1 check(openings between 1 and 10),
 skill_focus text not null default '',
 status text not null default 'draft' check(status in ('draft','open','closed','completed')),
 created_at timestamptz not null default now()
);
create table public.ts_responses (
 shift_id uuid not null references public.ts_shifts(id) on delete cascade,
 participant_id uuid not null references public.ts_participants(id) on delete cascade,
 created_at timestamptz not null default now(),
 primary key(shift_id,participant_id)
);
create table public.ts_assignments (
 id uuid primary key default gen_random_uuid(),
 shift_id uuid not null references public.ts_shifts(id),
 participant_id uuid not null references public.ts_participants(id),
 status text not null default 'confirmed' check(status in ('confirmed','cancelled','completed')),
 actual_paid_hours numeric(5,2) check(actual_paid_hours is null or (actual_paid_hours > 0 and actual_paid_hours <= 24)),
 skill_notes text not null default '',
 supervisor_notes text not null default '',
 confirmed_at timestamptz not null default now(),
 completed_at timestamptz,
 unique(shift_id,participant_id)
);
create index ts_participants_user_idx on public.ts_participants(user_id);
create index ts_shifts_status_date_idx on public.ts_shifts(status,start_at);
create index ts_assignments_participant_idx on public.ts_assignments(participant_id);
create index ts_responses_participant_idx on public.ts_responses(participant_id);

-- Admin lookup is a locked-down SECURITY DEFINER function in a non-API schema.
create or replace function private.ts_is_admin()
returns boolean language sql stable security definer set search_path=''
as $$ select exists(select 1 from public.ts_admins a where a.user_id=(select auth.uid())); $$;
revoke all on function private.ts_is_admin() from public;
grant usage on schema private to authenticated;
grant execute on function private.ts_is_admin() to authenticated;

alter table public.ts_admins enable row level security;
alter table public.ts_participants enable row level security;
alter table public.ts_shifts enable row level security;
alter table public.ts_responses enable row level security;
alter table public.ts_assignments enable row level security;
revoke all on all tables in schema public from anon,authenticated;
grant select on public.ts_admins to authenticated;
grant select,insert,update on public.ts_participants,public.ts_shifts,public.ts_responses,public.ts_assignments to authenticated;
grant delete on public.ts_responses to authenticated;
-- No client may insert admin roles or delete participant/history records.
create policy ts_admin_view_admins on public.ts_admins for select to authenticated using ((select private.ts_is_admin()));
create policy ts_read_participants on public.ts_participants for select to authenticated using ((select private.ts_is_admin()) or user_id=(select auth.uid()));
create policy ts_admin_insert_participants on public.ts_participants for insert to authenticated with check ((select private.ts_is_admin()));
create policy ts_admin_update_participants on public.ts_participants for update to authenticated using ((select private.ts_is_admin())) with check ((select private.ts_is_admin()));
create policy ts_read_shifts on public.ts_shifts for select to authenticated using ((select private.ts_is_admin()) or (status='open' and exists(select 1 from public.ts_participants p where p.user_id=(select auth.uid()) and p.status='active' and p.eligibility_verified)));
create policy ts_admin_insert_shifts on public.ts_shifts for insert to authenticated with check ((select private.ts_is_admin()));
create policy ts_admin_update_shifts on public.ts_shifts for update to authenticated using ((select private.ts_is_admin())) with check ((select private.ts_is_admin()));
create policy ts_read_responses on public.ts_responses for select to authenticated using ((select private.ts_is_admin()) or exists(select 1 from public.ts_participants p where p.id=participant_id and p.user_id=(select auth.uid())));
create policy ts_interest_insert on public.ts_responses for insert to authenticated with check (
 exists(select 1 from public.ts_participants p where p.id=participant_id and p.user_id=(select auth.uid()) and p.status='active' and p.eligibility_verified)
 and exists(select 1 from public.ts_shifts s where s.id=shift_id and s.status='open')
);
create policy ts_interest_delete on public.ts_responses for delete to authenticated using (
 (select private.ts_is_admin()) or
 (exists(select 1 from public.ts_participants p where p.id=participant_id and p.user_id=(select auth.uid()))
 and not exists(select 1 from public.ts_assignments a where a.shift_id=shift_id and a.participant_id=participant_id and a.status='confirmed'))
);
create policy ts_read_assignments on public.ts_assignments for select to authenticated using ((select private.ts_is_admin()) or exists(select 1 from public.ts_participants p where p.id=participant_id and p.user_id=(select auth.uid())));
create policy ts_admin_insert_assignments on public.ts_assignments for insert to authenticated with check ((select private.ts_is_admin()));
create policy ts_admin_update_assignments on public.ts_assignments for update to authenticated using ((select private.ts_is_admin())) with check ((select private.ts_is_admin()));
-- First admin must be seeded via SQL editor after creating their Supabase Auth user:
-- insert into public.ts_admins(user_id) values ('REPLACE_WITH_ADMIN_AUTH_USER_UUID');
-- Never expose a secret/service-role key or applicant data in GitHub.
