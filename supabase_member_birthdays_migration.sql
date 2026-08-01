-- Adds member birthdays for databases created before birth_date was introduced.
-- Safe to run more than once.
alter table public.members
  add column if not exists birth_date date;
