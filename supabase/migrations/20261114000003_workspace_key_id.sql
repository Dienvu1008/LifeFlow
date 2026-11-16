-- P04 T4 (ADR-0057): which workspace key the workspace's records are sealed
-- with, as a keyed fingerprint made on the device (it reveals nothing about
-- the key). A device whose key has another fingerprint knows the workspace
-- was reset with a new key and must unlock again; a re-wrapping (another
-- recovery key or passphrase for the same key) keeps the fingerprint.
alter table public.account_workspaces
  add column key_id text not null default '' check (key_id = '' or key_id ~ '^[0-9a-f]{64}$');

grant insert (key_id) on public.account_workspaces to authenticated;
