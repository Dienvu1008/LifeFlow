-- P04b spike S-16, part 2 (OQ-V5): how fast the members' read policy is.
-- A space with 20 000 records and 10 members; a member pulls a page of 1000
-- and counts everything, under two policies:
--   per row  space_role(workspace_id) is not null (called for each row)
--   set      workspace_id in (select my_workspace_ids()) (called once)
-- The times are printed (diag); the test asserts only an upper bound.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

create table public.spike_members (workspace_id uuid, account_id uuid, status text,
  primary key (workspace_id, account_id));
create function public.spike_role(p_workspace uuid) returns text
language sql stable security definer set search_path = '' as $$
  select coalesce(
    (select 'editor' from public.spike_members m
      where m.workspace_id = p_workspace and m.account_id = (select auth.uid()) and m.status = 'active'),
    (select 'owner' from public.account_workspaces w
      where w.workspace_id = p_workspace and w.account_id = (select auth.uid())));
$$;
create function public.spike_workspace_ids() returns setof uuid
language sql stable security definer set search_path = '' as $$
  select m.workspace_id from public.spike_members m where m.account_id = (select auth.uid()) and m.status = 'active'
  union
  select w.workspace_id from public.account_workspaces w where w.account_id = (select auth.uid());
$$;
grant execute on function public.spike_role(uuid), public.spike_workspace_ids() to authenticated;

insert into auth.users (id, email)
  select ('00000000-0000-4000-8000-0000000002' || lpad(n::text, 2, '0'))::uuid, 'm' || n || '@example.test'
    from generate_series(1, 10) n;
insert into public.account_workspaces (workspace_id, account_id, wrapped_key, unlock_kind)
  values ('20000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-000000000201', '\x01', 'recoveryKey');
insert into public.spike_members
  select '20000000-0000-4000-8000-0000000000e1', ('00000000-0000-4000-8000-0000000002' || lpad(n::text, 2, '0'))::uuid, 'active'
    from generate_series(1, 10) n;
-- Other accounts' data in the same table, as on a shared server.
insert into public.account_workspaces (workspace_id, account_id, wrapped_key, unlock_kind)
  select ('20000000-0000-4000-8000-0000000003' || lpad(n::text, 2, '0'))::uuid,
         ('00000000-0000-4000-8000-0000000002' || lpad(n::text, 2, '0'))::uuid, '\x01', 'recoveryKey'
    from generate_series(2, 10) n;
insert into public.sync_records (workspace_id, id, version, seq, deleted, sealed, device_id, operation_id)
  select '20000000-0000-4000-8000-0000000000e1', lpad(to_hex(g), 64, '0'), 1, g, false,
         decode(repeat('ab', 400), 'hex'), 'pc', gen_random_uuid()
    from generate_series(1, 20000) g;
insert into public.sync_records (workspace_id, id, version, seq, deleted, sealed, device_id, operation_id)
  select ('20000000-0000-4000-8000-0000000003' || lpad((2 + g % 9)::text, 2, '0'))::uuid, lpad(to_hex(g), 64, '0'), 1, g, false,
         decode(repeat('cd', 400), 'hex'), 'pc', gen_random_uuid()
    from generate_series(1, 20000) g;
analyze public.sync_records;
-- What member 5 may see: the space, and the personal workspace it owns.
create temp table expected as select count(*) as n from public.sync_records
  where workspace_id in ('20000000-0000-4000-8000-0000000000e1', '20000000-0000-4000-8000-000000000305');
grant select on expected to authenticated;

create function pg_temp.as_member(n int) returns void language sql as $$
  select set_config('role', 'authenticated', true),
         set_config('request.jwt.claims', json_build_object('sub',
           ('00000000-0000-4000-8000-0000000002' || lpad(n::text, 2, '0'))::uuid, 'role', 'authenticated')::text, true);
$$;

-- Times of a page of 1000 (as pull_records reads it) and of a full count.
create function pg_temp.measure() returns table (page_ms numeric, count_ms numeric, seen bigint) language plpgsql as $$
declare t0 timestamptz;
begin
  t0 := clock_timestamp();
  perform s.id from public.sync_records s
    where s.workspace_id = '20000000-0000-4000-8000-0000000000e1' and s.seq > 5000 order by s.seq limit 1000;
  page_ms := extract(epoch from clock_timestamp() - t0) * 1000;
  t0 := clock_timestamp();
  select count(*) into seen from public.sync_records;
  count_ms := extract(epoch from clock_timestamp() - t0) * 1000;
  return next;
end;
$$;

drop policy own_records on public.sync_records;
create policy per_row on public.sync_records for select to authenticated
  using (public.spike_role(workspace_id) is not null);
select pg_temp.as_member(5);
create temp table per_row_times as select * from pg_temp.measure();
select diag('per row: page of 1000 ' || round(page_ms, 1) || ' ms, count ' || round(count_ms, 1) || ' ms, rows seen ' || seen)
  from per_row_times;
select is((select seen from per_row_times), (select n from expected), 'per row: a member sees the space and their own workspace only');

select set_config('role', 'postgres', true), set_config('request.jwt.claims', '', true);
drop policy per_row on public.sync_records;
create policy by_set on public.sync_records for select to authenticated
  using (workspace_id in (select public.spike_workspace_ids()));
select pg_temp.as_member(5);
create temp table set_times as select * from pg_temp.measure();
select diag('set:     page of 1000 ' || round(page_ms, 1) || ' ms, count ' || round(count_ms, 1) || ' ms, rows seen ' || seen)
  from set_times;
select is((select seen from set_times), (select n from expected), 'set: the same rows');
select ok((select page_ms from set_times) < 500, 'set: a page of 1000 within 500 ms');

select * from finish();
rollback;
