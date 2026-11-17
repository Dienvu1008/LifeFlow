-- P04b T13 (ADR-0065; migration 20261120000001_member_names.sql): the name
-- of someone asking to join is sealed with the owner's public key; the
-- server keeps the sealed bytes only.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-0000000000d1', 'owner@example.test'),
  ('00000000-0000-4000-8000-0000000000d2', 'joiner@example.test'),
  ('00000000-0000-4000-8000-0000000000d3', 'stranger@example.test');
create function pg_temp.as_account(n int) returns void language sql as $$
  select set_config('role', 'authenticated', true),
         set_config('request.jwt.claims', json_build_object('sub',
           ('00000000-0000-4000-8000-0000000000d' || n)::uuid, 'role', 'authenticated')::text, true);
$$;
select pg_temp.as_account(n), public.set_account_keys(decode(repeat(lpad(to_hex(n), 2, '0'), 32), 'hex'), '\x01')
  from generate_series(1, 3) n;

select pg_temp.as_account(1);
select public.create_space('20000000-0000-4000-8000-0000000000d1', '\x01', repeat('a', 64));
select public.invite('20000000-0000-4000-8000-0000000000d1', repeat('1', 64), 'editor', 'approve');

select pg_temp.as_account(2);
select is(public.peek_invitation(repeat('1', 64)) ->> 'owner_public_key', encode(decode(repeat('01', 32), 'hex'), 'base64'),
          'the invitation gives the owner''s public key, to seal a name to');
select lives_ok($$ select public.accept_invitation(repeat('1', 64), '\x5ea1ed') $$, 'the joiner asks with a sealed name');

select pg_temp.as_account(1);
select is((select sealed_name from public.space_members where account_id = '00000000-0000-4000-8000-0000000000d2'),
          '\x5ea1ed'::bytea, 'the owner reads the sealed name of who waits');
select pg_temp.as_account(3);
select is((select count(*)::int from public.space_members), 0, 'a stranger reads nothing');
select throws_ok($$ select public.accept_invitation(repeat('9', 64), decode(repeat('00', 2000), 'hex')) $$,
                 'P0002', null, 'an unknown code first');
select pg_temp.as_account(1);
select public.invite('20000000-0000-4000-8000-0000000000d1', repeat('2', 64), 'viewer', 'approve');
select pg_temp.as_account(3);
select throws_ok($$ select public.accept_invitation(repeat('2', 64), decode(repeat('00', 2000), 'hex')) $$,
                 '23514', null, 'a sealed name is at most 1024 bytes');
select lives_ok($$ select public.accept_invitation(repeat('2', 64)) $$, 'and none is fine (an older app)');

select * from finish();
rollback;
