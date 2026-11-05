-- Backdrops as a shared resource ------------------------------------------------
-- One physical backdrop is a component of several themes (inv_theme_item), often
-- across sessions (a Cake Smash theme and a Sitter theme on the same printed
-- background). When a theme is blocked / booked for a date range, the backdrop it
-- uses is in use, so every OTHER theme that uses the same backdrop is unavailable
-- for that window too — and the backdrop itself reads as "in use".
--
-- This migration teaches the availability functions about that inheritance:
--   inv_is_shared_kind(kind)          which item kinds behave as shared backdrops
--   inv_stock / inv_units_out         small helpers (units at a branch / units blocked)
--   inv_shared_held / inv_shared_out  how many units of a backdrop booked themes hold
--   inv_is_blocked(item, on, loc)     now also true through a shared backdrop
--   inv_inherited_blocks(item)        the inherited windows, with who/what caused them
--   session_inventory()               `blocks` now carries inherited windows too
--                                     (flagged inherited:true, with via / source)

create or replace function public.inv_is_shared_kind(p_kind text)
returns boolean language sql immutable as $$
  select lower(coalesce(p_kind,'')) in ('backdrop','background','printed background','fabric/background');
$$;

create or replace function public.inv_stock(p_item uuid, p_location text default null)
returns numeric language sql stable security definer set search_path to 'public' as $$
  select coalesce(sum(greatest(coalesce(l.quantity,1),1)),0)
  from inv_item_location l
  where l.item_id = p_item and (p_location is null or l.location = p_location);
$$;

create or replace function public.inv_units_out(p_item uuid, p_on date, p_location text default null)
returns numeric language sql stable security definer set search_path to 'public' as $$
  select coalesce(sum(coalesce(b.qty, 999999)), 0)
  from inv_item_block b
  where b.item_id = p_item
    and coalesce(p_on, current_date) between b.from_date and b.to_date
    and (b.location is null or p_location is null or b.location = p_location);
$$;

-- Units of a backdrop held by blocked / booked themes on a date: one unit per
-- theme that is blocked that day. p_skip leaves one theme out of the count (the
-- theme we are evaluating — it is covered by its own direct block).
create or replace function public.inv_shared_held(p_backdrop uuid, p_on date, p_location text default null, p_skip uuid default null)
returns numeric language sql stable security definer set search_path to 'public' as $$
  select count(distinct ti.theme_id)::numeric
  from inv_theme_item ti
  join inv_item_block b on b.item_id = ti.theme_id
  join inv_item t on t.id = ti.theme_id and coalesce(t.archived, false) = false
  where ti.component_item_id = p_backdrop
    and (p_skip is null or ti.theme_id <> p_skip)
    and coalesce(p_on, current_date) between b.from_date and b.to_date
    and (b.location is null or p_location is null or b.location = p_location);
$$;

-- Is this backdrop fully out on the date? Its own blocks plus the themes holding
-- it, measured against its stock at the branch (same rule as a direct block).
create or replace function public.inv_shared_out(p_backdrop uuid, p_on date, p_location text default null, p_skip uuid default null)
returns boolean language sql stable security definer set search_path to 'public' as $$
  select (o.n > 0) and (o.n >= greatest(inv_stock(p_backdrop, p_location), 1))
  from (select inv_units_out(p_backdrop, p_on, p_location)
             + inv_shared_held(p_backdrop, p_on, p_location, p_skip) as n) o;
$$;

create or replace function public.inv_is_blocked(p_item uuid, p_on date, p_location text default null)
returns boolean language plpgsql stable security definer set search_path to 'public' as $$
declare
  v_on   date    := coalesce(p_on, current_date);
  v_out  numeric := inv_units_out(p_item, v_on, p_location);
  v_type text; v_kind text; v_bd uuid;
begin
  -- 1. direct blocks on the item itself (unchanged rule)
  if v_out > 0 and v_out >= greatest(inv_stock(p_item, p_location), 1) then
    return true;
  end if;
  select i.type, i.kind into v_type, v_kind from inv_item i where i.id = p_item;
  if v_type = 'theme' then
    -- 2. a theme is out when any backdrop it uses is out (a block on the backdrop
    --    itself, or another theme holding it that day)
    for v_bd in
      select ti.component_item_id
      from inv_theme_item ti
      join inv_item c on c.id = ti.component_item_id
      where ti.theme_id = p_item
        and inv_is_shared_kind(c.kind)
        and coalesce(c.archived, false) = false
    loop
      if inv_shared_out(v_bd, v_on, p_location, p_item) then return true; end if;
    end loop;
  elsif inv_is_shared_kind(v_kind) then
    -- 3. a backdrop is out when the themes using it hold every unit
    return inv_shared_out(p_item, v_on, p_location, null);
  end if;
  return false;
end $$;

-- Every inherited window for one item (or for all items when p_item is null),
-- live or upcoming. item_id is the item that inherits the block; source_* is the
-- block that causes it; via_* is the shared backdrop the two are connected by.
create or replace function public.inv_inherited_blocks(p_item uuid default null)
returns table(
  item_id uuid, block_id uuid, from_date date, to_date date, location text,
  reason text, note text, qty integer,
  via_id uuid, via_name text, via_code text,
  source_id uuid, source_name text, source_code text, source_type text,
  label text)
language sql stable security definer set search_path to 'public' as $$
  with shared as (
    select ti.theme_id, ti.component_item_id as backdrop_id
    from inv_theme_item ti
    join inv_item c on c.id = ti.component_item_id
    join inv_item t on t.id = ti.theme_id
    where inv_is_shared_kind(c.kind)
      and coalesce(c.archived, false) = false
      and coalesce(t.archived, false) = false
  ),
  live as (
    select b.* from inv_item_block b where b.to_date >= current_date
  ),
  why as (
    select 'other_branch' as reason, 'at another branch' as txt union all
    select 'repair',   'in repair'       union all
    select 'cleaning', 'being cleaned'   union all
    select 'reserved', 'reserved'        union all
    select 'other',    'unavailable'
  )
  -- 1. theme T inherits a block set directly on its backdrop B
  select s.theme_id, b.id, b.from_date, b.to_date, b.location, b.reason, b.note, b.qty,
         s.backdrop_id, bi.name, bi.code,
         s.backdrop_id, bi.name, bi.code, 'backdrop',
         'Backdrop "' || bi.name || '" is ' || coalesce(w.txt, b.reason)
  from shared s
  join live b on b.item_id = s.backdrop_id
  join inv_item bi on bi.id = s.backdrop_id
  left join why w on w.reason = b.reason
  where p_item is null or s.theme_id = p_item
  union all
  -- 2. theme T inherits a block on another theme T2 that shares backdrop B
  select s.theme_id, b.id, b.from_date, b.to_date, b.location, b.reason, b.note, b.qty,
         s.backdrop_id, bi.name, bi.code,
         s2.theme_id, t2.name, t2.code, 'theme',
         'Backdrop "' || bi.name || '" in use by ' || t2.name || ' (' || coalesce(w.txt, b.reason) || ')'
  from shared s
  join shared s2 on s2.backdrop_id = s.backdrop_id and s2.theme_id <> s.theme_id
  join live b on b.item_id = s2.theme_id
  join inv_item bi on bi.id = s.backdrop_id
  join inv_item t2 on t2.id = s2.theme_id
  left join why w on w.reason = b.reason
  where p_item is null or s.theme_id = p_item
  union all
  -- 3. backdrop B inherits a block on any theme T that uses it
  select s.backdrop_id, b.id, b.from_date, b.to_date, b.location, b.reason, b.note, b.qty,
         null::uuid, null::text, null::text,
         s.theme_id, t.name, t.code, 'theme',
         'In use by ' || t.name || ' (' || coalesce(w.txt, b.reason) || ')'
  from shared s
  join live b on b.item_id = s.theme_id
  join inv_item t on t.id = s.theme_id
  left join why w on w.reason = b.reason
  where p_item is null or s.backdrop_id = p_item;
$$;

-- session_inventory(): same signature, `blocks` now also lists inherited windows.
-- Inherited entries carry inherited:true, via (backdrop), source (theme/backdrop
-- that is blocked), source_reason, and qty null (every backdrop is a single unit,
-- so a theme holding it takes the whole thing).
create or replace function public.session_inventory(p_limit integer default null, p_offset integer default 0)
returns table(id uuid, code text, type text, kind text, name text, session_type text, subcategory text, gender text, size text, color text, photo_url text, extra_photos jsonb, website_display boolean, condition text, times_selected integer, item_group text, notes text, created_at timestamp with time zone, acquired_on date, condition_logged_at timestamp with time zone, condition_logged_by text, locations jsonb, blocks jsonb)
language sql stable security definer set search_path to 'public' as $$
  with ib as (select * from inv_inherited_blocks(null))
  select
    i.id, i.code, i.type, i.kind, i.name, i.session_type, i.subcategory,
    i.gender, i.size, i.color, i.photo_url,
    coalesce(i.extra_photos, '[]'::jsonb) as extra_photos,
    i.website_display, i.condition,
    coalesce(i.times_selected, 0) as times_selected,
    i.item_group, i.notes,
    i.created_at,
    (select min(l.acquired_on) from inv_item_location l where l.item_id = i.id) as acquired_on,
    (select max(l.condition_logged_at) from inv_item_location l where l.item_id = i.id) as condition_logged_at,
    (select l.condition_logged_by from inv_item_location l
       where l.item_id = i.id and l.condition_logged_at is not null
       order by l.condition_logged_at desc limit 1) as condition_logged_by,
    coalesce((
      select jsonb_agg(
               jsonb_build_object(
                 'location',                     l.location,
                 'status',                       l.status,
                 'quantity',                     l.quantity,
                 'size',                         l.size,
                 'condition',                    l.condition,
                 'unit_conditions',              l.unit_conditions,
                 'condition_logged_at',          l.condition_logged_at,
                 'condition_logged_by',          l.condition_logged_by,
                 'times_selected',               coalesce(l.times_selected,0),
                 'last_condition_check_at_count', l.last_condition_check_at_count,
                 'booked_until',                 l.booked_until
               ) order by l.location)
      from inv_item_location l
      where l.item_id = i.id
    ), '[]'::jsonb) as locations,
    coalesce((
      select jsonb_agg(x.j order by x.f)
      from (
        select b.from_date as f,
               jsonb_build_object(
                 'from', b.from_date, 'to', b.to_date,
                 'location', b.location, 'reason', b.reason, 'note', b.note,
                 'qty', b.qty) as j
        from inv_item_block b
        where b.item_id = i.id and b.to_date >= current_date
        union all
        select ib.from_date,
               jsonb_build_object(
                 'from', ib.from_date, 'to', ib.to_date,
                 'location', ib.location, 'reason', 'shared_backdrop', 'note', ib.label,
                 'qty', null,
                 'inherited', true,
                 'via', ib.via_name, 'via_code', ib.via_code,
                 'source', ib.source_name, 'source_code', ib.source_code,
                 'source_type', ib.source_type, 'source_reason', ib.reason)
        from ib
        where ib.item_id = i.id
      ) x
    ), '[]'::jsonb) as blocks
  from inv_item i
  where i.item_group = 'shoot'
    and coalesce(i.archived, false) = false
    and coalesce(i.origin, '') <> 'custom'
  order by i.created_at nulls last, i.id
  offset coalesce(p_offset, 0)
  limit p_limit;
$$;

grant execute on function public.inv_is_shared_kind(text) to anon, authenticated;
grant execute on function public.inv_stock(uuid, text) to anon, authenticated;
grant execute on function public.inv_units_out(uuid, date, text) to anon, authenticated;
grant execute on function public.inv_shared_held(uuid, date, text, uuid) to anon, authenticated;
grant execute on function public.inv_shared_out(uuid, date, text, uuid) to anon, authenticated;
grant execute on function public.inv_is_blocked(uuid, date, text) to anon, authenticated;
grant execute on function public.inv_inherited_blocks(uuid) to anon, authenticated;
grant execute on function public.session_inventory(integer, integer) to anon, authenticated;

-- Backdrop sub-types (editable from Settings → sub-types → backdrop)
update app_settings
   set value = jsonb_set(value, '{subtypeOpts,backdrop}',
               '["Plain colour","Printed","Fabric / curtain","Textured","Floral","Wooden","Scenic","Cutout set","Seasonal"]'::jsonb, true),
       updated_at = now()
 where key = 'taxonomy' and not (coalesce(value->'subtypeOpts','{}'::jsonb) ? 'backdrop');
