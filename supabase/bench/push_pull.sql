-- P04 spike S-03: push 10 000 sealed records (20 batches of 500, about
-- 300 bytes each, roughly a task with notes) and pull them back, as one
-- account through RLS. Run: psql -f supabase/bench/push_pull.sql (local stack).
\timing on
begin;
insert into auth.users (id, email) values ('00000000-0000-4000-8000-0000000000be', 'bench@example.test');
select set_config('role', 'authenticated', true),
       set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000be","role":"authenticated"}', true);
insert into public.account_workspaces (workspace_id, wrapped_key, unlock_kind)
  values ('10000000-0000-4000-8000-0000000000be', '\x01', 'recoveryKey');
\echo push: 20 batches of 500
select sum(jsonb_array_length(public.push_records('10000000-0000-4000-8000-0000000000be', 'bench',
         (select jsonb_agg(jsonb_build_object('id', encode(sha256(convert_to(b::text || ':' || g::text, 'utf8')), 'hex'),
                                              'base', null, 'version', 1, 'deleted', false,
                                              'sealed', encode(gen_random_bytes(300), 'base64'),
                                              'op', gen_random_uuid()))
            from generate_series(1, 500) g)) -> 'accepted'))
  from generate_series(1, 20) b;
\echo pull: everything after change number 0, in pages of 1000
select count(*), sum(length(sealed)) from (
  select sealed from public.sync_records
  where workspace_id = '10000000-0000-4000-8000-0000000000be' and seq > 0 order by seq limit 10000) x;
\echo pull: the last 50 changes
select count(*) from public.sync_records
  where workspace_id = '10000000-0000-4000-8000-0000000000be' and seq > 9950;
rollback;
