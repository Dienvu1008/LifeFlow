-- P04 spike S-03 (p04-plan.md, R-PERMISSION): allow/deny for the sync
-- tables and functions, per caller. Run with `supabase test db`.
--   A and B are two accounts; anon is a caller without a session.
--   An account reads and writes only its own workspace, also through the
--   functions; versions decide conflicts (SYNC-002); a replay changes
--   nothing (SYNC-001); a purge keeps the tombstone and moves it on (GS-14).
begin;
create extension if not exists pgtap with schema extensions;
select plan(29);

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-00000000000a', 'a@example.test'),
  ('00000000-0000-4000-8000-00000000000b', 'b@example.test');

create function pg_temp.as_account(who uuid) returns void language sql as $$
  select set_config('role', 'authenticated', true),
         set_config('request.jwt.claims',
                    json_build_object('sub', who, 'role', 'authenticated')::text, true);
$$;
create function pg_temp.as_admin() returns void language sql as $$
  select set_config('role', 'postgres', true), set_config('request.jwt.claims', '', true);
$$;

-- A record of the push format; ids are 64 hex characters.
create function pg_temp.rec(n int, base int, version int, op text, deleted boolean default false)
returns jsonb language sql as $$
  select jsonb_build_object('id', lpad(to_hex(n), 64, '0'), 'base', base, 'version', version,
                            'deleted', deleted, 'sealed', encode('sealed bytes'::bytea, 'base64'),
                            'op', op);
$$;

-- A makes its workspace and pushes two new records.
select pg_temp.as_account('00000000-0000-4000-8000-00000000000a');
select lives_ok($$ insert into public.account_workspaces (workspace_id, wrapped_key, unlock_kind)
                   values ('10000000-0000-4000-8000-00000000000a', '\x01', 'recoveryKey') $$,
                'A makes its workspace');
select is((public.push_records('10000000-0000-4000-8000-00000000000a', 'pc',
            jsonb_build_array(pg_temp.rec(1, null, 1, '20000000-0000-4000-8000-000000000001'),
                              pg_temp.rec(2, null, 1, '20000000-0000-4000-8000-000000000002')))
          -> 'accepted') -> 1 ->> 'seq', '2', 'new records get change numbers 1 and 2');
select is((select count(*)::int from public.sync_records), 2, 'A reads its two records');

-- A replay of the same operation is accepted and changes nothing (SYNC-001).
select is((public.push_records('10000000-0000-4000-8000-00000000000a', 'pc',
            jsonb_build_array(pg_temp.rec(1, null, 1, '20000000-0000-4000-8000-000000000001')))
          -> 'accepted') -> 0 ->> 'seq', '1', 'a replay is accepted with its first change number');
select is((select last_seq from public.account_workspaces), 2::bigint, 'a replay gives out no number');

-- A stale base is a conflict that names the stored version (SYNC-002).
select is(public.push_records('10000000-0000-4000-8000-00000000000a', 'phone',
            jsonb_build_array(pg_temp.rec(1, null, 1, '20000000-0000-4000-8000-000000000003'))),
          jsonb_build_object('accepted', '[]'::jsonb,
                             'conflicts', jsonb_build_array(jsonb_build_object('id', lpad('1', 64, '0'), 'version', 1))),
          'a new record over an existing one is a conflict');
select is((public.push_records('10000000-0000-4000-8000-00000000000a', 'phone',
            jsonb_build_array(pg_temp.rec(1, 1, 2, '20000000-0000-4000-8000-000000000004')))
          -> 'accepted') -> 0 ->> 'seq', '3', 'the right base is accepted with the next number');
select is((public.push_records('10000000-0000-4000-8000-00000000000a', 'pc',
            jsonb_build_array(pg_temp.rec(1, 1, 2, '20000000-0000-4000-8000-000000000005')))
          -> 'conflicts') -> 0 ->> 'version', '2', 'the old base is now a conflict, with version 2');
select throws_ok($$ select public.push_records('10000000-0000-4000-8000-00000000000a', 'pc',
                     jsonb_build_array(pg_temp.rec(1, 2, 2, '20000000-0000-4000-8000-000000000006'))) $$,
                 '22023', null, 'a version must go up');
select throws_ok($$ select public.push_records('10000000-0000-4000-8000-00000000000a', 'pc',
                     jsonb_build_array(jsonb_build_object('id', 'task-1', 'base', null, 'version', 1,
                       'sealed', '', 'op', '20000000-0000-4000-8000-000000000007'))) $$,
                 '23514', null, 'a readable local id is refused: ids are opaque');
select throws_ok($$ select public.push_records('10000000-0000-4000-8000-00000000000a', 'pc',
                     (select jsonb_agg(pg_temp.rec(g, null, 1, gen_random_uuid()::text))
                        from generate_series(10, 510) g)) $$,
                 '22023', null, 'a batch over 500 records is refused');

-- A cannot write records or change numbers around the functions.
select throws_ok($$ insert into public.sync_records (workspace_id, id, version, seq, sealed, device_id, operation_id)
                    values ('10000000-0000-4000-8000-00000000000a', lpad('9', 64, '0'), 1, 99, '\x00', 'pc',
                            gen_random_uuid()) $$,
                 '42501', null, 'no direct insert of records');
select throws_ok($$ update public.sync_records set seq = 1 $$, '42501', null, 'no direct update of records');
select throws_ok($$ update public.account_workspaces set last_seq = 0 $$, '42501', null,
                 'no direct change of the change number');

-- B sees nothing of A and cannot write into A's workspace.
select pg_temp.as_account('00000000-0000-4000-8000-00000000000b');
select is((select count(*)::int from public.sync_records), 0, 'B reads none of A''s records');
select is((select count(*)::int from public.account_workspaces), 0, 'B sees no workspace of A');
select throws_ok($$ select public.push_records('10000000-0000-4000-8000-00000000000a', 'b',
                     jsonb_build_array(pg_temp.rec(3, null, 1, '30000000-0000-4000-8000-000000000001'))) $$,
                 '42501', null, 'B cannot push into A''s workspace');
select throws_ok($$ select public.purge_records('10000000-0000-4000-8000-00000000000a', now()) $$,
                 '42501', null, 'B cannot purge A''s workspace');
select throws_ok($$ insert into public.account_workspaces (workspace_id, account_id, wrapped_key, unlock_kind)
                    values ('10000000-0000-4000-8000-0000000000bb', '00000000-0000-4000-8000-00000000000a',
                            '\x01', 'passphrase') $$,
                 '42501', null, 'B cannot make a workspace for A');
delete from public.account_workspaces where workspace_id = '10000000-0000-4000-8000-00000000000a';
select pg_temp.as_admin();
select is((select count(*)::int from public.account_workspaces), 1, 'B''s delete removed nothing of A');

-- A caller without a session reaches nothing.
select ok(not has_function_privilege('anon', 'public.push_records(uuid, text, jsonb)', 'execute'),
          'anon has no right to call push_records');
select ok(not has_function_privilege('anon', 'public.purge_records(uuid, timestamptz)', 'execute'),
          'anon has no right to call purge_records');
select set_config('role', 'anon', true);
select throws_ok($$ select count(*) from public.sync_records $$, '42501', null, 'anon cannot read records');
select throws_ok($$ select public.push_records('10000000-0000-4000-8000-00000000000a', 'x', '[]'::jsonb) $$,
                 '42501', null, 'anon cannot push');

-- Purge after the retention: the tombstone stays and moves on (GS-14).
select pg_temp.as_account('00000000-0000-4000-8000-00000000000a');
select public.push_records('10000000-0000-4000-8000-00000000000a', 'pc',
         jsonb_build_array(pg_temp.rec(2, 1, 2, '20000000-0000-4000-8000-000000000010', true),
                           pg_temp.rec(4, null, 1, '20000000-0000-4000-8000-000000000011', true)));
select pg_temp.as_admin();
update public.sync_records set updated_at = now() - interval '100 days' where id = lpad('2', 64, '0');
update public.sync_records set updated_at = now() - interval '10 days' where id = lpad('4', 64, '0');
select pg_temp.as_account('00000000-0000-4000-8000-00000000000a');
select is(public.purge_records('10000000-0000-4000-8000-00000000000a', now()), 1,
          'only the record deleted before the 90-day retention is purged');
select is((select (sealed is null, deleted) from public.sync_records where id = lpad('2', 64, '0')),
          (true, true), 'its tombstone stays without content');
select is((select seq from public.sync_records where id = lpad('2', 64, '0')),
          (select max(seq) from public.sync_records), 'the purge has the newest change number');

-- "Delete my data from the server" (D11): everything of the workspace goes.
delete from public.account_workspaces where workspace_id = '10000000-0000-4000-8000-00000000000a';
select pg_temp.as_admin();
select is((select count(*)::int from public.sync_records), 0, 'deleting the workspace deletes its records');
select is((select count(*)::int from auth.users), 2, 'the accounts themselves stay');

select * from finish();
rollback;
