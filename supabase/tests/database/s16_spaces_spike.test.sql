-- P04b spike S-16 (p04b-plan.md; R-PERMISSION, OQ-V5): members of a shared
-- space on the server. The spike's schema is made inside this test's
-- transaction and rolled back, so the migrations are untouched until T9.
-- Run with `supabase test db`.
--   O owner, E editor, V viewer, P invited (waiting for approval),
--   J joins at once with a code, R removed, S a stranger, anon no session.
-- Every write goes through owner- or role-checked functions; the tables
-- take no direct writes. The server sees wrapped keys and sealed records
-- only (D12).
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

-- === The spike's schema =====================================================

-- A shared space is a synced workspace whose key reaches each member wrapped
-- with that member's public key ('space').
alter table public.account_workspaces drop constraint account_workspaces_unlock_kind_check;
alter table public.account_workspaces add constraint account_workspaces_unlock_kind_check
  check (unlock_kind in ('recoveryKey', 'passphrase', 'space'));

-- Each account's X25519 public key (readable by the people it shares a space
-- with) and its private key sealed with the account's personal workspace key
-- (readable only by that account: its own devices open it).
create table public.account_public_keys (
  account_id uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  public_key bytea not null check (length(public_key) = 32),
  created_at timestamptz not null default now()
);
create table public.account_private_keys (
  account_id uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  sealed_private bytea not null
);

-- The space's rules (B7, B8, B14): plain, no content, set by the owner only.
create table public.spaces (
  workspace_id uuid primary key references public.account_workspaces (workspace_id) on delete cascade,
  leave_rule text not null default 'disappear'
    check (leave_rule in ('disappear', 'disappearWithExport', 'keepReadOnly')),
  export_rule text not null default 'ownerOnly' check (export_rule in ('ownerOnly', 'everyMember')),
  invite_default text not null default 'approve' check (invite_default in ('approve', 'joinAtOnce')),
  rules_changed_at timestamptz not null default now()
);

create table public.space_members (
  workspace_id uuid not null references public.spaces (workspace_id) on delete cascade,
  account_id uuid not null references auth.users (id) on delete cascade,
  role text not null check (role in ('owner', 'editor', 'viewer')),
  status text not null check (status in ('pending', 'active')),
  -- The space key wrapped for this member; none while waiting for approval.
  wrapped_key bytea,
  key_id text not null default '',
  added_by uuid,
  created_at timestamptz not null default now(),
  primary key (workspace_id, account_id),
  check (status = 'pending' or wrapped_key is not null),
  check (role <> 'owner' or status = 'active')
);
create unique index space_members_one_owner on public.space_members (workspace_id) where role = 'owner';
create index space_members_account on public.space_members (account_id);

-- An invitation: the server keeps a hash of the code, never the code. A
-- "join at once" invitation keeps the space key wrapped with a key made from
-- the code, until it is used.
create table public.space_invitations (
  code_hash text primary key check (code_hash ~ '^[0-9a-f]{64}$'),
  workspace_id uuid not null references public.spaces (workspace_id) on delete cascade,
  role text not null check (role in ('editor', 'viewer')),
  kind text not null check (kind in ('approve', 'joinAtOnce')),
  wrapped_key bytea,
  key_id text not null default '',
  expires_at timestamptz not null,
  created_by uuid not null,
  used_by uuid,
  used_at timestamptz,
  check (kind = 'approve' or used_by is not null or wrapped_key is not null)
);

-- The caller's role in a workspace: an active member's role in a space, or
-- 'owner' of a personal workspace; null otherwise. Security definer, so the
-- policies below can use it without recursing into each other.
create function public.space_role(p_workspace uuid) returns text
language sql stable security definer set search_path = '' as $$
  select coalesce(
    (select m.role from public.space_members m
      where m.workspace_id = p_workspace and m.account_id = (select auth.uid()) and m.status = 'active'),
    (select 'owner' from public.account_workspaces w
      where w.workspace_id = p_workspace and w.account_id = (select auth.uid())
        and not exists (select 1 from public.spaces s where s.workspace_id = p_workspace)));
$$;
revoke all on function public.space_role(uuid) from public, anon;
grant execute on function public.space_role(uuid) to authenticated;

-- Whether the caller and [p_account] are in one space (the caller active).
create function public.shares_space_with(p_account uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.space_members mine
      join public.space_members theirs on theirs.workspace_id = mine.workspace_id
     where mine.account_id = (select auth.uid()) and mine.status = 'active'
       and theirs.account_id = p_account);
$$;
revoke all on function public.shares_space_with(uuid) from public, anon;
grant execute on function public.shares_space_with(uuid) to authenticated;

alter table public.account_public_keys enable row level security;
alter table public.account_private_keys enable row level security;
alter table public.spaces enable row level security;
alter table public.space_members enable row level security;
alter table public.space_invitations enable row level security;
revoke all on public.account_public_keys, public.account_private_keys, public.spaces,
  public.space_members, public.space_invitations from anon, authenticated;
grant select on public.account_public_keys, public.account_private_keys, public.spaces,
  public.space_members, public.space_invitations to authenticated;
grant insert (public_key) on public.account_public_keys to authenticated;
grant insert (sealed_private) on public.account_private_keys to authenticated;

create policy own_or_shared_public_key on public.account_public_keys for all to authenticated
  using (account_id = (select auth.uid()) or public.shares_space_with(account_id))
  with check (account_id = (select auth.uid()));
create policy own_private_key on public.account_private_keys for all to authenticated
  using (account_id = (select auth.uid())) with check (account_id = (select auth.uid()));
create policy members_see_space on public.spaces for select to authenticated
  using (public.space_role(workspace_id) is not null);
create policy members_see_members on public.space_members for select to authenticated
  using (public.space_role(workspace_id) is not null or account_id = (select auth.uid()));
create policy owner_sees_invitations on public.space_invitations for select to authenticated
  using (public.space_role(workspace_id) = 'owner');

-- Records: readable by every active member; written only through the
-- functions, by an owner or an editor.
drop policy own_records on public.sync_records;
-- By set, not per row: the function runs once per query (S-16 part 2: a
-- full count of 22 000 rows 5 ms instead of 460 ms).
create function public.my_workspace_ids() returns setof uuid
language sql stable security definer set search_path = '' as $$
  select m.workspace_id from public.space_members m where m.account_id = (select auth.uid()) and m.status = 'active'
  union
  select w.workspace_id from public.account_workspaces w where w.account_id = (select auth.uid())
    and not exists (select 1 from public.spaces s where s.workspace_id = w.workspace_id);
$$;
revoke all on function public.my_workspace_ids() from public, anon;
grant execute on function public.my_workspace_ids() to authenticated;
create policy members_read_records on public.sync_records for select to authenticated
  using (workspace_id in (select public.my_workspace_ids()));

create or replace function public.push_records(p_workspace uuid, p_device text, p_records jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  r jsonb;
  cur public.sync_records%rowtype;
  next_seq bigint;
  accepted jsonb := '[]'::jsonb;
  conflicts jsonb := '[]'::jsonb;
  base integer;
begin
  if jsonb_typeof(p_records) <> 'array' or jsonb_array_length(p_records) > 500 then
    raise exception 'a batch is an array of at most 500 records' using errcode = '22023';
  end if;
  if coalesce(public.space_role(p_workspace), '') not in ('owner', 'editor') then
    raise exception 'unknown workspace' using errcode = '42501';
  end if;
  perform 1 from public.account_workspaces w where w.workspace_id = p_workspace for update;
  for r in select * from jsonb_array_elements(p_records) loop
    base := (r ->> 'base')::integer;
    select * into cur from public.sync_records s
      where s.workspace_id = p_workspace and s.id = r ->> 'id' for update;
    if found and cur.operation_id = (r ->> 'op')::uuid then
      accepted := accepted || jsonb_build_object('id', cur.id, 'seq', cur.seq, 'version', cur.version);
      continue;
    end if;
    if (not found and base is null) or (found and cur.version = base) then
      if (r ->> 'version')::integer <= coalesce(base, 0) then
        raise exception 'the new version must be above the base' using errcode = '22023';
      end if;
      update public.account_workspaces w set last_seq = w.last_seq + 1
        where w.workspace_id = p_workspace returning w.last_seq into next_seq;
      insert into public.sync_records as s
          (workspace_id, id, version, seq, deleted, sealed, device_id, operation_id, updated_at)
        values (p_workspace, r ->> 'id', (r ->> 'version')::integer, next_seq,
                coalesce((r ->> 'deleted')::boolean, false),
                decode(r ->> 'sealed', 'base64'), p_device, (r ->> 'op')::uuid, now())
        on conflict (workspace_id, id) do update
          set version = excluded.version, seq = excluded.seq, deleted = excluded.deleted,
              sealed = excluded.sealed, device_id = excluded.device_id,
              operation_id = excluded.operation_id, updated_at = excluded.updated_at;
      accepted := accepted || jsonb_build_object('id', r ->> 'id', 'seq', next_seq,
                                                 'version', (r ->> 'version')::integer);
    else
      conflicts := conflicts || jsonb_build_object('id', r ->> 'id',
                                                   'version', case when found then cur.version end);
    end if;
  end loop;
  return jsonb_build_object('accepted', accepted, 'conflicts', conflicts);
end;
$$;

create or replace function public.purge_records(p_workspace uuid, p_before timestamptz)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  n integer := 0;
  rec record;
  next_seq bigint;
begin
  if coalesce(public.space_role(p_workspace), '') not in ('owner', 'editor') then
    raise exception 'unknown workspace' using errcode = '42501';
  end if;
  perform 1 from public.account_workspaces w where w.workspace_id = p_workspace for update;
  for rec in select s.id from public.sync_records s
      where s.workspace_id = p_workspace and s.deleted and s.sealed is not null
        and s.updated_at < least(p_before, now() - interval '90 days')
      order by s.seq loop
    update public.account_workspaces w set last_seq = w.last_seq + 1
      where w.workspace_id = p_workspace returning w.last_seq into next_seq;
    update public.sync_records s set sealed = null, seq = next_seq, updated_at = now()
      where s.workspace_id = p_workspace and s.id = rec.id;
    n := n + 1;
  end loop;
  return n;
end;
$$;

-- --- Membership: only through these functions (LF-INV-SHARE-003) ---------

create function pg_temp.must_own(p_workspace uuid) returns void language plpgsql as $$
begin
  if coalesce(public.space_role(p_workspace), '') <> 'owner'
     or not exists (select 1 from public.spaces s where s.workspace_id = p_workspace) then
    raise exception 'not the owner of this space' using errcode = '42501';
  end if;
end;
$$;

create function public.create_space(p_workspace uuid, p_wrapped_for_me bytea, p_key_id text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not exists (select 1 from public.account_public_keys k where k.account_id = auth.uid()) then
    raise exception 'publish your public key first' using errcode = '22023';
  end if;
  if (select count(*) from public.space_members m where m.account_id = auth.uid()) >= 10 then
    raise exception 'at most 10 shared spaces per account' using errcode = '54000';
  end if;
  insert into public.account_workspaces (workspace_id, account_id, wrapped_key, unlock_kind, key_id)
    values (p_workspace, auth.uid(), p_wrapped_for_me, 'space', p_key_id);
  insert into public.spaces (workspace_id) values (p_workspace);
  insert into public.space_members (workspace_id, account_id, role, status, wrapped_key, key_id, added_by)
    values (p_workspace, auth.uid(), 'owner', 'active', p_wrapped_for_me, p_key_id, auth.uid());
end;
$$;

create function public.invite(p_workspace uuid, p_code_hash text, p_role text, p_kind text,
                              p_wrapped bytea default null, p_key_id text default '', p_days integer default 7)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform pg_temp.must_own(p_workspace);
  if p_days not between 1 and 7 then
    raise exception 'an invitation lasts 1 to 7 days' using errcode = '22023';
  end if;
  insert into public.space_invitations (code_hash, workspace_id, role, kind, wrapped_key, key_id, expires_at, created_by)
    values (p_code_hash, p_workspace, p_role, p_kind,
            case when p_kind = 'joinAtOnce' then p_wrapped end, p_key_id,
            now() + make_interval(days => p_days), auth.uid());
end;
$$;

-- What an invitation is for, before accepting it: the role, its kind and the
-- space's rules (LF-INV-SHARE-005). Unknown, used and expired look the same.
create function public.peek_invitation(p_code_hash text) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  i public.space_invitations%rowtype;
  s public.spaces%rowtype;
begin
  select * into i from public.space_invitations
    where code_hash = p_code_hash and used_by is null and expires_at > now();
  if not found then
    raise exception 'no such invitation' using errcode = 'P0002';
  end if;
  select * into s from public.spaces where workspace_id = i.workspace_id;
  return jsonb_build_object('workspace_id', i.workspace_id, 'role', i.role, 'kind', i.kind,
    'leave_rule', s.leave_rule, 'export_rule', s.export_rule);
end;
$$;

create function public.accept_invitation(p_code_hash text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  i public.space_invitations%rowtype;
  s public.spaces%rowtype;
begin
  select * into i from public.space_invitations
    where code_hash = p_code_hash and used_by is null and expires_at > now() for update;
  if not found then
    raise exception 'no such invitation' using errcode = 'P0002';
  end if;
  if not exists (select 1 from public.account_public_keys k where k.account_id = auth.uid()) then
    raise exception 'publish your public key first' using errcode = '22023';
  end if;
  if exists (select 1 from public.space_members m where m.workspace_id = i.workspace_id and m.account_id = auth.uid()) then
    raise exception 'already in this space' using errcode = '23505';
  end if;
  if (select count(*) from public.space_members m where m.workspace_id = i.workspace_id) >= 10 then
    raise exception 'at most 10 members per space' using errcode = '54000';
  end if;
  if (select count(*) from public.space_members m where m.account_id = auth.uid()) >= 10 then
    raise exception 'at most 10 shared spaces per account' using errcode = '54000';
  end if;
  update public.space_invitations set used_by = auth.uid(), used_at = now(), wrapped_key = null
    where code_hash = p_code_hash;
  insert into public.space_members (workspace_id, account_id, role, status, wrapped_key, key_id, added_by)
    values (i.workspace_id, auth.uid(), i.role,
            case when i.kind = 'joinAtOnce' then 'active' else 'pending' end,
            case when i.kind = 'joinAtOnce' then i.wrapped_key end, i.key_id, i.created_by);
  select * into s from public.spaces where workspace_id = i.workspace_id;
  return jsonb_build_object('workspace_id', i.workspace_id, 'role', i.role, 'kind', i.kind,
    'wrapped_key', case when i.kind = 'joinAtOnce' then encode(i.wrapped_key, 'base64') end,
    'leave_rule', s.leave_rule, 'export_rule', s.export_rule);
end;
$$;

create function public.approve_member(p_workspace uuid, p_account uuid, p_wrapped bytea, p_key_id text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform pg_temp.must_own(p_workspace);
  update public.space_members set status = 'active', wrapped_key = p_wrapped, key_id = p_key_id
    where workspace_id = p_workspace and account_id = p_account and status = 'pending';
  if not found then
    raise exception 'nobody is waiting' using errcode = 'P0002';
  end if;
end;
$$;

-- A member replaces the key wrapped for them (after joining at once, the
-- device wraps it again with its own public key), for the current key only.
create function public.set_my_wrapped_key(p_workspace uuid, p_wrapped bytea, p_key_id text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  update public.space_members m set wrapped_key = p_wrapped
    where m.workspace_id = p_workspace and m.account_id = auth.uid() and m.status = 'active'
      and p_key_id = (select w.key_id from public.account_workspaces w where w.workspace_id = p_workspace);
  if not found then
    raise exception 'not a member, or not the current key' using errcode = '42501';
  end if;
end;
$$;

create function public.remove_member(p_workspace uuid, p_account uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform pg_temp.must_own(p_workspace);
  delete from public.space_members
    where workspace_id = p_workspace and account_id = p_account and role <> 'owner';
  if not found then
    raise exception 'not a member who can be removed' using errcode = 'P0002';
  end if;
end;
$$;

create function public.leave_space(p_workspace uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  delete from public.space_members
    where workspace_id = p_workspace and account_id = auth.uid() and role <> 'owner';
  if not found then
    raise exception 'the owner hands the space over before leaving' using errcode = '42501';
  end if;
end;
$$;

create function public.set_role(p_workspace uuid, p_account uuid, p_role text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform pg_temp.must_own(p_workspace);
  if p_role not in ('editor', 'viewer') then
    raise exception 'use hand_over for the owner role' using errcode = '22023';
  end if;
  update public.space_members set role = p_role
    where workspace_id = p_workspace and account_id = p_account and role <> 'owner';
  if not found then
    raise exception 'no such member' using errcode = 'P0002';
  end if;
end;
$$;

create function public.hand_over(p_workspace uuid, p_account uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform pg_temp.must_own(p_workspace);
  if not exists (select 1 from public.space_members m where m.workspace_id = p_workspace
                   and m.account_id = p_account and m.status = 'active' and m.role <> 'owner') then
    raise exception 'hand over to an active member' using errcode = 'P0002';
  end if;
  update public.space_members set role = 'editor' where workspace_id = p_workspace and account_id = auth.uid();
  update public.space_members set role = 'owner' where workspace_id = p_workspace and account_id = p_account;
  update public.account_workspaces set account_id = p_account where workspace_id = p_workspace;
end;
$$;

create function public.set_space_rules(p_workspace uuid, p_leave text, p_export text, p_invite text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform pg_temp.must_own(p_workspace);
  update public.spaces set leave_rule = p_leave, export_rule = p_export, invite_default = p_invite,
         rules_changed_at = now()
    where workspace_id = p_workspace;
end;
$$;

-- A new space key (after a removal, B8): wrapped for exactly the active
-- members; unused "join at once" invitations of the old key stop working.
create function public.rotate_space_key(p_workspace uuid, p_key_id text, p_wraps jsonb)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform pg_temp.must_own(p_workspace);
  if (select coalesce(array_agg(m.account_id::text order by m.account_id::text), '{}')
        from public.space_members m where m.workspace_id = p_workspace and m.status = 'active')
     is distinct from
     (select coalesce(array_agg(e ->> 'account' order by e ->> 'account'), '{}')
        from jsonb_array_elements(p_wraps) e) then
    raise exception 'wrap the new key for exactly the active members' using errcode = '22023';
  end if;
  update public.space_members m set wrapped_key = decode(e ->> 'wrapped', 'base64'), key_id = p_key_id
    from jsonb_array_elements(p_wraps) e
    where m.workspace_id = p_workspace and m.account_id = (e ->> 'account')::uuid;
  update public.account_workspaces set key_id = p_key_id where workspace_id = p_workspace;
  delete from public.space_invitations
    where workspace_id = p_workspace and used_by is null and kind = 'joinAtOnce';
end;
$$;

do $$
declare f text;
begin
  foreach f in array array[
    'public.create_space(uuid, bytea, text)', 'public.invite(uuid, text, text, text, bytea, text, integer)',
    'public.peek_invitation(text)', 'public.accept_invitation(text)',
    'public.approve_member(uuid, uuid, bytea, text)', 'public.set_my_wrapped_key(uuid, bytea, text)',
    'public.remove_member(uuid, uuid)', 'public.leave_space(uuid)', 'public.set_role(uuid, uuid, text)',
    'public.hand_over(uuid, uuid)', 'public.set_space_rules(uuid, text, text, text)',
    'public.rotate_space_key(uuid, text, jsonb)'] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end;
$$;

-- === Test helpers ===========================================================

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-0000000000a1', 'owner@example.test'),
  ('00000000-0000-4000-8000-0000000000a2', 'editor@example.test'),
  ('00000000-0000-4000-8000-0000000000a3', 'viewer@example.test'),
  ('00000000-0000-4000-8000-0000000000a4', 'pending@example.test'),
  ('00000000-0000-4000-8000-0000000000a5', 'atonce@example.test'),
  ('00000000-0000-4000-8000-0000000000a6', 'removed@example.test'),
  ('00000000-0000-4000-8000-0000000000a7', 'stranger@example.test');

create function pg_temp.who(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-0000000000a' || n)::uuid;
$$;
create function pg_temp.as_account(n int) returns void language sql as $$
  select set_config('role', 'authenticated', true),
         set_config('request.jwt.claims',
                    json_build_object('sub', pg_temp.who(n), 'role', 'authenticated')::text, true);
$$;
create function pg_temp.as_admin() returns void language sql as $$
  select set_config('role', 'postgres', true), set_config('request.jwt.claims', '', true);
$$;
create function pg_temp.rec(n int, op text) returns jsonb language sql as $$
  select jsonb_build_object('id', lpad(to_hex(n), 64, '0'), 'base', null, 'version', 1, 'deleted', false,
                            'sealed', encode('sealed bytes'::bytea, 'base64'), 'op', op);
$$;
create function pg_temp.hash(code text) returns text language sql as $$
  select encode(extensions.digest('lifeflow invite v1:' || code, 'sha256'), 'hex');
$$;
-- Every account publishes a public key (its devices do it when sync is on).
create function pg_temp.publish(n int) returns void language sql as $$
  select pg_temp.as_account(n);
  insert into public.account_public_keys (public_key) values (decode(lpad(to_hex(n), 64, '0'), 'hex'));
  insert into public.account_private_keys (sealed_private) values ('\x5ea1ed');
$$;
select pg_temp.publish(n) from generate_series(1, 7) n;

-- The space: O makes it; E and V join through "approve" invitations.
select pg_temp.as_account(1);
select lives_ok($$ select public.create_space('20000000-0000-4000-8000-0000000000f1', '\x01', repeat('a', 64)) $$,
                'the owner makes a space');
select lives_ok($$ select public.invite('20000000-0000-4000-8000-0000000000f1', pg_temp.hash('code-editor'), 'editor', 'approve') $$,
                'the owner invites an editor');
select lives_ok($$ select public.invite('20000000-0000-4000-8000-0000000000f1', pg_temp.hash('code-viewer'), 'viewer', 'approve') $$,
                'the owner invites a viewer');
select lives_ok($$ select public.invite('20000000-0000-4000-8000-0000000000f1', pg_temp.hash('code-pending'), 'editor', 'approve') $$,
                'and someone who will wait for approval');
select lives_ok($$ select public.invite('20000000-0000-4000-8000-0000000000f1', pg_temp.hash('code-removed'), 'editor', 'approve') $$,
                'and someone who will be removed');
select lives_ok($$ select public.invite('20000000-0000-4000-8000-0000000000f1', pg_temp.hash('code-atonce'), 'editor', 'joinAtOnce', '\x0c0d', repeat('a', 64)) $$,
                'and a "join at once" invitation, carrying the key wrapped for the code');
select throws_ok($$ select public.invite('20000000-0000-4000-8000-0000000000f1', pg_temp.hash('x'), 'owner', 'approve') $$,
                 '23514', null, 'nobody is invited as owner');
select throws_ok($$ select public.invite('20000000-0000-4000-8000-0000000000f1', pg_temp.hash('y'), 'editor', 'approve', null, '', 30) $$,
                 '22023', null, 'an invitation lasts at most 7 days');

-- The invitee sees the role and the rules before accepting (SHARE-005).
select pg_temp.as_account(2);
select is(public.peek_invitation(pg_temp.hash('code-editor')) ->> 'leave_rule', 'disappear',
          'the rules are shown before joining');
select throws_ok($$ select public.peek_invitation(pg_temp.hash('no such code')) $$, 'P0002', null,
                 'an unknown code says nothing about any space');
select is(public.accept_invitation(pg_temp.hash('code-editor')) ->> 'kind', 'approve', 'E accepts');
select is((select count(*)::int from public.sync_records), 0, 'E reads nothing before the approval');
select throws_ok($$ select public.push_records('20000000-0000-4000-8000-0000000000f1', 'e',
                     jsonb_build_array(pg_temp.rec(1, '30000000-0000-4000-8000-000000000001'))) $$,
                 '42501', null, 'E writes nothing before the approval');
select pg_temp.as_account(3);
select lives_ok($$ select public.accept_invitation(pg_temp.hash('code-viewer')) $$, 'V accepts');
select pg_temp.as_account(4);
select lives_ok($$ select public.accept_invitation(pg_temp.hash('code-pending')) $$, 'P accepts');
select pg_temp.as_account(6);
select lives_ok($$ select public.accept_invitation(pg_temp.hash('code-removed')) $$, 'R accepts');
select pg_temp.as_account(7);
select throws_ok($$ select public.accept_invitation(pg_temp.hash('code-editor')) $$, 'P0002', null,
                 'a used code cannot be used again');

-- "Join at once": in at once; the key it carried is gone from the server.
select pg_temp.as_account(5);
select is(public.accept_invitation(pg_temp.hash('code-atonce')) ->> 'wrapped_key', encode('\x0c0d'::bytea, 'base64'),
          'J gets the key wrapped for the code');
select is(public.space_role('20000000-0000-4000-8000-0000000000f1'), 'editor', 'J is an editor at once');
select lives_ok($$ select public.set_my_wrapped_key('20000000-0000-4000-8000-0000000000f1', '\x05', repeat('a', 64)) $$,
                'J''s device wraps the key again for itself');
select pg_temp.as_admin();
select is((select wrapped_key from public.space_invitations where code_hash = pg_temp.hash('code-atonce')), null,
          'the code''s wrapped key is erased once used');

-- Approval: only the owner; only someone waiting.
select pg_temp.as_account(2);
select throws_ok($$ select public.approve_member('20000000-0000-4000-8000-0000000000f1', pg_temp.who(4), '\x02', repeat('a', 64)) $$,
                 '42501', null, 'an editor cannot approve');
select pg_temp.as_account(1);
select lives_ok($$ select public.approve_member('20000000-0000-4000-8000-0000000000f1', pg_temp.who(n), '\x02', repeat('a', 64))
                     from unnest(array[2, 3, 6]) n $$, 'the owner approves E, V and R');
select throws_ok($$ select public.approve_member('20000000-0000-4000-8000-0000000000f1', pg_temp.who(7), '\x02', repeat('a', 64)) $$,
                 'P0002', null, 'a stranger who never asked cannot be approved in');

-- Writes by role (SHARE-002).
select is((public.push_records('20000000-0000-4000-8000-0000000000f1', 'o',
            jsonb_build_array(pg_temp.rec(1, '30000000-0000-4000-8000-000000000011'))) -> 'accepted') -> 0 ->> 'seq', '1',
          'the owner writes');
select pg_temp.as_account(2);
select is((public.push_records('20000000-0000-4000-8000-0000000000f1', 'e',
            jsonb_build_array(pg_temp.rec(2, '30000000-0000-4000-8000-000000000012'))) -> 'accepted') -> 0 ->> 'seq', '2',
          'an editor writes');
select is((select count(*)::int from public.sync_records), 2, 'an editor reads the space');
select pg_temp.as_account(3);
select is((select count(*)::int from public.sync_records), 2, 'a viewer reads the space');
select throws_ok($$ select public.push_records('20000000-0000-4000-8000-0000000000f1', 'v',
                     jsonb_build_array(pg_temp.rec(3, '30000000-0000-4000-8000-000000000013'))) $$,
                 '42501', null, 'a viewer cannot write (the server says no)');
select throws_ok($$ select public.purge_records('20000000-0000-4000-8000-0000000000f1', now()) $$,
                 '42501', null, 'a viewer cannot purge');

-- Pending and strangers see nothing (GS-23).
select pg_temp.as_account(4);
select is((select count(*)::int from public.sync_records), 0, 'someone waiting reads no record');
select is((select count(*)::int from public.space_members), 1, 'someone waiting sees only their own request');
select pg_temp.as_account(7);
select is((select count(*)::int from public.sync_records), 0, 'a stranger reads no record');
select is((select count(*)::int from public.space_members), 0, 'a stranger sees no member');
select is((select count(*)::int from public.spaces), 0, 'a stranger sees no space');
select is((select count(*)::int from public.account_public_keys), 1, 'a stranger sees only their own public key');
select throws_ok($$ select public.push_records('20000000-0000-4000-8000-0000000000f1', 's',
                     jsonb_build_array(pg_temp.rec(4, '30000000-0000-4000-8000-000000000014'))) $$,
                 '42501', null, 'a stranger cannot write');

-- Crafted requests around the functions (SHARE-003).
select pg_temp.as_account(3);
select throws_ok($$ update public.space_members set role = 'owner' where account_id = pg_temp.who(3) $$,
                 '42501', null, 'a viewer cannot make themselves owner');
select throws_ok($$ insert into public.space_members (workspace_id, account_id, role, status, wrapped_key)
                    values ('20000000-0000-4000-8000-0000000000f1', pg_temp.who(7), 'editor', 'active', '\x01') $$,
                 '42501', null, 'nobody adds a member by hand');
select throws_ok($$ update public.spaces set export_rule = 'everyMember' $$, '42501', null,
                 'a member cannot change the rules by hand');
select throws_ok($$ delete from public.space_invitations $$, '42501', null, 'nor delete invitations');
select is((select count(*)::int from public.space_invitations), 0, 'a member cannot read the invitations');
select is((select count(*)::int from public.account_private_keys), 1, 'everyone reads only their own private key');
select is((select count(*)::int from public.account_public_keys), 6,
          'members see the public keys of the people in their space');
delete from public.account_workspaces where workspace_id = '20000000-0000-4000-8000-0000000000f1';
select pg_temp.as_admin();
select is((select count(*)::int from public.account_workspaces where workspace_id = '20000000-0000-4000-8000-0000000000f1'), 1,
          'a member cannot delete the space');

-- Owner-only actions refused to an editor.
select pg_temp.as_account(2);
select throws_ok($$ select public.remove_member('20000000-0000-4000-8000-0000000000f1', pg_temp.who(3)) $$,
                 '42501', null, 'an editor cannot remove a member');
select throws_ok($$ select public.set_role('20000000-0000-4000-8000-0000000000f1', pg_temp.who(3), 'editor') $$,
                 '42501', null, 'an editor cannot change roles');
select throws_ok($$ select public.set_space_rules('20000000-0000-4000-8000-0000000000f1', 'keepReadOnly', 'everyMember', 'approve') $$,
                 '42501', null, 'an editor cannot change the rules');
select throws_ok($$ select public.invite('20000000-0000-4000-8000-0000000000f1', pg_temp.hash('z'), 'editor', 'approve') $$,
                 '42501', null, 'an editor cannot invite');
select throws_ok($$ select public.rotate_space_key('20000000-0000-4000-8000-0000000000f1', repeat('c', 64), '[]'::jsonb) $$,
                 '42501', null, 'an editor cannot rotate the key');

-- The rules: the owner sets them; members see them and when they changed.
select pg_temp.as_account(1);
select lives_ok($$ select public.set_space_rules('20000000-0000-4000-8000-0000000000f1', 'keepReadOnly', 'everyMember', 'joinAtOnce') $$,
                'the owner sets the leaving and export rules');
select throws_ok($$ select public.set_space_rules('20000000-0000-4000-8000-0000000000f1', 'whatever', 'everyMember', 'approve') $$,
                 '23514', null, 'only the known rules');
select pg_temp.as_account(3);
select is((select (leave_rule, export_rule) from public.spaces)::text, '(keepReadOnly,everyMember)',
          'a viewer sees the new rules');

-- Removal: no access at once; a new key wrapped for exactly the others.
select pg_temp.as_account(1);
select lives_ok($$ select public.remove_member('20000000-0000-4000-8000-0000000000f1', pg_temp.who(6)) $$,
                'the owner removes R');
select pg_temp.as_account(6);
select is((select count(*)::int from public.sync_records), 0, 'R reads nothing after the removal');
select throws_ok($$ select public.push_records('20000000-0000-4000-8000-0000000000f1', 'r',
                     jsonb_build_array(pg_temp.rec(5, '30000000-0000-4000-8000-000000000015'))) $$,
                 '42501', null, 'R writes nothing after the removal');
select pg_temp.as_account(1);
select throws_ok($$ select public.rotate_space_key('20000000-0000-4000-8000-0000000000f1', repeat('b', 64),
                     jsonb_build_array(jsonb_build_object('account', pg_temp.who(1), 'wrapped', 'AQ=='))) $$,
                 '22023', null, 'the new key must be wrapped for every active member');
select throws_ok($$ select public.rotate_space_key('20000000-0000-4000-8000-0000000000f1', repeat('b', 64),
                     (select jsonb_agg(jsonb_build_object('account', pg_temp.who(n), 'wrapped', 'AQ=='))
                        from unnest(array[1, 2, 3, 5, 6]) n)) $$,
                 '22023', null, 'and not for the removed member');
select lives_ok($$ select public.rotate_space_key('20000000-0000-4000-8000-0000000000f1', repeat('b', 64),
                     (select jsonb_agg(jsonb_build_object('account', pg_temp.who(n), 'wrapped', 'Ag=='))
                        from unnest(array[1, 2, 3, 5]) n)) $$,
                'the owner rotates the key for O, E, V and J');
select pg_temp.as_admin();
select is((select key_id from public.account_workspaces where workspace_id = '20000000-0000-4000-8000-0000000000f1'), repeat('b', 64),
          'the space says which key is current');
select pg_temp.as_account(5);
select throws_ok($$ select public.set_my_wrapped_key('20000000-0000-4000-8000-0000000000f1', '\x05', repeat('a', 64)) $$,
                 '42501', null, 'an old key cannot be put back');

-- Leaving, roles, handing over.
select pg_temp.as_account(3);
select lives_ok($$ select public.leave_space('20000000-0000-4000-8000-0000000000f1') $$, 'V leaves');
select is(public.space_role('20000000-0000-4000-8000-0000000000f1'), null, 'V has no role any more');
select pg_temp.as_account(1);
select throws_ok($$ select public.leave_space('20000000-0000-4000-8000-0000000000f1') $$, '42501', null,
                 'the owner hands over before leaving');
select lives_ok($$ select public.set_role('20000000-0000-4000-8000-0000000000f1', pg_temp.who(5), 'viewer') $$,
                'the owner makes J a viewer');
select throws_ok($$ select public.set_role('20000000-0000-4000-8000-0000000000f1', pg_temp.who(5), 'owner') $$,
                 '22023', null, 'the owner role moves only by handing over');
select lives_ok($$ select public.hand_over('20000000-0000-4000-8000-0000000000f1', pg_temp.who(2)) $$,
                'O hands the space to E');
select is(public.space_role('20000000-0000-4000-8000-0000000000f1'), 'editor', 'O is an editor now');
select throws_ok($$ select public.remove_member('20000000-0000-4000-8000-0000000000f1', pg_temp.who(5)) $$,
                 '42501', null, 'O can no longer remove members');
select pg_temp.as_account(2);
select is(public.space_role('20000000-0000-4000-8000-0000000000f1'), 'owner', 'E owns the space');
select pg_temp.as_admin();
select is((select count(*)::int from public.space_members
            where workspace_id = '20000000-0000-4000-8000-0000000000f1' and role = 'owner'), 1,
          'one owner at a time');

-- Limits (B13): 10 members per space.
select pg_temp.as_account(2);
select public.invite('20000000-0000-4000-8000-0000000000f1', pg_temp.hash('fill-' || n), 'viewer', 'approve')
  from generate_series(1, 8) n;
select pg_temp.as_admin();
insert into auth.users (id, email)
  select ('00000000-0000-4000-8000-0000000001' || lpad(n::text, 2, '0'))::uuid, 'fill' || n || '@example.test'
    from generate_series(1, 8) n;
create function pg_temp.as_fill(n int) returns void language sql as $$
  select set_config('role', 'authenticated', true),
         set_config('request.jwt.claims', json_build_object('sub',
           ('00000000-0000-4000-8000-0000000001' || lpad(n::text, 2, '0'))::uuid, 'role', 'authenticated')::text, true);
$$;
create function pg_temp.fill_join(n int) returns jsonb language sql as $$
  select pg_temp.as_fill(n);
  insert into public.account_public_keys (public_key) values (decode(lpad(to_hex(100 + n), 64, '0'), 'hex'));
  select public.accept_invitation(pg_temp.hash('fill-' || n));
$$;
select pg_temp.fill_join(n) from generate_series(1, 6) n;
select pg_temp.as_admin();
select is((select count(*)::int from public.space_members where workspace_id = '20000000-0000-4000-8000-0000000000f1'), 10,
          'the space is full at 10');
select pg_temp.as_fill(7);
insert into public.account_public_keys (public_key) values (decode(lpad(to_hex(107), 64, '0'), 'hex'));
select throws_ok($$ select public.accept_invitation(pg_temp.hash('fill-7')) $$, '54000', null,
                 'an eleventh member is refused');

-- No session reaches nothing.
select pg_temp.as_admin();
select set_config('role', 'anon', true);
select throws_ok($$ select public.peek_invitation(pg_temp.hash('code-editor')) $$, '42501', null,
                 'anon cannot look at invitations');
select throws_ok($$ select count(*) from public.space_members $$, '42501', null, 'anon reads no members');

-- The owner deletes the space: everything of it goes.
select pg_temp.as_account(2);
delete from public.account_workspaces where workspace_id = '20000000-0000-4000-8000-0000000000f1';
select pg_temp.as_admin();
select is((select count(*)::int from public.sync_records where workspace_id = '20000000-0000-4000-8000-0000000000f1')
          + (select count(*)::int from public.space_members where workspace_id = '20000000-0000-4000-8000-0000000000f1')
          + (select count(*)::int from public.space_invitations where workspace_id = '20000000-0000-4000-8000-0000000000f1'), 0,
          'deleting the space deletes its records, members and invitations');

-- A personal workspace (P04a) still works as before.
select pg_temp.as_account(7);
select lives_ok($$ insert into public.account_workspaces (workspace_id, wrapped_key, unlock_kind)
                   values ('20000000-0000-4000-8000-0000000000f7', '\x01', 'recoveryKey') $$,
                'a personal workspace is made as in P04a');
select is((public.push_records('20000000-0000-4000-8000-0000000000f7', 'pc',
            jsonb_build_array(pg_temp.rec(1, '30000000-0000-4000-8000-000000000071'))) -> 'accepted') -> 0 ->> 'seq', '1',
          'and its owner writes to it');
select pg_temp.as_account(1);
select is((select count(*)::int from public.sync_records where workspace_id = '20000000-0000-4000-8000-0000000000f7'), 0,
          'nobody else reads it');

select * from finish();
rollback;
