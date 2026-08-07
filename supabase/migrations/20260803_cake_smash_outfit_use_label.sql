-- 2026-08-03 — Cake Smash outfits: "can the baby smash in this?"
--
-- Stored on inv_item.subcategory (the existing Style field), values:
--   'Smash-safe'        — can be worn into the cake
--   'Not for smashing'  — before-the-smash portraits only, must stay clean
-- NULL means "not classified yet" and deliberately shows no label at all.
--
-- 1) v_show_links did not carry subcategory/session_type, so the label was
--    invisible on hand-curated showcase sections — precisely where customers
--    browse outfits. Appended at the END so existing column order is untouched.
-- 2) The option list lives in the app_settings taxonomy, which OVERRIDES the
--    JS defaults on load, so it has to be added there too or the dropdown
--    stays empty for Cake Smash.

create or replace view public.v_show_links as
 SELECT ssi.id,
    ssi.section_id,
    COALESCE(ssi.sort, 0) AS sort,
    i.id AS item_id,
    i.name,
    i.photo_url,
    i.size,
    i.gender,
    i.kind,
    i.type,
    i.extra_photos,
    COALESCE(i.static_tags, '{}'::text[]) AS static_tags,
    COALESCE(( SELECT jsonb_object_agg(l.location, COALESCE(l.times_selected, 0)) AS jsonb_object_agg
           FROM inv_item_location l
          WHERE (l.item_id = i.id)), '{}'::jsonb) AS loc_selected,
    i.subcategory,
    i.session_type
   FROM (showcase_section_item ssi
     JOIN inv_item i ON ((i.id = ssi.item_id)))
  WHERE (COALESCE(i.archived, false) = false);

update app_settings
set value = jsonb_set(value, '{styleOpts,Cake Smash}',
                      '["Smash-safe","Not for smashing"]'::jsonb, true)
where key = 'taxonomy';
