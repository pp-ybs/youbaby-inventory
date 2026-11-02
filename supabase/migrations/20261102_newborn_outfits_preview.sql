-- Newborn outfits, arranged for review (owner, 2 Nov 2026: "for newborn give me
-- the link for newborn outfits — maybe you can arrange them, make some cleaning,
-- categorize and show it in a presentable way that maybe we can present them as
-- well"). 256 newborn outfits existed, none on the website, none categorised.
-- New boards "<studio> · Newborn · Outfits · Boys|Girls" (Dubai, Abu Dhabi —
-- Doha holds only 2), one curated section per category, each studio showing
-- only what it has. Sofia's newborn links point at "Newborn · Themes & setups ·
-- Girls|Boys", so these boards appear ONLY on their own review link:
--   https://inventory.youbabystudio.com/#p=Dubai%20%C2%B7%20Newborn%20%C2%B7%20Outfits
-- Nothing on the items changes (website_display stays as it was). Idempotent.
do $$
declare
  loc text; g text; b text; rec record; sid uuid; srt int;
begin
  foreach loc in array array['Dubai', 'Abu Dhabi'] loop
    foreach g in array array['Boys', 'Girls'] loop
      b := loc || ' · Newborn · Outfits · ' || g;
      if exists (select 1 from showcase_section where board = b) then continue; end if;
      srt := 0;
      for rec in
        with o as (
          select i.id, lower(i.name) n, i.name, i.code
            from inv_item i
           where i.session_type = 'Newborn' and i.type = 'item' and i.kind = 'outfit' and not coalesce(i.archived, false)
             and (coalesce(i.gender, '') = '' or i.gender = case g when 'Boys' then 'Boy' else 'Girl' end)
             and exists (select 1 from inv_item_location l where l.item_id = i.id and l.location = loc and l.status = 'available')
        ),
        c as (
          select o.*, case
            when g = 'Boys' then case
              when n ~ '(robe|slipper)' then 'Robes & Slippers'
              when n ~ '(kandora|jallabiya|gulf|emirati|bish)' then 'Emirati & Traditional'
              when n ~ '(pilot|police|chef|apron|cowboy|superman|wizard|penguin|gnome|barista|starbucks)' then 'Costumes & Little Professions'
              when n ~ '(jersey|lakers|bulls|sports|boxing|racing|ferrari|leather|moto|camo|army|t-shirt|toucan|beach)' then 'Casual & Cool'
              when n ~ '(bear|bunny|rabbit|tiger|elephant|monster|animal|teddy)' then 'Cuddly Animals'
              when n ~ '(tuxedo|suit|suspender|vest|blazer|bow tie|gentleman|newsboy|three-piece|houndstooth|herringbone|plaid|shirt|gingham|linen|tweed|jacket|two-piece|button set|pants & hat|tee)' then 'Little Gentleman'
              when n ~ '(knit|romper|bonnet|cardigan|sleepy|cocoon|waffle|ribbed|fuzzy|hooded|onesie|swaddle|overall|nightcap|wrap)' then 'Cosy Knits & Bonnets'
              else 'More Outfits' end
            else case
              when n ~ '(robe|slipper|pajama)' then 'Robes & Slippers'
              when n ~ '(tulle|tutu|sequin|sparkle|princess|beaded|fairy|butterfly|angel wing|flamingo)' then 'Tulle, Tutu & Sparkle'
              when n ~ '(lace|ruffle|petal|pearl|delicate)' then 'Lace & Ruffles'
              when n ~ '(floral|daisy|leaf)' then 'Florals'
              when n ~ '(knit|cable|quilted|bonnet|bunny|bear|cat ear)' then 'Cosy Knits & Bonnets'
              else 'Summer & Fun' end
            end grp
          from o
        )
        select grp, array_agg(id order by name, code) ids,
               case grp
                 when 'Little Gentleman' then 1 when 'Tulle, Tutu & Sparkle' then 1
                 when 'Cosy Knits & Bonnets' then 2 when 'Lace & Ruffles' then 2
                 when 'Cuddly Animals' then 3 when 'Florals' then 3
                 when 'Costumes & Little Professions' then 4 when 'Summer & Fun' then 5
                 when 'Casual & Cool' then 5 when 'Emirati & Traditional' then 6
                 when 'Robes & Slippers' then 7 else 8 end ord
          from c group by grp order by ord
      loop
        srt := srt + 1;
        insert into showcase_section (board, title, note, sort, dyn, rule)
        values (b, rec.grp, null, srt, false, null) returning id into sid;
        insert into showcase_section_item (section_id, item_id, sort)
        select sid, x.id, x.ord::int from unnest(rec.ids) with ordinality as x(id, ord);
      end loop;
    end loop;
  end loop;
end $$;
