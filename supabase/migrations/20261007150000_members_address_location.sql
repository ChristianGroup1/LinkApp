-- Optional street address and map pin for served members.
-- Safe to run more than once. Do not apply automatically; run this on the
-- database before using the new fields in the app.

alter table public.members
  add column if not exists address text,
  add column if not exists latitude double precision,
  add column if not exists longitude double precision;

alter table public.members
  drop constraint if exists members_location_pair_check;

alter table public.members
  add constraint members_location_pair_check check (
    (latitude is null and longitude is null)
    or (
      latitude is not null
      and longitude is not null
      and latitude between -90 and 90
      and longitude between -180 and 180
    )
  );
