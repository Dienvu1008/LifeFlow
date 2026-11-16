-- P04 T2 (ADR-0055): pull_records gives a caller only its own workspace's
-- changes, after a cursor, in change-number order, in pages of at most 1000.
begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-00000000000a', 'a@example.test'),
  ('00000000-0000-4000-8000-00000000000b', 'b@example.test');

create function pg_temp.as_account(who uuid) returns void language sql as $$
  select set_config('role', 'authenticated', true),
         set_config('request.jwt.claims', json_build_object('sub', who, 'role', 'authenticated')::text, true);
$$;

select pg_temp.as_account('00000000-0000-4000-8000-00000000000a');
insert into public.account_workspaces (workspace_id, wrapped_key, unlock_kind)
  values ('10000000-0000-4000-8000-00000000000a', '\x01', 'recoveryKey');
-- 1200 changes, in three batches of 400 (a batch holds at most 500).
select public.push_records('10000000-0000-4000-8000-00000000000a', 'pc',
  (select jsonb_agg(jsonb_build_object('id', lpad(to_hex(g), 64, '0'), 'base', null, 'version', 1,
                                       'deleted', false, 'sealed', encode(('s' || g)::bytea, 'base64'),
                                       'op', gen_random_uuid()) order by g)
     from generate_series(b * 400 + 1, b * 400 + 400) g))
from generate_series(0, 2) b;

select is((select count(*)::int from public.pull_records('10000000-0000-4000-8000-00000000000a', 0)), 1000,
          'a page holds at most 1000 changes');
select is((select count(*)::int from public.pull_records('10000000-0000-4000-8000-00000000000a', 0, 5000)), 1000,
          'a bigger page is capped');
select is((select array_agg(seq order by seq) from public.pull_records('10000000-0000-4000-8000-00000000000a', 1197)),
          array[1198, 1199, 1200]::bigint[], 'after the cursor, in order');
select is((select convert_from(decode(sealed, 'base64'), 'utf8')
             from public.pull_records('10000000-0000-4000-8000-00000000000a', 1199)),
          's1200', 'the sealed bytes come back as base64');
select is((select count(*)::int from public.pull_records('10000000-0000-4000-8000-00000000000a', 0, 0)), 1,
          'a page holds at least one change');

select pg_temp.as_account('00000000-0000-4000-8000-00000000000b');
select is((select count(*)::int from public.pull_records('10000000-0000-4000-8000-00000000000a', 0)), 0,
          'B pulls nothing of A''s workspace');

select set_config('role', 'anon', true);
select throws_ok($$ select * from public.pull_records('10000000-0000-4000-8000-00000000000a', 0) $$,
                 '42501', null, 'anon cannot pull');
select ok(not has_function_privilege('anon', 'public.pull_records(uuid, bigint, integer)', 'execute'),
          'anon has no right to call pull_records');

select * from finish();
rollback;
