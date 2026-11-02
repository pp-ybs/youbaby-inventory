-- Newborn wraps, for review (owner, 2 Nov 2026: "I want to show them that
-- wrapping can be done in almost any colour, because we have all the colours
-- available — not only the white one … maybe they think wrap is too simple but
-- actually it is minimalistic and beautiful"). 86 wraps in 28 colours were in
-- the inventory (Dubai) and none was on the website; the 40 wrapped setups show
-- one photo each. Board "Dubai · Newborn · Wraps": the wrapped setups first,
-- then every wrap by colour family. Its own review link only:
--   https://inventory.youbabystudio.com/#p=Dubai%20%C2%B7%20Newborn%20%C2%B7%20Wraps
-- Nothing on the items changes. Idempotent.
do $$
declare
  b text := 'Dubai · Newborn · Wraps';
  rec record; sid uuid; srt int := 1;
begin
  if exists (select 1 from showcase_section where board = b) then return; end if;
  insert into showcase_section (board, title, note, sort, dyn, rule)
  values (b, 'Wrapped Setups', 'Minimal, soft and timeless — and every setup can be wrapped in any colour below', srt, false, null) returning id into sid;
  insert into showcase_section_item (section_id, item_id, sort)
  select sid, x.id, x.ord::int from unnest(array(
      select i.id from inv_item i
       where i.session_type = 'Newborn' and i.type = 'theme' and i.name ilike '%wrap%' and not coalesce(i.archived, false)
         and exists (select 1 from inv_item_location l where l.item_id = i.id and l.location = 'Dubai')
       order by coalesce(i.times_selected, 0) desc, i.code)) with ordinality as x(id, ord);
  for rec in
    with w as (
      select i.id, i.code, lower(split_part(coalesce(nullif(i.color, ''), i.name), ',', 1)) c1, i.color
        from inv_item i
       where i.kind = 'wrap' and not coalesce(i.archived, false)
         and exists (select 1 from inv_item_location l where l.item_id = i.id and l.location = 'Dubai' and l.status = 'available')
    ),
    f as (
      select w.*, case
        when c1 ~ '(multi|print|pattern)' then 'Mixed & Prints'
        when c1 ~ '(white|cream|ivory)' then 'Whites & Creams'
        when c1 ~ '(beige|tan|brown|taupe|camel|nude)' then 'Warm Neutrals'
        when c1 ~ '(pink|blush|rose)' then 'Pinks & Blush'
        when c1 ~ '(lavender|purple|lilac)' then 'Lavender'
        when c1 ~ '(navy|blue)' then 'Blues'
        when c1 ~ '(green|sage|mint|olive|teal)' then 'Greens'
        when c1 ~ '(yellow|gold|mustard)' then 'Yellows & Golds'
        when c1 ~ '(red|burgundy|wine)' then 'Reds'
        when c1 ~ '(grey|gray|black|charcoal)' then 'Greys & Black'
        else 'Mixed & Prints' end fam
      from w
    )
    select fam, array_agg(id order by color, code) ids,
           case fam when 'Whites & Creams' then 1 when 'Warm Neutrals' then 2 when 'Pinks & Blush' then 3 when 'Lavender' then 4
                    when 'Blues' then 5 when 'Greens' then 6 when 'Yellows & Golds' then 7 when 'Reds' then 8
                    when 'Greys & Black' then 9 else 10 end ord
      from f group by fam order by ord
  loop
    srt := srt + 1;
    insert into showcase_section (board, title, note, sort, dyn, rule)
    values (b, 'Wraps · ' || rec.fam, null, srt, false, null) returning id into sid;
    insert into showcase_section_item (section_id, item_id, sort)
    select sid, x.id, x.ord::int from unnest(rec.ids) with ordinality as x(id, ord);
  end loop;
end $$;
