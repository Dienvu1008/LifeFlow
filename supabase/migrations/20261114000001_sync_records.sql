-- P04 spike S-03 (p04-plan.md D2, D12): the server side of sync for one
-- account's devices. The server stores sealed (end-to-end encrypted)
-- records and orders changes; it never sees content, kinds or relations.
--
--   account_workspaces  the account's synced workspace and its key, wrapped
--                       by the account key (the server cannot unwrap it)
--   sync_records        one row per record: an opaque id (a keyed hash of
--                       the record's kind and local id, made on the device),
--                       its version, a per-workspace change number (seq),
--                       a deleted flag and the sealed bytes
--
-- Every table has row-level security: an account reads only its own
-- workspaces' rows. Records are written only by push_records and
-- purge_records, which check that the caller owns the workspace first.

create table public.account_workspaces (
  workspace_id uuid primary key,
  account_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  -- The workspace key wrapped by the account key (D12), and how the account
  -- key is recovered (D15): 'recoveryKey' or 'passphrase', with its salt.
  wrapped_key bytea not null,
  unlock_kind text not null check (unlock_kind in ('recoveryKey', 'passphrase')),
  unlock_salt bytea,
  -- The last change number given out in this workspace.
  last_seq bigint not null default 0,
  created_at timestamptz not null default now()
);

create index account_workspaces_account on public.account_workspaces (account_id);

create table public.sync_records (
  workspace_id uuid not null references public.account_workspaces (workspace_id) on delete cascade,
  -- Opaque: 64 hex characters made on the device (D12); never a local id.
  id text not null check (id ~ '^[0-9a-f]{64}$'),
  version integer not null check (version >= 1),
  seq bigint not null,
  deleted boolean not null default false,
  -- Null only after a purge: the tombstone stays so other devices purge too.
  sealed bytea,
  device_id text not null check (length(device_id) between 1 and 64),
  operation_id uuid not null,
  updated_at timestamptz not null default now(),
  primary key (workspace_id, id),
  check (sealed is not null or deleted)
);

create index sync_records_pull on public.sync_records (workspace_id, seq);

alter table public.account_workspaces enable row level security;
alter table public.sync_records enable row level security;

-- Nothing for anonymous callers; signed-in accounts go through the policies.
revoke all on public.account_workspaces from anon, authenticated;
revoke all on public.sync_records from anon, authenticated;
grant select, delete on public.account_workspaces to authenticated;
grant insert (workspace_id, wrapped_key, unlock_kind, unlock_salt) on public.account_workspaces to authenticated;
grant update (wrapped_key, unlock_kind, unlock_salt) on public.account_workspaces to authenticated;
-- Records are written only through push_records and purge_records.
grant select on public.sync_records to authenticated;

create policy own_workspaces on public.account_workspaces
  for all to authenticated
  using (account_id = (select auth.uid()))
  with check (account_id = (select auth.uid()));

create policy own_records on public.sync_records
  for select to authenticated
  using (exists (
    select 1 from public.account_workspaces w
    where w.workspace_id = sync_records.workspace_id
      and w.account_id = (select auth.uid())));


-- Push a batch of sealed records. Each element:
--   {"id": hex, "base": int|null, "version": int, "deleted": bool,
--    "sealed": base64|null, "op": uuid}
-- A record is accepted when its base is the stored version (or it is new and
-- base is null); otherwise it is a conflict and the stored version is
-- returned, so the device pulls and resolves it (version, never time:
-- LF-INV-SYNC-002). A replay of an accepted operation is accepted again
-- without a change (LF-INV-SYNC-001). One lock per workspace makes change
-- numbers commit in order, so a pull never skips a change.
create function public.push_records(p_workspace uuid, p_device text, p_records jsonb)
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
  -- The caller must own the workspace; the row lock orders the change
  -- numbers of concurrent pushes.
  perform 1 from public.account_workspaces w
    where w.workspace_id = p_workspace and w.account_id = auth.uid() for update;
  if not found then
    raise exception 'unknown workspace' using errcode = '42501';
  end if;

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

revoke all on function public.push_records(uuid, text, jsonb) from public, anon;
grant execute on function public.push_records(uuid, text, jsonb) to authenticated;

-- Purge (GS-14): the sealed bytes of records deleted before the cut-off go,
-- and never before the 90-day retention (p04-plan.md section 4);
-- the tombstone stays with a new change number, so every device purges too.
create function public.purge_records(p_workspace uuid, p_before timestamptz)
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
  perform 1 from public.account_workspaces w
    where w.workspace_id = p_workspace and w.account_id = auth.uid() for update;
  if not found then
    raise exception 'unknown workspace' using errcode = '42501';
  end if;
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

revoke all on function public.purge_records(uuid, timestamptz) from public, anon;
grant execute on function public.purge_records(uuid, timestamptz) to authenticated;
