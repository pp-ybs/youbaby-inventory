-- The item code on the public pages (owner, 2 Nov 2026: "insert something on
-- each image so the AI recognises it directly when they screenshot it … the
-- exact product id" · "make it nice, sensitive, small, so the images and dresses
-- stay visible"). Both public views gain ONE column at the end — `code` — and
-- nothing else changes (CREATE OR REPLACE keeps the grants). The chat assistant
-- (Sofia, HR project) looks the code up in the same public data.
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
          WHERE l.item_id = i.id), '{}'::jsonb) AS loc_selected,
    i.subcategory,
    i.session_type,
    i.code
   FROM showcase_section_item ssi
     JOIN inv_item i ON i.id = ssi.item_id
  WHERE COALESCE(i.archived, false) = false;

create or replace view public.v_show_items as
 SELECT id,
    name,
    photo_url,
    session_type,
    gender,
    kind,
    type,
    size,
    COALESCE(static_tags, '{}'::text[]) AS static_tags,
    COALESCE(times_selected, 0) AS times_selected,
    created_at,
    ARRAY( SELECT l.location
           FROM inv_item_location l
          WHERE l.item_id = i.id) AS branches,
    COALESCE(extra_photos, '[]'::jsonb) AS extra_photos,
    COALESCE(( SELECT jsonb_object_agg(l.location, COALESCE(l.times_selected, 0)) AS jsonb_object_agg
           FROM inv_item_location l
          WHERE l.item_id = i.id), '{}'::jsonb) AS loc_selected,
    subcategory,
    COALESCE(website_display, false) AS website_display,
    COALESCE(( SELECT jsonb_agg(jsonb_build_object('from', x.from_date, 'to', x.to_date, 'location', x.location, 'reason', x.reason, 'qty', x.qty, 'via', x.via) ORDER BY x.from_date) AS jsonb_agg
           FROM ( SELECT b.id,
                    b.from_date,
                    b.to_date,
                    b.location,
                    b.reason,
                    b.qty,
                    NULL::text AS via
                   FROM inv_item_block b
                  WHERE b.item_id = i.id
                UNION
                 SELECT b.id,
                    b.from_date,
                    b.to_date,
                    b.location,
                    b.reason,
                    b.qty,
                    s.code
                   FROM inv_theme_item ti
                     JOIN inv_item s ON s.id = ti.component_item_id AND ('shared_set'::text = ANY (s.static_tags))
                     JOIN inv_item_block b ON b.item_id = s.id
                  WHERE ti.theme_id = i.id
                UNION
                 SELECT b.id,
                    b.from_date,
                    b.to_date,
                    b.location,
                    b.reason,
                    b.qty,
                    t2.code
                   FROM inv_theme_item ti
                     JOIN inv_item s ON s.id = ti.component_item_id AND ('shared_set'::text = ANY (s.static_tags))
                     JOIN inv_theme_item ti2 ON ti2.component_item_id = s.id AND ti2.theme_id <> i.id
                     JOIN inv_item t2 ON t2.id = ti2.theme_id
                     JOIN inv_item_block b ON b.item_id = ti2.theme_id
                     JOIN inv_item_location sl ON sl.item_id = s.id AND sl.location = b.location
                  WHERE ti.theme_id = i.id
                UNION
                 SELECT b.id,
                    b.from_date,
                    b.to_date,
                    b.location,
                    b.reason,
                    b.qty,
                    t3.code
                   FROM inv_theme_item ti3
                     JOIN inv_item t3 ON t3.id = ti3.theme_id
                     JOIN inv_item_block b ON b.item_id = ti3.theme_id
                  WHERE ti3.component_item_id = i.id AND ('shared_set'::text = ANY (i.static_tags))) x
          WHERE x.to_date >= CURRENT_DATE), '[]'::jsonb) AS blocks,
    COALESCE(( SELECT jsonb_object_agg(l.location, GREATEST(COALESCE(l.quantity, 1), 1)) AS jsonb_object_agg
           FROM inv_item_location l
          WHERE l.item_id = i.id), '{}'::jsonb) AS loc_qty,
    code
   FROM inv_item i
  WHERE item_group = 'shoot'::text AND COALESCE(archived, false) = false;

-- SECURITY (found while adding the code, 2 Nov 2026): both views are owned by
-- postgres (they read past RLS) and anon + authenticated held INSERT / UPDATE /
-- DELETE / TRUNCATE on them. v_show_items is a one-table view, so it was
-- auto-updatable: anyone with the public anon key (it is in the page source)
-- could rename, re-photo, insert or delete shoot items through it. The app only
-- ever SELECTs from these views (index.html: 3 reads, 0 writes). Read-only now.
revoke insert, update, delete, truncate, references, trigger on public.v_show_items from anon, authenticated;
revoke insert, update, delete, truncate, references, trigger on public.v_show_links from anon, authenticated;
grant select on public.v_show_items, public.v_show_links to anon, authenticated;
