-- Create the first hanger and its first barcode scan in one transaction.
-- Cached clients can no longer insert empty scan_hangers rows directly.

create schema if not exists private;

create or replace function private.record_hanger_scan(
  p_device_id uuid,
  p_barcode text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  request_device_id text;
  normalized_barcode text;
  target_row public.photo_targets%rowtype;
  hanger_row public.scan_hangers%rowtype;
  scan_row public.hanger_scans%rowtype;
begin
  request_device_id :=
    (nullif(current_setting('request.headers', true), '')::jsonb ->> 'x-device-id');

  if request_device_id is null or request_device_id <> p_device_id::text then
    raise exception using
      errcode = '42501',
      message = 'device header does not match the requested device';
  end if;

  normalized_barcode := upper(regexp_replace(btrim(p_barcode), '\s+', '', 'g'));
  if char_length(normalized_barcode) not between 1 and 128 then
    raise exception using
      errcode = '22023',
      message = 'barcode length must be between 1 and 128 characters';
  end if;

  -- Serialize hanger creation per device so two tabs cannot create competing rows.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_device_id::text, 0)
  );

  select h.*
    into hanger_row
  from public.scan_hangers h
  where h.device_id = p_device_id
    and h.status = 'active'
  order by h.hanger_number desc
  limit 1
  for update;

  if not found then
    insert into public.scan_hangers (device_id, hanger_number, status)
    select p_device_id, coalesce(max(h.hanger_number), 0) + 1, 'active'
    from public.scan_hangers h
    where h.device_id = p_device_id
    returning * into hanger_row;
  end if;

  select t.*
    into target_row
  from public.photo_targets t
  where upper(regexp_replace(btrim(t.barcode), '\s+', '', 'g')) = normalized_barcode
  limit 1;

  insert into public.hanger_scans (
    hanger_id,
    device_id,
    barcode,
    target_id,
    is_target,
    photo_saved
  ) values (
    hanger_row.id,
    p_device_id,
    normalized_barcode,
    case when target_row.id is null then null else target_row.id end,
    target_row.id is not null,
    false
  )
  returning * into scan_row;

  return jsonb_build_object(
    'id', scan_row.id,
    'barcode', scan_row.barcode,
    'target_id', scan_row.target_id,
    'is_target', scan_row.is_target,
    'photo_saved', scan_row.photo_saved,
    'scanned_at', scan_row.scanned_at,
    'hanger_id', hanger_row.id,
    'hanger_number', hanger_row.hanger_number,
    'hanger_status', hanger_row.status,
    'hanger_created_at', hanger_row.created_at
  );
end;
$$;

create or replace function public.record_hanger_scan(
  p_device_id uuid,
  p_barcode text
)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select private.record_hanger_scan(p_device_id, p_barcode);
$$;

revoke all on function private.record_hanger_scan(uuid, text)
  from public, anon, authenticated, service_role;
revoke all on function public.record_hanger_scan(uuid, text)
  from public, anon, authenticated, service_role;

grant usage on schema private to anon;
grant execute on function private.record_hanger_scan(uuid, text) to anon;
grant execute on function public.record_hanger_scan(uuid, text) to anon;

drop policy if exists "sandbox device can create own hangers" on public.scan_hangers;
drop policy if exists "sandbox device can create own hanger scans" on public.hanger_scans;

revoke insert on table public.scan_hangers from anon, authenticated;
revoke insert on table public.hanger_scans from anon, authenticated;
revoke usage, select on sequence public.scan_hangers_id_seq from anon, authenticated;
revoke usage, select on sequence public.hanger_scans_id_seq from anon, authenticated;

comment on function public.record_hanger_scan(uuid, text) is
  'Atomically creates the active hanger when needed and records its barcode scan.';

notify pgrst, 'reload schema';
