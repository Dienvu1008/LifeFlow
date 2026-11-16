-- P04 T2 (ADR-0055): pulling changes. Runs as the caller, so row-level
-- security keeps it to the caller's own workspaces (an unknown or foreign
-- workspace gives no rows, never an error that says it exists). Sealed bytes
-- come back as base64 text, the form push_records takes them in.
create function public.pull_records(p_workspace uuid, p_after bigint, p_limit integer default 1000)
returns table (id text, version integer, seq bigint, deleted boolean, sealed text, device_id text)
language sql
stable
security invoker
set search_path = ''
as $$
  select s.id, s.version, s.seq, s.deleted, encode(s.sealed, 'base64'), s.device_id
  from public.sync_records s
  where s.workspace_id = p_workspace and s.seq > p_after
  order by s.seq
  limit least(greatest(p_limit, 1), 1000);
$$;

revoke all on function public.pull_records(uuid, bigint, integer) from public, anon;
grant execute on function public.pull_records(uuid, bigint, integer) to authenticated;
