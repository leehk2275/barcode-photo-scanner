-- Barcode normalization, per-device duplicate prevention, KST helper columns, and export metadata.
-- Apply to the isolated test project before deploying the matching frontend.

create schema if not exists private;

create or replace function private.normalize_hanger_scan_barcode()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.barcode := upper(regexp_replace(btrim(new.barcode), '\s+', '', 'g'));
  return new;
end;
$$;

revoke all on function private.normalize_hanger_scan_barcode() from public, anon, authenticated;

drop trigger if exists normalize_hanger_scan_barcode_before_write on public.hanger_scans;
create trigger normalize_hanger_scan_barcode_before_write
before insert or update of barcode on public.hanger_scans
for each row execute function private.normalize_hanger_scan_barcode();

update public.hanger_scans
set barcode = upper(regexp_replace(btrim(barcode), '\s+', '', 'g'))
where barcode is distinct from upper(regexp_replace(btrim(barcode), '\s+', '', 'g'));

alter table public.hanger_scans
  drop constraint if exists hanger_scans_barcode_key;
alter table public.hanger_scans
  drop constraint if exists hanger_scans_device_barcode_key;
alter table public.hanger_scans
  add constraint hanger_scans_device_barcode_key unique (device_id, barcode);

alter table public.hanger_scans
  add column if not exists scanned_at_kst timestamp without time zone
  generated always as (scanned_at at time zone 'Asia/Seoul') stored;

alter table public.scan_hangers
  add column if not exists completed_at_kst timestamp without time zone
  generated always as (completed_at at time zone 'Asia/Seoul') stored;

alter table public.photo_targets
  add column if not exists completed_at_kst timestamp without time zone
  generated always as (completed_at at time zone 'Asia/Seoul') stored;

alter table public.item_photos
  add column if not exists device_id uuid,
  add column if not exists created_at_kst timestamp without time zone
  generated always as (created_at at time zone 'Asia/Seoul') stored;

create index if not exists item_photos_device_id_idx
  on public.item_photos (device_id);

comment on constraint hanger_scans_device_barcode_key on public.hanger_scans is
  'Prevents the same normalized barcode from being counted twice by the same device across hangers.';
comment on column public.photo_targets.completed_at_kst is
  'Korea Standard Time representation of completed_at for Dashboard inspection and exports.';

notify pgrst, 'reload schema';
