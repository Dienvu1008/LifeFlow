-- P04b T10 (ADR-0062; migration 20261118000001_record_key_id.sql): rotating
-- a space's key. A push names the key its records are sealed with; a space
-- takes only its current key, so nothing is sealed with the old key after a
-- rotation (LF-INV-SHARE-004). The old key's rows go only when the owner
-- drops them, after the records were sealed again.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-0000000000c1', 'owner@example.test'),
  ('00000000-0000-4000-8000-0000000000c2', 'editor@example.test'),
  ('00000000-0000-4000-8000-0000000000c3', 'personal@example.test');

create function pg_temp.as_account(n int) returns void language sql as $$
  select set_config('role', 'authenticated', true),
         set_config('request.jwt.claims', json_build_object('sub',
           ('00000000-0000-4000-8000-0000000000c' || n)::uuid, 'role', 'authenticated')::text, true);
$$;
create function pg_temp.rec(n int) returns jsonb language sql as $$
  select jsonb_build_object('id', lpad(to_hex(n), 64, '0'), 'base', null, 'version', 1, 'deleted', false,
                            'sealed', encode('sealed bytes'::bytea, 'base64'), 'op', gen_random_uuid());
$$;
create function pg_temp.hint_of(stmt text) returns text language plpgsql as $$
declare h text;
begin
  execute stmt;
  return 'no error';
exception when others then
  get stacked diagnostics h = pg_exception_hint;
  return coalesce(h, '');
end;
$$;
grant execute on function pg_temp.hint_of(text) to authenticated;

-- The space, with the editor in it.
select pg_temp.as_account(2);
select public.set_account_keys(decode(repeat('02', 32), 'hex'), '\x01');
select pg_temp.as_account(1);
select public.set_account_keys(decode(repeat('01', 32), 'hex'), '\x01');
select public.create_space('20000000-0000-4000-8000-0000000000c1', '\x01', repeat('a', 64));
select public.invite('20000000-0000-4000-8000-0000000000c1', repeat('e', 64), 'editor', 'approve');
select pg_temp.as_account(2);
select public.accept_invitation(repeat('e', 64));
select pg_temp.as_account(1);
select public.approve_member('20000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000c2', '\x02', repeat('a', 64));

select is((public.push_records('20000000-0000-4000-8000-0000000000c1', 'o', jsonb_build_array(pg_temp.rec(1)), repeat('a', 64))
           -> 'accepted') -> 0 ->> 'seq', '1', 'the owner pushes with the current key');
select is(pg_temp.hint_of($$ select public.push_records('20000000-0000-4000-8000-0000000000c1', 'o',
                              jsonb_build_array(pg_temp.rec(2)), repeat('b', 64)) $$),
          'lifeflow:staleKey', 'a key that is not the current one is refused');
select is(pg_temp.hint_of($$ select public.push_records('20000000-0000-4000-8000-0000000000c1', 'o',
                              jsonb_build_array(pg_temp.rec(2))) $$),
          'lifeflow:staleKey', 'and so is a push that names no key');
select is((select key_id from public.pull_records('20000000-0000-4000-8000-0000000000c1', 0)), repeat('a', 64),
          'a pulled record says which key it is sealed with');

select lives_ok($$ select public.rotate_space_key('20000000-0000-4000-8000-0000000000c1', repeat('b', 64),
                     jsonb_build_array(jsonb_build_object('account', '00000000-0000-4000-8000-0000000000c1', 'wrapped', 'Aw=='),
                                       jsonb_build_object('account', '00000000-0000-4000-8000-0000000000c2', 'wrapped', 'Aw=='))) $$,
                'the owner rotates the key');
select pg_temp.as_account(2);
select is(pg_temp.hint_of($$ select public.push_records('20000000-0000-4000-8000-0000000000c1', 'e',
                              jsonb_build_array(pg_temp.rec(3)), repeat('a', 64)) $$),
          'lifeflow:staleKey', 'after the rotation nothing is sealed with the old key (SHARE-004)');
select is((public.push_records('20000000-0000-4000-8000-0000000000c1', 'e', jsonb_build_array(pg_temp.rec(3)), repeat('b', 64))
           -> 'accepted') -> 0 ->> 'seq', '2', 'the editor pushes with the new key');
select is((select array_agg(key_id order by seq) from public.pull_records('20000000-0000-4000-8000-0000000000c1', 0)),
          array[repeat('a', 64), repeat('b', 64)], 'until the drop, both keys'' rows are there');
select throws_ok($$ select public.drop_old_key_records('20000000-0000-4000-8000-0000000000c1') $$, '42501', null,
                 'only the owner drops the old rows');

select pg_temp.as_account(1);
select is(public.drop_old_key_records('20000000-0000-4000-8000-0000000000c1'), 1, 'the owner drops the old key''s rows');
select is((select array_agg(key_id) from public.pull_records('20000000-0000-4000-8000-0000000000c1', 0)),
          array[repeat('b', 64)], 'the new key''s rows stay');
select is(public.drop_old_key_records('20000000-0000-4000-8000-0000000000c1'), 0, 'dropping again drops nothing');

-- A personal workspace: as in P04a, with or without a key id.
select pg_temp.as_account(3);
insert into public.account_workspaces (workspace_id, wrapped_key, unlock_kind)
  values ('20000000-0000-4000-8000-0000000000c3', '\x01', 'recoveryKey');
select is((public.push_records('20000000-0000-4000-8000-0000000000c3', 'pc', jsonb_build_array(pg_temp.rec(1)))
           -> 'accepted') -> 0 ->> 'seq', '1', 'a P04a push (three arguments) still works');
select is((public.push_records('20000000-0000-4000-8000-0000000000c3', 'pc', jsonb_build_array(pg_temp.rec(2)), repeat('c', 64))
           -> 'accepted') -> 0 ->> 'seq', '2', 'and one that names a key');
select is((select array_agg(key_id order by seq) from public.pull_records('20000000-0000-4000-8000-0000000000c3', 0)),
          array['', repeat('c', 64)], 'a personal workspace keeps what it is given');
select throws_ok($$ select public.drop_old_key_records('20000000-0000-4000-8000-0000000000c3') $$, '42501', null,
                 'and has no old rows to drop');
select throws_ok($$ select public.push_records('20000000-0000-4000-8000-0000000000c3', 'pc', jsonb_build_array(pg_temp.rec(3)), 'not hex') $$,
                 '23514', null, 'a key id is 64 hex characters');

select * from finish();
rollback;
