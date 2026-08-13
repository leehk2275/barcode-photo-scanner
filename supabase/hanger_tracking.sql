-- Test-only hanger progress tracking for the barcode photo scanner.
-- The public client uses a random per-device UUID in the x-device-id header.

create table if not exists public.scan_hangers (
  id bigint generated always as identity primary key,
  device_id uuid not null,
  hanger_number integer not null check (hanger_number > 0),
  status text not null default 'active'
    check (status in ('active', 'completed')),
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  constraint scan_hangers_device_number_key unique (device_id, hanger_number),
  constraint scan_hangers_id_device_key unique (id, device_id),
  constraint scan_hangers_completion_check check (
    (status = 'active' and completed_at is null)
    or (status = 'completed' and completed_at is not null)
  )
);

create unique index if not exists scan_hangers_one_active_per_device_idx
  on public.scan_hangers (device_id)
  where status = 'active';

create index if not exists scan_hangers_device_status_number_idx
  on public.scan_hangers (device_id, status, hanger_number desc);

create table if not exists public.hanger_scans (
  id bigint generated always as identity primary key,
  hanger_id bigint not null,
  device_id uuid not null,
  barcode text not null check (char_length(barcode) between 1 and 128),
  target_id bigint
    references public.photo_targets(id) on delete set null,
  is_target boolean not null default false,
  photo_saved boolean not null default false,
  scanned_at timestamptz not null default now(),
  constraint hanger_scans_hanger_device_fkey
    foreign key (hanger_id, device_id)
    references public.scan_hangers(id, device_id)
    on delete cascade
);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'scan_hangers_id_device_key'
      and conrelid = 'public.scan_hangers'::regclass
  ) then
    alter table public.scan_hangers
      add constraint scan_hangers_id_device_key unique (id, device_id);
  end if;
end
$$;

alter table public.hanger_scans
  drop constraint if exists hanger_scans_hanger_id_fkey;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'hanger_scans_hanger_device_fkey'
      and conrelid = 'public.hanger_scans'::regclass
  ) then
    alter table public.hanger_scans
      add constraint hanger_scans_hanger_device_fkey
      foreign key (hanger_id, device_id)
      references public.scan_hangers(id, device_id)
      on delete cascade;
  end if;
end
$$;

create index if not exists hanger_scans_device_hanger_id_idx
  on public.hanger_scans (device_id, hanger_id, id desc);

drop index if exists public.hanger_scans_hanger_id_idx;

create index if not exists hanger_scans_hanger_device_idx
  on public.hanger_scans (hanger_id, device_id);

create index if not exists hanger_scans_target_id_idx
  on public.hanger_scans (target_id);

alter table public.item_photos
  add column if not exists hanger_scan_id bigint;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'item_photos_hanger_scan_id_fkey'
      and conrelid = 'public.item_photos'::regclass
  ) then
    alter table public.item_photos
      add constraint item_photos_hanger_scan_id_fkey
      foreign key (hanger_scan_id)
      references public.hanger_scans(id)
      on delete set null;
  end if;
end
$$;

create index if not exists item_photos_hanger_scan_id_idx
  on public.item_photos (hanger_scan_id);

alter table public.scan_hangers enable row level security;
alter table public.hanger_scans enable row level security;

drop policy if exists "sandbox device can read own hangers" on public.scan_hangers;
create policy "sandbox device can read own hangers"
  on public.scan_hangers for select to anon
  using (
    device_id::text = ((select current_setting('request.headers', true))::jsonb ->> 'x-device-id')
  );

drop policy if exists "sandbox device can create own hangers" on public.scan_hangers;
create policy "sandbox device can create own hangers"
  on public.scan_hangers for insert to anon
  with check (
    device_id::text = ((select current_setting('request.headers', true))::jsonb ->> 'x-device-id')
  );

drop policy if exists "sandbox device can complete own hangers" on public.scan_hangers;
create policy "sandbox device can complete own hangers"
  on public.scan_hangers for update to anon
  using (
    device_id::text = ((select current_setting('request.headers', true))::jsonb ->> 'x-device-id')
  )
  with check (
    device_id::text = ((select current_setting('request.headers', true))::jsonb ->> 'x-device-id')
  );

drop policy if exists "sandbox device can read own hanger scans" on public.hanger_scans;
create policy "sandbox device can read own hanger scans"
  on public.hanger_scans for select to anon
  using (
    device_id::text = ((select current_setting('request.headers', true))::jsonb ->> 'x-device-id')
  );

drop policy if exists "sandbox device can create own hanger scans" on public.hanger_scans;
create policy "sandbox device can create own hanger scans"
  on public.hanger_scans for insert to anon
  with check (
    device_id::text = ((select current_setting('request.headers', true))::jsonb ->> 'x-device-id')
  );

drop policy if exists "sandbox device can update own hanger scans" on public.hanger_scans;
create policy "sandbox device can update own hanger scans"
  on public.hanger_scans for update to anon
  using (
    device_id::text = ((select current_setting('request.headers', true))::jsonb ->> 'x-device-id')
  )
  with check (
    device_id::text = ((select current_setting('request.headers', true))::jsonb ->> 'x-device-id')
  );

drop policy if exists "sandbox device can delete own hanger scans" on public.hanger_scans;
create policy "sandbox device can delete own hanger scans"
  on public.hanger_scans for delete to anon
  using (
    device_id::text = ((select current_setting('request.headers', true))::jsonb ->> 'x-device-id')
  );

grant usage on schema public to anon;
grant select, insert, update on table public.scan_hangers to anon;
grant select, insert, update, delete on table public.hanger_scans to anon;
grant usage, select on sequence public.scan_hangers_id_seq to anon;
grant usage, select on sequence public.hanger_scans_id_seq to anon;
grant update (hanger_scan_id) on table public.item_photos to anon;

comment on table public.scan_hangers is
  'Test-only persistent hanger checkpoints, isolated by a client-generated device UUID.';
comment on table public.hanger_scans is
  'Test-only barcode scans grouped under a hanger checkpoint.';

notify pgrst, 'reload schema';
