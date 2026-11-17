-- P04b T10 (ADR-0062): which key each record is sealed with, so a shared
-- space's key can be rotated after a removal (B8, LF-INV-SHARE-004):
--   1. the owner's device rotates the key (rotate_space_key);
--   2. pushes to the space must name the current key: a device still on the
--      old key is refused (hint lifeflow:staleKey) and fetches the new one,
--      so nothing is sealed with the old key after the rotation;
--   3. the records are sealed again with the new key and pushed (new server
--      ids, since ids are keyed too);
--   4. only then the owner drops the rows of the old key
--      (drop_old_key_records). Until then a member's device still reads
--      them, and skips the rows of a key it does not hold.
-- A personal workspace stores the key id a device gives ('' from P04a
-- devices) and checks nothing: its key changes only by a reset, which
-- deletes and uploads the workspace again (ADR-0057).

alter table public.sync_records
  add column key_id text not null default '' check (key_id = '' or key_id ~ '^[0-9a-f]{64}$');

drop function public.push_records(uuid, text, jsonb);

create function public.push_records(p_workspace uuid, p_device text, p_records jsonb, p_key_id text default '')
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r jsonb;
  cur public.sync_records%rowtype;
  ws public.account_workspaces%rowtype;
  next_seq bigint;
  accepted jsonb := '[]'::jsonb;
  conflicts jsonb := '[]'::jsonb;
  base integer;
begin
  if jsonb_typeof(p_records) <> 'array' or jsonb_array_length(p_records) > 500 then
    raise exception 'a batch is an array of at most 500 records' using errcode = '22023';
  end if;
  -- An owner or an editor (a viewer, someone waiting, a removed member and
  -- a stranger are all told the same); the row lock orders change numbers
  -- and keeps a rotation from passing a push half way.
  if coalesce(private.role_in(p_workspace), '') not in ('owner', 'editor') then
    raise exception 'unknown workspace' using errcode = '42501';
  end if;
  select * into ws from public.account_workspaces w where w.workspace_id = p_workspace for update;
  if ws.unlock_kind = 'space' and p_key_id is distinct from ws.key_id then
    raise exception 'sealed with a key that is not the space''s current key' using errcode = '22023',
      hint = 'lifeflow:staleKey';
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
          (workspace_id, id, version, seq, deleted, sealed, device_id, operation_id, updated_at, key_id)
        values (p_workspace, r ->> 'id', (r ->> 'version')::integer, next_seq,
                coalesce((r ->> 'deleted')::boolean, false),
                decode(r ->> 'sealed', 'base64'), p_device, (r ->> 'op')::uuid, now(), coalesce(p_key_id, ''))
        on conflict (workspace_id, id) do update
          set version = excluded.version, seq = excluded.seq, deleted = excluded.deleted,
              sealed = excluded.sealed, device_id = excluded.device_id,
              operation_id = excluded.operation_id, updated_at = excluded.updated_at,
              key_id = excluded.key_id;
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

revoke all on function public.push_records(uuid, text, jsonb, text) from public, anon;
grant execute on function public.push_records(uuid, text, jsonb, text) to authenticated;

drop function public.pull_records(uuid, bigint, integer);

create function public.pull_records(p_workspace uuid, p_after bigint, p_limit integer default 1000)
returns table (id text, version integer, seq bigint, deleted boolean, sealed text, device_id text, key_id text)
language sql
stable
security invoker
set search_path = ''
as $$
  select s.id, s.version, s.seq, s.deleted, encode(s.sealed, 'base64'), s.device_id, s.key_id
  from public.sync_records s
  where s.workspace_id = p_workspace and s.seq > p_after
  order by s.seq
  limit least(greatest(p_limit, 1), 1000);
$$;

revoke all on function public.pull_records(uuid, bigint, integer) from public, anon;
grant execute on function public.pull_records(uuid, bigint, integer) to authenticated;

-- Step 4: the owner drops the rows sealed with any key but the current one,
-- once the records are sealed again with it. Returns how many went.
create function public.drop_old_key_records(p_workspace uuid)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  current_key text;
  n integer;
begin
  perform private.must_own(p_workspace);
  select w.key_id into current_key from public.account_workspaces w where w.workspace_id = p_workspace for update;
  delete from public.sync_records s where s.workspace_id = p_workspace and s.key_id is distinct from current_key;
  get diagnostics n = row_count;
  return n;
end;
$$;

revoke all on function public.drop_old_key_records(uuid) from public, anon;
grant execute on function public.drop_old_key_records(uuid) to authenticated;
