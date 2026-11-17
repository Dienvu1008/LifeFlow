-- P04b T9 (ADR-0061): shared spaces on the server, from spike S-16's cases,
-- against the migration 20261117000001_spaces.sql. Run with `supabase test db`.
--   O owner, E editor, V viewer, P invited (waiting for approval),
--   J joins at once with a code, R removed, S a stranger, anon no session.
-- Every write goes through owner- or role-checked functions; the tables take
-- no direct writes (LF-INV-SHARE-002/003). The server sees wrapped keys and
-- sealed records only (D12).
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-0000000000a1', 'owner@example.test'),
  ('00000000-0000-4000-8000-0000000000a2', 'editor@example.test'),
  ('00000000-0000-4000-8000-0000000000a3', 'viewer@example.test'),
  ('00000000-0000-4000-8000-0000000000a4', 'pending@example.test'),
  ('00000000-0000-4000-8000-0000000000a5', 'atonce@example.test'),
  ('00000000-0000-4000-8000-0000000000a6', 'removed@example.test'),
  ('00000000-0000-4000-8000-0000000000a7', 'stranger@example.test'),
  ('00000000-0000-4000-8000-0000000000a8', 'nokey@example.test');

create function pg_temp.who(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-0000000000a' || n)::uuid;
$$;
create function pg_temp.as_account(n int) returns void language sql as $$
  select set_config('role', 'authenticated', true),
         set_config('request.jwt.claims',
                    json_build_object('sub', pg_temp.who(n), 'role', 'authenticated')::text, true);
$$;
create function pg_temp.as_admin() returns void language sql as $$
  select set_config('role', 'postgres', true), set_config('request.jwt.claims', '', true);
$$;
create function pg_temp.rec(n int, op text) returns jsonb language sql as $$
  select jsonb_build_object('id', lpad(to_hex(n), 64, '0'), 'base', null, 'version', 1, 'deleted', false,
                            'sealed', encode('sealed bytes'::bytea, 'base64'), 'op', op);
$$;
create function pg_temp.hash(code text) returns text language sql as $$
  select encode(extensions.digest('lifeflow invite v1:' || code, 'sha256'), 'hex');
$$;
-- The hint a statement fails with (the reason the app shows), or 'no error'.
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
-- Every account but N8 publishes its keys (its devices do it when sync is on).
create function pg_temp.publish(n int) returns void language sql as $$
  select pg_temp.as_account(n);
  select public.set_account_keys(decode(lpad(to_hex(n), 64, '0'), 'hex'), '\x5ea1ed');
$$;
select pg_temp.publish(n) from generate_series(1, 7) n;

-- === Account keys ==========================================================

select pg_temp.as_account(8);
select is(pg_temp.hint_of($$ select public.create_space('20000000-0000-4000-8000-0000000000f8', '\x01', repeat('a', 64)) $$),
          'lifeflow:noPublicKey', 'no space without a published public key');
select throws_ok($$ insert into public.account_public_keys (account_id, public_key) values (pg_temp.who(8), decode(repeat('00', 32), 'hex')) $$,
                 '42501', null, 'keys are written only through set_account_keys');
select throws_ok($$ select public.set_account_keys('\x01', '\x01') $$, '23514', null, 'a public key is 32 bytes');
select pg_temp.as_account(1);
select lives_ok($$ select public.set_account_keys(decode(lpad(to_hex(1), 64, '0'), 'hex'), '\x5ea1ed02') $$,
                'the private key is sealed again (after a reset of the personal key)');
select is((select sealed_private from public.account_private_keys), '\x5ea1ed02'::bytea, 'and the new sealing is kept');

-- === The space: O makes it; E and V join through "approve" invitations =====

select lives_ok($$ select public.create_space('20000000-0000-4000-8000-0000000000f1', '\x01', repeat('a', 64)) $$,
                'the owner makes a space');
select is(private.role_in('20000000-0000-4000-8000-0000000000f1'), 'owner', 'and owns it');
select throws_ok($$ insert into public.account_workspaces (workspace_id, wrapped_key, unlock_kind)
                    values ('20000000-0000-4000-8000-0000000000f9', '\x01', 'space') $$,
                 '42501', null, 'a space is made only through create_space');
update public.account_workspaces set unlock_kind = 'recoveryKey', wrapped_key = '\x99'
  where workspace_id = '20000000-0000-4000-8000-0000000000f1';
select is((select (unlock_kind, wrapped_key)::text from public.account_workspaces
            where workspace_id = '20000000-0000-4000-8000-0000000000f1'), '(space,"\\x01")',
          'the owner cannot turn the space into a personal workspace by hand');
select lives_ok($$ select public.invite('20000000-0000-4000-8000-0000000000f1', pg_temp.hash('code-editor'), 'editor', 'approve') $$,
                'the owner invites an editor');
select lives_ok($$ select public.invite('20000000-0000-4000-8000-0000000000f1', pg_temp.hash('code-viewer'), 'viewer', 'approve') $$,
                'the owner invites a viewer');
select lives_ok($$ select public.invite('20000000-0000-4000-8000-0000000000f1', pg_temp.hash('code-pending'), 'editor', 'approve') $$,
                'and someone who will wait for approval');
select lives_ok($$ select public.invite('20000000-0000-4000-8000-0000000000f1', pg_temp.hash('code-removed'), 'editor', 'approve') $$,
                'and someone who will be removed');
select lives_ok($$ select public.invite('20000000-0000-4000-8000-0000000000f1', pg_temp.hash('code-atonce'), 'editor', 'joinAtOnce', '\x0c0d', repeat('a', 64)) $$,
                'and a "join at once" invitation, carrying the key wrapped for the code');
select lives_ok($$ select public.invite('20000000-0000-4000-8000-0000000000f1', pg_temp.hash('code-cancel'), 'viewer', 'approve') $$,
                'and one that will be cancelled');
select throws_ok($$ select public.invite('20000000-0000-4000-8000-0000000000f1', pg_temp.hash('x'), 'owner', 'approve') $$,
                 '23514', null, 'nobody is invited as owner');
select throws_ok($$ select public.invite('20000000-0000-4000-8000-0000000000f1', pg_temp.hash('y'), 'editor', 'approve', null, '', 30) $$,
                 '22023', null, 'an invitation lasts at most 7 days');
select throws_ok($$ select public.invite('20000000-0000-4000-8000-0000000000f1', pg_temp.hash('w'), 'editor', 'joinAtOnce') $$,
                 '22023', null, 'a "join at once" invitation carries the key');
select is((select count(*)::int from public.space_invitations), 6, 'the owner sees the invitations');
select is((select count(*)::int from public.space_invitations where kind = 'approve' and (wrapped_key is not null or key_id <> '')), 0,
          'an "approve" invitation carries no key');

-- The invitee sees the role and the rules before accepting (SHARE-005).
select pg_temp.as_account(2);
select is(public.peek_invitation(pg_temp.hash('code-editor')) ->> 'leave_rule', 'disappear',
          'the rules are shown before joining');
select is(pg_temp.hint_of($$ select public.peek_invitation(pg_temp.hash('no such code')) $$), 'lifeflow:noSuchInvitation',
          'an unknown code says nothing about any space');
select is(pg_temp.hint_of($$ select public.cancel_invitation(pg_temp.hash('code-cancel')) $$), '',
          'only the owner cancels an invitation');
select is(public.accept_invitation(pg_temp.hash('code-editor')) ->> 'kind', 'approve', 'E accepts');
select is((select count(*)::int from public.sync_records), 0, 'E reads nothing before the approval');
select is((select count(*)::int from public.spaces), 0, 'nor the rules');
select is((select (role, status, leave_rule, wrapped_key) from public.my_spaces())::text, '(editor,pending,,)',
          'E sees their own request, without the rules or a key');
select throws_ok($$ select public.push_records('20000000-0000-4000-8000-0000000000f1', 'e',
                     jsonb_build_array(pg_temp.rec(1, '30000000-0000-4000-8000-000000000001'))) $$,
                 '42501', null, 'E writes nothing before the approval');
select pg_temp.as_account(3);
select lives_ok($$ select public.accept_invitation(pg_temp.hash('code-viewer')) $$, 'V accepts');
select pg_temp.as_account(4);
select lives_ok($$ select public.accept_invitation(pg_temp.hash('code-pending')) $$, 'P accepts');
select pg_temp.as_account(6);
select lives_ok($$ select public.accept_invitation(pg_temp.hash('code-removed')) $$, 'R accepts');
select pg_temp.as_account(7);
select is(pg_temp.hint_of($$ select public.accept_invitation(pg_temp.hash('code-editor')) $$), 'lifeflow:noSuchInvitation',
          'a used code cannot be used again');
select pg_temp.as_account(1);
select lives_ok($$ select public.cancel_invitation(pg_temp.hash('code-cancel')) $$, 'the owner cancels an invitation');
select pg_temp.as_account(7);
select is(pg_temp.hint_of($$ select public.accept_invitation(pg_temp.hash('code-cancel')) $$), 'lifeflow:noSuchInvitation',
          'a cancelled code no longer works');
select pg_temp.as_account(8);
select is(pg_temp.hint_of($$ select public.peek_invitation(pg_temp.hash('code-pending')) $$), 'lifeflow:noSuchInvitation',
          'a code someone else used says nothing either');

-- "Join at once": in at once; the key it carried is gone from the server.
select pg_temp.as_account(5);
select is(public.accept_invitation(pg_temp.hash('code-atonce')) ->> 'wrapped_key', encode('\x0c0d'::bytea, 'base64'),
          'J gets the key wrapped for the code');
select is(private.role_in('20000000-0000-4000-8000-0000000000f1'), 'editor', 'J is an editor at once');
select is(pg_temp.hint_of($$ select public.accept_invitation(pg_temp.hash('code-pending')) $$), 'lifeflow:noSuchInvitation',
          'nor can J use a code already used');
select lives_ok($$ select public.set_my_wrapped_key('20000000-0000-4000-8000-0000000000f1', '\x05', repeat('a', 64)) $$,
                'J''s device wraps the key again for itself');
select pg_temp.as_admin();
select is((select wrapped_key from public.space_invitations where code_hash = pg_temp.hash('code-atonce')), null,
          'the code''s wrapped key is erased once used');
select is((select wrapped_key from public.space_members where account_id = pg_temp.who(5)), '\x05'::bytea,
          'J''s own wrapping is kept');

-- Approval: only the owner; only someone waiting; only with the current key.
select pg_temp.as_account(2);
select throws_ok($$ select public.approve_member('20000000-0000-4000-8000-0000000000f1', pg_temp.who(4), '\x02', repeat('a', 64)) $$,
                 '42501', null, 'an editor cannot approve');
select pg_temp.as_account(1);
select is(pg_temp.hint_of($$ select public.approve_member('20000000-0000-4000-8000-0000000000f1', pg_temp.who(2), '\x02', repeat('e', 64)) $$),
          'lifeflow:staleKey', 'nobody is approved with a key that is not the current one');
select lives_ok($$ select public.approve_member('20000000-0000-4000-8000-0000000000f1', pg_temp.who(n), '\x02', repeat('a', 64))
                     from unnest(array[2, 3, 6]) n $$, 'the owner approves E, V and R');
select is(pg_temp.hint_of($$ select public.approve_member('20000000-0000-4000-8000-0000000000f1', pg_temp.who(7), '\x02', repeat('a', 64)) $$),
          'lifeflow:nobodyWaiting', 'a stranger who never asked cannot be approved in');
select is((select count(*)::int from public.account_public_keys), 6,
          'the owner sees the public keys of everyone in the space, also those waiting');

-- Writes by role (SHARE-002).
select is((public.push_records('20000000-0000-4000-8000-0000000000f1', 'o',
            jsonb_build_array(pg_temp.rec(1, '30000000-0000-4000-8000-000000000011'))) -> 'accepted') -> 0 ->> 'seq', '1',
          'the owner writes');
select pg_temp.as_account(2);
select is((public.push_records('20000000-0000-4000-8000-0000000000f1', 'e',
            jsonb_build_array(pg_temp.rec(2, '30000000-0000-4000-8000-000000000012'))) -> 'accepted') -> 0 ->> 'seq', '2',
          'an editor writes');
select is((select count(*)::int from public.sync_records), 2, 'an editor reads the space');
select is((select (status, leave_rule, wrapped_key, key_id = repeat('a', 64)) from public.my_spaces())::text,
          '(active,disappear,"\\x02",t)', 'and their space, its rules and the key wrapped for them');
select is((select count(*)::int from public.pull_records('20000000-0000-4000-8000-0000000000f1', 0)), 2,
          'and pulls it');
select is((select count(*)::int from public.account_workspaces), 0, 'an editor does not see the space''s workspace row');
select pg_temp.as_account(3);
select is((select count(*)::int from public.sync_records), 2, 'a viewer reads the space');
select throws_ok($$ select public.push_records('20000000-0000-4000-8000-0000000000f1', 'v',
                     jsonb_build_array(pg_temp.rec(3, '30000000-0000-4000-8000-000000000013'))) $$,
                 '42501', null, 'a viewer cannot write (the server says no)');
select throws_ok($$ select public.purge_records('20000000-0000-4000-8000-0000000000f1', now()) $$,
                 '42501', null, 'a viewer cannot purge');

-- Pending and strangers see nothing (GS-23).
select pg_temp.as_account(4);
select is((select count(*)::int from public.sync_records), 0, 'someone waiting reads no record');
select is((select count(*)::int from public.space_members), 1, 'someone waiting sees only their own request');
select is((select count(*)::int from public.account_public_keys), 1, 'and only their own public key');
select pg_temp.as_account(7);
select is((select count(*)::int from public.sync_records), 0, 'a stranger reads no record');
select is((select count(*)::int from public.pull_records('20000000-0000-4000-8000-0000000000f1', 0)), 0,
          'nor pulls one');
select is((select count(*)::int from public.space_members), 0, 'a stranger sees no member');
select is((select count(*)::int from public.spaces), 0, 'a stranger sees no space');
select is((select count(*)::int from public.account_public_keys), 1, 'a stranger sees only their own public key');
select throws_ok($$ select public.push_records('20000000-0000-4000-8000-0000000000f1', 's',
                     jsonb_build_array(pg_temp.rec(4, '30000000-0000-4000-8000-000000000014'))) $$,
                 '42501', null, 'a stranger cannot write');

-- Crafted requests around the functions (SHARE-003).
select pg_temp.as_account(3);
select throws_ok($$ update public.space_members set role = 'owner' where account_id = pg_temp.who(3) $$,
                 '42501', null, 'a viewer cannot make themselves owner');
select throws_ok($$ insert into public.space_members (workspace_id, account_id, role, status, wrapped_key)
                    values ('20000000-0000-4000-8000-0000000000f1', pg_temp.who(7), 'editor', 'active', '\x01') $$,
                 '42501', null, 'nobody adds a member by hand');
select throws_ok($$ update public.spaces set export_rule = 'everyMember' $$, '42501', null,
                 'a member cannot change the rules by hand');
select throws_ok($$ delete from public.space_invitations $$, '42501', null, 'nor delete invitations');
select throws_ok($$ insert into public.sync_records (workspace_id, id, version, seq, sealed, device_id, operation_id)
                    values ('20000000-0000-4000-8000-0000000000f1', repeat('f', 64), 1, 99, '\x01', 'v', gen_random_uuid()) $$,
                 '42501', null, 'nor write a record by hand');
select is((select count(*)::int from public.space_invitations), 0, 'a member cannot read the invitations');
select is((select count(*)::int from public.account_private_keys), 1, 'everyone reads only their own private key');
select is((select count(*)::int from public.account_public_keys), 6,
          'members see the public keys of the people in their space');
delete from public.account_workspaces where workspace_id = '20000000-0000-4000-8000-0000000000f1';
select pg_temp.as_admin();
select is((select count(*)::int from public.account_workspaces where workspace_id = '20000000-0000-4000-8000-0000000000f1'), 1,
          'a member cannot delete the space');

-- Owner-only actions refused to an editor.
select pg_temp.as_account(2);
select throws_ok($$ select public.remove_member('20000000-0000-4000-8000-0000000000f1', pg_temp.who(3)) $$,
                 '42501', null, 'an editor cannot remove a member');
select throws_ok($$ select public.set_role('20000000-0000-4000-8000-0000000000f1', pg_temp.who(3), 'editor') $$,
                 '42501', null, 'an editor cannot change roles');
select throws_ok($$ select public.set_space_rules('20000000-0000-4000-8000-0000000000f1', 'keepReadOnly', 'everyMember', 'approve') $$,
                 '42501', null, 'an editor cannot change the rules');
select throws_ok($$ select public.invite('20000000-0000-4000-8000-0000000000f1', pg_temp.hash('z'), 'editor', 'approve') $$,
                 '42501', null, 'an editor cannot invite');
select throws_ok($$ select public.rotate_space_key('20000000-0000-4000-8000-0000000000f1', repeat('c', 64), '[]'::jsonb) $$,
                 '42501', null, 'an editor cannot rotate the key');
select throws_ok($$ select public.hand_over('20000000-0000-4000-8000-0000000000f1', pg_temp.who(2)) $$,
                 '42501', null, 'an editor cannot take the space');

-- The rules: the owner sets them; members see them and when they changed.
select pg_temp.as_admin();
update public.spaces set rules_changed_at = now() - interval '1 hour';
select pg_temp.as_account(1);
select lives_ok($$ select public.set_space_rules('20000000-0000-4000-8000-0000000000f1', 'disappear', 'ownerOnly', 'approve') $$,
                'setting the same rules again');
select ok((select rules_changed_at < now() - interval '30 minutes' from public.spaces), 'is no change members are told about');
select lives_ok($$ select public.set_space_rules('20000000-0000-4000-8000-0000000000f1', 'keepReadOnly', 'everyMember', 'joinAtOnce') $$,
                'the owner sets the leaving and export rules');
select throws_ok($$ select public.set_space_rules('20000000-0000-4000-8000-0000000000f1', 'whatever', 'everyMember', 'approve') $$,
                 '23514', null, 'only the known rules');
select pg_temp.as_account(3);
select is((select (leave_rule, export_rule, invite_default) from public.spaces)::text, '(keepReadOnly,everyMember,joinAtOnce)',
          'a viewer sees the new rules');
select ok((select rules_changed_at > now() - interval '1 minute' from public.spaces), 'and that they just changed');

-- Removal: no access at once; a new key wrapped for exactly the others.
select pg_temp.as_account(1);
select lives_ok($$ select public.remove_member('20000000-0000-4000-8000-0000000000f1', pg_temp.who(6)) $$,
                'the owner removes R');
select is(pg_temp.hint_of($$ select public.remove_member('20000000-0000-4000-8000-0000000000f1', pg_temp.who(1)) $$),
          'lifeflow:notAMember', 'the owner cannot be removed');
select pg_temp.as_account(6);
select is((select count(*)::int from public.sync_records), 0, 'R reads nothing after the removal');
select is((select count(*)::int from public.account_public_keys), 1, 'nor anyone''s public key');
select throws_ok($$ select public.push_records('20000000-0000-4000-8000-0000000000f1', 'r',
                     jsonb_build_array(pg_temp.rec(5, '30000000-0000-4000-8000-000000000015'))) $$,
                 '42501', null, 'R writes nothing after the removal');
select pg_temp.as_account(1);
select lives_ok($$ select public.invite('20000000-0000-4000-8000-0000000000f1', pg_temp.hash('code-old-key'), 'editor', 'joinAtOnce', '\x0e', repeat('a', 64)) $$,
                'an unused "join at once" invitation of the old key');
select is(pg_temp.hint_of($$ select public.rotate_space_key('20000000-0000-4000-8000-0000000000f1', repeat('b', 64),
                     jsonb_build_array(jsonb_build_object('account', pg_temp.who(1), 'wrapped', 'AQ=='))) $$),
          'lifeflow:wrongMembers', 'the new key must be wrapped for every active member');
select is(pg_temp.hint_of($$ select public.rotate_space_key('20000000-0000-4000-8000-0000000000f1', repeat('b', 64),
                     (select jsonb_agg(jsonb_build_object('account', pg_temp.who(n), 'wrapped', 'AQ=='))
                        from unnest(array[1, 2, 3, 5, 6]) n)) $$),
          'lifeflow:wrongMembers', 'and not for the removed member');
select lives_ok($$ select public.rotate_space_key('20000000-0000-4000-8000-0000000000f1', repeat('b', 64),
                     (select jsonb_agg(jsonb_build_object('account', pg_temp.who(n), 'wrapped', 'Ag=='))
                        from unnest(array[1, 2, 3, 5]) n)) $$,
                'the owner rotates the key for O, E, V and J');
select is((select (key_id, wrapped_key)::text from public.account_workspaces
            where workspace_id = '20000000-0000-4000-8000-0000000000f1'), '(' || repeat('b', 64) || ',"\\x02")',
          'the space says which key is current, wrapped for the owner');
select is((select count(*)::int from public.space_members where key_id = repeat('b', 64) and wrapped_key = '\x02'), 4,
          'every active member holds the new key');
select pg_temp.as_account(7);
select is(pg_temp.hint_of($$ select public.peek_invitation(pg_temp.hash('code-old-key')) $$), 'lifeflow:noSuchInvitation',
          'an unused "join at once" code of the old key stops working');
select pg_temp.as_account(5);
select throws_ok($$ select public.set_my_wrapped_key('20000000-0000-4000-8000-0000000000f1', '\x05', repeat('a', 64)) $$,
                 '42501', null, 'an old key cannot be put back');
select pg_temp.as_account(1);
select is(pg_temp.hint_of($$ select public.approve_member('20000000-0000-4000-8000-0000000000f1', pg_temp.who(4), '\x03', repeat('a', 64)) $$),
          'lifeflow:staleKey', 'someone waiting is not approved with the old key');

-- Leaving, roles, handing over.
select pg_temp.as_account(4);
select lives_ok($$ select public.leave_space('20000000-0000-4000-8000-0000000000f1') $$, 'P withdraws the request');
select pg_temp.as_account(3);
select lives_ok($$ select public.leave_space('20000000-0000-4000-8000-0000000000f1') $$, 'V leaves');
select is(private.role_in('20000000-0000-4000-8000-0000000000f1'), null, 'V has no role any more');
select is(pg_temp.hint_of($$ select public.leave_space('20000000-0000-4000-8000-0000000000f1') $$), 'lifeflow:notAMember',
          'and cannot leave twice');
select pg_temp.as_account(1);
select is(pg_temp.hint_of($$ select public.leave_space('20000000-0000-4000-8000-0000000000f1') $$), 'lifeflow:ownerMustHandOver',
          'the owner hands over before leaving');
select lives_ok($$ select public.set_role('20000000-0000-4000-8000-0000000000f1', pg_temp.who(5), 'viewer') $$,
                'the owner makes J a viewer');
select throws_ok($$ select public.set_role('20000000-0000-4000-8000-0000000000f1', pg_temp.who(5), 'owner') $$,
                 '22023', null, 'the owner role moves only by handing over');
select is(pg_temp.hint_of($$ select public.hand_over('20000000-0000-4000-8000-0000000000f1', pg_temp.who(3)) $$),
          'lifeflow:notAMember', 'not to someone who left');
select lives_ok($$ select public.hand_over('20000000-0000-4000-8000-0000000000f1', pg_temp.who(2)) $$,
                'O hands the space to E');
select is(private.role_in('20000000-0000-4000-8000-0000000000f1'), 'editor', 'O is an editor now');
select is((public.push_records('20000000-0000-4000-8000-0000000000f1', 'o',
            jsonb_build_array(pg_temp.rec(6, '30000000-0000-4000-8000-000000000016'))) -> 'accepted') -> 0 ->> 'seq', '3',
          'and still writes');
select throws_ok($$ select public.remove_member('20000000-0000-4000-8000-0000000000f1', pg_temp.who(5)) $$,
                 '42501', null, 'O can no longer remove members');
select pg_temp.as_account(2);
select is(private.role_in('20000000-0000-4000-8000-0000000000f1'), 'owner', 'E owns the space');
select is((select count(*)::int from public.account_workspaces where workspace_id = '20000000-0000-4000-8000-0000000000f1'), 1,
          'and its workspace row');
select pg_temp.as_admin();
select is((select count(*)::int from public.space_members
            where workspace_id = '20000000-0000-4000-8000-0000000000f1' and role = 'owner'), 1,
          'one owner at a time');

-- Limits (B13): 10 members per space.
select pg_temp.as_account(2);
select public.invite('20000000-0000-4000-8000-0000000000f1', pg_temp.hash('fill-' || n), 'viewer', 'approve')
  from generate_series(1, 9) n;
select public.invite('20000000-0000-4000-8000-0000000000f1', pg_temp.hash('again-1'), 'viewer', 'approve');
select pg_temp.as_account(1);
select is(pg_temp.hint_of($$ select public.accept_invitation(pg_temp.hash('again-1')) $$), 'lifeflow:alreadyMember',
          'a member cannot join again');
select pg_temp.as_admin();
insert into auth.users (id, email)
  select ('00000000-0000-4000-8000-0000000001' || lpad(n::text, 2, '0'))::uuid, 'fill' || n || '@example.test'
    from generate_series(1, 9) n;
create function pg_temp.as_fill(n int) returns void language sql as $$
  select set_config('role', 'authenticated', true),
         set_config('request.jwt.claims', json_build_object('sub',
           ('00000000-0000-4000-8000-0000000001' || lpad(n::text, 2, '0'))::uuid, 'role', 'authenticated')::text, true);
$$;
create function pg_temp.fill_join(n int) returns jsonb language sql as $$
  select pg_temp.as_fill(n);
  select public.set_account_keys(decode(lpad(to_hex(100 + n), 64, '0'), 'hex'), '\x01');
  select public.accept_invitation(pg_temp.hash('fill-' || n));
$$;
-- O, E and J are in; seven more fill the space.
select pg_temp.fill_join(n) from generate_series(1, 7) n;
select pg_temp.as_admin();
select is((select count(*)::int from public.space_members where workspace_id = '20000000-0000-4000-8000-0000000000f1'), 10,
          'the space is full at 10');
select pg_temp.as_fill(8);
select public.set_account_keys(decode(lpad(to_hex(108), 64, '0'), 'hex'), '\x01');
select is(pg_temp.hint_of($$ select public.accept_invitation(pg_temp.hash('fill-8')) $$), 'lifeflow:spaceFull',
          'an eleventh member is refused');

-- 10 spaces per account.
select pg_temp.as_account(7);
select public.create_space(('20000000-0000-4000-8000-0000000007' || lpad(n::text, 2, '0'))::uuid, '\x01', repeat('a', 64))
  from generate_series(1, 10) n;
select is(pg_temp.hint_of($$ select public.create_space('20000000-0000-4000-8000-000000000799', '\x01', repeat('a', 64)) $$),
          'lifeflow:tooManySpaces', 'an eleventh space is refused');
select is((select count(*)::int from public.account_workspaces), 10, 'the spaces are the owner''s rows');

-- No session reaches nothing.
select pg_temp.as_admin();
select set_config('role', 'anon', true);
select throws_ok($$ select public.peek_invitation(pg_temp.hash('code-editor')) $$, '42501', null,
                 'anon cannot look at invitations');
select throws_ok($$ select count(*) from public.space_members $$, '42501', null, 'anon reads no members');
select throws_ok($$ select public.set_account_keys(decode(repeat('00', 32), 'hex'), '\x01') $$, '42501', null,
                 'anon publishes no key');
select throws_ok($$ select private.role_in('20000000-0000-4000-8000-0000000000f1') $$, '42501', null,
                 'anon reaches no private function');

-- The owner deletes the space: everything of it goes.
select pg_temp.as_account(2);
delete from public.account_workspaces where workspace_id = '20000000-0000-4000-8000-0000000000f1';
select pg_temp.as_admin();
select is((select count(*)::int from public.sync_records where workspace_id = '20000000-0000-4000-8000-0000000000f1')
          + (select count(*)::int from public.space_members where workspace_id = '20000000-0000-4000-8000-0000000000f1')
          + (select count(*)::int from public.space_invitations where workspace_id = '20000000-0000-4000-8000-0000000000f1')
          + (select count(*)::int from public.spaces where workspace_id = '20000000-0000-4000-8000-0000000000f1'), 0,
          'deleting the space deletes its records, members, invitations and rules');

-- A personal workspace (P04a) still works as before.
select pg_temp.as_account(8);
select lives_ok($$ insert into public.account_workspaces (workspace_id, wrapped_key, unlock_kind)
                   values ('20000000-0000-4000-8000-0000000000f8', '\x01', 'recoveryKey') $$,
                'a personal workspace is made as in P04a');
select is(private.role_in('20000000-0000-4000-8000-0000000000f8'), 'owner', 'and its account owns it');
select is((public.push_records('20000000-0000-4000-8000-0000000000f8', 'pc',
            jsonb_build_array(pg_temp.rec(1, '30000000-0000-4000-8000-000000000081'))) -> 'accepted') -> 0 ->> 'seq', '1',
          'and writes to it');
select lives_ok($$ update public.account_workspaces set unlock_kind = 'passphrase', unlock_salt = '\x01'
                   where workspace_id = '20000000-0000-4000-8000-0000000000f8' $$, 'and re-wraps its key');
select throws_ok($$ update public.account_workspaces set unlock_kind = 'space'
                    where workspace_id = '20000000-0000-4000-8000-0000000000f8' $$,
                 '42501', null, 'but cannot turn it into a space by hand');
select pg_temp.as_account(1);
select is((select count(*)::int from public.sync_records where workspace_id = '20000000-0000-4000-8000-0000000000f8'), 0,
          'nobody else reads it');

select * from finish();
rollback;
