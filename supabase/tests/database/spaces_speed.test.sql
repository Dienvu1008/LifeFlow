-- P04b T9 (ADR-0061; S-16 part 2, OQ-V5): the members' read policy under
-- load. A space with 20 000 records and 10 members, and 20 000 records of
-- other accounts' personal workspaces; a member pulls a page of 1000 and
-- counts everything they can read. The times are printed (diag); the test
-- asserts the rows and an upper bound.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users (id, email)
  select ('00000000-0000-4000-8000-0000000002' || lpad(n::text, 2, '0'))::uuid, 'm' || n || '@example.test'
    from generate_series(1, 10) n;
-- The space (made here as the server's owner would; the functions are
-- tested in spaces.test.sql).
insert into public.account_workspaces (workspace_id, account_id, wrapped_key, unlock_kind)
  values ('20000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-000000000201', '\x01', 'space');
insert into public.spaces (workspace_id) values ('20000000-0000-4000-8000-0000000000e1');
insert into public.space_members (workspace_id, account_id, role, status, wrapped_key)
  select '20000000-0000-4000-8000-0000000000e1', ('00000000-0000-4000-8000-0000000002' || lpad(n::text, 2, '0'))::uuid,
         case when n = 1 then 'owner' else 'editor' end, 'active', '\x01'
    from generate_series(1, 10) n;
-- Each other member's personal workspace, in the same table.
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
-- What member 5 may read: the space, and their own personal workspace.
create temp table expected as select count(*) as n from public.sync_records
  where workspace_id in ('20000000-0000-4000-8000-0000000000e1', '20000000-0000-4000-8000-000000000305');
grant select on expected to authenticated;

create function pg_temp.as_member(n int) returns void language sql as $$
  select set_config('role', 'authenticated', true),
         set_config('request.jwt.claims', json_build_object('sub',
           ('00000000-0000-4000-8000-0000000002' || lpad(n::text, 2, '0'))::uuid, 'role', 'authenticated')::text, true);
$$;

create function pg_temp.measure() returns table (page_ms numeric, count_ms numeric, page bigint, seen bigint)
language plpgsql as $$
declare t0 timestamptz;
begin
  t0 := clock_timestamp();
  select count(*) into page from public.pull_records('20000000-0000-4000-8000-0000000000e1', 5000);
  page_ms := extract(epoch from clock_timestamp() - t0) * 1000;
  t0 := clock_timestamp();
  select count(*) into seen from public.sync_records;
  count_ms := extract(epoch from clock_timestamp() - t0) * 1000;
  return next;
end;
$$;

select pg_temp.as_member(5);
create temp table times as select * from pg_temp.measure();
select diag('page of 1000 ' || round(page_ms, 1) || ' ms, count ' || round(count_ms, 1) || ' ms, rows seen ' || seen)
  from times;
select is((select page from times), 1000::bigint, 'a member pulls a full page of the space');
select is((select seen from times), (select n from expected), 'a member reads the space and their own workspace only');
select ok((select page_ms from times) < 500, 'a page of 1000 within 500 ms');
select ok((select count_ms from times) < 500, 'a count of everything within 500 ms');

select * from finish();
rollback;
