-- P04b T9 (ADR-0061, from spike S-16): shared spaces on the server.
--
-- A shared space is a synced workspace (account_workspaces, unlock_kind
-- 'space') with rules (spaces), members (space_members) and invitations
-- (space_invitations). Its key reaches each member wrapped with that
-- member's X25519 public key (account_public_keys); each account's private
-- key is kept sealed with its personal workspace key (account_private_keys).
-- The server sees wrapped keys, hashes of invitation codes and sealed
-- records only (D12).
--
-- Row-level security reads by set (`workspace_id in (select ...)`), never a
-- function per row (S-16 part 2: a count of 22 000 rows 5 ms instead of
-- 460 ms). Every write to the new tables goes through the functions below,
-- which check the caller's role first (LF-INV-SHARE-002/003). A refusal the
-- app explains carries a hint 'lifeflow:<reason>' (ADR-0061).

-- Functions the policies and other functions use, out of the REST API's
-- reach (only the 'public' schema is exposed).
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

alter table public.account_workspaces drop constraint account_workspaces_unlock_kind_check;
alter table public.account_workspaces add constraint account_workspaces_unlock_kind_check
  check (unlock_kind in ('recoveryKey', 'passphrase', 'space'));

create table public.account_public_keys (
  account_id uuid primary key references auth.users (id) on delete cascade,
  public_key bytea not null check (length(public_key) = 32),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.account_private_keys (
  account_id uuid primary key references auth.users (id) on delete cascade,
  sealed_private bytea not null check (length(sealed_private) between 1 and 1024),
  updated_at timestamptz not null default now()
);

-- The space's rules (B7, B8, B14): plain words, no content; the owner sets
-- them and every member reads them and when they last changed.
create table public.spaces (
  workspace_id uuid primary key references public.account_workspaces (workspace_id) on delete cascade,
  leave_rule text not null default 'disappear'
    check (leave_rule in ('disappear', 'disappearWithExport', 'keepReadOnly')),
  export_rule text not null default 'ownerOnly' check (export_rule in ('ownerOnly', 'everyMember')),
  invite_default text not null default 'approve' check (invite_default in ('approve', 'joinAtOnce')),
  rules_changed_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table public.space_members (
  workspace_id uuid not null references public.spaces (workspace_id) on delete cascade,
  account_id uuid not null references auth.users (id) on delete cascade,
  role text not null check (role in ('owner', 'editor', 'viewer')),
  status text not null check (status in ('pending', 'active')),
  -- The space key wrapped for this member; none while waiting for approval.
  wrapped_key bytea check (wrapped_key is null or length(wrapped_key) between 1 and 1024),
  -- Which space key [wrapped_key] is (the device's fingerprint of it).
  key_id text not null default '' check (key_id = '' or key_id ~ '^[0-9a-f]{64}$'),
  added_by uuid,
  created_at timestamptz not null default now(),
  primary key (workspace_id, account_id),
  check (status = 'pending' or wrapped_key is not null),
  check (role <> 'owner' or status = 'active')
);
create unique index space_members_one_owner on public.space_members (workspace_id) where role = 'owner';
create index space_members_account on public.space_members (account_id);

-- An invitation keeps a hash of the code, never the code. A "join at once"
-- invitation keeps the space key wrapped with a key made from the code,
-- until it is used (then it is erased).
create table public.space_invitations (
  code_hash text primary key check (code_hash ~ '^[0-9a-f]{64}$'),
  workspace_id uuid not null references public.spaces (workspace_id) on delete cascade,
  role text not null check (role in ('editor', 'viewer')),
  kind text not null check (kind in ('approve', 'joinAtOnce')),
  wrapped_key bytea check (wrapped_key is null or length(wrapped_key) between 1 and 1024),
  key_id text not null default '' check (key_id = '' or key_id ~ '^[0-9a-f]{64}$'),
  expires_at timestamptz not null,
  created_by uuid not null,
  created_at timestamptz not null default now(),
  used_by uuid,
  used_at timestamptz,
  check (kind = 'approve' or used_by is not null or wrapped_key is not null)
);
create index space_invitations_workspace on public.space_invitations (workspace_id);

-- === Who may do what ========================================================

-- The workspaces whose records the caller reads: the spaces they are an
-- active member of, and their own personal workspaces.
create function private.my_workspace_ids() returns setof uuid
language sql stable security definer set search_path = '' as $$
  select m.workspace_id from public.space_members m
    where m.account_id = (select auth.uid()) and m.status = 'active'
  union
  select w.workspace_id from public.account_workspaces w
    where w.account_id = (select auth.uid()) and w.unlock_kind <> 'space';
$$;

-- The spaces the caller owns.
create function private.my_owned_space_ids() returns setof uuid
language sql stable security definer set search_path = '' as $$
  select m.workspace_id from public.space_members m
    where m.account_id = (select auth.uid()) and m.role = 'owner';
$$;

-- The accounts the caller shares a space with (the caller active; the
-- other active or waiting, so the owner can wrap the key for them).
create function private.co_member_ids() returns setof uuid
language sql stable security definer set search_path = '' as $$
  select theirs.account_id from public.space_members mine
    join public.space_members theirs on theirs.workspace_id = mine.workspace_id
   where mine.account_id = (select auth.uid()) and mine.status = 'active';
$$;

-- The caller's role in a workspace: an active member's role in a space, or
-- 'owner' of their personal workspace; null otherwise.
create function private.role_in(p_workspace uuid) returns text
language sql stable security definer set search_path = '' as $$
  select coalesce(
    (select m.role from public.space_members m
      where m.workspace_id = p_workspace and m.account_id = (select auth.uid()) and m.status = 'active'),
    (select 'owner' from public.account_workspaces w
      where w.workspace_id = p_workspace and w.account_id = (select auth.uid()) and w.unlock_kind <> 'space'));
$$;

create function private.must_own(p_workspace uuid) returns void
language plpgsql stable security definer set search_path = '' as $$
begin
  if not exists (select 1 from public.space_members m
                  where m.workspace_id = p_workspace and m.account_id = (select auth.uid()) and m.role = 'owner') then
    raise exception 'not the owner of this space' using errcode = '42501';
  end if;
end;
$$;

revoke all on function private.my_workspace_ids(), private.my_owned_space_ids(), private.co_member_ids(),
  private.role_in(uuid), private.must_own(uuid) from public, anon;
grant execute on function private.my_workspace_ids(), private.my_owned_space_ids(), private.co_member_ids(),
  private.role_in(uuid), private.must_own(uuid) to authenticated;

-- === Tables: read under the policies, written through the functions =======

alter table public.account_public_keys enable row level security;
alter table public.account_private_keys enable row level security;
alter table public.spaces enable row level security;
alter table public.space_members enable row level security;
alter table public.space_invitations enable row level security;
revoke all on public.account_public_keys, public.account_private_keys, public.spaces,
  public.space_members, public.space_invitations from anon, authenticated;
grant select on public.account_public_keys, public.account_private_keys, public.spaces,
  public.space_members, public.space_invitations to authenticated;

create policy own_or_shared_public_key on public.account_public_keys for select to authenticated
  using (account_id = (select auth.uid()) or account_id in (select private.co_member_ids()));
create policy own_private_key on public.account_private_keys for select to authenticated
  using (account_id = (select auth.uid()));
create policy members_see_space on public.spaces for select to authenticated
  using (workspace_id in (select private.my_workspace_ids()));
create policy members_see_members on public.space_members for select to authenticated
  using (workspace_id in (select private.my_workspace_ids()) or account_id = (select auth.uid()));
create policy owner_sees_invitations on public.space_invitations for select to authenticated
  using (workspace_id in (select private.my_owned_space_ids()));

-- Personal workspaces as in P04a; a space's row is made, changed and handed
-- over only by the functions (its owner may still delete it: the space and
-- everything in it goes).
drop policy own_workspaces on public.account_workspaces;
create policy own_workspaces_read on public.account_workspaces for select to authenticated
  using (account_id = (select auth.uid()));
create policy own_workspaces_delete on public.account_workspaces for delete to authenticated
  using (account_id = (select auth.uid()));
create policy own_personal_insert on public.account_workspaces for insert to authenticated
  with check (account_id = (select auth.uid()) and unlock_kind <> 'space');
create policy own_personal_update on public.account_workspaces for update to authenticated
  using (account_id = (select auth.uid()) and unlock_kind <> 'space')
  with check (account_id = (select auth.uid()) and unlock_kind <> 'space');

-- Records: every active member reads them; written only through
-- push_records and purge_records, by an owner or an editor.
drop policy own_records on public.sync_records;
create policy members_read_records on public.sync_records for select to authenticated
  using (workspace_id in (select private.my_workspace_ids()));

create or replace function public.push_records(p_workspace uuid, p_device text, p_records jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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
  -- An owner or an editor (a viewer, someone waiting, a removed member and
  -- a stranger are all told the same); the row lock orders change numbers.
  if coalesce(private.role_in(p_workspace), '') not in ('owner', 'editor') then
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
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer := 0;
  rec record;
  next_seq bigint;
begin
  if coalesce(private.role_in(p_workspace), '') not in ('owner', 'editor') then
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

-- === Account keys ==========================================================

-- Publishes the caller's public key and keeps their private key sealed with
-- their personal workspace key; again with a new sealing after a reset of
-- the personal key. A new public key leaves the keys wrapped with the old
-- one unusable until they are wrapped again (ADR-0061).
create function public.set_account_keys(p_public bytea, p_sealed_private bytea)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  insert into public.account_public_keys as k (account_id, public_key)
    values (auth.uid(), p_public)
    on conflict (account_id) do update set public_key = excluded.public_key, updated_at = now()
      where k.public_key is distinct from excluded.public_key;
  insert into public.account_private_keys as k (account_id, sealed_private)
    values (auth.uid(), p_sealed_private)
    on conflict (account_id) do update set sealed_private = excluded.sealed_private, updated_at = now();
end;
$$;

-- === Spaces and members (LF-INV-SHARE-003) ===============================

-- The spaces the caller is in or waits to join, with the key wrapped for
-- them and the rules (none while waiting: the policy on spaces hides them).
create function public.my_spaces()
returns table (workspace_id uuid, role text, status text, wrapped_key bytea, key_id text,
               leave_rule text, export_rule text, invite_default text, rules_changed_at timestamptz)
language sql stable security invoker set search_path = '' as $$
  select m.workspace_id, m.role, m.status, m.wrapped_key, m.key_id,
         s.leave_rule, s.export_rule, s.invite_default, s.rules_changed_at
    from public.space_members m
    left join public.spaces s on s.workspace_id = m.workspace_id
   where m.account_id = (select auth.uid())
   order by m.created_at;
$$;

create function public.create_space(p_workspace uuid, p_wrapped_for_me bytea, p_key_id text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not exists (select 1 from public.account_public_keys k where k.account_id = auth.uid()) then
    raise exception 'publish your public key first' using errcode = '22023', hint = 'lifeflow:noPublicKey';
  end if;
  if (select count(*) from public.space_members m where m.account_id = auth.uid()) >= 10 then
    raise exception 'at most 10 shared spaces per account' using errcode = '54000', hint = 'lifeflow:tooManySpaces';
  end if;
  if exists (select 1 from public.account_workspaces w where w.workspace_id = p_workspace) then
    raise exception 'the workspace exists' using errcode = '23505';
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
  perform private.must_own(p_workspace);
  if p_days not between 1 and 7 then
    raise exception 'an invitation lasts 1 to 7 days' using errcode = '22023';
  end if;
  if p_kind = 'joinAtOnce' and p_wrapped is null then
    raise exception 'a "join at once" invitation carries the key' using errcode = '22023';
  end if;
  insert into public.space_invitations (code_hash, workspace_id, role, kind, wrapped_key, key_id, expires_at, created_by)
    values (p_code_hash, p_workspace, p_role, p_kind,
            case when p_kind = 'joinAtOnce' then p_wrapped end,
            case when p_kind = 'joinAtOnce' then p_key_id else '' end,
            now() + make_interval(days => p_days), auth.uid());
end;
$$;

create function public.cancel_invitation(p_code_hash text)
returns void language plpgsql security definer set search_path = '' as $$
declare ws uuid;
begin
  select i.workspace_id into ws from public.space_invitations i where i.code_hash = p_code_hash and i.used_by is null;
  if not found then
    raise exception 'no such invitation' using errcode = 'P0002', hint = 'lifeflow:noSuchInvitation';
  end if;
  perform private.must_own(ws);
  delete from public.space_invitations where code_hash = p_code_hash;
end;
$$;

-- What an invitation is for, before accepting it: the role, its kind and
-- the space's rules (LF-INV-SHARE-005). Unknown, used and expired look the
-- same, and say nothing about any space.
create function public.peek_invitation(p_code_hash text) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  i public.space_invitations%rowtype;
  s public.spaces%rowtype;
begin
  select * into i from public.space_invitations
    where code_hash = p_code_hash and used_by is null and expires_at > now();
  if not found then
    raise exception 'no such invitation' using errcode = 'P0002', hint = 'lifeflow:noSuchInvitation';
  end if;
  select * into s from public.spaces where workspace_id = i.workspace_id;
  return jsonb_build_object('workspace_id', i.workspace_id, 'role', i.role, 'kind', i.kind,
    'leave_rule', s.leave_rule, 'export_rule', s.export_rule, 'expires_at', i.expires_at);
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
    raise exception 'no such invitation' using errcode = 'P0002', hint = 'lifeflow:noSuchInvitation';
  end if;
  if not exists (select 1 from public.account_public_keys k where k.account_id = auth.uid()) then
    raise exception 'publish your public key first' using errcode = '22023', hint = 'lifeflow:noPublicKey';
  end if;
  if exists (select 1 from public.space_members m where m.workspace_id = i.workspace_id and m.account_id = auth.uid()) then
    raise exception 'already in this space' using errcode = '23505', hint = 'lifeflow:alreadyMember';
  end if;
  -- The space's row is locked so two people cannot both take the tenth seat.
  perform 1 from public.spaces sp where sp.workspace_id = i.workspace_id for update;
  if (select count(*) from public.space_members m where m.workspace_id = i.workspace_id) >= 10 then
    raise exception 'at most 10 members per space' using errcode = '54000', hint = 'lifeflow:spaceFull';
  end if;
  if (select count(*) from public.space_members m where m.account_id = auth.uid()) >= 10 then
    raise exception 'at most 10 shared spaces per account' using errcode = '54000', hint = 'lifeflow:tooManySpaces';
  end if;
  update public.space_invitations set used_by = auth.uid(), used_at = now(), wrapped_key = null
    where code_hash = p_code_hash;
  insert into public.space_members (workspace_id, account_id, role, status, wrapped_key, key_id, added_by)
    values (i.workspace_id, auth.uid(), i.role,
            case when i.kind = 'joinAtOnce' then 'active' else 'pending' end,
            case when i.kind = 'joinAtOnce' then i.wrapped_key end,
            case when i.kind = 'joinAtOnce' then i.key_id else '' end, i.created_by);
  select * into s from public.spaces where workspace_id = i.workspace_id;
  return jsonb_build_object('workspace_id', i.workspace_id, 'role', i.role, 'kind', i.kind,
    'wrapped_key', case when i.kind = 'joinAtOnce' then encode(i.wrapped_key, 'base64') end,
    'key_id', case when i.kind = 'joinAtOnce' then i.key_id else '' end,
    'leave_rule', s.leave_rule, 'export_rule', s.export_rule);
end;
$$;

create function public.approve_member(p_workspace uuid, p_account uuid, p_wrapped bytea, p_key_id text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform private.must_own(p_workspace);
  if p_key_id is distinct from (select w.key_id from public.account_workspaces w where w.workspace_id = p_workspace) then
    raise exception 'not the current key' using errcode = '22023', hint = 'lifeflow:staleKey';
  end if;
  update public.space_members set status = 'active', wrapped_key = p_wrapped, key_id = p_key_id
    where workspace_id = p_workspace and account_id = p_account and status = 'pending';
  if not found then
    raise exception 'nobody is waiting' using errcode = 'P0002', hint = 'lifeflow:nobodyWaiting';
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
      and m.key_id = p_key_id
      and p_key_id = (select w.key_id from public.account_workspaces w where w.workspace_id = p_workspace);
  if not found then
    raise exception 'not a member, or not the current key' using errcode = '42501';
  end if;
end;
$$;

-- Removes a member or turns down someone waiting. The key is rotated next
-- (B8), by the owner's device.
create function public.remove_member(p_workspace uuid, p_account uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform private.must_own(p_workspace);
  delete from public.space_members
    where workspace_id = p_workspace and account_id = p_account and role <> 'owner';
  if not found then
    raise exception 'not a member who can be removed' using errcode = 'P0002', hint = 'lifeflow:notAMember';
  end if;
end;
$$;

create function public.leave_space(p_workspace uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if exists (select 1 from public.space_members m
              where m.workspace_id = p_workspace and m.account_id = auth.uid() and m.role = 'owner') then
    raise exception 'the owner hands the space over before leaving' using errcode = '22023',
      hint = 'lifeflow:ownerMustHandOver';
  end if;
  delete from public.space_members where workspace_id = p_workspace and account_id = auth.uid();
  if not found then
    raise exception 'not a member' using errcode = 'P0002', hint = 'lifeflow:notAMember';
  end if;
end;
$$;

create function public.set_role(p_workspace uuid, p_account uuid, p_role text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform private.must_own(p_workspace);
  if p_role not in ('editor', 'viewer') then
    raise exception 'use hand_over for the owner role' using errcode = '22023';
  end if;
  update public.space_members set role = p_role
    where workspace_id = p_workspace and account_id = p_account and role <> 'owner';
  if not found then
    raise exception 'no such member' using errcode = 'P0002', hint = 'lifeflow:notAMember';
  end if;
end;
$$;

-- The owner role moves to an active member; the old owner stays as an
-- editor, and the space's workspace row follows the new owner.
create function public.hand_over(p_workspace uuid, p_account uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform private.must_own(p_workspace);
  if not exists (select 1 from public.space_members m where m.workspace_id = p_workspace
                   and m.account_id = p_account and m.status = 'active' and m.role <> 'owner') then
    raise exception 'hand over to an active member' using errcode = 'P0002', hint = 'lifeflow:notAMember';
  end if;
  update public.space_members set role = 'editor' where workspace_id = p_workspace and account_id = auth.uid();
  update public.space_members set role = 'owner' where workspace_id = p_workspace and account_id = p_account;
  update public.account_workspaces set account_id = p_account where workspace_id = p_workspace;
end;
$$;

create function public.set_space_rules(p_workspace uuid, p_leave text, p_export text, p_invite text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform private.must_own(p_workspace);
  update public.spaces set leave_rule = p_leave, export_rule = p_export, invite_default = p_invite,
         rules_changed_at = now()
    where workspace_id = p_workspace
      and (leave_rule, export_rule, invite_default) is distinct from (p_leave, p_export, p_invite);
end;
$$;

-- A new space key (after a removal, B8): wrapped for exactly the active
-- members; unused "join at once" invitations of the old key stop working.
-- Anyone still waiting holds no key and is approved with the new one.
create function public.rotate_space_key(p_workspace uuid, p_key_id text, p_wraps jsonb)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform private.must_own(p_workspace);
  perform 1 from public.spaces sp where sp.workspace_id = p_workspace for update;
  if (select coalesce(array_agg(m.account_id::text order by m.account_id::text), '{}')
        from public.space_members m where m.workspace_id = p_workspace and m.status = 'active')
     is distinct from
     (select coalesce(array_agg(e ->> 'account' order by e ->> 'account'), '{}')
        from jsonb_array_elements(p_wraps) e) then
    raise exception 'wrap the new key for exactly the active members' using errcode = '22023',
      hint = 'lifeflow:wrongMembers';
  end if;
  update public.space_members m set wrapped_key = decode(e ->> 'wrapped', 'base64'), key_id = p_key_id
    from jsonb_array_elements(p_wraps) e
    where m.workspace_id = p_workspace and m.account_id = (e ->> 'account')::uuid;
  update public.account_workspaces w set key_id = p_key_id,
         wrapped_key = (select decode(e ->> 'wrapped', 'base64') from jsonb_array_elements(p_wraps) e
                         where (e ->> 'account')::uuid = auth.uid())
    where w.workspace_id = p_workspace;
  delete from public.space_invitations
    where workspace_id = p_workspace and used_by is null and kind = 'joinAtOnce';
end;
$$;

do $$
declare f text;
begin
  foreach f in array array[
    'public.set_account_keys(bytea, bytea)', 'public.my_spaces()',
    'public.create_space(uuid, bytea, text)', 'public.invite(uuid, text, text, text, bytea, text, integer)',
    'public.cancel_invitation(text)', 'public.peek_invitation(text)', 'public.accept_invitation(text)',
    'public.approve_member(uuid, uuid, bytea, text)', 'public.set_my_wrapped_key(uuid, bytea, text)',
    'public.remove_member(uuid, uuid)', 'public.leave_space(uuid)', 'public.set_role(uuid, uuid, text)',
    'public.hand_over(uuid, uuid)', 'public.set_space_rules(uuid, text, text, text)',
    'public.rotate_space_key(uuid, text, jsonb)'] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end;
$$;
