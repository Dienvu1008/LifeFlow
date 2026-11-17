-- P04b T13 (ADR-0065; the owner's choice (b)): members' names, end to end.
-- The server never sees a name:
--   waiting   the person who asks to join seals their name with the space
--             owner's public key (X25519, as a member's key wrap), so only
--             the owner's devices read who is waiting (B7)
--   members   once in, each member's name is a record of the space ("member
--             card"), sealed with the space key like every record
-- So peek_invitation also gives the owner's public key, and
-- accept_invitation takes the sealed name.

alter table public.space_members
  add column sealed_name bytea check (sealed_name is null or length(sealed_name) between 1 and 1024);

-- The owner's public key, for sealing a name to them before joining.
create or replace function public.peek_invitation(p_code_hash text) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  i public.space_invitations%rowtype;
  s public.spaces%rowtype;
  owner_key bytea;
begin
  select * into i from public.space_invitations
    where code_hash = p_code_hash and used_by is null and expires_at > now();
  if not found then
    raise exception 'no such invitation' using errcode = 'P0002', hint = 'lifeflow:noSuchInvitation';
  end if;
  select * into s from public.spaces where workspace_id = i.workspace_id;
  select k.public_key into owner_key from public.space_members m
    join public.account_public_keys k on k.account_id = m.account_id
   where m.workspace_id = i.workspace_id and m.role = 'owner';
  return jsonb_build_object('workspace_id', i.workspace_id, 'role', i.role, 'kind', i.kind,
    'leave_rule', s.leave_rule, 'export_rule', s.export_rule, 'expires_at', i.expires_at,
    'owner_public_key', encode(owner_key, 'base64'));
end;
$$;

drop function public.accept_invitation(text);

create function public.accept_invitation(p_code_hash text, p_sealed_name bytea default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  i public.space_invitations%rowtype;
  s public.spaces%rowtype;
begin
  select * into i from public.space_invitations
    where code_hash = p_code_hash and used_by is null and expires_at > now() for update;
  if not found then
    raise exception 'no such invitation' using errcode = 'P0002', hint = 'lifeflow:noSuchInvitation';
  end if;
  if not exists (select 1 from public.account_public_keys k where k.account_id = auth.uid()) then
    raise exception 'publish your public key first' using errcode = '22023', hint = 'lifeflow:noPublicKey';
  end if;
  if exists (select 1 from public.space_members m where m.workspace_id = i.workspace_id and m.account_id = auth.uid()) then
    raise exception 'already in this space' using errcode = '23505', hint = 'lifeflow:alreadyMember';
  end if;
  perform 1 from public.spaces sp where sp.workspace_id = i.workspace_id for update;
  if (select count(*) from public.space_members m where m.workspace_id = i.workspace_id) >= 10 then
    raise exception 'at most 10 members per space' using errcode = '54000', hint = 'lifeflow:spaceFull';
  end if;
  if (select count(*) from public.space_members m where m.account_id = auth.uid()) >= 10 then
    raise exception 'at most 10 shared spaces per account' using errcode = '54000', hint = 'lifeflow:tooManySpaces';
  end if;
  update public.space_invitations set used_by = auth.uid(), used_at = now(), wrapped_key = null
    where code_hash = p_code_hash;
  insert into public.space_members (workspace_id, account_id, role, status, wrapped_key, key_id, added_by, sealed_name)
    values (i.workspace_id, auth.uid(), i.role,
            case when i.kind = 'joinAtOnce' then 'active' else 'pending' end,
            case when i.kind = 'joinAtOnce' then i.wrapped_key end,
            case when i.kind = 'joinAtOnce' then i.key_id else '' end, i.created_by, p_sealed_name);
  select * into s from public.spaces where workspace_id = i.workspace_id;
  return jsonb_build_object('workspace_id', i.workspace_id, 'role', i.role, 'kind', i.kind,
    'wrapped_key', case when i.kind = 'joinAtOnce' then encode(i.wrapped_key, 'base64') end,
    'key_id', case when i.kind = 'joinAtOnce' then i.key_id else '' end,
    'leave_rule', s.leave_rule, 'export_rule', s.export_rule);
end;
$$;

revoke all on function public.accept_invitation(text, bytea) from public, anon;
grant execute on function public.accept_invitation(text, bytea) to authenticated;
