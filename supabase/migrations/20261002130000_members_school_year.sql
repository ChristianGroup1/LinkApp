alter table public.members
  add column if not exists school_year text;

-- Earlier app versions stored the school year in notes. Move known choices
-- into the dedicated field while preserving any unrelated notes.
update public.members
set school_year = notes,
    notes = null
where school_year is null
  and notes in (
    'أولى حضانة', 'ثانية حضانة',
    'أولى ابتدائي', 'ثانية ابتدائي', 'ثالثة ابتدائي', 'رابعة ابتدائي', 'خامسة ابتدائي', 'سادسة ابتدائي',
    'أولى إعدادي', 'ثانية إعدادي', 'ثالثة إعدادي',
    'أولى ثانوي', 'ثانية ثانوي', 'ثالثة ثانوي'
  );
