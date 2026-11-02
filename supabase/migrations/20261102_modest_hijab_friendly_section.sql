-- "Modest & Hijab-friendly" on every maternity outfits page (owner, 2 Nov 2026:
-- "Add a Modest / hijab-friendly section to the maternity page, starting from
-- the 11 long-sleeve and full-coverage pieces — yes"). 33 chats in 60 days asked
-- for hijab-friendly / modest dresses and got only the link: no such selection
-- existed. The pieces with long sleeves or full coverage, each studio showing
-- only what it has (inv_item_location). MA-OF-010 (off-shoulder) is left out —
-- off-shoulder is not hijab-friendly. Each item is also tagged "Modest" so the
-- chat assistant and later filters can find them.
-- Placed right after "Elegant" (the sections after it move down one place).
-- Idempotent: nothing happens on a board that already has the section.
do $$
declare
  b text;
  el int;
  sid uuid;
  codes text[] := array['MA-OF-002','MA-OF-003','MA-OF-004','MA-OF-008','MA-OF-014','MA-OF-075','MA-OF-104','MA-OF-132','MA-OF-139','MA-OF-277'];
  loc text;
  n int;
begin
  update inv_item set static_tags = array_append(coalesce(static_tags, '{}'), 'Modest'), updated_at = now()
   where code = any(codes) and not ('Modest' = any(coalesce(static_tags, '{}')));
  foreach b in array array['Dubai · Maternity · Outfits', 'Abu Dhabi · Maternity · Outfits', 'Doha · Maternity · Outfits'] loop
    if exists (select 1 from showcase_section where board = b and title = 'Modest & Hijab-friendly') then continue; end if;
    loc := split_part(b, ' · ', 1);
    select coalesce(max(sort) filter (where title ilike 'Elegant'), max(sort)) into el from showcase_section where board = b;
    update showcase_section set sort = sort + 1 where board = b and sort > el;
    insert into showcase_section (board, title, note, sort, dyn, rule)
    values (b, 'Modest & Hijab-friendly', 'Long sleeves & fuller coverage · you''re also welcome to bring your own dress', el + 1, false, null)
    returning id into sid;
    n := 0;
    insert into showcase_section_item (section_id, item_id, sort)
    select sid, i.id, row_number() over (order by i.code)
      from inv_item i
     where i.code = any(codes) and i.website_display and not coalesce(i.archived, false)
       and exists (select 1 from inv_item_location l where l.item_id = i.id and l.location = loc and l.status = 'available');
    get diagnostics n = row_count;
    raise notice '% → % pieces', b, n;
  end loop;
end $$;
